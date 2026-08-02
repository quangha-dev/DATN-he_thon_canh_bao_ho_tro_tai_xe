"use client";

import { useEffect, useMemo, useState } from "react";
import { cn, formatTimeAgo, getSafetyScoreInfo, STATUS_COLORS, ALERT_TYPE_LABELS } from "@/lib/utils";
import { safeFleetApi } from "@/lib/safeFleetApi";
import MapView from "@/components/map/MapView";
import { Alert, CommandCenterStats, FloodPoint, Incident, Trip, Vehicle } from "@/types";
import { useToast } from "@/context/ToastContext";
import {
  Truck,
  AlertTriangle,
  Siren,
  Clock,
  WifiOff,
  Droplets,
  Phone,
  Eye,
  CheckCircle,
  ChevronRight,
  Activity,
  TrendingUp,
  Shield,
} from "lucide-react";

// =============================================================================
// FILTER CHIPS
// =============================================================================
const FILTERS = [
  { key: "all", label: "Tất cả" },
  { key: "running", label: "Đang chạy" },
  { key: "alert", label: "Cảnh báo" },
  { key: "sos", label: "SOS" },
  { key: "flood", label: "Gần điểm ngập" },
  { key: "offline", label: "Mất GPS" },
];

// =============================================================================
// STAT CARDS DATA
// =============================================================================
const EMPTY_STATS: CommandCenterStats = {
  totalOperating: 0,
  alertsToday: 0,
  openSos: 0,
  driversNearOvertime: 0,
  vehiclesOffline: 0,
  activeFloodPoints: 0,
};

function getStatCards(stats: CommandCenterStats) {
  return [
    {
      key: "operating",
      label: "Đang vận hành",
      value: stats.totalOperating,
      icon: Truck,
      tone: "bg-slate-900",
      shadow: "shadow-blue-500/20",
      change: "Dữ liệu backend",
      changePositive: true,
    },
    {
      key: "alerts",
      label: "Cảnh báo đang mở",
      value: stats.alertsToday,
      icon: AlertTriangle,
      tone: "bg-amber-500",
      shadow: "shadow-amber-500/20",
      change: "Cần theo dõi",
      changePositive: false,
    },
    {
      key: "sos",
      label: "SOS đang mở",
      value: stats.openSos,
      icon: Siren,
      tone: "bg-red-600",
      shadow: "shadow-red-500/20",
      pulse: true,
    },
    {
      key: "overtime",
      label: "Tài xế gần quá giờ",
      value: stats.driversNearOvertime,
      icon: Clock,
      tone: "bg-slate-700",
      shadow: "shadow-violet-500/20",
    },
    {
      key: "offline",
      label: "Xe mất kết nối",
      value: stats.vehiclesOffline,
      icon: WifiOff,
      tone: "bg-slate-500",
      shadow: "shadow-slate-500/20",
    },
    {
      key: "flood",
      label: "Điểm ngập hoạt động",
      value: stats.activeFloodPoints,
      icon: Droplets,
      tone: "bg-teal-600",
      shadow: "shadow-cyan-500/20",
    },
  ];
}

// =============================================================================
// PRIORITY PANEL DATA
// =============================================================================
function getPriorityItems(incidents: Incident[], alerts: Alert[]) {
  const items: {
    id: string;
    color: string;
    borderColor: string;
    bgColor: string;
    title: string;
    subtitle: string;
    time: string;
    type: "sos" | "alert" | "warning";
  }[] = [];

  // SOS incidents
  incidents
    .filter((i) => i.status === "open" || i.status === "in_progress")
    .forEach((incident) => {
      items.push({
        id: incident.id,
        color: "text-red-600 dark:text-red-400",
        borderColor: "border-red-500",
        bgColor: "bg-red-50 dark:bg-red-950/30",
        title: `Xe ${incident.vehiclePlate} gửi SOS`,
        subtitle: incident.location,
        time: formatTimeAgo(incident.timestamp),
        type: "sos",
      });
    });

  // Critical alerts
  alerts
    .filter((a) => a.severity === "critical" && a.status === "new")
    .forEach((alert) => {
      items.push({
        id: alert.id,
        color: "text-orange-600 dark:text-orange-400",
        borderColor: "border-orange-500",
        bgColor: "bg-orange-50 dark:bg-orange-950/30",
        title: `${alert.driverName} ${ALERT_TYPE_LABELS[alert.type]?.toLowerCase() || alert.type}`,
        subtitle: alert.repeatCount ? `Lặp lại ${alert.repeatCount} lần` : alert.message,
        time: formatTimeAgo(alert.timestamp),
        type: "alert",
      });
    });

  // High alerts
  alerts
    .filter((a) => a.severity === "high" && a.status === "new")
    .slice(0, 3)
    .forEach((alert) => {
      items.push({
        id: alert.id,
        color: "text-amber-600 dark:text-amber-400",
        borderColor: "border-amber-500",
        bgColor: "bg-amber-50 dark:bg-amber-950/30",
        title: `${ALERT_TYPE_LABELS[alert.type] || alert.type}: ${alert.vehiclePlate}`,
        subtitle: alert.message,
        time: formatTimeAgo(alert.timestamp),
        type: "warning",
      });
    });

  return items;
}

// =============================================================================
// MAIN COMPONENT
// =============================================================================
export default function CommandCenterPage() {
  const { showToast } = useToast();
  const [activeFilter, setActiveFilter] = useState("all");
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [trips, setTrips] = useState<Trip[]>([]);
  const [stats, setStats] = useState<CommandCenterStats>(EMPTY_STATS);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    let realtimeDebounce: ReturnType<typeof setTimeout> | null = null;

    const loadDashboard = async () => {
      setIsLoading(true);
      try {
        const [vehicleData, alertData, incidentData, tripData, floodData, statData] = await Promise.all([
          safeFleetApi.vehicles(),
          safeFleetApi.safetyEvents(),
          safeFleetApi.incidents(),
          safeFleetApi.trips(),
          safeFleetApi.floodPoints(),
          safeFleetApi.dashboardStats(),
        ]);
        if (!cancelled) {
          setVehicles(vehicleData);
          setAlerts(alertData);
          setIncidents(incidentData);
          setTrips(tripData);
          setFloodPoints(floodData);
          setStats(statData);
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được dashboard.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadDashboard();
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

  const priorityItems = useMemo(() => getPriorityItems(incidents, alerts), [incidents, alerts]);
  const activeTrips = useMemo(() => trips.filter((t) => t.status === "in_progress"), [trips]);
  const statCards = useMemo(() => getStatCards(stats), [stats]);
  const filteredVehicles = useMemo(() => {
    if (activeFilter === "running") return vehicles.filter((vehicle) => vehicle.status === "running");
    if (activeFilter === "alert") return vehicles.filter((vehicle) => vehicle.totalAlerts > 0);
    if (activeFilter === "offline") return vehicles.filter((vehicle) => vehicle.status === "offline");
    if (activeFilter === "sos") {
      const vehicleIds = new Set(
        incidents
          .filter((incident) => incident.status === "open" || incident.status === "in_progress")
          .map((incident) => incident.vehicleId)
      );
      return vehicles.filter((vehicle) => vehicleIds.has(vehicle.id));
    }
    if (activeFilter === "flood") {
      return vehicles.filter((vehicle) =>
        floodPoints.some(
          (point) =>
            Math.abs(point.lat - vehicle.lat) < 0.01 &&
            Math.abs(point.lng - vehicle.lng) < 0.01
        )
      );
    }
    return vehicles;
  }, [activeFilter, floodPoints, incidents, vehicles]);

  // Top risky drivers
  const riskyDrivers = [...vehicles]
    .filter((v) => v.currentDriverId)
    .map((v) => {
      const driver = v.currentDriverName;
      const vehicleAlerts = alerts.filter(
        (a) => a.vehicleId === v.id && a.status !== "resolved"
      );
      return { vehicle: v, driverName: driver, alertCount: vehicleAlerts.length };
    })
    .filter((d) => d.alertCount > 0)
    .sort((a, b) => b.alertCount - a.alertCount)
    .slice(0, 5);

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* ===== Filter Chips ===== */}
      <div className="flex items-center gap-2 flex-wrap">
        {FILTERS.map((filter) => (
          <button
            key={filter.key}
            onClick={() => setActiveFilter(filter.key)}
            className={cn(
              "px-4 py-2 rounded-full text-sm font-medium transition-all duration-200",
              activeFilter === filter.key
                ? "bg-slate-900 text-white shadow-sm"
                : "bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700 hover:border-teal-500 hover:text-teal-700 dark:hover:text-teal-400"
            )}
          >
            {filter.label}
          </button>
        ))}
      </div>

      {/* ===== Main Grid: Map Area + Priority Panel ===== */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Realtime operating map */}
        <div className="xl:col-span-2 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 overflow-hidden shadow-sm">
          <div className="relative h-[400px] bg-slate-100 dark:bg-slate-900">
            <MapView
              vehicles={filteredVehicles}
              floodPoints={floodPoints}
              incidents={incidents.filter(
                (incident) =>
                  incident.status === "open" || incident.status === "in_progress"
              )}
            />
            <div className="absolute top-4 left-4 flex gap-2">
              <span className="px-3 py-1.5 rounded-lg bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm text-xs font-semibold text-slate-800 dark:text-white border border-slate-200 dark:border-slate-700">
                {filteredVehicles.length} xe hiển thị
              </span>
              <span className="px-3 py-1.5 rounded-lg bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm text-xs font-semibold text-amber-700 dark:text-amber-400 border border-slate-200 dark:border-slate-700">
                {alerts.filter((a) => a.status === "new").length} cảnh báo
              </span>
              {isLoading && (
                <span className="px-3 py-1.5 rounded-lg bg-white/95 border border-slate-200 text-xs font-semibold text-teal-700">
                  Đang đồng bộ...
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Priority Panel */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
            <div>
              <h3 className="font-bold text-slate-900 dark:text-white text-sm">
                Việc cần xử lý ngay
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                {priorityItems.length} mục ưu tiên
              </p>
            </div>
            <span className="relative flex h-3 w-3">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-3 w-3 bg-red-500" />
            </span>
          </div>

          <div className="overflow-y-auto max-h-[340px] divide-y divide-slate-100 dark:divide-slate-800">
            {priorityItems.map((item) => (
              <div
                key={`${item.type}-${item.id}`}
                className={cn(
                  "px-5 py-3.5 border-l-[3px] hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors cursor-pointer",
                  item.borderColor
                )}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="flex-1 min-w-0">
                    <p className={cn("text-sm font-semibold", item.color)}>
                      {item.title}
                    </p>
                    <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5 truncate">
                      {item.subtitle}
                    </p>
                  </div>
                  <span className="text-[10px] text-slate-400 dark:text-slate-500 whitespace-nowrap">
                    {item.time}
                  </span>
                </div>

                {/* Action buttons */}
                <div className="flex items-center gap-2 mt-2.5">
                  <button className="flex items-center gap-1 px-2.5 py-1 rounded-md bg-slate-100 dark:bg-slate-800 text-xs font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 transition">
                    <Eye className="w-3 h-3" /> Xem
                  </button>
                  <button className="flex items-center gap-1 px-2.5 py-1 rounded-md bg-blue-50 dark:bg-blue-950/30 text-xs font-medium text-blue-600 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/30 transition">
                    <CheckCircle className="w-3 h-3" /> Tiếp nhận
                  </button>
                  <button className="flex items-center gap-1 px-2.5 py-1 rounded-md bg-emerald-50 dark:bg-emerald-950/30 text-xs font-medium text-emerald-600 dark:text-emerald-400 hover:bg-emerald-100 dark:hover:bg-emerald-900/30 transition">
                    <Phone className="w-3 h-3" /> Gọi
                  </button>
                </div>
              </div>
            ))}

            {priorityItems.length === 0 && (
              <div className="px-5 py-10 text-center">
                <CheckCircle className="w-10 h-10 text-emerald-300 dark:text-emerald-700 mx-auto mb-2" />
                <p className="text-sm text-slate-400 dark:text-slate-500 font-medium">
                  Không có việc cần xử lý
                </p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ===== Stat Cards ===== */}
      <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4">
        {statCards.map((card) => {
          const Icon = card.icon;
          return (
            <div
              key={card.key}
              className="group bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 p-4 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-200 cursor-pointer"
            >
              <div className="flex items-start justify-between mb-3">
                <div
                  className={cn(
                    "w-10 h-10 rounded-xl flex items-center justify-center",
                    card.tone,
                    card.shadow,
                    card.pulse && "animate-pulse-sos"
                  )}
                >
                  <Icon className="w-5 h-5 text-white" />
                </div>
                {card.change && (
                  <TrendingUp
                    className={cn(
                      "w-3.5 h-3.5",
                      card.changePositive
                        ? "text-emerald-500"
                        : "text-red-500 rotate-180"
                    )}
                  />
                )}
              </div>
              <p className="text-2xl font-bold text-slate-900 dark:text-white">
                {card.value}
              </p>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                {card.label}
              </p>
              {card.change && (
                <p
                  className={cn(
                    "text-[10px] mt-1 font-medium",
                    card.changePositive
                      ? "text-emerald-600 dark:text-emerald-400"
                      : "text-red-600 dark:text-red-400"
                  )}
                >
                  {card.change}
                </p>
              )}
            </div>
          );
        })}
      </div>

      {/* ===== Bottom Grid: Active Trips + Event Feed + Risky Drivers ===== */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        {/* Active Trips */}
        <div className="xl:col-span-2 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Activity className="w-4 h-4 text-blue-500" />
              <h3 className="font-bold text-slate-900 dark:text-white text-sm">
                Chuyến đang chạy
              </h3>
              <span className="px-2 py-0.5 rounded-full bg-blue-50 dark:bg-blue-950/30 text-xs font-semibold text-blue-600 dark:text-blue-400">
                {activeTrips.length}
              </span>
            </div>
            <button className="text-xs text-blue-600 dark:text-blue-400 font-medium hover:text-blue-700 dark:hover:text-blue-300 flex items-center gap-1 transition">
              Xem tất cả <ChevronRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="divide-y divide-slate-100 dark:divide-slate-800">
            {activeTrips.slice(0, 5).map((trip) => (
              <div
                key={trip.id}
                className="px-5 py-3.5 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors cursor-pointer"
              >
                <div className="flex items-center justify-between">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-sm font-semibold text-slate-900 dark:text-white">
                        {trip.code}
                      </span>
                      <span className="text-xs text-slate-500 dark:text-slate-400">
                        · {trip.vehiclePlate}
                      </span>
                    </div>
                    <p className="text-xs text-slate-500 dark:text-slate-400 truncate">
                      {trip.origin} → {trip.destination}
                    </p>
                  </div>

                  <div className="flex items-center gap-3 ml-4">
                    {/* Risk badge */}
                    {trip.riskLevel !== "low" && (
                      <span
                        className="px-2 py-0.5 rounded-full text-[10px] font-bold text-white"
                        style={{
                          backgroundColor:
                            STATUS_COLORS[trip.riskLevel] || "#6b7280",
                        }}
                      >
                        {trip.riskLevel === "high" ? "Rủi ro cao" : "Cần theo dõi"}
                      </span>
                    )}

                    {/* Progress bar */}
                    <div className="w-20">
                      <div className="flex items-center justify-between text-[10px] text-slate-500 mb-0.5">
                        <span>{trip.progress}%</span>
                      </div>
                      <div className="w-full h-1.5 bg-slate-100 dark:bg-slate-700 rounded-full overflow-hidden">
                        <div
                          className="h-full rounded-full bg-teal-600 transition-all duration-500"
                          style={{ width: `${trip.progress}%` }}
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Top Risky Drivers */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b border-slate-100 dark:border-slate-800 flex items-center gap-2.5">
            <Shield className="w-4 h-4 text-amber-500" />
            <h3 className="font-bold text-slate-900 dark:text-white text-sm">
              Tài xế rủi ro cao
            </h3>
          </div>

          <div className="divide-y divide-slate-100 dark:divide-slate-800">
            {riskyDrivers.map((item, idx) => {
              const driver = item.vehicle;
              const driverData = alerts.find(
                (a) => a.vehicleId === driver.id
              );
              const safetyInfo = driverData
                ? getSafetyScoreInfo(
                    100 - item.alertCount * 10
                  )
                : null;

              return (
                <div
                  key={driver.id}
                  className="px-5 py-3 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors cursor-pointer flex items-center gap-3"
                >
                  {/* Rank */}
                  <span
                    className={cn(
                      "w-6 h-6 rounded-full flex items-center justify-center text-[10px] font-bold",
                      idx === 0
                        ? "bg-red-100 dark:bg-red-950/50 text-red-600 dark:text-red-400"
                        : "bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400"
                    )}
                  >
                    {idx + 1}
                  </span>

                  {/* Driver info */}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-900 dark:text-white truncate">
                      {item.driverName}
                    </p>
                    <p className="text-[10px] text-slate-500 dark:text-slate-400">
                      {driver.plate} · {item.alertCount} cảnh báo
                    </p>
                  </div>

                  {/* Safety indicator */}
                  {safetyInfo && (
                    <span
                      className="px-2 py-0.5 rounded-full text-[10px] font-bold text-white"
                      style={{ backgroundColor: safetyInfo.color }}
                    >
                      {safetyInfo.label}
                    </span>
                  )}
                </div>
              );
            })}

            {riskyDrivers.length === 0 && (
              <div className="px-5 py-8 text-center">
                <Shield className="w-8 h-8 text-emerald-300 dark:text-emerald-700 mx-auto mb-2" />
                <p className="text-sm text-slate-400 dark:text-slate-500 font-medium">
                  Không có tài xế rủi ro cao
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
