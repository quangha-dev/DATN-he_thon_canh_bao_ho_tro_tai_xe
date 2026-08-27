"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { cn, formatTimeAgo, ALERT_TYPE_LABELS } from "@/lib/utils";
import { safeFleetApi } from "@/lib/safeFleetApi";
import MapView from "@/components/map/MapView";
import { Alert, CommandCenterStats, FloodPoint, Incident, Trip, Vehicle } from "@/types";
import { useToast } from "@/context/ToastContext";
import { useAuth } from "@/context/AuthContext";
import {
  Badge,
  Button,
  Card,
  CardHeader,
  EmptyState,
  PeriodSelect,
  ProgressBar,
  ScoreRing,
  Segmented,
  Stagger,
  StatCard,
  StatSkeletonGrid,
  StatusDot,
  type Tone,
} from "@/components/ui";
import {
  Truck,
  AlertTriangle,
  Siren,
  Clock,
  WifiOff,
  Droplets,
  Phone,
  Eye,
  CheckCircle2,
  ChevronRight,
  Activity,
  Shield,
  Radio,
} from "lucide-react";

/* ==========================================================================
   CẤU HÌNH
   ========================================================================== */

const FILTERS = [
  { value: "all", label: "Tất cả" },
  { value: "running", label: "Đang chạy" },
  { value: "alert", label: "Có cảnh báo" },
  { value: "sos", label: "SOS" },
  { value: "flood", label: "Gần điểm ngập" },
  { value: "offline", label: "Mất GPS" },
] as const;

type FilterKey = (typeof FILTERS)[number]["value"];

const EMPTY_STATS: CommandCenterStats = {
  totalOperating: 0,
  alertsToday: 0,
  openSos: 0,
  driversNearOvertime: 0,
  vehiclesOffline: 0,
  activeFloodPoints: 0,
};

/**
 * Thẻ "Đang vận hành" được tô đặc màu thương hiệu — đúng một điểm nhấn màu
 * trên toàn màn hình, phần còn lại là thẻ trắng.
 */
function statCards(stats: CommandCenterStats) {
  return [
    { key: "operating", label: "Đang vận hành", value: stats.totalOperating, icon: Truck, tone: "primary" as Tone, hint: "Xe có tín hiệu trong 15 phút", filled: true },
    { key: "alerts", label: "Cảnh báo đang mở", value: stats.alertsToday, icon: AlertTriangle, tone: "accent" as Tone, hint: "Cần theo dõi và xử lý" },
    { key: "sos", label: "SOS đang mở", value: stats.openSos, icon: Siren, tone: "danger" as Tone, hint: "Ưu tiên cao nhất", pulse: true },
    { key: "overtime", label: "Tài xế gần quá giờ", value: stats.driversNearOvertime, icon: Clock, tone: "accent" as Tone, hint: "Sắp chạm giới hạn 4 giờ" },
    { key: "offline", label: "Xe mất kết nối", value: stats.vehiclesOffline, icon: WifiOff, tone: "neutral" as Tone, hint: "Không nhận được telemetry" },
    { key: "flood", label: "Điểm ngập hoạt động", value: stats.activeFloodPoints, icon: Droplets, tone: "primary" as Tone, hint: "Đang ảnh hưởng tuyến đường" },
  ];
}

interface PriorityItem {
  id: string;
  tone: Tone;
  title: string;
  subtitle: string;
  time: string;
  kind: "sos" | "critical" | "high";
  href: string;
  actionable: boolean;
}

function buildPriorityItems(incidents: Incident[], alerts: Alert[]): PriorityItem[] {
  const items: PriorityItem[] = [];

  incidents
    .filter((i) => i.status === "open" || i.status === "in_progress")
    .forEach((incident) => {
      items.push({
        id: `sos-${incident.id}`,
        tone: "danger",
        title: `Xe ${incident.vehiclePlate} gửi tín hiệu SOS`,
        subtitle: incident.location,
        time: formatTimeAgo(incident.timestamp),
        kind: "sos",
        href: `/incidents?id=${incident.id}`,
        actionable: incident.status === "open",
      });
    });

  alerts
    .filter((a) => a.severity === "critical" && a.status === "new")
    .forEach((alert) => {
      items.push({
        id: `crit-${alert.id}`,
        tone: "danger",
        title: `${alert.driverName} — ${(ALERT_TYPE_LABELS[alert.type] || alert.type).toLowerCase()}`,
        subtitle: alert.repeatCount ? `Lặp lại ${alert.repeatCount} lần` : alert.message,
        time: formatTimeAgo(alert.timestamp),
        kind: "critical",
        href: `/alerts?id=${alert.id}`,
        actionable: true,
      });
    });

  alerts
    .filter((a) => a.severity === "high" && a.status === "new")
    .slice(0, 4)
    .forEach((alert) => {
      items.push({
        id: `high-${alert.id}`,
        tone: "warning",
        title: `${ALERT_TYPE_LABELS[alert.type] || alert.type} · ${alert.vehiclePlate}`,
        subtitle: alert.message,
        time: formatTimeAgo(alert.timestamp),
        kind: "high",
        href: `/alerts?id=${alert.id}`,
        actionable: true,
      });
    });

  return items;
}

/* ==========================================================================
   TRANG
   ========================================================================== */

export default function CommandCenterPage() {
  const { showToast } = useToast();
  const { user } = useAuth();
  const [activeFilter, setActiveFilter] = useState<FilterKey>("all");
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [trips, setTrips] = useState<Trip[]>([]);
  const [stats, setStats] = useState<CommandCenterStats>(EMPTY_STATS);
  const [isLoading, setIsLoading] = useState(true);
  const [lastSync, setLastSync] = useState<Date | null>(null);
  const [period, setPeriod] = useState("week");
  const [busyPriorityId, setBusyPriorityId] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    let realtimeDebounce: ReturnType<typeof setTimeout> | null = null;

    const loadDashboard = async () => {
      try {
        const [vehicleData, alertData, incidentData, tripData, floodData, statData] =
          await Promise.all([
            safeFleetApi.vehicles(),
            safeFleetApi.safetyEvents(),
            safeFleetApi.incidents(),
            safeFleetApi.trips(),
            safeFleetApi.floodPoints(),
            safeFleetApi.dashboardStats(),
          ]);
        if (cancelled) return;
        setVehicles(vehicleData);
        setAlerts(alertData);
        setIncidents(incidentData);
        setTrips(tripData);
        setFloodPoints(floodData);
        setStats(statData);
        setLastSync(new Date());
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được dashboard.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    void loadDashboard();

    const onRealtime = () => {
      if (realtimeDebounce) clearTimeout(realtimeDebounce);
      realtimeDebounce = setTimeout(loadDashboard, 350);
    };
    window.addEventListener("safefleet:realtime", onRealtime);
    const pollingFallback = window.setInterval(loadDashboard, 30_000);

    return () => {
      cancelled = true;
      window.removeEventListener("safefleet:realtime", onRealtime);
      window.clearInterval(pollingFallback);
      if (realtimeDebounce) clearTimeout(realtimeDebounce);
    };
  }, [showToast]);

  const priorityItems = useMemo(() => buildPriorityItems(incidents, alerts), [incidents, alerts]);
  const activeTrips = useMemo(() => trips.filter((t) => t.status === "in_progress"), [trips]);
  const cards = useMemo(() => statCards(stats), [stats]);
  const openAlerts = useMemo(() => alerts.filter((a) => a.status === "new").length, [alerts]);
  const canAcceptIncident = user?.role === "ADMIN" || user?.role === "DISPATCHER";

  const handleAcceptPriority = async (item: PriorityItem) => {
    setBusyPriorityId(item.id);
    try {
      const [kind, id] = item.id.split("-");
      if (kind === "sos") {
        const updated = await safeFleetApi.acceptIncident(id);
        setIncidents((current) => current.map((incident) => incident.id === id ? updated : incident));
        showToast("Đã tiếp nhận sự cố.", "success");
      } else {
        const updated = await safeFleetApi.acknowledgeSafetyEvent(id);
        setAlerts((current) => current.map((alert) => alert.id === id ? updated : alert));
        showToast("Đã xác nhận cảnh báo.", "success");
      }
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể tiếp nhận mục này.", "error");
    } finally {
      setBusyPriorityId(null);
    }
  };

  const filteredVehicles = useMemo(() => {
    if (activeFilter === "running") return vehicles.filter((v) => v.status === "running");
    if (activeFilter === "alert") return vehicles.filter((v) => v.totalAlerts > 0);
    if (activeFilter === "offline") return vehicles.filter((v) => v.status === "offline");
    if (activeFilter === "sos") {
      const ids = new Set(
        incidents
          .filter((i) => i.status === "open" || i.status === "in_progress")
          .map((i) => i.vehicleId)
      );
      return vehicles.filter((v) => ids.has(v.id));
    }
    if (activeFilter === "flood") {
      return vehicles.filter((v) =>
        floodPoints.some(
          (p) => v.lat !== null && v.lng !== null
            && Math.abs(p.lat - v.lat) < 0.01
            && Math.abs(p.lng - v.lng) < 0.01
        )
      );
    }
    return vehicles;
  }, [activeFilter, floodPoints, incidents, vehicles]);

  const filterCounts = useMemo(
    () => ({
      all: vehicles.length,
      running: vehicles.filter((v) => v.status === "running").length,
      alert: vehicles.filter((v) => v.totalAlerts > 0).length,
      sos: incidents.filter((i) => i.status === "open" || i.status === "in_progress").length,
      flood: floodPoints.length,
      offline: vehicles.filter((v) => v.status === "offline").length,
    }),
    [vehicles, incidents, floodPoints]
  );

  /* Tài xế rủi ro cao — xếp theo số cảnh báo chưa xử lý */
  const riskyDrivers = useMemo(() => {
    return vehicles
      .filter((v) => v.currentDriverId)
      .map((v) => ({
        vehicle: v,
        driverName: v.currentDriverName ?? "Không rõ",
        alertCount: alerts.filter((a) => a.vehicleId === v.id && a.status !== "resolved").length,
      }))
      .filter((d) => d.alertCount > 0)
      .sort((a, b) => b.alertCount - a.alertCount)
      .slice(0, 5);
  }, [vehicles, alerts]);

  return (
    <div className="space-y-5">
      {/* ===== Thẻ thống kê ===== */}
      <Stagger className="grid grid-cols-2 gap-3.5 md:grid-cols-3 xl:grid-cols-6">
        {isLoading && vehicles.length === 0 ? (
          <StatSkeletonGrid count={6} />
        ) : (
          cards.map((c) => (
            <StatCard
              key={c.key}
              label={c.label}
              value={c.value}
              icon={c.icon}
              tone={c.tone}
              hint={c.hint}
              pulse={c.pulse}
              filled={c.filled}
              trailing={
                <PeriodSelect value={period} onChange={setPeriod} onFilled={c.filled} />
              }
            />
          ))
        )}
      </Stagger>

      {/* ===== Bản đồ + Việc cần xử lý ===== */}
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-3">
        <Card padding="none" className="xl:col-span-2">
          {/* Thanh lọc */}
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--sf-border)] px-4 py-3">
            <Segmented
              value={activeFilter}
              onChange={setActiveFilter}
              options={FILTERS.map((f) => ({
                value: f.value,
                label: f.label,
                count: filterCounts[f.value],
              }))}
              size="sm"
              className="max-w-full overflow-x-auto"
            />
            <span className="flex items-center gap-2 text-[12.5px] font-semibold text-sf-text-muted">
              <StatusDot tone={isLoading ? "warning" : "success"} pulse />
              {isLoading
                ? "Đang đồng bộ…"
                : lastSync
                  ? `Cập nhật ${lastSync.toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit", second: "2-digit" })}`
                  : "Sẵn sàng"}
            </span>
          </div>

          <div className="sf-map-dark relative h-[420px]">
            <MapView
              vehicles={filteredVehicles}
              floodPoints={floodPoints}
              incidents={incidents.filter(
                (i) => i.status === "open" || i.status === "in_progress"
              )}
            />

            {/* Chỉ số nổi trên bản đồ */}
            <div className="pointer-events-none absolute left-4 top-4 flex flex-wrap gap-2">
              <span className="sf-glass-panel pointer-events-auto flex items-center gap-2 px-3 py-1.5 text-[12.5px] font-bold text-sf-text">
                <Truck className="h-3.5 w-3.5 text-[var(--sf-primary)]" />
                <span className="sf-tnum">{filteredVehicles.length}</span> xe hiển thị
              </span>
              {openAlerts > 0 && (
                <span
                  className="sf-glass-panel pointer-events-auto flex items-center gap-2 px-3 py-1.5 text-[12.5px] font-bold"
                  style={{ color: "var(--sf-accent-hover)" }}
                >
                  <AlertTriangle className="h-3.5 w-3.5" />
                  <span className="sf-tnum">{openAlerts}</span> cảnh báo mở
                </span>
              )}
            </div>
          </div>
        </Card>

        {/* Việc cần xử lý */}
        <Card padding="none" className="flex flex-col">
          <div className="flex items-center justify-between gap-3 border-b border-[var(--sf-border)] px-4 py-3.5">
            <CardHeader
              title="Việc cần xử lý ngay"
              subtitle={`${priorityItems.length} mục ưu tiên`}
              icon={Radio}
            />
            {priorityItems.length > 0 && <StatusDot tone="danger" pulse />}
          </div>

          <div className="max-h-[24rem] min-h-0 flex-1 overflow-y-auto">
            {priorityItems.length === 0 ? (
              <EmptyState
                icon={CheckCircle2}
                title="Không có việc tồn đọng"
                description="Toàn bộ cảnh báo nghiêm trọng và SOS đã được xử lý."
              />
            ) : (
              priorityItems.map((item) => (
                <div
                  key={item.id}
                  className="group border-b border-[var(--sf-border-light)] border-l-[3px] px-4 py-3 transition-colors last:border-b-0 hover:bg-[var(--sf-bg-inset)]"
                  style={{
                    borderLeftColor:
                      item.tone === "danger" ? "var(--sf-danger)" : "var(--sf-accent)",
                  }}
                >
                  <div className="flex items-start justify-between gap-2">
                    <p
                      className="min-w-0 flex-1 text-[13px] font-bold leading-snug"
                      style={{
                        color:
                          item.tone === "danger" ? "var(--sf-danger)" : "var(--sf-accent-hover)",
                      }}
                    >
                      {item.title}
                    </p>
                    <span className="flex-shrink-0 text-[12px] font-semibold text-sf-text-muted">
                      {item.time}
                    </span>
                  </div>
                  <p className="mt-0.5 truncate text-[12.5px] text-sf-text-muted">
                    {item.subtitle}
                  </p>

                  <div className="mt-2.5 flex items-center gap-1.5">
                    <Link href={item.href}>
                      <Button size="xs" variant="subtle" icon={Eye}>
                        Xem
                      </Button>
                    </Link>
                    <Button
                      size="xs"
                      variant="outline"
                      icon={CheckCircle2}
                      loading={busyPriorityId === item.id}
                      disabled={item.kind === "sos" && (!canAcceptIncident || !item.actionable)}
                      title={item.kind === "sos"
                        ? !canAcceptIncident
                          ? "Chỉ điều phối viên được tiếp nhận sự cố tại màn hình này"
                          : !item.actionable
                            ? "Sự cố đã được tiếp nhận"
                            : undefined
                        : undefined}
                      onClick={() => void handleAcceptPriority(item)}
                    >
                      {item.kind === "sos"
                        ? !canAcceptIncident
                          ? "Không có quyền tiếp nhận"
                          : !item.actionable
                            ? "Đã tiếp nhận"
                            : "Tiếp nhận"
                        : "Tiếp nhận"}
                    </Button>
                    {item.kind === "sos" && (
                      <Button
                        size="xs"
                        variant="danger"
                        icon={Phone}
                        disabled
                        title="Chưa có số điện thoại trong dữ liệu sự cố"
                      >
                        Gọi — chưa có SĐT
                      </Button>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </Card>
      </div>

      {/* ===== Chuyến đang chạy + Tài xế rủi ro ===== */}
      <div className="grid grid-cols-1 gap-5 xl:grid-cols-3">
        <Card padding="none" className="xl:col-span-2">
          <div className="flex items-center justify-between gap-3 border-b border-[var(--sf-border)] px-4 py-3.5">
            <CardHeader
              title="Chuyến đang chạy"
              subtitle={`${activeTrips.length} chuyến đang thực hiện`}
              icon={Activity}
            />
            <Link href="/trips">
              <Button size="xs" variant="ghost" iconRight={ChevronRight}>
                Xem tất cả
              </Button>
            </Link>
          </div>

          {activeTrips.length === 0 ? (
            <EmptyState
              icon={Activity}
              title="Chưa có chuyến nào đang chạy"
              description="Các chuyến được giao sẽ hiển thị ở đây khi tài xế bắt đầu hành trình."
              compact
            />
          ) : (
            <div>
              {activeTrips.slice(0, 6).map((trip) => (
                <div
                  key={trip.id}
                  className="flex items-center gap-4 border-b border-[var(--sf-border-light)] px-4 py-3 transition-colors last:border-0 hover:bg-[var(--sf-bg-inset)]"
                >
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className="text-[13px] font-extrabold tracking-tight text-sf-text">
                        {trip.code}
                      </span>
                      <span className="text-[12.5px] font-semibold text-sf-text-muted">
                        · {trip.vehiclePlate}
                      </span>
                      {trip.riskLevel !== "low" && (
                        <Badge
                          tone={trip.riskLevel === "high" ? "danger" : "warning"}
                          size="sm"
                        >
                          {trip.riskLevel === "high" ? "Rủi ro cao" : "Cần theo dõi"}
                        </Badge>
                      )}
                    </div>
                    <p className="mt-0.5 truncate text-[12.5px] text-sf-text-muted">
                      {trip.origin} → {trip.destination}
                    </p>
                  </div>

                  <div className="w-28 flex-shrink-0">
                    <ProgressBar value={trip.progress} tone="primary" showLabel />
                  </div>
                </div>
              ))}
            </div>
          )}
        </Card>

        <Card padding="none">
          <div className="border-b border-[var(--sf-border)] px-4 py-3.5">
            <CardHeader
              title="Tài xế rủi ro cao"
              subtitle="Xếp theo số cảnh báo chưa xử lý"
              icon={Shield}
            />
          </div>

          {riskyDrivers.length === 0 ? (
            <EmptyState
              icon={Shield}
              title="Không có tài xế rủi ro"
              description="Chưa ghi nhận cảnh báo tồn đọng nào."
              compact
            />
          ) : (
            <div>
              {riskyDrivers.map((item, idx) => (
                <div
                  key={item.vehicle.id}
                  className="flex items-center gap-3 border-b border-[var(--sf-border-light)] px-4 py-3 transition-colors last:border-0 hover:bg-[var(--sf-bg-inset)]"
                >
                  <span
                    className={cn(
                      "sf-tnum grid h-6 w-6 flex-shrink-0 place-items-center rounded-full text-[12px] font-extrabold"
                    )}
                    style={{
                      background: idx === 0 ? "var(--sf-danger-soft)" : "var(--sf-bg-inset)",
                      color: idx === 0 ? "var(--sf-danger)" : "var(--sf-text-muted)",
                    }}
                  >
                    {idx + 1}
                  </span>

                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[13px] font-bold text-sf-text">
                      {item.driverName}
                    </p>
                    <p className="text-[12.5px] text-sf-text-muted">
                      {item.vehicle.plate} · {item.alertCount} cảnh báo
                    </p>
                  </div>

                  <ScoreRing
                    score={Math.max(0, 100 - item.alertCount * 10)}
                    size={38}
                    label="Điểm an toàn ước tính"
                  />
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
