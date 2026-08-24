"use client";

import { useEffect, useState, useMemo } from "react";
import { Trip, TripStatus } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { formatDateTime, TRIP_STATUS_LABELS } from "@/lib/utils";
import {
  Badge,
  Button,
  CellProgress,
  CellText,
  DataTable,
  Drawer,
  FilterChips,
  InfoRow,
  Modal,
  ProgressBar,
  StatCard,
  TableCard,
  TableToolbar,
  toneOf,
  type FilterChip,
} from "@/components/ui";
import {
  Ban,
  Download,
  Navigation,
  Route,
  Siren,
  TriangleAlert,
} from "lucide-react";

/** "all" hoặc một trong năm trạng thái chuyến đi của backend */
type StatusFilter = "all" | TripStatus;

const RISK_LABELS: Record<string, string> = {
  low: "Thấp",
  medium: "Trung bình",
  high: "Cao",
  critical: "Nguy hiểm",
};

/** Backend không đặt tên tiếng Việt cho loại chuyến nên gán nhãn ở tầng hiển thị */
const TRIP_TYPE_LABELS: Record<string, string> = {
  delivery: "Giao hàng",
  passenger: "Hành khách",
  transfer: "Trung chuyển",
  return: "Chuyến về",
};

function formatTime(value?: string | null): string | null {
  if (!value) return null;
  return new Date(value).toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit" });
}

/** Nhãn ô tiến độ: API không trả sẵn câu mô tả nên suy ra từ các mốc giờ theo đúng vòng đời chuyến */
function progressLabel(trip: Trip): string {
  const scheduled = formatTime(trip.scheduledStart) ?? "—";
  if (trip.status === "completed") {
    return `Kết thúc ${formatTime(trip.actualEnd) ?? formatTime(trip.scheduledEnd) ?? "—"}`;
  }
  if (trip.status === "cancelled") {
    return trip.notes ? `Đã hủy · ${trip.notes}` : "Đã hủy chuyến";
  }
  if (trip.status === "pending") {
    return `Khởi hành ${scheduled}`;
  }
  const eta = formatTime(trip.eta);
  if (eta) return `KH ${scheduled} · ETA ${eta}`;
  const actual = formatTime(trip.actualStart);
  if (actual) return `KH ${scheduled} · thực tế ${actual}`;
  return `KH ${scheduled}`;
}

/** Tô màu thanh tiến độ theo rủi ro tuyến & độ trễ so với kế hoạch (lệch quá 10 phút coi là trễ) */
function progressTone(trip: Trip): "primary" | "warning" | "danger" {
  if (trip.status === "incident" || trip.riskLevel === "critical") return "danger";
  const compareTo = trip.actualStart || trip.eta;
  const isLate =
    Boolean(compareTo) &&
    Boolean(trip.scheduledStart) &&
    new Date(compareTo as string).getTime() - new Date(trip.scheduledStart).getTime() > 10 * 60 * 1000;
  if (trip.riskLevel === "high" || isLate) return "warning";
  return "primary";
}

export default function TripsPage() {
  const { showToast } = useToast();
  const [trips, setTrips] = useState<Trip[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [highRiskOnly, setHighRiskOnly] = useState(false);
  const [selected, setSelected] = useState<Trip | null>(null);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [cancelling, setCancelling] = useState(false);

  const cancelTrip = async () => {
    if (!selected || !cancelReason.trim()) {
      showToast("Vui lòng nhập lý do hủy chuyến.", "error");
      return;
    }
    setCancelling(true);
    try {
      const updated = await safeFleetApi.cancelTrip(selected.id, cancelReason.trim());
      setTrips((items) => items.map((item) => item.id === updated.id ? updated : item));
      setSelected(updated);
      setCancelOpen(false);
      setCancelReason("");
      showToast(`Đã hủy chuyến ${updated.code}.`, "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không hủy được chuyến.", "error");
    } finally {
      setCancelling(false);
    }
  };

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.trips();
        if (!cancelled) setTrips(data);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "Không tải được danh sách chuyến.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [showToast]);

  const stats = useMemo(
    () => ({
      total: trips.length,
      inProgress: trips.filter((t) => t.status === "in_progress").length,
      incident: trips.filter((t) => t.status === "incident").length,
      highRisk: trips.filter((t) => t.riskLevel === "high" || t.riskLevel === "critical").length,
    }),
    [trips]
  );

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return trips.filter((t) => {
      if (statusFilter !== "all" && t.status !== statusFilter) return false;
      if (highRiskOnly && !(t.riskLevel === "high" || t.riskLevel === "critical")) return false;
      if (!q) return true;
      return (
        t.code.toLowerCase().includes(q) ||
        t.vehiclePlate.toLowerCase().includes(q) ||
        t.driverName.toLowerCase().includes(q) ||
        t.origin.toLowerCase().includes(q) ||
        t.destination.toLowerCase().includes(q)
      );
    });
  }, [trips, searchQuery, statusFilter, highRiskOnly]);

  /* Chip lọc dựng theo đúng năm trạng thái chuyến của backend, kể cả "cancelled"
     mà bản thiết kế gốc bỏ sót — chỉ hiện chip có dữ liệu thật. */
  const statusChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "all", label: "Tất cả", count: trips.length }];
    (Object.keys(TRIP_STATUS_LABELS) as TripStatus[]).forEach((key) => {
      const count = trips.filter((t) => t.status === key).length;
      if (count > 0) chips.push({ key, label: TRIP_STATUS_LABELS[key], count });
    });
    return chips;
  }, [trips]);

  /* Chưa có API xuất danh sách nên dựng CSV ngay trên trình duyệt từ dữ liệu
     đã tải và đang lọc — không phát sinh lời gọi API mới. */
  const exportTrips = () => {
    if (filtered.length === 0) {
      showToast("Không có chuyến nào để xuất theo bộ lọc hiện tại.", "error");
      return;
    }
    const header = ["Mã chuyến", "Loại", "Điểm đi", "Điểm đến", "Tài xế", "Biển số", "Trạng thái", "Rủi ro", "Tiến độ (%)"];
    const rows = filtered.map((t) => [
      t.code,
      TRIP_TYPE_LABELS[t.type] || t.type,
      t.origin,
      t.destination,
      t.driverName,
      t.vehiclePlate,
      TRIP_STATUS_LABELS[t.status] || t.status,
      RISK_LABELS[t.riskLevel] || t.riskLevel,
      String(t.progress),
    ]);
    const csv = [header, ...rows]
      .map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(","))
      .join("\n");
    const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `chuyen-di-${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
    showToast(`Đã xuất ${filtered.length} chuyến ra tệp CSV.`, "success");
  };

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Tổng chuyến"
          value={stats.total}
          icon={Navigation}
          delta={`${stats.inProgress} đang chạy`}
          delay={0}
        />
        <StatCard
          label="Đang chạy"
          value={stats.inProgress}
          icon={Route}
          tone="primary"
          delta={stats.total ? `${Math.round((stats.inProgress / stats.total) * 100)}% tổng chuyến` : ""}
          onClick={() => setStatusFilter(statusFilter === "in_progress" ? "all" : "in_progress")}
          active={statusFilter === "in_progress"}
          delay={70}
        />
        <StatCard
          label="Gặp sự cố"
          value={stats.incident}
          icon={Siren}
          tone="danger"
          deltaTone="danger"
          delta="cần xử lý"
          onClick={() => setStatusFilter(statusFilter === "incident" ? "all" : "incident")}
          active={statusFilter === "incident"}
          delay={140}
        />
        <StatCard
          label="Rủi ro tuyến cao"
          value={stats.highRisk}
          icon={TriangleAlert}
          tone="warning"
          deltaTone="warning"
          delta="mức cao & nguy hiểm"
          onClick={() => setHighRiskOnly((v) => !v)}
          active={highRiskOnly}
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
              placeholder: "Mã chuyến, biển số, tài xế, điểm đi/đến…",
            }}
            filters={
              <FilterChips items={statusChips} value={statusFilter} onChange={(k) => setStatusFilter(k as StatusFilter)} />
            }
            action={
              <button type="button" className="sf-pill-primary" onClick={exportTrips}>
                <Download className="h-[17px] w-[17px]" />
                Xuất danh sách
              </button>
            }
          />
        }
      >
        <DataTable
          grid="1.2fr 1.3fr 1.2fr 1.3fr 1fr"
          columns={["Mã chuyến", "Hành trình", "Tài xế & xe", "Tiến độ", "Trạng thái"]}
          loading={isLoading}
          empty={{
            icon: Navigation,
            title: "Không tìm thấy chuyến đi",
            description: "Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng.",
          }}
          rows={filtered.map((trip) => ({
            key: trip.id,
            onClick: () => setSelected(trip),
            cells: [
              <CellText
                key="code"
                mono
                strong
                text={trip.code}
                sub={TRIP_TYPE_LABELS[trip.type] || trip.type}
              />,
              <CellText
                key="route"
                text={`${trip.origin} → ${trip.destination}`}
                sub={`${trip.totalKm} km${trip.waypoints.length ? ` · qua ${trip.waypoints.join(", ")}` : ""}`}
              />,
              <CellText key="driver" text={trip.driverName} sub={trip.vehiclePlate} subMono />,
              <CellProgress
                key="progress"
                label={progressLabel(trip)}
                percent={trip.progress}
                tone={progressTone(trip)}
              />,
              <Badge key="status" tone={toneOf(trip.status)} dot size="sm">
                {(TRIP_STATUS_LABELS[trip.status] || trip.status).toUpperCase()}
              </Badge>,
            ],
          }))}
        />
      </TableCard>

      {/* ===== Panel chi tiết ===== */}
      <Drawer
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        title={selected?.code ?? ""}
        subtitle={selected ? `${selected.origin} → ${selected.destination}` : undefined}
        width="lg"
        footer={
          <>
            {selected && !["completed", "cancelled"].includes(selected.status) && (
              <Button variant="outline" size="sm" icon={Ban} onClick={() => setCancelOpen(true)}>Hủy chuyến</Button>
            )}
            <Button variant="outline" size="sm" onClick={() => setSelected(null)}>Đóng</Button>
          </>
        }
      >
        {selected && (
          <div className="space-y-5">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={toneOf(selected.status)} solid>
                {TRIP_STATUS_LABELS[selected.status] || selected.status}
              </Badge>
              <Badge tone={toneOf(selected.riskLevel)}>
                Rủi ro {(RISK_LABELS[selected.riskLevel] || selected.riskLevel).toLowerCase()}
              </Badge>
            </div>

            <div>
              <p className="sf-eyebrow mb-2">Tiến độ hành trình</p>
              <ProgressBar
                value={selected.progress}
                tone={selected.status === "completed" ? "success" : "primary"}
                showLabel
              />
            </div>

            <div>
              <InfoRow label="Phương tiện" value={selected.vehiclePlate} />
              <InfoRow label="Tài xế" value={selected.driverName} />
              <InfoRow label="Điểm đi" value={selected.origin} />
              <InfoRow label="Điểm đến" value={selected.destination} />
              {selected.waypoints.length > 0 && (
                <InfoRow label="Điểm dừng" value={selected.waypoints.join(", ")} />
              )}
              <InfoRow
                label="Khởi hành dự kiến"
                value={selected.scheduledStart ? formatDateTime(selected.scheduledStart) : "—"}
              />
              <InfoRow
                label="Kết thúc dự kiến"
                value={selected.scheduledEnd ? formatDateTime(selected.scheduledEnd) : "—"}
              />
              {selected.actualStart && (
                <InfoRow label="Bắt đầu thực tế" value={formatDateTime(selected.actualStart)} />
              )}
              {selected.actualEnd && (
                <InfoRow label="Kết thúc thực tế" value={formatDateTime(selected.actualEnd)} />
              )}
              {selected.notes && <InfoRow label="Ghi chú" value={selected.notes} />}
            </div>
          </div>
        )}
      </Drawer>

      <Modal
        open={cancelOpen}
        onClose={() => !cancelling && setCancelOpen(false)}
        title={`Hủy chuyến ${selected?.code || ""}`}
        subtitle="Thao tác sẽ giải phóng tài xế và phương tiện đang được phân công."
        size="sm"
        footer={<><Button variant="outline" size="sm" disabled={cancelling} onClick={() => setCancelOpen(false)}>Quay lại</Button><Button variant="danger" size="sm" icon={Ban} loading={cancelling} onClick={() => void cancelTrip()}>Xác nhận hủy</Button></>}
      >
        <label className="space-y-1.5">
          <span className="text-xs font-bold text-sf-text-secondary">Lý do hủy *</span>
          <textarea className="sf-input min-h-28 w-full resize-y" maxLength={255} value={cancelReason} onChange={(event) => setCancelReason(event.target.value)} placeholder="Ví dụ: khách đổi lịch, phương tiện gặp sự cố…" />
        </label>
      </Modal>
    </div>
  );
}
