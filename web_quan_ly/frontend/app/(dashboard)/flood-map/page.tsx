"use client";

import { useEffect, useState, useMemo } from "react";
import MapView from "@/components/map/MapView";
import { FloodPoint, FloodSeverity } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { formatTimeAgo } from "@/lib/utils";
import { AnimatePresence, motion } from "framer-motion";
import { Droplets, CheckCircle2, Send, X, MapPin, Route } from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { Badge, Button, IconButton, InfoRow, Segmented, StatusDot, toneOf } from "@/components/ui";

const SEVERITY_VI: Record<FloodSeverity, string> = {
  light: "Ngập nhẹ",
  moderate: "Ngập vừa",
  heavy: "Ngập nặng",
  impassable: "Không thể đi qua",
};

const SEVERITY_FILTERS = ["all", "light", "moderate", "heavy", "impassable"] as const;
type SeverityFilter = (typeof SEVERITY_FILTERS)[number];

type VerifyFilter = "all" | "verified" | "unverified";

export default function FloodMapPage() {
  const { showToast } = useToast();
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedPoint, setSelectedPoint] = useState<FloodPoint | null>(null);
  const [severityFilter, setSeverityFilter] = useState<SeverityFilter>("all");
  const [verifyFilter, setVerifyFilter] = useState<VerifyFilter>("all");
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
        if (severityFilter !== "all" && p.severity !== severityFilter) return false;
        if (verifyFilter === "verified" && !p.verified) return false;
        if (verifyFilter === "unverified" && p.verified) return false;
        return true;
      }),
    [floodPoints, severityFilter, verifyFilter]
  );

  const counts = useMemo(
    () => ({
      all: floodPoints.length,
      light: floodPoints.filter((p) => p.severity === "light").length,
      moderate: floodPoints.filter((p) => p.severity === "moderate").length,
      heavy: floodPoints.filter((p) => p.severity === "heavy").length,
      impassable: floodPoints.filter((p) => p.severity === "impassable").length,
    }),
    [floodPoints]
  );

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
    <div className="relative flex h-[calc(100vh-68px)] w-full overflow-hidden bg-[var(--sf-bg-inset)]">
      {/* ===== Bản đồ toàn màn hình ===== */}
      <div className="sf-map-dark absolute inset-0 z-0">
        <MapView
          floodPoints={filtered}
          onFloodPointClick={(p) => setSelectedPoint(p)}
          selectedVehicleId={null}
        />
      </div>

      {/* ===== Thanh điều khiển nổi ===== */}
      <div className="pointer-events-none absolute inset-x-4 top-4 z-10 flex flex-col items-start justify-between gap-3 md:flex-row md:items-center">
        <div className="sf-glass-panel pointer-events-auto flex max-w-full items-center gap-2 overflow-x-auto p-2">
          <span className="flex flex-shrink-0 items-center gap-2 pl-1.5 pr-1 text-[12.5px] font-extrabold text-sf-text">
            <Droplets className="h-4 w-4" style={{ color: "var(--sf-primary)" }} />
            {filtered.length} điểm
          </span>
          <Segmented
            value={severityFilter}
            onChange={setSeverityFilter}
            options={SEVERITY_FILTERS.map((s) => ({
              value: s,
              label: s === "all" ? "Tất cả" : SEVERITY_VI[s as FloodSeverity],
              count: counts[s],
            }))}
            size="sm"
          />
        </div>

        <div className="sf-glass-panel pointer-events-auto flex items-center gap-2 p-2">
          {isLoading && (
            <span className="flex items-center gap-1.5 pl-1 text-[12.5px] font-bold text-sf-text-muted">
              <StatusDot tone="warning" pulse /> Đang tải…
            </span>
          )}
          <Segmented
            value={verifyFilter}
            onChange={setVerifyFilter}
            options={[
              { value: "all", label: "Tất cả" },
              { value: "verified", label: "Đã xác minh" },
              { value: "unverified", label: "Chưa xác minh" },
            ]}
            size="sm"
          />
        </div>
      </div>

      {/* ===== Panel chi tiết ===== */}
      <AnimatePresence>
        {selectedPoint && (
          <motion.aside
            initial={{ opacity: 0, x: 340 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 340 }}
            transition={{ type: "spring", stiffness: 320, damping: 32 }}
            className="sf-glass-panel absolute bottom-4 right-4 top-4 z-20 flex w-[21rem] flex-col overflow-hidden"
          >
            <div className="flex flex-shrink-0 items-center justify-between border-b border-[var(--sf-border)] px-4 py-3.5">
              <h3 className="flex items-center gap-2 text-[13.5px] font-extrabold text-sf-text">
                <Droplets className="h-4 w-4" style={{ color: "var(--sf-primary)" }} />
                Thông tin điểm ngập
              </h3>
              <IconButton
                icon={X}
                label="Đóng"
                size="sm"
                onClick={() => setSelectedPoint(null)}
              />
            </div>

            <div className="min-h-0 flex-1 space-y-4 overflow-y-auto p-4">
              <div>
                <div className="flex flex-wrap items-center gap-2">
                  <Badge
                    tone={toneOf(selectedPoint.severity)}
                    solid={selectedPoint.severity === "impassable"}
                  >
                    {SEVERITY_VI[selectedPoint.severity]}
                  </Badge>
                  <Badge tone={selectedPoint.verified ? "success" : "warning"} size="sm">
                    {selectedPoint.verified ? "Đã xác minh" : "Chờ xác minh"}
                  </Badge>
                </div>

                <h4 className="mt-2.5 text-[17px] font-extrabold leading-tight tracking-tight text-sf-text">
                  {selectedPoint.location}
                </h4>
                <p className="mt-1.5 flex items-center gap-1.5 text-[12px] text-sf-text-muted">
                  <MapPin className="h-3 w-3" />
                  <span className="sf-tnum font-mono">
                    {selectedPoint.lat.toFixed(5)}, {selectedPoint.lng.toFixed(5)}
                  </span>
                  · {formatTimeAgo(selectedPoint.lastUpdated)}
                </p>
              </div>

              <div className="sf-inset px-3.5 py-1">
                <InfoRow label="Nguồn tin" value={selectedPoint.source} />
                <InfoRow label="Báo cáo trùng khớp" value={`${selectedPoint.reportCount} lần`} />
                <InfoRow
                  label="Độ tin cậy"
                  value={
                    <span style={{ color: "var(--sf-success)" }}>{selectedPoint.confidence}%</span>
                  }
                />
              </div>

              <div className="space-y-2.5">
                <p className="sf-eyebrow">Tác động đội xe</p>
                <div className="grid grid-cols-2 gap-2.5">
                  <div className="sf-inset p-3">
                    <span className="block text-[12px] font-semibold text-sf-text-muted">
                      Xe bị ảnh hưởng
                    </span>
                    <span className="sf-metric mt-1 block text-[18px]">
                      {selectedPoint.affectedVehicles}
                    </span>
                  </div>
                  <div className="sf-inset p-3">
                    <span className="block text-[12px] font-semibold text-sf-text-muted">
                      Tuyến bị cắt
                    </span>
                    <span className="sf-metric mt-1 block text-[18px]">
                      {selectedPoint.affectedRoutes.length}
                    </span>
                  </div>
                </div>

                {selectedPoint.affectedRoutes.length > 0 && (
                  <div className="sf-inset p-3">
                    <span className="mb-2 flex items-center gap-1.5 text-[12px] font-bold text-sf-text-muted">
                      <Route className="h-3 w-3" />
                      Mã tuyến bị ảnh hưởng
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
              </div>

              <div className="space-y-2 border-t border-[var(--sf-border)] pt-4">
                {!selectedPoint.verified && (
                  <Button
                    block
                    size="sm"
                    icon={CheckCircle2}
                    loading={busy}
                    onClick={() => handleVerify(selectedPoint.id)}
                  >
                    Xác minh điểm ngập
                  </Button>
                )}
                <Button
                  block
                  size="sm"
                  variant="accent"
                  icon={Send}
                  loading={busy}
                  onClick={() => void handleSendWarning(selectedPoint)}
                >
                  Gửi cảnh báo xe gần đó
                </Button>
                <Button
                  block
                  size="sm"
                  variant="outline"
                  loading={busy}
                  onClick={() => handleClearFlood(selectedPoint.id)}
                >
                  Đánh dấu hết ngập
                </Button>
              </div>
            </div>
          </motion.aside>
        )}
      </AnimatePresence>
    </div>
  );
}
