"use client";

import { useEffect, useState, useMemo } from "react";
import MapView from "@/components/map/MapView";
import { FloodPoint, FloodSeverity } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { formatTimeAgo } from "@/lib/utils";
import { CheckCircle2, Droplets, MapPin, Route, Send } from "lucide-react";
import { useToast } from "@/context/ToastContext";
import {
  Badge,
  FilterChips,
  MiniStat,
  Skeleton,
  toneOf,
  type FilterChip,
} from "@/components/ui";

/* Đủ bốn mức ngập của backend — bản thiết kế chỉ vẽ ba. */
const SEVERITY_VI: Record<FloodSeverity, string> = {
  light: "Ngập nhẹ",
  moderate: "Ngập vừa",
  heavy: "Ngập nặng",
  impassable: "Đường bị chặn",
};

const SEVERITY_ORDER: FloodSeverity[] = ["light", "moderate", "heavy", "impassable"];

/** "all" | mức ngập | "unverified" — chip "Chưa xác minh" lọc theo cờ verified */
type Filter = "all" | FloodSeverity | "unverified";

export default function FloodMapPage() {
  const { showToast } = useToast();
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedPoint, setSelectedPoint] = useState<FloodPoint | null>(null);
  const [filter, setFilter] = useState<Filter>("all");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.floodPoints();
        if (!cancelled) setFloodPoints(data);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được điểm ngập.";
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

  const filtered = useMemo(
    () =>
      floodPoints.filter((p) => {
        if (filter === "all") return true;
        if (filter === "unverified") return !p.verified;
        return p.severity === filter;
      }),
    [floodPoints, filter]
  );

  /* Chip lọc chỉ hiện mức thực sự có dữ liệu, luôn có "Tất cả" đứng đầu */
  const chips = useMemo(() => {
    const items: FilterChip[] = [{ key: "all", label: "Tất cả", count: floodPoints.length }];
    SEVERITY_ORDER.forEach((key) => {
      const count = floodPoints.filter((p) => p.severity === key).length;
      if (count > 0) items.push({ key, label: SEVERITY_VI[key], count });
    });
    const unverified = floodPoints.filter((p) => !p.verified).length;
    if (unverified > 0) items.push({ key: "unverified", label: "Chưa xác minh", count: unverified });
    return items;
  }, [floodPoints]);

  /* Khi bộ lọc đổi mà điểm đang chọn bị lọc ra thì bỏ chọn cho khỏi lệch */
  useEffect(() => {
    if (selectedPoint && !filtered.some((p) => p.id === selectedPoint.id)) {
      setSelectedPoint(null);
    }
  }, [filtered, selectedPoint]);

  const updateFloodPoint = (next: FloodPoint) => {
    setFloodPoints((prev) => prev.map((p) => (p.id === next.id ? next : p)));
    setSelectedPoint(next);
  };

  const handleVerify = async (id: string) => {
    setBusy(true);
    try {
      updateFloodPoint(await safeFleetApi.verifyFloodPoint(id));
      showToast("Đã xác minh điểm ngập.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể xác minh điểm ngập.", "error");
    } finally {
      setBusy(false);
    }
  };

  const handleClearFlood = async (id: string) => {
    setBusy(true);
    try {
      updateFloodPoint(await safeFleetApi.resolveFloodPoint(id));
      showToast("Đã đánh dấu hết ngập.", "info");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể cập nhật điểm ngập.", "error");
    } finally {
      setBusy(false);
    }
  };

  const handleSendWarning = async (point: FloodPoint) => {
    setBusy(true);
    try {
      const result = await safeFleetApi.warnNearbyFloodPoint(point.id);
      showToast(
        result.recipientCount > 0
          ? `Đã gửi cảnh báo tới ${result.recipientCount} tài xế trong bán kính ${result.radiusKm} km.`
          : `Không có xe đang hoạt động trong bán kính ${result.radiusKm} km.`,
        result.recipientCount > 0 ? "success" : "info"
      );
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không gửi được cảnh báo ngập.", "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="grid items-start gap-5 xl:grid-cols-[minmax(0,1fr)_340px]">
      {/* ===================== Bản đồ ===================== */}
      <div className="sf-surface overflow-hidden">
        <div className="flex flex-wrap items-center gap-2.5 px-6 py-5">
          <FilterChips items={chips} value={filter} onChange={(k) => setFilter(k as Filter)} />
          <span className="flex-1" />
          <span className="flex items-center gap-2 text-[12px] text-sf-text-muted">
            <Droplets className="h-4 w-4" style={{ color: "var(--sf-info)" }} />
            {filtered.length} điểm đang hiển thị
          </span>
        </div>

        <div className="sf-map-dark mx-4 mb-4 h-[420px] overflow-hidden rounded-[22px] xl:h-[calc(100vh-300px)] xl:min-h-[440px]">
          <MapView
            floodPoints={filtered}
            onFloodPointClick={(p) => setSelectedPoint(p)}
            selectedVehicleId={null}
          />
        </div>
      </div>

      {/* ===================== Chi tiết điểm ngập ===================== */}
      <div className="sf-surface animate-sf-slide-left p-6">
        {isLoading && !selectedPoint ? (
          <div className="grid gap-3">
            <Skeleton className="h-6 w-32" />
            <Skeleton className="h-8 w-full" />
            <Skeleton className="h-24 w-full" />
          </div>
        ) : !selectedPoint ? (
          <div className="py-10 text-center">
            <span
              className="mx-auto grid h-14 w-14 place-items-center rounded-full"
              style={{ background: "var(--sf-info-soft)", color: "var(--sf-info)" }}
            >
              <Droplets className="h-7 w-7" />
            </span>
            <p className="mt-4 text-[15px] font-bold text-sf-text">Chưa chọn điểm ngập</p>
            <p className="mt-1.5 text-[12.5px] leading-relaxed text-sf-text-muted">
              Bấm một điểm trên bản đồ để xem mức ngập, độ tin cậy và gửi cảnh báo cho xe gần đó.
            </p>
          </div>
        ) : (
          <>
            <div className="flex items-center justify-between gap-3">
              <Badge
                tone={toneOf(selectedPoint.severity)}
                dot
                size="sm"
                solid={selectedPoint.severity === "impassable"}
              >
                {SEVERITY_VI[selectedPoint.severity].toUpperCase()}
              </Badge>
              <span className="sf-mono text-[11.5px] text-sf-text-muted">
                {formatTimeAgo(selectedPoint.lastUpdated)}
              </span>
            </div>

            <h3 className="mt-3.5 text-[18px] font-bold tracking-[-0.01em] text-sf-text">
              {selectedPoint.location}
            </h3>
            <p className="mt-1.5 text-[12.5px] text-sf-text-muted">
              Nguồn: {selectedPoint.source} · {selectedPoint.reportCount} báo cáo
            </p>
            <p className="mt-1.5 flex items-center gap-1.5 text-[11.5px] text-sf-text-muted">
              <MapPin className="h-3 w-3 flex-none" />
              <span className="sf-mono">
                {selectedPoint.lat.toFixed(5)}, {selectedPoint.lng.toFixed(5)}
              </span>
            </p>

            <div className="mt-5 grid grid-cols-2 gap-2.5">
              <MiniStat
                label="Mức ngập"
                value={SEVERITY_VI[selectedPoint.severity]}
                color="var(--sf-info)"
              />
              <MiniStat
                label="Độ tin cậy"
                value={`${selectedPoint.confidence}%`}
                color="var(--sf-success)"
              />
              <MiniStat label="Báo cáo trùng" value={selectedPoint.reportCount} />
              <MiniStat
                label="Xe bị ảnh hưởng"
                value={selectedPoint.affectedVehicles}
                tone="warning"
              />
            </div>

            {selectedPoint.affectedRoutes.length > 0 && (
              <div
                className="mt-3 rounded-[var(--sf-r-md)] p-3.5"
                style={{ background: "var(--sf-bg-inset)" }}
              >
                <span className="mb-2 flex items-center gap-1.5 text-[11.5px] text-sf-text-muted">
                  <Route className="h-3.5 w-3.5" />
                  Tuyến bị ảnh hưởng
                </span>
                <span className="flex flex-wrap gap-1.5">
                  {selectedPoint.affectedRoutes.map((code) => (
                    <Badge key={code} tone="primary" size="sm">
                      {code}
                    </Badge>
                  ))}
                </span>
              </div>
            )}

            <div className="mt-5 grid gap-2.5">
              {!selectedPoint.verified && (
                <button
                  type="button"
                  disabled={busy}
                  onClick={() => void handleVerify(selectedPoint.id)}
                  className="cursor-pointer rounded-[var(--sf-r-md)] border-0 py-3.5 text-[13px] font-semibold text-white disabled:opacity-50"
                  style={{
                    background: "linear-gradient(140deg,#0b8c7f,#076a61)",
                    boxShadow: "0 14px 28px -14px rgba(8,127,115,.7)",
                  }}
                >
                  <CheckCircle2 className="mr-2 inline h-[17px] w-[17px] align-text-bottom" />
                  Xác minh điểm ngập
                </button>
              )}
              <button
                type="button"
                disabled={busy}
                onClick={() => void handleSendWarning(selectedPoint)}
                className="cursor-pointer rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] py-3.5 text-[13px] font-semibold text-sf-text-secondary disabled:opacity-50"
              >
                <Send className="mr-2 inline h-[17px] w-[17px] align-text-bottom" />
                Gửi cảnh báo cho xe gần
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={() => void handleClearFlood(selectedPoint.id)}
                className="cursor-pointer rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] py-3.5 text-[13px] font-semibold text-sf-text-secondary disabled:opacity-50"
              >
                Đánh dấu hết ngập
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
