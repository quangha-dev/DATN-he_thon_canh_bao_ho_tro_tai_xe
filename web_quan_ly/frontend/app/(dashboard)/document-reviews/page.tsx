"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { DocumentPlateReview, DocumentPlateReviewStatus } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { formatDateTime } from "@/lib/utils";
import {
  Badge,
  Button,
  Drawer,
  EmptyState,
  IconButton,
  InfoRow,
  Segmented,
  SkeletonRows,
  Table,
  TableShell,
  Td,
  Tr,
} from "@/components/ui";
import { CheckCircle2, Eye, FileWarning, ShieldCheck, XCircle } from "lucide-react";

const FILTERS: DocumentPlateReviewStatus[] = [
  "REVIEW_REQUIRED",
  "APPROVED",
  "REJECTED",
];

const LABELS: Record<DocumentPlateReviewStatus, string> = {
  REVIEW_REQUIRED: "Chờ xác nhận",
  APPROVED: "Đã chấp nhận",
  REJECTED: "Đã từ chối",
  MATCHED: "Tự động khớp",
};

function reviewTone(status: DocumentPlateReviewStatus) {
  if (status === "APPROVED" || status === "MATCHED") return "success" as const;
  if (status === "REJECTED") return "danger" as const;
  return "warning" as const;
}

export default function DocumentReviewsPage() {
  const { showToast } = useToast();
  const [status, setStatus] = useState<DocumentPlateReviewStatus>("REVIEW_REQUIRED");
  const [items, setItems] = useState<DocumentPlateReview[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<DocumentPlateReview | null>(null);
  const [note, setNote] = useState("");
  const [acting, setActing] = useState(false);
  const [imageObjectUrl, setImageObjectUrl] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setItems(await safeFleetApi.documentPlateReviews(status));
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không tải được phiếu chờ xác nhận.", "error");
    } finally {
      setLoading(false);
    }
  }, [showToast, status]);

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

  const mismatchCount = useMemo(
    () => items.filter((item) => item.expectedVehiclePlate !== item.recognizedVehiclePlate).length,
    [items]
  );

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

  return (
    <div className="space-y-5">
      <div className="grid gap-3 md:grid-cols-2">
        <div className="rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] p-5">
          <div className="flex items-center gap-3">
            <FileWarning className="h-8 w-8 text-[var(--sf-warning)]" />
            <div>
              <p className="text-2xl font-extrabold text-sf-text">{items.length}</p>
              <p className="text-sm text-sf-text-muted">Phiếu trong trạng thái đang chọn</p>
            </div>
          </div>
        </div>
        <div className="rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] p-5">
          <div className="flex items-center gap-3">
            <ShieldCheck className="h-8 w-8 text-[var(--sf-primary)]" />
            <div>
              <p className="text-2xl font-extrabold text-sf-text">{mismatchCount}</p>
              <p className="text-sm text-sf-text-muted">Biển OCR khác xe cố định</p>
            </div>
          </div>
        </div>
      </div>

      <Segmented
        value={status}
        onChange={(value) => setStatus(value as DocumentPlateReviewStatus)}
        options={FILTERS.map((value) => ({ value, label: LABELS[value] }))}
      />

      <TableShell loading={loading}>
        <Table head={["Tài xế", "Biển số cố định", "Biển số OCR", "Chuyến", "Phiếu", "Trạng thái", ""]}>
          {loading && items.length === 0 ? (
            <SkeletonRows rows={5} cols={7} />
          ) : items.length === 0 ? (
            <tr>
              <Td colSpan={7}>
                <EmptyState
                  icon={ShieldCheck}
                  title="Không có phiếu cần xử lý"
                  description="Các phiếu có biển số khớp được xác nhận tự động."
                />
              </Td>
            </tr>
          ) : (
            items.map((item) => (
              <Tr key={item.id} onClick={() => { setSelected(item); setNote(item.reviewNote || ""); }}>
                <Td>
                  <p className="font-bold text-sf-text">{item.driverName}</p>
                  <p className="text-xs text-sf-text-muted">{formatDateTime(item.createdAt)}</p>
                </Td>
                <Td><span className="font-extrabold text-sf-text">{item.expectedVehiclePlate || "Chưa gán"}</span></Td>
                <Td><span className="font-extrabold text-[var(--sf-danger)]">{item.recognizedVehiclePlate || "Không đọc được"}</span></Td>
                <Td>{item.tripCode || "Không có chuyến đang chạy"}</Td>
                <Td>{item.voucherNumber || "—"}</Td>
                <Td><Badge tone={reviewTone(item.reviewStatus)}>{LABELS[item.reviewStatus]}</Badge></Td>
                <Td align="center">
                  <IconButton icon={Eye} label="Xem và xác nhận" onClick={(event) => { event.stopPropagation(); setSelected(item); setNote(item.reviewNote || ""); }} />
                </Td>
              </Tr>
            ))
          )}
        </Table>
      </TableShell>

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
