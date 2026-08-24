"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { DocumentPlateReview, DocumentPlateReviewStatus } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { formatDateTime } from "@/lib/utils";
import {
  Badge,
  Button,
  CellText,
  DataTable,
  Drawer,
  FilterChips,
  InfoRow,
  StatCard,
  TableCard,
  TableToolbar,
  type FilterChip,
  type Tone,
} from "@/components/ui";
import { CheckCircle2, FileWarning, ShieldCheck, XCircle } from "lucide-react";

/** Bốn trạng thái thật của phiếu — bản thiết kế gốc bỏ sót MATCHED (phiếu khớp
    biển tự động, không cần duyệt tay) nên phải bổ sung nhãn và tông màu riêng. */
const LABELS: Record<DocumentPlateReviewStatus, string> = {
  REVIEW_REQUIRED: "Chờ xác nhận",
  APPROVED: "Đã chấp nhận",
  REJECTED: "Đã từ chối",
  MATCHED: "Tự động khớp",
};

const STATUS_ORDER: DocumentPlateReviewStatus[] = [
  "REVIEW_REQUIRED",
  "APPROVED",
  "REJECTED",
  "MATCHED",
];

function reviewTone(status: DocumentPlateReviewStatus): Tone {
  if (status === "APPROVED" || status === "MATCHED") return "success";
  if (status === "REJECTED") return "danger";
  return "warning";
}

type EmptyByStatus = Record<DocumentPlateReviewStatus, DocumentPlateReview[]>;
const EMPTY_BY_STATUS: EmptyByStatus = {
  REVIEW_REQUIRED: [],
  APPROVED: [],
  REJECTED: [],
  MATCHED: [],
};

export default function DocumentReviewsPage() {
  const { showToast } = useToast();
  /* API chỉ lọc theo đúng một trạng thái mỗi lần gọi (không có "tất cả"), nên
     để dựng đủ 4 thẻ số liệu + chip theo đúng bản thiết kế, tải song song cả
     bốn trạng thái rồi lọc ở trình duyệt — không đổi hành vi duyệt/từ chối/xem
     ảnh, chỉ đổi cách nạp danh sách hiển thị. */
  const [byStatus, setByStatus] = useState<EmptyByStatus>(EMPTY_BY_STATUS);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<"all" | DocumentPlateReviewStatus>("REVIEW_REQUIRED");
  const [searchQuery, setSearchQuery] = useState("");
  const [selected, setSelected] = useState<DocumentPlateReview | null>(null);
  const [note, setNote] = useState("");
  const [acting, setActing] = useState(false);
  const [imageObjectUrl, setImageObjectUrl] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [reviewRequired, approved, rejected, matched] = await Promise.all([
        safeFleetApi.documentPlateReviews("REVIEW_REQUIRED"),
        safeFleetApi.documentPlateReviews("APPROVED"),
        safeFleetApi.documentPlateReviews("REJECTED"),
        safeFleetApi.documentPlateReviews("MATCHED"),
      ]);
      setByStatus({ REVIEW_REQUIRED: reviewRequired, APPROVED: approved, REJECTED: rejected, MATCHED: matched });
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không tải được phiếu chờ xác nhận.", "error");
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    let cancelled = false;
    let objectUrl: string | null = null;
    setImageObjectUrl(null);
    if (selected?.imageUrl) {
      safeFleetApi
        .documentPlateReviewImage(selected.id)
        .then((blob) => {
          if (cancelled) return;
          objectUrl = URL.createObjectURL(blob);
          setImageObjectUrl(objectUrl);
        })
        .catch(() => {
          if (!cancelled) showToast("Không tải được ảnh phiếu đối chiếu.", "error");
        });
    }
    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [selected, showToast]);

  const decide = async (decision: "approve" | "reject") => {
    if (!selected) return;
    setActing(true);
    try {
      if (decision === "approve") {
        await safeFleetApi.approveDocumentPlateReview(selected.id, note);
        showToast("Đã xác nhận phiếu và trả kết quả về ứng dụng.", "success");
      } else {
        await safeFleetApi.rejectDocumentPlateReview(selected.id, note);
        showToast("Đã từ chối phiếu lệch biển số.", "success");
      }
      setSelected(null);
      setNote("");
      await load();
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không cập nhật được phiếu.", "error");
    } finally {
      setActing(false);
    }
  };

  const allItems = useMemo(
    () => STATUS_ORDER.flatMap((key) => byStatus[key]),
    [byStatus]
  );

  const items = statusFilter === "all" ? allItems : byStatus[statusFilter];

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return items;
    return items.filter((item) =>
      (item.voucherNumber?.toLowerCase().includes(q) ?? false) ||
      item.driverName.toLowerCase().includes(q) ||
      (item.tripCode?.toLowerCase().includes(q) ?? false) ||
      (item.projectAddress?.toLowerCase().includes(q) ?? false) ||
      (item.expectedVehiclePlate?.toLowerCase().includes(q) ?? false) ||
      (item.recognizedVehiclePlate?.toLowerCase().includes(q) ?? false)
    );
  }, [items, searchQuery]);

  /* Chip lọc chỉ hiện trạng thái thực sự có phiếu, luôn có "Tất cả" đứng đầu */
  const statusChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "all", label: "Tất cả", count: allItems.length }];
    STATUS_ORDER.forEach((key) => {
      const count = byStatus[key].length;
      if (count > 0) chips.push({ key, label: LABELS[key], count });
    });
    return chips;
  }, [byStatus, allItems.length]);

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Phiếu chờ duyệt"
          value={byStatus.REVIEW_REQUIRED.length}
          icon={FileWarning}
          delta="cần xử lý hôm nay"
          delay={0}
        />
        <StatCard
          label="Đã duyệt"
          value={byStatus.APPROVED.length}
          icon={CheckCircle2}
          tone="success"
          onClick={() => setStatusFilter(statusFilter === "APPROVED" ? "all" : "APPROVED")}
          active={statusFilter === "APPROVED"}
          delay={70}
        />
        <StatCard
          label="Từ chối"
          value={byStatus.REJECTED.length}
          icon={XCircle}
          tone="danger"
          deltaTone="danger"
          delta="yêu cầu làm lại"
          onClick={() => setStatusFilter(statusFilter === "REJECTED" ? "all" : "REJECTED")}
          active={statusFilter === "REJECTED"}
          delay={140}
        />
        <StatCard
          label="Tự động khớp"
          value={byStatus.MATCHED.length}
          icon={ShieldCheck}
          tone="info"
          delta="không cần duyệt tay"
          onClick={() => setStatusFilter(statusFilter === "MATCHED" ? "all" : "MATCHED")}
          active={statusFilter === "MATCHED"}
          delay={210}
        />
      </div>

      {/* ===== Thẻ bảng: thanh công cụ + bảng dạng thẻ ===== */}
      <TableCard
        toolbar={
          <TableToolbar
            search={{
              value: searchQuery,
              onChange: setSearchQuery,
              placeholder: "Mã phiếu, biển OCR, công trình…",
            }}
            filters={
              <FilterChips
                items={statusChips}
                value={statusFilter}
                onChange={(k) => setStatusFilter(k as "all" | DocumentPlateReviewStatus)}
              />
            }
          />
        }
      >
        <DataTable
          grid="1.1fr 1.2fr 1.3fr 1.2fr 1fr"
          columns={["Mã phiếu", "Biển OCR ↔ Xe giao", "Tài xế & chuyến", "Công trình", "Trạng thái"]}
          loading={loading}
          empty={{
            icon: ShieldCheck,
            title: "Không tìm thấy phiếu",
            description: "Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng.",
          }}
          rows={filtered.map((item) => {
            const expected = item.expectedVehiclePlate || "Chưa gán";
            const recognized = item.recognizedVehiclePlate || "Không đọc được";
            const matched =
              Boolean(item.expectedVehiclePlate) &&
              Boolean(item.recognizedVehiclePlate) &&
              item.expectedVehiclePlate!.trim().toUpperCase() === item.recognizedVehiclePlate!.trim().toUpperCase();

            return {
              key: item.id,
              onClick: () => {
                setSelected(item);
                setNote(item.reviewNote || "");
              },
              cells: [
                <CellText
                  key="voucher"
                  mono
                  strong
                  text={item.voucherNumber || `#${item.id}`}
                  sub={formatDateTime(item.createdAt)}
                />,
                <CellText
                  key="plate"
                  mono
                  text={`${recognized} ${matched ? "=" : "≠"} ${expected}`}
                  sub={matched ? "khớp biển số" : "lệch biển số — cần đối chiếu"}
                  color={matched ? undefined : "var(--sf-danger)"}
                />,
                <CellText
                  key="driver"
                  text={item.driverName}
                  sub={item.tripCode || "Không có chuyến đang chạy"}
                />,
                <CellText key="project" text={item.projectAddress || "—"} sub={item.voucherDate || undefined} />,
                <Badge key="status" tone={reviewTone(item.reviewStatus)} dot size="sm">
                  {LABELS[item.reviewStatus].toUpperCase()}
                </Badge>,
              ],
            };
          })}
        />
      </TableCard>

      {/* ===== Panel đối chiếu & duyệt ===== */}
      <Drawer
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        title={selected ? `Đối chiếu phiếu ${selected.voucherNumber || `#${selected.id}`}` : ""}
        subtitle={selected?.driverName}
        width="lg"
        footer={
          selected?.reviewStatus === "REVIEW_REQUIRED" ? (
            <div className="flex w-full gap-2">
              <Button variant="danger" icon={XCircle} loading={acting} onClick={() => void decide("reject")} className="flex-1">Từ chối</Button>
              <Button icon={CheckCircle2} loading={acting} onClick={() => void decide("approve")} className="flex-1">Xác nhận hợp lệ</Button>
            </div>
          ) : (
            <Button variant="outline" onClick={() => setSelected(null)}>Đóng</Button>
          )
        }
      >
        {selected && (
          <div className="space-y-5">
            <div className="overflow-hidden rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-inset)]">
              {imageObjectUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={imageObjectUrl} alt="Ảnh phiếu cần đối chiếu" className="max-h-[420px] w-full object-contain" />
              ) : (
                <div className="grid h-52 place-items-center text-sm text-sf-text-muted">Đang tải ảnh phiếu…</div>
              )}
            </div>
            <div className="rounded-[var(--sf-r-md)] border border-[var(--sf-warning)] bg-[var(--sf-warning-soft)] p-4">
              <p className="font-extrabold text-[var(--sf-warning)]">{selected.reviewReason || "Biển số cần kiểm tra"}</p>
              <p className="mt-1 text-sm text-sf-text-secondary">Chỉ xác nhận nếu ảnh đúng chuyến của tài xế hoặc có lý do đổi xe hợp lệ.</p>
            </div>
            <div>
              <InfoRow label="Tài xế" value={selected.driverName} />
              <InfoRow label="Xe cố định" value={selected.expectedVehiclePlate || "Chưa gán"} />
              <InfoRow label="Biển số OCR" value={selected.recognizedVehiclePlate || "Không đọc được"} />
              <InfoRow label="Mã chuyến" value={selected.tripCode || "Không có chuyến đang hoạt động"} />
              <InfoRow label="Ngày phiếu" value={selected.voucherDate || "—"} />
              <InfoRow label="Công trình" value={selected.projectAddress || "—"} />
            </div>
            <label className="block">
              <span className="mb-1.5 block text-sm font-bold text-sf-text">Ghi chú xác nhận</span>
              <textarea
                value={note}
                onChange={(event) => setNote(event.target.value)}
                maxLength={500}
                disabled={selected.reviewStatus !== "REVIEW_REQUIRED"}
                placeholder="Ví dụ: Điều phối đổi xe tạm thời theo lệnh số…"
                className="min-h-24 w-full rounded-[var(--sf-r-sm)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] p-3 text-sm text-sf-text outline-none focus:border-[var(--sf-primary)] disabled:opacity-60"
              />
            </label>
          </div>
        )}
      </Drawer>
    </div>
  );
}
