"use client";

import { useEffect, useState, useMemo } from "react";
import { Trip } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { formatDateTime, TRIP_STATUS_LABELS } from "@/lib/utils";
import {
  Badge,
  Button,
  Drawer,
  EmptyState,
  IconButton,
  InfoRow,
  Modal,
  ProgressBar,
  SearchInput,
  Segmented,
  Select,
  SkeletonRows,
  Stagger,
  StatCard,
  StatSkeletonGrid,
  StatusLabel,
  Table,
  TableShell,
  Td,
  Toolbar,
  Tr,
  toneOf,
} from "@/components/ui";
import {
  Navigation,
  Eye,
  Activity,
  CircleCheck,
  CircleDashed,
  Siren,
  TriangleAlert,
  ArrowRight,
  Ban,
} from "lucide-react";

const STATUS_FILTERS = [
  "all",
  "pending",
  "in_progress",
  "completed",
  "cancelled",
  "incident",
] as const;
type StatusFilter = (typeof STATUS_FILTERS)[number];

const RISK_LABELS: Record<string, string> = {
  low: "Thấp",
  medium: "Trung bình",
  high: "Cao",
  critical: "Nguy hiểm",
};

export default function TripsPage() {
  const { showToast } = useToast();
  const [trips, setTrips] = useState<Trip[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [riskFilter, setRiskFilter] = useState("all");
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
      in_progress: trips.filter((t) => t.status === "in_progress").length,
      pending: trips.filter((t) => t.status === "pending").length,
      completed: trips.filter((t) => t.status === "completed").length,
      incident: trips.filter((t) => t.status === "incident").length,
      highRisk: trips.filter((t) => t.riskLevel === "high" || t.riskLevel === "critical").length,
    }),
    [trips]
  );

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return trips.filter((t) => {
      if (statusFilter !== "all" && t.status !== statusFilter) return false;
      if (riskFilter !== "all" && t.riskLevel !== riskFilter) return false;
      if (!q) return true;
      return (
        t.code.toLowerCase().includes(q) ||
        t.vehiclePlate.toLowerCase().includes(q) ||
        t.driverName.toLowerCase().includes(q) ||
        t.origin.toLowerCase().includes(q) ||
        t.destination.toLowerCase().includes(q)
      );
    });
  }, [trips, searchQuery, statusFilter, riskFilter]);

  return (
    <div className="space-y-5">
      {/* ===== Thống kê ===== */}
      <Stagger className="grid grid-cols-2 gap-3.5 md:grid-cols-3 lg:grid-cols-6">
        {isLoading && trips.length === 0 ? (
          <StatSkeletonGrid count={6} />
        ) : (
          <>
            <StatCard label="Tổng chuyến" value={stats.total} icon={Navigation} tone="primary" />
            <StatCard
              label="Đang thực hiện"
              value={stats.in_progress}
              icon={Activity}
              tone="primary"
              onClick={() =>
                setStatusFilter(statusFilter === "in_progress" ? "all" : "in_progress")
              }
              active={statusFilter === "in_progress"}
            />
            <StatCard
              label="Chưa bắt đầu"
              value={stats.pending}
              icon={CircleDashed}
              tone="neutral"
              onClick={() => setStatusFilter(statusFilter === "pending" ? "all" : "pending")}
              active={statusFilter === "pending"}
            />
            <StatCard
              label="Đã hoàn thành"
              value={stats.completed}
              icon={CircleCheck}
              tone="success"
              onClick={() => setStatusFilter(statusFilter === "completed" ? "all" : "completed")}
              active={statusFilter === "completed"}
            />
            <StatCard
              label="Gặp sự cố"
              value={stats.incident}
              icon={Siren}
              tone="danger"
              pulse
              onClick={() => setStatusFilter(statusFilter === "incident" ? "all" : "incident")}
              active={statusFilter === "incident"}
            />
            <StatCard
              label="Tuyến rủi ro cao"
              value={stats.highRisk}
              icon={TriangleAlert}
              tone="accent"
              onClick={() => setRiskFilter(riskFilter === "high" ? "all" : "high")}
              active={riskFilter === "high"}
            />
          </>
        )}
      </Stagger>

      {/* ===== Thanh công cụ ===== */}
      <Toolbar>
        <SearchInput
          value={searchQuery}
          onChange={setSearchQuery}
          placeholder="Tìm mã chuyến, biển số, tài xế, điểm đi/đến…"
          className="sm:max-w-md"
        />
        <div className="flex flex-wrap items-center gap-2">
          <Select
            ariaLabel="Lọc theo mức rủi ro"
            value={riskFilter}
            onChange={setRiskFilter}
            options={[
              { value: "all", label: "Tất cả mức rủi ro" },
              ...Object.entries(RISK_LABELS).map(([value, label]) => ({
                value,
                label: `Rủi ro ${label.toLowerCase()}`,
              })),
            ]}
            className="min-w-[11rem]"
          />
          <Segmented
            value={statusFilter}
            onChange={setStatusFilter}
            options={STATUS_FILTERS.map((s) => ({
              value: s,
              label: s === "all" ? "Tất cả" : TRIP_STATUS_LABELS[s] || s,
            }))}
          />
        </div>
      </Toolbar>

      {/* ===== Bảng ===== */}
      <TableShell loading={isLoading}>
        <Table
          head={[
            "Mã chuyến",
            "Lộ trình",
            "Phương tiện",
            "Tài xế",
            "Khởi hành dự kiến",
            "Tiến độ",
            "Rủi ro",
            "Trạng thái",
            "",
          ]}
        >
          {isLoading && trips.length === 0 ? (
            <SkeletonRows rows={6} cols={9} />
          ) : filtered.length === 0 ? (
            <tr>
              <Td colSpan={9}>
                <EmptyState
                  icon={Navigation}
                  title="Không tìm thấy chuyến đi"
                  description="Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng."
                />
              </Td>
            </tr>
          ) : (
            filtered.map((trip) => (
              <Tr key={trip.id} onClick={() => setSelected(trip)}>
                <Td>
                  <span className="flex items-center gap-2.5">
                    <span
                      className="grid h-7 w-7 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)]"
                      style={{ background: "var(--sf-primary-soft)", color: "var(--sf-primary)" }}
                    >
                      <Navigation className="h-3.5 w-3.5" />
                    </span>
                    <span className="text-[13px] font-extrabold tracking-tight text-sf-text">
                      {trip.code}
                    </span>
                  </span>
                </Td>
                <Td>
                  <span className="flex items-center gap-1.5 font-semibold text-sf-text-secondary">
                    <span className="truncate">{trip.origin}</span>
                    <ArrowRight className="h-3 w-3 flex-shrink-0 text-sf-text-muted" />
                    <span className="truncate">{trip.destination}</span>
                  </span>
                </Td>
                <Td className="font-bold">{trip.vehiclePlate}</Td>
                <Td>{trip.driverName}</Td>
                <Td className="sf-tnum whitespace-nowrap">
                  {trip.scheduledStart ? formatDateTime(trip.scheduledStart) : "—"}
                </Td>
                <Td align="center">
                  <ProgressBar
                    className="mx-auto w-24"
                    value={trip.progress}
                    tone={trip.status === "completed" ? "success" : "primary"}
                    showLabel
                  />
                </Td>
                <Td align="center">
                  <Badge tone={toneOf(trip.riskLevel)} size="sm">
                    {RISK_LABELS[trip.riskLevel] || trip.riskLevel}
                  </Badge>
                </Td>
                <Td>
                  <StatusLabel
                    status={trip.status}
                    label={TRIP_STATUS_LABELS[trip.status] || trip.status}
                    pulse={trip.status === "in_progress" || trip.status === "incident"}
                  />
                </Td>
                <Td align="center">
                  <IconButton
                    icon={Eye}
                    label="Xem chi tiết"
                    size="sm"
                    tone="primary"
                    onClick={(e) => {
                      e.stopPropagation();
                      setSelected(trip);
                    }}
                  />
                </Td>
              </Tr>
            ))
          )}
        </Table>
      </TableShell>

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
