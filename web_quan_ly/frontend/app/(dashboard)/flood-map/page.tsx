"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import MapView, { type MapViewHandle } from "@/components/map/MapView";
import { FloodPoint, FloodSeverity, Vehicle } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { formatDateTime, formatTimeAgo } from "@/lib/utils";
import { useToast } from "@/context/ToastContext";
import {
  Badge,
  Callout,
  FilterChips,
  MiniStat,
  Skeleton,
  toneOf,
  type FilterChip,
} from "@/components/ui";
import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  Clock3,
  Droplets,
  LocateFixed,
  MapPin,
  Navigation,
  Radio,
  RefreshCw,
  Send,
  ShieldCheck,
  Truck,
} from "lucide-react";

const SEVERITY_VI: Record<FloodSeverity, string> = {
  light: "Ngập nhẹ",
  moderate: "Ngập vừa",
  heavy: "Ngập nặng",
  impassable: "Đường bị chặn",
};

const SEVERITY_ORDER: FloodSeverity[] = [
  "impassable",
  "heavy",
  "moderate",
  "light",
];

const SEVERITY_RANK: Record<FloodSeverity, number> = {
  light: 1,
  moderate: 2,
  heavy: 3,
  impassable: 4,
};

const TRAFFIC_SEVERITY_VI: Record<FloodSeverity, string> = {
  light: "Di chuyển chậm",
  moderate: "Ùn kéo dài",
  heavy: "Tắc nghẽn nặng",
  impassable: "Tắc cứng",
};

function severityLabel(point: FloodPoint) {
  return point.hazardType === "traffic_jam"
    ? TRAFFIC_SEVERITY_VI[point.severity]
    : SEVERITY_VI[point.severity];
}

type Filter = "all" | FloodSeverity | "unverified";

function distanceKm(aLat: number, aLng: number, bLat: number, bLng: number) {
  const radians = (value: number) => (value * Math.PI) / 180;
  const earthRadiusKm = 6371;
  const dLat = radians(bLat - aLat);
  const dLng = radians(bLng - aLng);
  const value =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(aLat)) *
      Math.cos(radians(bLat)) *
      Math.sin(dLng / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
}

function routingPolicy(point: FloodPoint) {
  if (point.severity === "impassable") {
    return {
      label: "Đang loại khỏi tuyến",
      description: "Điểm BLOCKED được gửi vào bộ định tuyến như một vùng cấm.",
      tone: "danger" as const,
    };
  }
  if (
    point.severity === "heavy" &&
    (point.verified || point.confidence >= 65)
  ) {
    return {
      label: "Đang ưu tiên đường vòng",
      description: "Tuyến mới sẽ né điểm này; tuyến đang chạy được đánh giá lại khi có mạng.",
      tone: "warning" as const,
    };
  }
  return {
    label: "Chờ thêm bằng chứng",
    description: "Điểm vẫn hiển thị cảnh báo nhưng chưa tự động chặn toàn bộ tuyến.",
    tone: "info" as const,
  };
}

export default function FloodMapPage() {
  const { showToast } = useToast();
  const mapRef = useRef<MapViewHandle>(null);
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [selectedPointId, setSelectedPointId] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [busyPointId, setBusyPointId] = useState("");
  const [lastSyncedAt, setLastSyncedAt] = useState<Date | null>(null);

  const load = useCallback(
    async (silent = false) => {
      if (silent) setIsRefreshing(true);
      else setIsLoading(true);
      try {
        const [points, fleet] = await Promise.all([
          safeFleetApi.floodPoints(),
          safeFleetApi.vehicles(),
        ]);
        setFloodPoints(points);
        setVehicles(fleet);
        setLastSyncedAt(new Date());
      } catch (error) {
        showToast(
          error instanceof Error
            ? error.message
            : "Không tải được dữ liệu ngập và vị trí xe.",
          "error"
        );
      } finally {
        setIsLoading(false);
        setIsRefreshing(false);
      }
    },
    [showToast]
  );

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(true), 20_000);
    return () => window.clearInterval(timer);
  }, [load]);

  const selectedPoint = useMemo(
    () => floodPoints.find((point) => point.id === selectedPointId) ?? null,
    [floodPoints, selectedPointId]
  );

  const filtered = useMemo(
    () =>
      floodPoints
        .filter((point) => {
          if (filter === "all") return true;
          if (filter === "unverified") return !point.verified;
          return point.severity === filter;
        })
        .sort(
          (left, right) =>
            SEVERITY_RANK[right.severity] - SEVERITY_RANK[left.severity] ||
            new Date(right.receivedAt).getTime() - new Date(left.receivedAt).getTime()
        ),
    [floodPoints, filter]
  );

  useEffect(() => {
    if (selectedPoint && !filtered.some((point) => point.id === selectedPoint.id)) {
      setSelectedPointId("");
    }
  }, [filtered, selectedPoint]);

  const chips = useMemo(() => {
    const items: FilterChip[] = [
      { key: "all", label: "Tất cả", count: floodPoints.length },
    ];
    for (const key of SEVERITY_ORDER) {
      const count = floodPoints.filter((point) => point.severity === key).length;
      if (count > 0) items.push({ key, label: SEVERITY_VI[key], count });
    }
    const unverified = floodPoints.filter((point) => !point.verified).length;
    if (unverified > 0) {
      items.push({ key: "unverified", label: "Chưa xác minh", count: unverified });
    }
    return items;
  }, [floodPoints]);

  const liveVehicles = useMemo(
    () =>
      vehicles.filter(
        (vehicle) =>
          vehicle.lat != null &&
          vehicle.lng != null &&
          vehicle.gpsStatus !== "offline"
      ),
    [vehicles]
  );

  const nearbyVehicles = useMemo(() => {
    if (!selectedPoint) return [];
    return liveVehicles.filter(
      (vehicle) =>
        distanceKm(
          selectedPoint.lat,
          selectedPoint.lng,
          vehicle.lat!,
          vehicle.lng!
        ) <= 10
    );
  }, [liveVehicles, selectedPoint]);

  const stats = useMemo(
    () => ({
      active: floodPoints.length,
      blocked: floodPoints.filter((point) => point.severity === "impassable").length,
      unverified: floodPoints.filter((point) => !point.verified).length,
      protectedVehicles: liveVehicles.length,
    }),
    [floodPoints, liveVehicles]
  );

  const selectPoint = (point: FloodPoint) => {
    setSelectedPointId(point.id);
    mapRef.current?.flyTo(point.lat, point.lng, 15);
  };

  const updatePoint = (next: FloodPoint) => {
    setFloodPoints((current) =>
      current.map((point) => (point.id === next.id ? next : point))
    );
    setSelectedPointId(next.id);
  };

  const handleVerify = async (point: FloodPoint) => {
    setBusyPointId(point.id);
    try {
      updatePoint(await safeFleetApi.verifyFloodPoint(point.id));
      showToast("Đã xác minh; bộ định tuyến sẽ áp dụng chính sách né tuyến.", "success");
    } catch (error) {
      showToast(
        error instanceof Error ? error.message : "Không thể xác minh cảnh báo.",
        "error"
      );
    } finally {
      setBusyPointId("");
    }
  };

  const handleResolve = async (point: FloodPoint) => {
    if (!window.confirm("Xác nhận tình trạng tại khu vực này đã kết thúc?")) return;
    setBusyPointId(point.id);
    try {
      await safeFleetApi.resolveFloodPoint(point.id);
      setFloodPoints((current) => current.filter((item) => item.id !== point.id));
      setSelectedPointId("");
      showToast("Đã gỡ vùng tránh khỏi các yêu cầu định tuyến mới.", "success");
    } catch (error) {
      showToast(
        error instanceof Error ? error.message : "Không thể kết thúc cảnh báo.",
        "error"
      );
    } finally {
      setBusyPointId("");
    }
  };

  const handleWarn = async (point: FloodPoint) => {
    setBusyPointId(point.id);
    try {
      const result = await safeFleetApi.warnNearbyFloodPoint(point.id);
      showToast(
        result.recipientCount > 0
          ? `Đã gửi tới ${result.recipientCount} tài xế trong bán kính ${result.radiusKm} km.`
          : `Không có tài xế trực tuyến trong bán kính ${result.radiusKm} km.`,
        result.recipientCount > 0 ? "success" : "info"
      );
    } catch (error) {
      showToast(
        error instanceof Error ? error.message : "Không gửi được cảnh báo.",
        "error"
      );
    } finally {
      setBusyPointId("");
    }
  };

  return (
    <div className="grid gap-5">
      <section className="sf-surface overflow-hidden p-5 sm:p-6">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="flex items-center gap-2">
            <span className="grid h-10 w-10 place-items-center rounded-[14px] bg-[var(--sf-info-soft)] text-[var(--sf-info)]">
              <Droplets className="h-5 w-5" />
            </span>
            <div>
              <h1 className="text-[20px] font-bold tracking-[-0.02em] text-sf-text">
                Điều hành ngập lụt theo thời gian thực
              </h1>
              <p className="mt-0.5 text-[12.5px] text-sf-text-muted">
                Xác minh báo cáo, theo dõi xe GPS và kiểm soát vùng né tuyến.
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Badge tone="success" dot>
              LIVE · 20 GIÂY
            </Badge>
            <button
              type="button"
              onClick={() => void load(true)}
              disabled={isRefreshing}
              className="inline-flex cursor-pointer items-center gap-2 rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] px-3.5 py-2.5 text-[12.5px] font-semibold text-sf-text-secondary disabled:opacity-50"
            >
              <RefreshCw className={`h-4 w-4 ${isRefreshing ? "animate-spin" : ""}`} />
              Làm mới
            </button>
          </div>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-4">
          <MiniStat label="Điểm đang hiệu lực" value={stats.active} color="var(--sf-info)" />
          <MiniStat label="Đường bị chặn" value={stats.blocked} tone="danger" />
          <MiniStat label="Chờ xác minh" value={stats.unverified} tone="warning" />
          <MiniStat
            label="Xe GPS trực tuyến"
            value={stats.protectedVehicles}
            color="var(--sf-success)"
          />
        </div>
      </section>

      <div className="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_380px]">
        <section className="sf-surface overflow-hidden">
          <div className="flex flex-wrap items-center gap-2.5 border-b border-[var(--sf-border)] px-5 py-4">
            <FilterChips
              items={chips}
              value={filter}
              onChange={(key) => setFilter(key as Filter)}
            />
            <span className="flex-1" />
            <span className="flex items-center gap-1.5 text-[11.5px] text-sf-text-muted">
              <Radio className="h-3.5 w-3.5 text-[var(--sf-success)]" />
              {lastSyncedAt
                ? `Đồng bộ ${formatTimeAgo(lastSyncedAt.toISOString())}`
                : "Đang kết nối"}
            </span>
          </div>

          <div className="relative m-4 h-[470px] overflow-hidden rounded-[22px] xl:h-[calc(100vh-340px)] xl:min-h-[500px]">
            {isLoading ? (
              <Skeleton className="h-full w-full" />
            ) : (
              <MapView
                ref={mapRef}
                vehicles={liveVehicles}
                floodPoints={filtered}
                onFloodPointClick={selectPoint}
                selectedVehicleId={null}
                showNativeControls={false}
              />
            )}
            <div className="pointer-events-none absolute left-3 top-3 flex flex-wrap gap-2">
              <span className="rounded-full bg-[var(--sf-bg-card)]/95 px-3 py-1.5 text-[11px] font-semibold text-sf-text shadow-[var(--sf-shadow-sm)]">
                <span className="mr-1.5 inline-block h-2 w-2 rounded-full bg-[var(--sf-danger)]" />
                Chặn đường
              </span>
              <span className="rounded-full bg-[var(--sf-bg-card)]/95 px-3 py-1.5 text-[11px] font-semibold text-sf-text shadow-[var(--sf-shadow-sm)]">
                <span className="mr-1.5 inline-block h-2 w-2 rounded-full bg-[var(--sf-primary)]" />
                Xe trực tuyến
              </span>
            </div>
            <div className="absolute bottom-3 right-3 grid gap-2">
              <button
                type="button"
                aria-label="Về toàn cảnh"
                onClick={() => mapRef.current?.reset()}
                className="grid h-10 w-10 cursor-pointer place-items-center rounded-xl border border-[var(--sf-border)] bg-[var(--sf-bg-card)] text-sf-text shadow-[var(--sf-shadow-md)]"
              >
                <LocateFixed className="h-4 w-4" />
              </button>
            </div>
          </div>

          <div className="border-t border-[var(--sf-border)] p-4">
            <div className="mb-3 flex items-center justify-between">
              <p className="sf-eyebrow">Ưu tiên xử lý</p>
              <span className="text-[11.5px] text-sf-text-muted">
                {filtered.length} báo cáo
              </span>
            </div>
            {filtered.length === 0 ? (
              <div className="py-7 text-center text-[12.5px] text-sf-text-muted">
                Không có điểm ngập phù hợp bộ lọc.
              </div>
            ) : (
              <div className="grid gap-2.5 md:grid-cols-2">
                {filtered.slice(0, 6).map((point) => (
                  <button
                    key={point.id}
                    type="button"
                    onClick={() => selectPoint(point)}
                    className={`cursor-pointer rounded-[var(--sf-r-md)] border p-3.5 text-left transition-colors ${
                      point.id === selectedPointId
                        ? "border-[var(--sf-primary)] bg-[var(--sf-primary-soft)]"
                        : "border-[var(--sf-border)] bg-[var(--sf-bg-card)] hover:bg-[var(--sf-bg-hover)]"
                    }`}
                  >
                    <div className="flex items-center justify-between gap-2">
                      <Badge tone={toneOf(point.severity)} dot size="sm">
                        {severityLabel(point).toUpperCase()}
                      </Badge>
                      <span className="sf-mono text-[10.5px] text-sf-text-muted">
                        {formatTimeAgo(point.receivedAt)}
                      </span>
                    </div>
                    <p className="mt-2 line-clamp-1 text-[13px] font-semibold text-sf-text">
                      {point.location}
                    </p>
                    <p className="mt-1 text-[11.5px] text-sf-text-muted">
                      Tin cậy {point.confidence}% · {point.verified ? "đã xác minh" : "chờ xác minh"}
                    </p>
                  </button>
                ))}
              </div>
            )}
          </div>
        </section>

        <aside className="sf-surface p-5 xl:sticky xl:top-5">
          {!selectedPoint ? (
            <div className="py-12 text-center">
              <span className="mx-auto grid h-16 w-16 place-items-center rounded-full bg-[var(--sf-info-soft)] text-[var(--sf-info)]">
                <Navigation className="h-7 w-7" />
              </span>
              <p className="mt-4 text-[15px] font-bold text-sf-text">
                Chọn một vùng cảnh báo
              </p>
              <p className="mx-auto mt-1.5 max-w-[270px] text-[12.5px] leading-relaxed text-sf-text-muted">
                Chọn marker hoặc báo cáo ưu tiên để xác minh, xem xe ở gần và gửi cảnh báo.
              </p>
            </div>
          ) : (
            <FloodDetail
              point={selectedPoint}
              nearbyVehicles={nearbyVehicles}
              busy={busyPointId === selectedPoint.id}
              onVerify={() => void handleVerify(selectedPoint)}
              onWarn={() => void handleWarn(selectedPoint)}
              onResolve={() => void handleResolve(selectedPoint)}
            />
          )}
        </aside>
      </div>
    </div>
  );
}

function FloodDetail({
  point,
  nearbyVehicles,
  busy,
  onVerify,
  onWarn,
  onResolve,
}: {
  point: FloodPoint;
  nearbyVehicles: Vehicle[];
  busy: boolean;
  onVerify: () => void;
  onWarn: () => void;
  onResolve: () => void;
}) {
  const policy = routingPolicy(point);
  return (
    <div className="animate-sf-slide-left">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Badge tone={point.hazardType === "traffic_jam" ? "warning" : "info"}>
            {point.hazardType === "traffic_jam" ? "KẸT XE" : "NGẬP NƯỚC"}
          </Badge>
          <Badge
            tone={toneOf(point.severity)}
            dot
            solid={point.severity === "impassable"}
          >
            {severityLabel(point).toUpperCase()}
          </Badge>
        </div>
        <Badge tone={point.verified ? "success" : "warning"}>
          {point.verified ? "ĐÃ XÁC MINH" : "CHƯA XÁC MINH"}
        </Badge>
      </div>

      <h2 className="mt-4 text-[18px] font-bold leading-snug tracking-[-0.01em] text-sf-text">
        {point.location}
      </h2>
      <p className="mt-2 flex items-center gap-1.5 text-[11.5px] text-sf-text-muted">
        <MapPin className="h-3.5 w-3.5" />
        <span className="sf-mono">
          {point.lat.toFixed(5)}, {point.lng.toFixed(5)}
        </span>
      </p>

      <div className="mt-5 grid grid-cols-2 gap-2.5">
        <MiniStat
          label="Độ tin cậy"
          value={`${point.confidence}%`}
          color="var(--sf-success)"
        />
        <MiniStat label="Xe trong 10 km" value={nearbyVehicles.length} tone="warning" />
        <MiniStat label="Nguồn" value={point.source} color="var(--sf-info)" />
        <MiniStat
          label="Phạm vi"
          value={
            point.geometryType === "segment"
              ? "Tuyến ngập"
              : point.geometryType === "polygon"
                ? "Vùng ngập"
                : `${point.radiusMeters ?? 120} m`
          }
          color="var(--sf-primary)"
        />
        <MiniStat
          label="Nhận lúc"
          value={formatTimeAgo(point.receivedAt)}
          color="var(--sf-text-muted)"
        />
      </div>

      <div className="mt-4">
        <Callout
          tone={policy.tone}
          icon={policy.tone === "danger" ? AlertTriangle : ShieldCheck}
          title={policy.label}
        >
          {policy.description}
        </Callout>
      </div>

      <div className="mt-5 space-y-2.5 rounded-[var(--sf-r-md)] bg-[var(--sf-bg-inset)] p-3.5">
        <p className="sf-eyebrow">Bằng chứng vận hành</p>
        <p className="flex items-center gap-2 text-[12px] text-sf-text-secondary">
          <Activity className="h-4 w-4 text-[var(--sf-info)]" />
          {point.reporterName ? `Tài xế ${point.reporterName}` : "Nguồn hệ thống"}
        </p>
        <p className="flex items-center gap-2 text-[12px] text-sf-text-secondary">
          <Clock3 className="h-4 w-4 text-sf-text-muted" />
          {formatDateTime(point.receivedAt)}
        </p>
        {point.expiresAt ? (
          <p className="flex items-center gap-2 text-[12px] text-sf-text-secondary">
            <RefreshCw className="h-4 w-4 text-sf-text-muted" />
            Hết hiệu lực dự kiến {formatDateTime(point.expiresAt)}
          </p>
        ) : null}
      </div>

      {nearbyVehicles.length > 0 ? (
        <div className="mt-5">
          <p className="sf-eyebrow">
            Xe cần theo dõi gần {point.hazardType === "traffic_jam" ? "điểm kẹt xe" : "điểm ngập"}
          </p>
          <div className="mt-2.5 grid gap-2">
            {nearbyVehicles.slice(0, 4).map((vehicle) => (
              <div
                key={vehicle.id}
                className="flex items-center gap-2.5 rounded-[var(--sf-r-sm)] border border-[var(--sf-border)] px-3 py-2.5"
              >
                <Truck className="h-4 w-4 text-[var(--sf-primary)]" />
                <span className="sf-mono text-[12px] font-semibold text-sf-text">
                  {vehicle.plate}
                </span>
                <span className="ml-auto text-[11px] text-sf-text-muted">
                  {vehicle.currentSpeed} km/h
                </span>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      <div className="mt-5 grid gap-2.5">
        {!point.verified ? (
          <button
            type="button"
            disabled={busy}
            onClick={onVerify}
            className="cursor-pointer rounded-[var(--sf-r-md)] border-0 bg-[linear-gradient(140deg,#0b8c7f,#076a61)] py-3.5 text-[13px] font-semibold text-white shadow-[0_14px_28px_-14px_rgba(8,127,115,.7)] disabled:opacity-50"
          >
            <CheckCircle2 className="mr-2 inline h-[17px] w-[17px] align-text-bottom" />
            Xác minh và áp dụng né tuyến
          </button>
        ) : null}
        <button
          type="button"
          disabled={busy}
          onClick={onWarn}
          className="cursor-pointer rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] py-3.5 text-[13px] font-semibold text-sf-text-secondary disabled:opacity-50"
        >
          <Send className="mr-2 inline h-[17px] w-[17px] align-text-bottom" />
          Cảnh báo xe trong bán kính 10 km
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={onResolve}
          className="cursor-pointer rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] py-3 text-[12.5px] font-semibold text-sf-text-muted disabled:opacity-50"
        >
          {point.hazardType === "traffic_jam"
            ? "Đánh dấu khu vực đã hết kẹt xe"
            : "Đánh dấu khu vực đã hết ngập"}
        </button>
      </div>
    </div>
  );
}
