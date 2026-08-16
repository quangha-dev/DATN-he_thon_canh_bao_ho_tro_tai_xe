"use client";

import { useEffect, useState, useMemo } from "react";
import MapView from "@/components/map/MapView";
import { Vehicle, FloodPoint, Incident } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { useAuth } from "@/context/AuthContext";
import {
  cn,
  VEHICLE_STATUS_LABELS,
  FLOOD_SEVERITY_LABELS,
  INCIDENT_STATUS_LABELS,
} from "@/lib/utils";
import { AnimatePresence, motion } from "framer-motion";
import {
  Search,
  ChevronLeft,
  ChevronRight,
  Phone,
  MessageSquare,
  Siren,
  X,
  Truck,
  Droplets,
  Gauge,
  AlertTriangle,
  Route as RouteIcon,
  MapPin,
} from "lucide-react";
import {
  Badge,
  Button,
  EmptyState,
  IconButton,
  InfoRow,
  Segmented,
  StatusDot,
  TONE,
  toneOf,
} from "@/components/ui";

type DetailItem =
  | { type: "vehicle"; data: Vehicle }
  | { type: "flood"; data: FloodPoint }
  | { type: "incident"; data: Incident };

const FILTERS = ["all", "running", "alert", "maintenance", "offline"] as const;
type FilterKey = (typeof FILTERS)[number];

const FILTER_LABELS: Record<FilterKey, string> = {
  all: "Tất cả",
  running: "Đang chạy",
  alert: "Cảnh báo",
  maintenance: "Bảo trì",
  offline: "Mất GPS",
};

export default function RealtimeMapPage() {
  const { showToast } = useToast();
  const { user } = useAuth();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [activeFilter, setActiveFilter] = useState<FilterKey>("all");
  const [isLeftPanelOpen, setIsLeftPanelOpen] = useState(true);
  const [selectedItem, setSelectedItem] = useState<DetailItem | null>(null);
  const [acceptingIncidentId, setAcceptingIncidentId] = useState<string | null>(null);

  const handleAcceptIncident = async (incident: Incident) => {
    setAcceptingIncidentId(incident.id);
    try {
      const updated = await safeFleetApi.acceptIncident(incident.id);
      setIncidents((current) => current.map((item) => item.id === updated.id ? updated : item));
      setSelectedItem({ type: "incident", data: updated });
      showToast("Đã tiếp nhận sự cố.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể tiếp nhận sự cố.", "error");
    } finally {
      setAcceptingIncidentId(null);
    }
  };

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const [vehicleData, floodData, incidentData] = await Promise.all([
          safeFleetApi.vehicles(),
          safeFleetApi.floodPoints(),
          safeFleetApi.incidents(),
        ]);
        if (cancelled) return;
        setVehicles(vehicleData);
        setFloodPoints(floodData);
        setIncidents(incidentData);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "Không tải được dữ liệu bản đồ.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };
    void load();

    const onRealtime = () => void load();
    window.addEventListener("safefleet:realtime", onRealtime);
    return () => {
      cancelled = true;
      window.removeEventListener("safefleet:realtime", onRealtime);
    };
  }, [showToast]);

  const filteredVehicles = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return vehicles.filter((v) => {
      if (activeFilter === "running" && v.status !== "running") return false;
      if (activeFilter === "offline" && v.status !== "offline") return false;
      if (activeFilter === "alert" && v.totalAlerts === 0) return false;
      if (activeFilter === "maintenance" && v.status !== "maintenance") return false;
      if (!q) return true;
      return (
        v.plate.toLowerCase().includes(q) ||
        (v.currentDriverName?.toLowerCase().includes(q) ?? false) ||
        v.type.toLowerCase().includes(q)
      );
    });
  }, [vehicles, activeFilter, searchQuery]);

  const counts = useMemo(
    () => ({
      all: vehicles.length,
      running: vehicles.filter((v) => v.status === "running").length,
      alert: vehicles.filter((v) => v.totalAlerts > 0).length,
      maintenance: vehicles.filter((v) => v.status === "maintenance").length,
      offline: vehicles.filter((v) => v.status === "offline").length,
    }),
    [vehicles]
  );

  const detailIcon =
    selectedItem?.type === "vehicle"
      ? Truck
      : selectedItem?.type === "flood"
        ? Droplets
        : Siren;
  const detailTone =
    selectedItem?.type === "incident"
      ? "danger"
      : selectedItem?.type === "flood"
        ? "accent"
        : "primary";
  const canAcceptIncident = user?.role === "ADMIN" || user?.role === "DISPATCHER";

  return (
    <div className="relative flex h-[calc(100vh-68px)] w-full overflow-hidden bg-[var(--sf-bg-inset)]">
      {/* ===== Bản đồ ===== */}
      <div className="sf-map-dark absolute inset-0 z-0">
        <MapView
          vehicles={filteredVehicles}
          floodPoints={floodPoints}
          incidents={incidents}
          onVehicleClick={(v) => setSelectedItem({ type: "vehicle", data: v })}
          onFloodPointClick={(p) => setSelectedItem({ type: "flood", data: p })}
          onIncidentClick={(i) => setSelectedItem({ type: "incident", data: i })}
          selectedVehicleId={selectedItem?.type === "vehicle" ? selectedItem.data.id : null}
        />
      </div>

      {/* ===== Tìm kiếm + bộ lọc nổi ===== */}
      <div
        className={cn(
          "pointer-events-none absolute right-4 top-4 z-10 flex flex-col gap-2 transition-[left] duration-[var(--sf-dur-base)]",
          isLeftPanelOpen ? "left-4 md:left-[22.5rem]" : "left-4 md:left-[4.5rem]"
        )}
      >
        <div className="pointer-events-auto flex w-full max-w-xl gap-2">
          <div className="sf-glass-panel relative flex-1">
            <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-sf-text-muted" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Tìm xe, tài xế, loại xe…"
              className="w-full border-none bg-transparent py-3 pl-11 pr-4 text-[13.5px] font-medium text-sf-text placeholder:text-sf-text-muted focus:outline-none"
            />
          </div>
          {isLoading && (
            <span className="sf-glass-panel flex items-center gap-2 px-3.5 text-[12.5px] font-bold text-sf-text-muted">
              <StatusDot tone="warning" pulse /> Đang tải…
            </span>
          )}
        </div>

        <div className="pointer-events-auto max-w-full overflow-x-auto">
          <Segmented
            value={activeFilter}
            onChange={setActiveFilter}
            options={FILTERS.map((f) => ({
              value: f,
              label: FILTER_LABELS[f],
              count: counts[f],
            }))}
            size="sm"
            className="shadow-[var(--sf-shadow-md)]"
          />
        </div>
      </div>

      {/* ===== Panel trái: danh sách xe ===== */}
      <div className="pointer-events-none absolute bottom-4 left-4 top-4 z-10 flex items-stretch">
        <AnimatePresence initial={false}>
          {isLeftPanelOpen && (
            <motion.div
              initial={{ opacity: 0, x: -300 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -300 }}
              transition={{ type: "spring", stiffness: 320, damping: 32 }}
              className="sf-glass-panel pointer-events-auto flex w-72 flex-col overflow-hidden"
            >
              <div className="flex flex-shrink-0 items-center justify-between border-b border-[var(--sf-border)] px-4 py-3">
                <div>
                  <h3 className="text-[13.5px] font-extrabold text-sf-text">Đội xe</h3>
                  <p className="mt-0.5 text-[12px] text-sf-text-muted">
                    Hiển thị {filteredVehicles.length}/{vehicles.length} xe
                  </p>
                </div>
                <StatusDot tone={isLoading ? "warning" : "success"} pulse />
              </div>

              <div className="min-h-0 flex-1 overflow-y-auto">
                {filteredVehicles.length === 0 ? (
                  <EmptyState
                    icon={Truck}
                    title="Không có xe phù hợp"
                    description="Thử đổi từ khóa hoặc bộ lọc."
                    compact
                  />
                ) : (
                  filteredVehicles.map((vehicle) => {
                    const active =
                      selectedItem?.type === "vehicle" && selectedItem.data.id === vehicle.id;
                    const tone = toneOf(vehicle.status);
                    return (
                      <button
                        key={vehicle.id}
                        onClick={() => setSelectedItem({ type: "vehicle", data: vehicle })}
                        className={cn(
                          "flex w-full items-center gap-3 border-b border-[var(--sf-border-light)] px-4 py-3 text-left transition-colors last:border-0 cursor-pointer",
                          active
                            ? "bg-[var(--sf-primary-soft)]"
                            : "hover:bg-[var(--sf-bg-inset)]"
                        )}
                      >
                        <span className="relative flex-shrink-0">
                          <span
                            className="grid h-8 w-8 place-items-center rounded-[var(--sf-r-xs)]"
                            style={{ background: TONE[tone].bg, color: TONE[tone].fg }}
                          >
                            <Truck className="h-4 w-4" />
                          </span>
                          {vehicle.totalAlerts > 0 && (
                            <span
                              className="absolute -right-1 -top-1 h-2.5 w-2.5 animate-sf-pulse-dot rounded-full border-2"
                              style={{
                                background: "var(--sf-danger)",
                                borderColor: "var(--sf-bg-card)",
                              }}
                            />
                          )}
                        </span>

                        <span className="min-w-0 flex-1">
                          <span className="flex items-center justify-between gap-2">
                            <span className="truncate text-[12.5px] font-extrabold text-sf-text">
                              {vehicle.plate}
                            </span>
                            <span className="sf-tnum flex-shrink-0 text-[12px] font-bold text-sf-text-muted">
                              {vehicle.status === "running"
                                ? `${vehicle.currentSpeed} km/h`
                                : "Dừng"}
                            </span>
                          </span>
                          <span className="mt-0.5 block truncate text-[12px] text-sf-text-muted">
                            {vehicle.currentDriverName || "Chưa giao xe"}
                          </span>
                        </span>
                      </button>
                    );
                  })
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        <div className="pointer-events-auto ml-2 flex items-center">
          <button
            type="button"
            onClick={() => setIsLeftPanelOpen(!isLeftPanelOpen)}
            aria-label={isLeftPanelOpen ? "Ẩn danh sách xe" : "Hiện danh sách xe"}
            className="sf-glass-panel grid h-11 w-7 place-items-center text-sf-text-muted transition-colors hover:text-sf-text cursor-pointer"
          >
            {isLeftPanelOpen ? (
              <ChevronLeft className="h-4 w-4" />
            ) : (
              <ChevronRight className="h-4 w-4" />
            )}
          </button>
        </div>
      </div>

      {/* ===== Panel phải: chi tiết ===== */}
      <AnimatePresence>
        {selectedItem && (
          <motion.aside
            initial={{ opacity: 0, x: 340 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 340 }}
            transition={{ type: "spring", stiffness: 320, damping: 32 }}
            className="sf-glass-panel absolute bottom-4 right-4 top-4 z-20 flex w-80 flex-col overflow-hidden"
          >
            <div className="flex flex-shrink-0 items-center justify-between border-b border-[var(--sf-border)] px-4 py-3.5">
              <h3 className="flex items-center gap-2 text-[13.5px] font-extrabold text-sf-text">
                {(() => {
                  const Icon = detailIcon;
                  return (
                    <Icon
                      className={cn(
                        "h-4 w-4",
                        selectedItem.type === "incident" && "animate-sf-breathe"
                      )}
                      style={{ color: TONE[detailTone].fg }}
                    />
                  );
                })()}
                Chi tiết
              </h3>
              <IconButton icon={X} label="Đóng" size="sm" onClick={() => setSelectedItem(null)} />
            </div>

            <div className="min-h-0 flex-1 space-y-4 overflow-y-auto p-4">
              {/* --- Xe --- */}
              {selectedItem.type === "vehicle" && (
                <>
                  <div>
                    <h4 className="text-[20px] font-black leading-none tracking-tight text-sf-text">
                      {selectedItem.data.plate}
                    </h4>
                    <p className="mt-1.5 text-[12.5px] text-sf-text-muted">
                      {selectedItem.data.brand} {selectedItem.data.model} ·{" "}
                      {selectedItem.data.type}
                    </p>
                    <Badge
                      tone={toneOf(selectedItem.data.status)}
                      className="mt-2.5"
                    >
                      <StatusDot
                        tone={toneOf(selectedItem.data.status)}
                        pulse={selectedItem.data.status === "running"}
                      />
                      {VEHICLE_STATUS_LABELS[selectedItem.data.status]}
                    </Badge>
                  </div>

                  {selectedItem.data.currentDriverName ? (
                    <div className="sf-inset p-3">
                      <div className="flex items-center justify-between">
                        <span className="text-[12.5px] font-semibold text-sf-text-muted">
                          Tài xế hiện tại
                        </span>
                        <span className="text-[12.5px] font-bold text-sf-text">
                          {selectedItem.data.currentDriverName}
                        </span>
                      </div>
                      <div className="mt-2.5 flex items-center justify-between border-t border-[var(--sf-border-light)] pt-2.5">
                        <span className="text-[12px] text-sf-text-muted">Liên hệ nhanh</span>
                        <span className="flex gap-1">
                          <IconButton
                            icon={Phone}
                            label="Gọi tài xế — chưa có số điện thoại"
                            size="sm"
                            tone="success"
                            disabled
                          />
                          <IconButton
                            icon={MessageSquare}
                            label="Nhắn tin"
                            size="sm"
                            tone="primary"
                            disabled
                          />
                        </span>
                      </div>
                      <p className="mt-2 text-[11.5px] text-sf-text-muted">
                        Gọi và nhắn tin chưa khả dụng vì API xe chưa cung cấp thông tin liên hệ.
                      </p>
                    </div>
                  ) : (
                    <div className="rounded-[var(--sf-r-md)] border border-dashed border-[var(--sf-border-strong)] p-3 text-center text-[12.5px] text-sf-text-muted">
                      Chưa giao xe cho tài xế nào
                    </div>
                  )}

                  <div className="grid grid-cols-2 gap-2.5">
                    <MetricBox
                      icon={Gauge}
                      label="Tốc độ hiện tại"
                      value={`${selectedItem.data.currentSpeed} km/h`}
                    />
                    <MetricBox
                      icon={AlertTriangle}
                      label="Cảnh báo"
                      value={`${selectedItem.data.totalAlerts} lần`}
                      danger={selectedItem.data.totalAlerts > 0}
                    />
                    <MetricBox
                      icon={RouteIcon}
                      label="Tổng km"
                      value={`${selectedItem.data.totalKm} km`}
                    />
                    <MetricBox
                      icon={Truck}
                      label="Số chuyến"
                      value={`${selectedItem.data.totalTrips}`}
                    />
                  </div>
                  <div className="sf-inset px-3.5 py-1">
                    <InfoRow
                      label="Vị trí GPS"
                      value={selectedItem.data.lat !== null && selectedItem.data.lng !== null
                        ? `${selectedItem.data.lat.toFixed(5)}, ${selectedItem.data.lng.toFixed(5)}`
                        : "Chưa có dữ liệu GPS"}
                    />
                    <InfoRow
                      label="Cập nhật GPS"
                      value={selectedItem.data.lastUpdated
                        ? new Date(selectedItem.data.lastUpdated).toLocaleString("vi-VN")
                        : "Chưa có dữ liệu"}
                    />
                  </div>
                </>
              )}

              {/* --- Điểm ngập --- */}
              {selectedItem.type === "flood" && (
                <>
                  <div>
                    <Badge tone="accent" solid>
                      Điểm ngập lụt
                    </Badge>
                    <h4 className="mt-2.5 text-[17px] font-extrabold leading-tight tracking-tight text-sf-text">
                      {selectedItem.data.location}
                    </h4>
                    <p className="mt-1.5 flex items-center gap-1.5 text-[12px] text-sf-text-muted">
                      <MapPin className="h-3 w-3" />
                      <span className="sf-tnum font-mono">
                        {selectedItem.data.lat.toFixed(5)}, {selectedItem.data.lng.toFixed(5)}
                      </span>
                    </p>
                  </div>

                  <div className="sf-inset px-3.5 py-1">
                    <InfoRow
                      label="Mức độ ngập"
                      value={
                        <Badge tone={toneOf(selectedItem.data.severity)} size="sm">
                          {FLOOD_SEVERITY_LABELS[selectedItem.data.severity]}
                        </Badge>
                      }
                    />
                    <InfoRow
                      label="Số báo cáo"
                      value={`${selectedItem.data.reportCount} người`}
                    />
                    <InfoRow
                      label="Độ tin cậy"
                      value={
                        <span style={{ color: "var(--sf-success)" }}>
                          {selectedItem.data.confidence}%
                        </span>
                      }
                    />
                    <InfoRow
                      label="Xe bị ảnh hưởng"
                      value={`${selectedItem.data.affectedVehicles} phương tiện`}
                    />
                  </div>
                </>
              )}

              {/* --- Sự cố --- */}
              {selectedItem.type === "incident" && (
                <>
                  <div>
                    <Badge tone="danger" solid icon={Siren}>
                      SOS khẩn cấp
                    </Badge>
                    <h4 className="mt-2.5 text-[17px] font-extrabold leading-tight tracking-tight text-sf-text">
                      Sự cố xe {selectedItem.data.vehiclePlate}
                    </h4>
                  </div>

                  <div className="sf-inset px-3.5 py-1">
                    <InfoRow label="Tài xế" value={selectedItem.data.driverName} />
                    <InfoRow label="Vị trí" value={selectedItem.data.location} />
                    <InfoRow
                      label="Trạng thái"
                      value={
                        <Badge tone={toneOf(selectedItem.data.status)} size="sm">
                          {INCIDENT_STATUS_LABELS[selectedItem.data.status]}
                        </Badge>
                      }
                    />
                  </div>

                  <Button
                    block
                    variant="danger"
                    size="sm"
                    icon={Siren}
                    loading={acceptingIncidentId === selectedItem.data.id}
                    disabled={selectedItem.data.status !== "open" || !canAcceptIncident}
                    title={!canAcceptIncident
                      ? "Chỉ điều phối viên được tiếp nhận sự cố tại màn hình này"
                      : undefined}
                    onClick={() => void handleAcceptIncident(selectedItem.data)}
                  >
                    {!canAcceptIncident
                      ? "Không có quyền tiếp nhận"
                      : selectedItem.data.status !== "open"
                        ? "Sự cố đã được tiếp nhận"
                        : "Tiếp nhận sự cố ngay"}
                  </Button>
                </>
              )}
            </div>
          </motion.aside>
        )}
      </AnimatePresence>
    </div>
  );
}

function MetricBox({
  icon: Icon,
  label,
  value,
  danger,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
  danger?: boolean;
}) {
  return (
    <div className="sf-inset p-3">
      <span className="flex items-center gap-1.5 text-[12px] font-semibold text-sf-text-muted">
        <Icon className="h-3 w-3" />
        {label}
      </span>
      <span
        className="sf-metric mt-1.5 block text-[15px]"
        style={danger ? { color: "var(--sf-danger)" } : undefined}
      >
        {value}
      </span>
    </div>
  );
}
