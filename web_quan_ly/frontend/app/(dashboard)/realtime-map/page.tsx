"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import MapView, { type MapViewHandle } from "@/components/map/MapView";
import { Vehicle, FloodPoint, Incident } from "@/types";
import { ActiveNavigation, safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { useAuth } from "@/context/AuthContext";
import {
  cn,
  formatTimeAgo,
  VEHICLE_STATUS_LABELS,
  FLOOD_SEVERITY_LABELS,
  INCIDENT_STATUS_LABELS,
} from "@/lib/utils";
import {
  Crosshair,
  Droplets,
  List,
  Minus,
  Phone,
  Plus,
  Search,
  Siren,
  Truck,
  WifiOff,
  X,
} from "lucide-react";
import { Badge, DetailRow, MiniStat } from "@/components/ui";

type DetailItem =
  | { type: "vehicle"; data: Vehicle }
  | { type: "flood"; data: FloodPoint }
  | { type: "incident"; data: Incident };

/**
 * Trạng thái hiển thị của một xe trên bản đồ được suy từ dữ liệu thật:
 * mất tín hiệu GPS > đang có sự cố > có cảnh báo > trạng thái vận hành.
 * Bản thiết kế dùng danh sách trạng thái cứng, ở đây phải bám enum backend.
 */
function vehicleTone(
  vehicle: Vehicle,
  hasOpenIncident: boolean
): { tone: "primary" | "warning" | "danger" | "neutral" | "info"; label: string } {
  if (hasOpenIncident) return { tone: "danger", label: "SOS" };
  if (vehicle.gpsStatus === "offline" || vehicle.status === "offline")
    return { tone: "neutral", label: "Mất GPS" };
  if (vehicle.gpsStatus === "weak") return { tone: "warning", label: "Tín hiệu yếu" };
  if (vehicle.totalAlerts > 0) return { tone: "warning", label: "Có cảnh báo" };
  if (vehicle.status === "maintenance") return { tone: "info", label: "Bảo trì" };
  return {
    tone: "primary",
    label: VEHICLE_STATUS_LABELS[vehicle.status] || vehicle.status,
  };
}

const DOT_COLOR: Record<string, string> = {
  primary: "#0b8c7f",
  warning: "#f59e0b",
  danger: "#e5484d",
  neutral: "#8496a0",
  info: "#2563c9",
};

export default function RealtimeMapPage() {
  const router = useRouter();
  const { showToast } = useToast();
  const { user } = useAuth();
  const mapRef = useRef<MapViewHandle>(null);

  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [showVehicleList, setShowVehicleList] = useState(false);
  const [selectedItem, setSelectedItem] = useState<DetailItem | null>(null);
  const [acceptingIncidentId, setAcceptingIncidentId] = useState<string | null>(null);
  const [activeNavigation, setActiveNavigation] = useState<ActiveNavigation | null>(null);

  const handleAcceptIncident = async (incident: Incident) => {
    setAcceptingIncidentId(incident.id);
    try {
      const updated = await safeFleetApi.acceptIncident(incident.id);
      setIncidents((current) => current.map((item) => (item.id === updated.id ? updated : item)));
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
        const message = error instanceof Error ? error.message : "Không tải được dữ liệu bản đồ.";
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

  useEffect(() => {
    if (selectedItem?.type !== "vehicle") {
      setActiveNavigation(null);
      return;
    }
    let cancelled = false;
    const vehicleId = selectedItem.data.id;
    const loadRoute = async () => {
      try {
        const route = await safeFleetApi.activeNavigation(vehicleId);
        if (!cancelled) setActiveNavigation(route);
      } catch {
        if (!cancelled) setActiveNavigation(null);
      }
    };
    void loadRoute();
    window.addEventListener("safefleet:realtime", loadRoute);
    const polling = window.setInterval(loadRoute, 15_000);
    return () => {
      cancelled = true;
      window.removeEventListener("safefleet:realtime", loadRoute);
      window.clearInterval(polling);
    };
  }, [selectedItem]);

  const monitoredRoute = useMemo(() => {
    if (!activeNavigation) return null;
    return (
      activeNavigation.routes.find((route) => route.recommended) ??
      activeNavigation.routes[activeNavigation.selectedRouteIndex] ??
      null
    );
  }, [activeNavigation]);

  /** Xe đang có sự cố chưa đóng — dùng để tô màu marker và chip trạng thái */
  const incidentVehicleIds = useMemo(
    () =>
      new Set(
        incidents
          .filter((i) => i.status === "open" || i.status === "overdue" || i.status === "in_progress")
          .map((i) => i.vehicleId)
      ),
    [incidents]
  );

  /* Xe không có toạ độ vẫn nằm trong danh sách nhưng không vẽ lên bản đồ */
  const mappableVehicles = useMemo(
    () => vehicles.filter((v) => v.lat !== null && v.lng !== null),
    [vehicles]
  );

  const query = searchQuery.trim().toLowerCase();

  const handleSearchPick = (item: DetailItem) => {
    setSelectedItem(item);
    setSearchQuery("");
    if (item.type === "vehicle") {
      if (item.data.lat !== null && item.data.lng !== null) {
        mapRef.current?.flyTo(item.data.lat, item.data.lng);
      }
      return;
    }
    mapRef.current?.flyTo(item.data.lat, item.data.lng);
  };

  const searchResults = useMemo(() => {
    if (!query) return [];
    const out: {
      key: string;
      icon: typeof Truck;
      title: string;
      sub: string;
      tone: string;
      item: DetailItem;
    }[] = [];

    vehicles.forEach((v) => {
      const haystack = `${v.plate} ${v.currentDriverName ?? ""} ${v.type}`.toLowerCase();
      if (!haystack.includes(query)) return;
      out.push({
        key: `v-${v.id}`,
        icon: Truck,
        title: v.plate,
        sub: `${v.currentDriverName ?? "Chưa gán tài xế"} · ${v.type}`,
        tone: "primary",
        item: { type: "vehicle", data: v },
      });
    });

    floodPoints.forEach((p) => {
      const haystack = `${p.location} ${FLOOD_SEVERITY_LABELS[p.severity] ?? ""}`.toLowerCase();
      if (!haystack.includes(query)) return;
      out.push({
        key: `f-${p.id}`,
        icon: Droplets,
        title: p.location,
        sub: `${FLOOD_SEVERITY_LABELS[p.severity] ?? p.severity} · ${p.reportCount} báo cáo`,
        tone: "info",
        item: { type: "flood", data: p },
      });
    });

    return out.slice(0, 6);
  }, [query, vehicles, floodPoints]);

  const canAcceptIncident = user?.role === "ADMIN" || user?.role === "DISPATCHER";

  /* Nội dung panel chi tiết bên phải, dựng theo loại đối tượng đang chọn */
  const detail = useMemo(() => {
    if (!selectedItem) return null;

    if (selectedItem.type === "vehicle") {
      const v = selectedItem.data;
      const state = vehicleTone(v, incidentVehicleIds.has(v.id));
      return {
        kindLabel: "Báo cáo phương tiện",
        title: v.plate,
        subtitle: `${v.brand} ${v.model} · ${v.type}`,
        tone: state.tone,
        chip: state.label,
      };
    }

    if (selectedItem.type === "flood") {
      const p = selectedItem.data;
      return {
        kindLabel: "Điểm ngập",
        title: p.location,
        subtitle: `Nguồn: ${p.source} · ${p.reportCount} báo cáo`,
        tone: "info" as const,
        chip: FLOOD_SEVERITY_LABELS[p.severity] ?? p.severity,
      };
    }

    const i = selectedItem.data;
    return {
      kindLabel: "Sự cố",
      title: `${i.vehiclePlate} · ${i.driverName}`,
      subtitle: i.location,
      tone: "danger" as const,
      chip: INCIDENT_STATUS_LABELS[i.status] ?? i.status,
    };
  }, [selectedItem, incidentVehicleIds]);

  return (
    <div className="relative h-[calc(100vh-var(--header-height)-56px)] min-h-[540px] overflow-hidden rounded-[var(--sf-r-xl)] border border-[var(--sf-border-card)] shadow-[var(--sf-shadow-md)]">
      {/* ===================== Bản đồ thật ===================== */}
      <div className="sf-map-dark absolute inset-0 z-0">
        <MapView
          ref={mapRef}
          showNativeControls={false}
          vehicles={mappableVehicles}
          floodPoints={floodPoints}
          incidents={incidents}
          onVehicleClick={(v) => setSelectedItem({ type: "vehicle", data: v })}
          onFloodPointClick={(p) => setSelectedItem({ type: "flood", data: p })}
          onIncidentClick={(i) => setSelectedItem({ type: "incident", data: i })}
          selectedVehicleId={selectedItem?.type === "vehicle" ? selectedItem.data.id : null}
          routeCoordinates={monitoredRoute?.geometry ?? []}
        />
      </div>

      {/* ===================== Hàng điều khiển phía trên ===================== */}
      <div className="pointer-events-none absolute inset-x-5 top-5 z-10 flex items-start gap-3">
        {/* --- Ô tìm nhanh --- */}
        <div className="pointer-events-auto relative min-w-0 max-w-[440px] flex-1">
          <div
            className="flex h-11 items-center gap-2.5 rounded-2xl border border-white/80 px-4 backdrop-blur-[14px]"
            style={{
              background: "color-mix(in srgb, var(--sf-bg-card) 94%, transparent)",
              boxShadow: "0 14px 32px -16px rgba(20,40,55,.45)",
            }}
          >
            <Search className="h-[19px] w-[19px] flex-none text-sf-text-muted" />
            <input
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Tìm xe, tài xế hoặc điểm ngập…"
              className="min-w-0 flex-1 border-0 bg-transparent text-[13px] text-sf-text outline-none placeholder:text-sf-text-muted"
            />
            {searchQuery && (
              <button
                type="button"
                aria-label="Xóa từ khóa"
                onClick={() => setSearchQuery("")}
                className="grid flex-none cursor-pointer place-items-center text-sf-text-muted hover:text-sf-text"
              >
                <X className="h-[18px] w-[18px]" />
              </button>
            )}
          </div>

          {query && (
            <div
              className="animate-sf-rise-sm absolute inset-x-0 top-[52px] flex flex-col gap-1 rounded-[18px] border border-white/80 p-2 backdrop-blur-[16px]"
              style={{
                background: "color-mix(in srgb, var(--sf-bg-card) 97%, transparent)",
                boxShadow: "0 18px 40px -18px rgba(20,40,55,.45)",
              }}
            >
              {searchResults.length === 0 ? (
                <p className="px-3 py-3.5 text-[12.5px] text-sf-text-muted">
                  Không tìm thấy xe, tài xế hay điểm ngập phù hợp.
                </p>
              ) : (
                searchResults.map((r) => {
                  const Icon = r.icon;
                  return (
                    <button
                      key={r.key}
                      type="button"
                      onClick={() => handleSearchPick(r.item)}
                      className="flex cursor-pointer items-center gap-3 rounded-[14px] px-3 py-2.5 text-left transition-colors hover:bg-[var(--sf-bg-inset)]"
                    >
                      <span
                        className="grid h-8 w-8 flex-none place-items-center rounded-[11px]"
                        style={{
                          background:
                            r.tone === "info" ? "var(--sf-info-soft)" : "var(--sf-primary-soft)",
                          color: r.tone === "info" ? "var(--sf-info)" : "var(--sf-primary)",
                        }}
                      >
                        <Icon className="h-[18px] w-[18px]" />
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-[13px] font-semibold text-sf-text">
                          {r.title}
                        </span>
                        <span className="mt-0.5 block truncate text-[11.5px] text-sf-text-muted">
                          {r.sub}
                        </span>
                      </span>
                    </button>
                  );
                })
              )}
            </div>
          )}
        </div>

        {/* --- Nút bật danh sách xe --- */}
        <button
          type="button"
          onClick={() => setShowVehicleList((v) => !v)}
          title="Danh sách các xe"
          className="pointer-events-auto flex h-11 flex-none cursor-pointer items-center gap-2.5 rounded-2xl border border-white/80 px-4 text-[12.5px] font-semibold backdrop-blur-[12px] transition-colors"
          style={{
            background: showVehicleList
              ? "#0b8c7f"
              : "color-mix(in srgb, var(--sf-bg-card) 94%, transparent)",
            color: showVehicleList ? "#ffffff" : "var(--sf-text-secondary)",
            boxShadow: "0 14px 30px -16px rgba(20,40,55,.5)",
          }}
        >
          <List className="h-5 w-5" />
          <span className="hidden sm:inline">Danh sách xe</span>
        </button>

        {/* --- Cụm nút phóng to / thu nhỏ / về khung mặc định --- */}
        <div
          className="pointer-events-auto ml-auto flex flex-none flex-col overflow-hidden rounded-2xl border border-white/80 backdrop-blur-[12px]"
          style={{
            background: "color-mix(in srgb, var(--sf-bg-card) 94%, transparent)",
            boxShadow: "0 14px 30px -16px rgba(20,40,55,.5)",
          }}
        >
          <button
            type="button"
            title="Phóng to"
            onClick={() => mapRef.current?.zoomIn()}
            className="grid h-11 w-11 cursor-pointer place-items-center text-sf-text-secondary transition-colors hover:bg-[var(--sf-bg-inset)]"
          >
            <Plus className="h-[22px] w-[22px]" />
          </button>
          <span className="h-px bg-[var(--sf-border-card)]" />
          <button
            type="button"
            title="Thu nhỏ"
            onClick={() => mapRef.current?.zoomOut()}
            className="grid h-11 w-11 cursor-pointer place-items-center text-sf-text-secondary transition-colors hover:bg-[var(--sf-bg-inset)]"
          >
            <Minus className="h-[22px] w-[22px]" />
          </button>
          <span className="h-px bg-[var(--sf-border-card)]" />
          <button
            type="button"
            title="Về khung mặc định"
            onClick={() => mapRef.current?.reset()}
            className="grid h-11 w-11 cursor-pointer place-items-center text-sf-text-secondary transition-colors hover:bg-[var(--sf-bg-inset)]"
          >
            <Crosshair className="h-5 w-5" />
          </button>
        </div>
      </div>

      {/* ===================== Panel trái: danh sách xe ===================== */}
      {showVehicleList && (
        <div
          className="animate-sf-slide-left absolute bottom-20 left-5 top-20 z-[7] flex w-[288px] max-w-[calc(100%-40px)] flex-col overflow-hidden rounded-3xl border border-white/80 backdrop-blur-[18px]"
          style={{
            background: "color-mix(in srgb, var(--sf-bg-card) 95%, transparent)",
            boxShadow: "0 24px 52px -22px rgba(20,40,55,.5)",
          }}
        >
          <div className="flex flex-none items-center justify-between gap-2.5 border-b border-[var(--sf-border-card)] px-4 pb-3 pt-4">
            <span className="sf-eyebrow truncate">Xe trên bản đồ · {vehicles.length} xe</span>
            <button
              type="button"
              aria-label="Đóng danh sách xe"
              onClick={() => setShowVehicleList(false)}
              className="grid h-[26px] w-[26px] flex-none cursor-pointer place-items-center rounded-[9px] text-sf-text-muted"
              style={{ background: "var(--sf-bg-inset)" }}
            >
              <X className="h-4 w-4" />
            </button>
          </div>

          <div className="flex min-h-0 flex-1 flex-col gap-2 overflow-y-auto px-3 pb-3.5 pt-2.5">
            {isLoading && vehicles.length === 0 ? (
              <p className="px-2 py-6 text-center text-[12.5px] text-sf-text-muted">Đang tải…</p>
            ) : (
              vehicles.map((v) => {
                const state = vehicleTone(v, incidentVehicleIds.has(v.id));
                const active = selectedItem?.type === "vehicle" && selectedItem.data.id === v.id;
                const noPosition = v.lat === null || v.lng === null;
                return (
                  <button
                    key={v.id}
                    type="button"
                    onClick={() => {
                      setSelectedItem({ type: "vehicle", data: v });
                      if (!noPosition) mapRef.current?.flyTo(v.lat as number, v.lng as number);
                    }}
                    className={cn(
                      "cursor-pointer rounded-[18px] px-3.5 py-3 text-left transition-colors",
                      active ? "bg-[var(--sf-primary-soft)]" : "hover:bg-[var(--sf-bg-inset)]"
                    )}
                    style={{
                      boxShadow: active
                        ? "inset 0 0 0 1px color-mix(in srgb, var(--sf-primary) 16%, transparent)"
                        : "inset 0 0 0 1px var(--sf-border-card)",
                    }}
                  >
                    <span className="flex items-center gap-2">
                      <span
                        className="h-[7px] w-[7px] flex-none rounded-full"
                        style={{ background: DOT_COLOR[state.tone] }}
                      />
                      <span className="sf-mono min-w-0 flex-1 truncate text-[13px] font-medium text-sf-text">
                        {v.plate}
                      </span>
                      <span className="sf-mono flex-none text-[11.5px] text-sf-text-muted">
                        {v.currentSpeed} km/h
                      </span>
                    </span>
                    <span className="mt-1.5 block truncate text-[12px] text-sf-text-secondary">
                      {v.currentDriverName ?? "Chưa gán tài xế"}
                    </span>
                    <span className="mt-2 flex flex-wrap items-center gap-1.5">
                      <Badge tone={state.tone} size="sm">
                        {state.label.toUpperCase()}
                      </Badge>
                      {noPosition && (
                        <span className="inline-flex items-center gap-1 text-[10.5px] text-sf-text-muted">
                          <WifiOff className="h-3 w-3" />
                          chưa có toạ độ
                        </span>
                      )}
                    </span>
                  </button>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* ===================== Chú giải ===================== */}
      <div
        className="absolute bottom-5 left-5 z-[4] flex max-w-[calc(100%-40px)] gap-3 overflow-x-auto whitespace-nowrap rounded-full border border-white/75 px-4 py-2.5 backdrop-blur-[12px]"
        style={{
          background: "color-mix(in srgb, var(--sf-bg-card) 90%, transparent)",
          boxShadow: "0 14px 32px -18px rgba(20,40,55,.5)",
        }}
      >
        {[
          { color: DOT_COLOR.primary, label: "Đang chạy" },
          { color: DOT_COLOR.warning, label: "Cảnh báo" },
          { color: DOT_COLOR.danger, label: "SOS" },
          { color: DOT_COLOR.neutral, label: "Mất GPS" },
          { color: DOT_COLOR.info, label: "Điểm ngập" },
        ].map((item) => (
          <span
            key={item.label}
            className="flex items-center gap-1.5 text-[11.5px] text-sf-text-secondary"
          >
            <span
              className="h-[7px] w-[7px] rounded-full"
              style={{ background: item.color }}
            />
            {item.label}
          </span>
        ))}
      </div>

      {/* ===================== Panel phải: chi tiết ===================== */}
      {selectedItem && detail && (
        <div
          className="animate-sf-slide-left absolute bottom-5 right-5 top-20 z-[9] flex w-[min(340px,calc(100%-40px))] flex-col overflow-hidden rounded-3xl border border-white/80 backdrop-blur-[18px]"
          style={{
            background: "color-mix(in srgb, var(--sf-bg-card) 96%, transparent)",
            boxShadow: "0 26px 56px -22px rgba(20,40,55,.5)",
          }}
        >
          <div className="flex-none border-b border-[var(--sf-border-card)] px-5 pb-4 pt-5">
            <div className="flex items-start gap-2.5">
              <div className="min-w-0 flex-1">
                <div className="sf-eyebrow">{detail.kindLabel}</div>
                <div className="mt-1.5 truncate text-[17px] font-bold tracking-[-0.015em] text-sf-text">
                  {detail.title}
                </div>
                <div className="mt-1 truncate text-[12.5px] text-sf-text-muted">
                  {detail.subtitle}
                </div>
              </div>
              <button
                type="button"
                aria-label="Đóng"
                onClick={() => setSelectedItem(null)}
                className="grid h-[30px] w-[30px] flex-none cursor-pointer place-items-center rounded-[11px] text-sf-text-muted"
                style={{ background: "var(--sf-bg-inset)" }}
              >
                <X className="h-[18px] w-[18px]" />
              </button>
            </div>
            <Badge tone={detail.tone} dot size="sm" className="mt-3">
              {detail.chip.toUpperCase()}
            </Badge>
          </div>

          <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto px-5 pb-5 pt-4">
            {selectedItem.type === "vehicle" && (
              <>
                {monitoredRoute && (
                  <div
                    className="rounded-[var(--sf-r-lg)] p-4"
                    style={{ background: "var(--sf-bg-inset)" }}
                  >
                    <div className="flex items-center justify-between gap-2.5">
                      <span className="truncate text-[12.5px] font-bold text-sf-text">
                        {activeNavigation?.destinationName ?? "Hành trình đang chạy"}
                      </span>
                      <span className="sf-mono flex-none text-[12px] text-sf-text-muted">
                        {Math.round(monitoredRoute.distanceMeters / 100) / 10} km
                      </span>
                    </div>
                    <div className="mt-2 text-[12px] leading-[1.5] text-sf-text-secondary">
                      Còn khoảng {Math.round(monitoredRoute.durationSeconds / 60)} phút
                      {activeNavigation && !activeNavigation.safe
                        ? " · tuyến đi qua vùng rủi ro"
                        : ""}
                    </div>
                  </div>
                )}

                <div className="grid grid-cols-2 gap-2.5">
                  <MiniStat label="Tốc độ hiện tại" value={`${selectedItem.data.currentSpeed} km/h`} />
                  <MiniStat
                    label="Tín hiệu GPS"
                    value={selectedItem.data.gpsStatus === "online" ? "Ổn định" : "Yếu / mất"}
                    tone={selectedItem.data.gpsStatus === "online" ? undefined : "danger"}
                  />
                </div>

                <div className="grid gap-2.5">
                  <DetailRow
                    label="Tài xế"
                    value={selectedItem.data.currentDriverName ?? "Chưa gán"}
                  />
                  <DetailRow
                    label="Loại xe"
                    value={`${selectedItem.data.type} · ${selectedItem.data.capacity} tấn`}
                  />
                  <DetailRow
                    label="Cập nhật cuối"
                    value={
                      selectedItem.data.lastUpdated
                        ? formatTimeAgo(selectedItem.data.lastUpdated)
                        : "Chưa ghi nhận"
                    }
                    mono
                  />
                  <DetailRow label="Tổng chuyến" value={selectedItem.data.totalTrips} mono />
                  <DetailRow
                    label="Cảnh báo tích lũy"
                    value={selectedItem.data.totalAlerts}
                    mono
                    color={
                      selectedItem.data.totalAlerts > 0 ? "var(--sf-accent-hover)" : undefined
                    }
                  />
                </div>
              </>
            )}

            {selectedItem.type === "flood" && (
              <>
                <div className="grid grid-cols-2 gap-2.5">
                  <MiniStat
                    label="Mức ngập"
                    value={FLOOD_SEVERITY_LABELS[selectedItem.data.severity] ?? selectedItem.data.severity}
                    color="var(--sf-info)"
                  />
                  <MiniStat label="Độ tin cậy" value={`${selectedItem.data.confidence}%`} />
                </div>
                <div
                  className="flex gap-2.5 rounded-[var(--sf-r-md)] p-3.5"
                  style={{ background: "var(--sf-info-soft)" }}
                >
                  <Droplets
                    className="h-[18px] w-[18px] flex-none"
                    style={{ color: "var(--sf-info)" }}
                  />
                  <span className="text-[12px] leading-[1.5]" style={{ color: "var(--sf-info)" }}>
                    {selectedItem.data.reportCount} báo cáo trùng ·{" "}
                    {selectedItem.data.affectedVehicles} xe trong vùng ảnh hưởng ·{" "}
                    {formatTimeAgo(selectedItem.data.lastUpdated)}
                  </span>
                </div>
              </>
            )}

            {selectedItem.type === "incident" && (
              <>
                <div className="grid gap-2.5">
                  <DetailRow label="Tài xế" value={selectedItem.data.driverName} />
                  <DetailRow label="Vị trí" value={selectedItem.data.location} />
                  <DetailRow
                    label="Thời điểm"
                    value={formatTimeAgo(selectedItem.data.timestamp)}
                    mono
                  />
                  <DetailRow
                    label="Số bước xử lý"
                    value={selectedItem.data.timeline.length}
                    mono
                  />
                </div>
                <div
                  className="flex gap-2.5 rounded-[var(--sf-r-md)] p-3.5"
                  style={{ background: "var(--sf-danger-soft)" }}
                >
                  <Siren
                    className="h-[18px] w-[18px] flex-none"
                    style={{ color: "var(--sf-danger)" }}
                  />
                  <span className="text-[12px] leading-[1.5]" style={{ color: "var(--sf-danger)" }}>
                    {selectedItem.data.description || "Sự cố chưa có mô tả chi tiết."}
                  </span>
                </div>
              </>
            )}
          </div>

          <div className="flex flex-none gap-2.5 border-t border-[var(--sf-border-card)] px-5 py-4">
            {selectedItem.type === "incident" && canAcceptIncident ? (
              <button
                type="button"
                disabled={acceptingIncidentId === selectedItem.data.id}
                onClick={() => void handleAcceptIncident(selectedItem.data)}
                className="flex-1 cursor-pointer rounded-[15px] border-0 py-3 text-[12.5px] font-semibold text-white disabled:opacity-50"
                style={{
                  background: "linear-gradient(140deg,#0b8c7f,#076a61)",
                  boxShadow: "0 14px 26px -14px rgba(8,127,115,.7)",
                }}
              >
                {acceptingIncidentId === selectedItem.data.id ? "Đang xử lý…" : "Tiếp nhận sự cố"}
              </button>
            ) : (
              <button
                type="button"
                onClick={() =>
                  router.push(selectedItem.type === "flood" ? "/flood-map" : "/drivers")
                }
                className="flex flex-1 cursor-pointer items-center justify-center gap-2 rounded-[15px] border-0 py-3 text-[12.5px] font-semibold text-white"
                style={{
                  background: "linear-gradient(140deg,#0b8c7f,#076a61)",
                  boxShadow: "0 14px 26px -14px rgba(8,127,115,.7)",
                }}
              >
                {selectedItem.type === "flood" ? (
                  "Mở trang điểm ngập"
                ) : (
                  <>
                    <Phone className="h-4 w-4" />
                    Liên hệ tài xế
                  </>
                )}
              </button>
            )}
            <button
              type="button"
              onClick={() =>
                router.push(selectedItem.type === "incident" ? "/incidents" : "/trips")
              }
              className="flex-1 cursor-pointer rounded-[15px] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] py-3 text-[12.5px] font-semibold text-sf-text-secondary"
            >
              {selectedItem.type === "incident" ? "Xem sự cố" : "Xem chuyến"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
