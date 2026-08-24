"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { formatTimeAgo, ALERT_TYPE_LABELS, ALERT_SEVERITY_LABELS } from "@/lib/utils";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { Alert, CommandCenterStats, FloodPoint, Incident, Trip, Vehicle } from "@/types";
import { useToast } from "@/context/ToastContext";
import { useAuth } from "@/context/AuthContext";
import {
  HeroPanel,
  HeroTile,
  ScoreRing,
  Skeleton,
  type Tone,
} from "@/components/ui";
import { Map as MapIcon, Phone, TriangleAlert } from "lucide-react";

/* ==========================================================================
   TRUNG TÂM ĐIỀU HÀNH
   --------------------------------------------------------------------------
   Bản thiết kế chia màn hình làm hai tầng: dải nhấn tối tổng quan đội xe ở
   trên, cạnh nó là hàng việc cần xử lý ngay; tầng dưới là chuyến đang chạy và
   tài xế rủi ro cao. Bản đồ không còn nằm ở đây mà đã có trang riêng
   (Bản đồ realtime), nên trang này tập trung vào việc phải làm.
   ========================================================================== */

const EMPTY_STATS: CommandCenterStats = {
  totalOperating: 0,
  alertsToday: 0,
  openSos: 0,
  driversNearOvertime: 0,
  vehiclesOffline: 0,
  activeFloodPoints: 0,
};

interface PriorityItem {
  id: string;
  /** Khoá thật của bản ghi để gọi API tiếp nhận */
  recordId: string;
  kind: "sos" | "alert" | "flood";
  tone: Tone;
  /** Nhãn in hoa dạng "SOS · NGHIÊM TRỌNG" */
  tag: string;
  title: string;
  description: string;
  time: string;
  href: string;
  actionable: boolean;
}

const TONE_COLOR: Record<string, { fg: string; bg: string; dot: string }> = {
  danger: { fg: "var(--sf-danger)", bg: "var(--sf-danger-soft)", dot: "var(--sf-danger)" },
  warning: { fg: "var(--sf-accent-hover)", bg: "var(--sf-bg-card-alt)", dot: "var(--sf-accent)" },
  info: { fg: "var(--sf-info)", bg: "var(--sf-bg-card-alt)", dot: "var(--sf-info)" },
  neutral: { fg: "var(--sf-text-secondary)", bg: "var(--sf-bg-card-alt)", dot: "var(--sf-neutral)" },
};

/**
 * Gộp ba nguồn thật thành một hàng việc: sự cố đang mở, cảnh báo mới mức cao
 * trở lên, và điểm ngập chưa xác minh. Sắp xếp theo mức ưu tiên giảm dần.
 */
function buildPriorityItems(
  incidents: Incident[],
  alerts: Alert[],
  floodPoints: FloodPoint[]
): PriorityItem[] {
  const items: PriorityItem[] = [];

  incidents
    .filter((i) => i.status === "open" || i.status === "overdue" || i.status === "in_progress")
    .forEach((incident) => {
      const critical = incident.priority === "critical" || incident.status === "overdue";
      items.push({
        id: `sos-${incident.id}`,
        recordId: incident.id,
        kind: "sos",
        tone: critical ? "danger" : "warning",
        tag: `${incident.type === "sos" ? "SOS" : "SỰ CỐ"} · ${critical ? "NGHIÊM TRỌNG" : "CAO"}`,
        title: `${incident.driverName} · ${incident.vehiclePlate}`,
        description: incident.description || incident.location,
        time: formatTimeAgo(incident.timestamp),
        href: `/incidents?id=${incident.id}`,
        actionable: incident.status !== "in_progress",
      });
    });

  alerts
    .filter((a) => a.status === "new" && (a.severity === "critical" || a.severity === "high"))
    .forEach((alert) => {
      items.push({
        id: `alert-${alert.id}`,
        recordId: alert.id,
        kind: "alert",
        tone: alert.severity === "critical" ? "danger" : "warning",
        tag: `${(ALERT_TYPE_LABELS[alert.type] || alert.type).toUpperCase()} · ${(
          ALERT_SEVERITY_LABELS[alert.severity] || alert.severity
        ).toUpperCase()}`,
        title: `${alert.driverName} · ${alert.vehiclePlate}`,
        description: alert.message,
        time: formatTimeAgo(alert.timestamp),
        href: `/alerts?id=${alert.id}`,
        actionable: true,
      });
    });

  floodPoints
    .filter((p) => !p.verified)
    .forEach((point) => {
      items.push({
        id: `flood-${point.id}`,
        recordId: point.id,
        kind: "flood",
        tone: "info",
        tag: "ĐIỂM NGẬP · CHỜ XÁC MINH",
        title: point.location,
        description: `${point.reportCount} báo cáo trùng · ${point.affectedVehicles} xe trong vùng ảnh hưởng`,
        time: formatTimeAgo(point.lastUpdated),
        href: "/flood-map",
        actionable: false,
      });
    });

  const weight: Record<Tone, number> = {
    danger: 0,
    warning: 1,
    accent: 2,
    info: 3,
    primary: 4,
    success: 5,
    neutral: 6,
  };
  return items.sort((a, b) => weight[a.tone] - weight[b.tone]).slice(0, 6);
}

/** Đếm cảnh báo theo từng giờ trong 12 giờ gần nhất, dùng cho biểu đồ dải nhấn */
function alertsPerHour(alerts: Alert[]): { hour: number; count: number }[] {
  const now = new Date();
  const buckets: { hour: number; count: number }[] = [];
  for (let i = 11; i >= 0; i -= 1) {
    const slot = new Date(now.getTime() - i * 3_600_000);
    buckets.push({ hour: slot.getHours(), count: 0 });
  }
  alerts.forEach((alert) => {
    const t = new Date(alert.timestamp).getTime();
    const diffHours = Math.floor((now.getTime() - t) / 3_600_000);
    if (diffHours >= 0 && diffHours < 12) buckets[11 - diffHours].count += 1;
  });
  return buckets;
}

export default function CommandCenterPage() {
  const router = useRouter();
  const { showToast } = useToast();
  const { user } = useAuth();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [trips, setTrips] = useState<Trip[]>([]);
  const [stats, setStats] = useState<CommandCenterStats>(EMPTY_STATS);
  const [isLoading, setIsLoading] = useState(true);
  const [busyPriorityId, setBusyPriorityId] = useState<string | null>(null);
  const [now, setNow] = useState<Date | null>(null);

  /* Đồng hồ chỉ chạy phía trình duyệt để tránh lệch giữa server và client */
  useEffect(() => {
    setNow(new Date());
    const timer = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(timer);
  }, []);

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

  const priorityItems = useMemo(
    () => buildPriorityItems(incidents, alerts, floodPoints),
    [incidents, alerts, floodPoints]
  );
  const activeTrips = useMemo(
    () => trips.filter((t) => t.status === "in_progress").slice(0, 4),
    [trips]
  );
  const hourly = useMemo(() => alertsPerHour(alerts), [alerts]);
  const maxHourly = Math.max(1, ...hourly.map((h) => h.count));
  const canAcceptIncident = user?.role === "ADMIN" || user?.role === "DISPATCHER";

  const handleAcceptPriority = async (item: PriorityItem) => {
    setBusyPriorityId(item.id);
    try {
      if (item.kind === "sos") {
        const updated = await safeFleetApi.acceptIncident(item.recordId);
        setIncidents((current) =>
          current.map((incident) => (incident.id === item.recordId ? updated : incident))
        );
        showToast("Đã tiếp nhận sự cố.", "success");
      } else {
        const updated = await safeFleetApi.acknowledgeSafetyEvent(item.recordId);
        setAlerts((current) =>
          current.map((alert) => (alert.id === item.recordId ? updated : alert))
        );
        showToast("Đã tiếp nhận cảnh báo.", "success");
      }
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể tiếp nhận mục này.", "error");
    } finally {
      setBusyPriorityId(null);
    }
  };

  /* Tài xế rủi ro cao — xếp theo số cảnh báo chưa xử lý */
  const riskyDrivers = useMemo(() => {
    return vehicles
      .filter((v) => v.currentDriverId)
      .map((v) => ({
        id: v.id,
        driverName: v.currentDriverName ?? "Không rõ",
        plate: v.plate,
        alertCount: alerts.filter((a) => a.vehicleId === v.id && a.status !== "resolved").length,
      }))
      .filter((d) => d.alertCount > 0)
      .sort((a, b) => b.alertCount - a.alertCount)
      .slice(0, 4);
  }, [vehicles, alerts]);

  return (
    <div className="grid gap-5">
      {/* ================= Tầng trên: dải nhấn + việc cần xử lý ================= */}
      <div className="grid items-stretch gap-5 xl:grid-cols-[minmax(0,1.15fr)_minmax(0,0.85fr)]">
        {/* ---------- Dải nhấn tối: tổng quan đội xe ---------- */}
        <HeroPanel>
          <div className="flex items-start justify-between gap-4">
            <div>
              <div
                className="text-[11.5px] uppercase tracking-[0.11em]"
                style={{ color: "rgba(190,238,229,.68)" }}
              >
                Đội xe hôm nay
              </div>
              <div className="mt-2 text-[15px] font-medium" style={{ color: "#e7f7f4" }}>
                {now
                  ? now.toLocaleString("vi-VN", {
                      weekday: "long",
                      day: "2-digit",
                      month: "2-digit",
                      year: "numeric",
                      hour: "2-digit",
                      minute: "2-digit",
                    })
                  : "Đang đồng bộ…"}
              </div>
            </div>
            <button
              type="button"
              onClick={() => router.push("/realtime-map")}
              className="sf-hero-chip cursor-pointer"
            >
              <MapIcon className="h-4 w-4" />
              Bản đồ realtime
            </button>
          </div>

          <div className="mt-6 grid grid-cols-2 gap-2.5 sm:grid-cols-3 lg:grid-cols-5">
            <HeroTile value={stats.totalOperating} label="Đang vận hành" delay={0} />
            <HeroTile value={stats.alertsToday} label="Có cảnh báo" tone="warning" delay={60} />
            <HeroTile value={stats.vehiclesOffline} label="Mất GPS" delay={120} />
            <HeroTile value={stats.openSos} label="SOS mở" tone="danger" delay={180} />
            <HeroTile value={stats.activeFloodPoints} label="Điểm ngập" delay={240} />
          </div>

          <div className="mt-6 flex h-16 items-end gap-1.5 sm:h-24">
            {hourly.map((slot, i) => {
              const isPeak = slot.count === maxHourly && slot.count > 0;
              return (
                <div
                  key={i}
                  title={`${String(slot.hour).padStart(2, "0")}:00 · ${slot.count} cảnh báo`}
                  className="animate-sf-bar flex-1 rounded-t-lg"
                  style={{
                    height: `${Math.max(8, (slot.count / maxHourly) * 100)}%`,
                    background: isPeak ? "rgba(127,227,205,.85)" : "rgba(255,255,255,.22)",
                    animationDelay: `${i * 50}ms`,
                  }}
                />
              );
            })}
          </div>
          <div className="mt-2 text-[11.5px]" style={{ color: "rgba(206,232,229,.6)" }}>
            Cảnh báo an toàn theo giờ · 12 giờ gần nhất
          </div>
        </HeroPanel>

        {/* ---------- Việc cần xử lý ngay ---------- */}
        <div className="sf-surface flex flex-col p-6">
          <div className="mb-4 flex items-start justify-between gap-3">
            <div>
              <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
                Việc cần xử lý ngay
              </div>
              <div className="mt-1 text-[12.5px] text-sf-text-muted">
                {priorityItems.length} việc theo mức ưu tiên
              </div>
            </div>
            <span
              className="grid h-[38px] w-[38px] flex-none place-items-center rounded-[14px]"
              style={{ background: "var(--sf-accent-soft)", color: "var(--sf-accent-hover)" }}
            >
              <TriangleAlert className="h-5 w-5" />
            </span>
          </div>

          <div className="flex flex-1 flex-col gap-2.5">
            {isLoading && priorityItems.length === 0 ? (
              <>
                <Skeleton className="h-28 w-full" />
                <Skeleton className="h-24 w-full" />
              </>
            ) : priorityItems.length === 0 ? (
              <div className="flex flex-1 items-center justify-center rounded-[var(--sf-r-lg)] border border-dashed border-[var(--sf-border)] px-4 py-10 text-center text-[13px] text-sf-text-muted">
                Không có việc nào đang chờ. Đội xe đang vận hành bình thường.
              </div>
            ) : (
              priorityItems.map((item, index) => {
                const c = TONE_COLOR[item.tone] ?? TONE_COLOR.neutral;
                const isTop = index === 0 && item.tone === "danger";
                return (
                  <div
                    key={item.id}
                    className="animate-sf-slide-left rounded-[var(--sf-r-lg)] border px-4 py-3.5"
                    style={{
                      background: isTop ? "var(--sf-danger-soft)" : "var(--sf-bg-card-alt)",
                      borderColor: isTop
                        ? "color-mix(in srgb, var(--sf-danger) 16%, transparent)"
                        : "var(--sf-border-card)",
                      animationDelay: `${index * 70}ms`,
                    }}
                  >
                    <div className="flex items-center gap-2.5">
                      <span
                        className={`h-2 w-2 flex-none rounded-full ${isTop ? "animate-sf-pulse-dot" : ""}`}
                        style={{ background: c.dot }}
                      />
                      <span
                        className="truncate text-[12px] font-bold tracking-[0.03em]"
                        style={{ color: c.fg }}
                      >
                        {item.tag}
                      </span>
                      <span className="flex-1" />
                      <span className="sf-mono flex-none text-[11.5px] text-sf-text-muted">
                        {item.time}
                      </span>
                    </div>

                    <div className="mt-2 truncate text-[13.5px] font-semibold text-sf-text">
                      {item.title}
                    </div>
                    <div className="mt-1 line-clamp-2 text-[12.5px] text-sf-text-secondary">
                      {item.description}
                    </div>

                    <div className="mt-3 flex flex-wrap gap-2">
                      {item.actionable && (item.kind !== "sos" || canAcceptIncident) && (
                        <button
                          type="button"
                          disabled={busyPriorityId === item.id}
                          onClick={() => void handleAcceptPriority(item)}
                          className="cursor-pointer rounded-full border-0 px-3.5 py-2 text-[12px] font-semibold text-white disabled:opacity-50"
                          style={{ background: isTop ? "var(--sf-danger)" : "#0b8c7f" }}
                        >
                          {busyPriorityId === item.id ? "Đang xử lý…" : "Tiếp nhận"}
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={() => router.push(item.href)}
                        className="cursor-pointer rounded-full border border-[var(--sf-border)] bg-[var(--sf-bg-card)] px-3.5 py-2 text-[12px] font-semibold text-sf-text-secondary"
                      >
                        Xem chi tiết
                      </button>
                      {item.kind === "sos" && (
                        <button
                          type="button"
                          onClick={() => router.push(`/incidents?id=${item.recordId}`)}
                          className="flex cursor-pointer items-center gap-1.5 rounded-full border border-[var(--sf-border)] bg-[var(--sf-bg-card)] px-3 py-2 text-[12px] text-sf-text-secondary"
                        >
                          <Phone className="h-[15px] w-[15px]" />
                          Gọi
                        </button>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>

      {/* ================= Tầng dưới: chuyến đang chạy + tài xế rủi ro ================= */}
      <div className="grid items-start gap-5 lg:grid-cols-2">
        {/* ---------- Chuyến đang chạy ---------- */}
        <div className="sf-surface px-6 py-5">
          <div className="mb-4 flex items-center justify-between gap-3">
            <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
              Chuyến đang chạy
            </div>
            <button
              type="button"
              onClick={() => router.push("/trips")}
              className="cursor-pointer border-0 bg-transparent text-[12.5px] font-semibold"
              style={{ color: "var(--sf-primary)" }}
            >
              Tất cả
            </button>
          </div>

          {isLoading && activeTrips.length === 0 ? (
            <div className="grid gap-3.5">
              <Skeleton className="h-12 w-full" />
              <Skeleton className="h-12 w-full" />
            </div>
          ) : activeTrips.length === 0 ? (
            <p className="py-8 text-center text-[13px] text-sf-text-muted">
              Chưa có chuyến nào đang chạy.
            </p>
          ) : (
            <div className="flex flex-col gap-3.5">
              {activeTrips.map((trip, index) => (
                <div
                  key={trip.id}
                  className="animate-sf-slide-left"
                  style={{ animationDelay: `${index * 70}ms` }}
                >
                  <div className="mb-1.5 flex items-baseline justify-between gap-3">
                    <span className="truncate text-[13px] font-semibold text-sf-text">
                      {trip.code} · {trip.vehiclePlate}
                    </span>
                    <span className="sf-mono flex-none text-[12px] text-sf-text-muted">
                      {trip.progress}%
                    </span>
                  </div>
                  <div
                    className={`sf-track ${
                      trip.riskLevel === "critical"
                        ? "sf-track-danger"
                        : trip.riskLevel === "high"
                          ? "sf-track-warn"
                          : ""
                    }`}
                  >
                    <span style={{ width: `${Math.min(100, Math.max(0, trip.progress))}%` }} />
                  </div>
                  <div className="mt-1.5 truncate text-[11.5px] text-sf-text-muted">
                    {trip.origin} → {trip.destination} · {trip.driverName}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* ---------- Tài xế rủi ro cao ---------- */}
        <div className="sf-surface px-6 py-5">
          <div className="mb-4 flex items-center justify-between gap-3">
            <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
              Tài xế rủi ro cao
            </div>
            <button
              type="button"
              onClick={() => router.push("/drivers")}
              className="cursor-pointer border-0 bg-transparent text-[12.5px] font-semibold"
              style={{ color: "var(--sf-primary)" }}
            >
              Tất cả
            </button>
          </div>

          {isLoading && riskyDrivers.length === 0 ? (
            <div className="grid gap-3">
              <Skeleton className="h-12 w-full" />
              <Skeleton className="h-12 w-full" />
            </div>
          ) : riskyDrivers.length === 0 ? (
            <p className="py-8 text-center text-[13px] text-sf-text-muted">
              Không có tài xế nào đang có cảnh báo chưa xử lý.
            </p>
          ) : (
            <div className="flex flex-col gap-3">
              {riskyDrivers.map((driver) => (
                <button
                  key={driver.id}
                  type="button"
                  onClick={() => router.push("/drivers")}
                  className="flex cursor-pointer items-center gap-3.5 rounded-[var(--sf-r-md)] p-1 text-left transition-colors hover:bg-[var(--sf-hover)]"
                >
                  <ScoreRing
                    score={Math.max(0, 100 - driver.alertCount * 8)}
                    size={44}
                    label={`${driver.alertCount} cảnh báo`}
                  />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13px] font-semibold text-sf-text">
                      {driver.driverName}
                    </span>
                    <span className="block truncate text-[11.5px] text-sf-text-muted">
                      {driver.plate} · {driver.alertCount} cảnh báo chưa xử lý
                    </span>
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
