"use client";

import { useEffect, useState, useMemo } from "react";
import MapView from "@/components/map/MapView";
import { FloodPoint, FloodSeverity } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { cn, formatTimeAgo } from "@/lib/utils";
import { AnimatePresence, motion } from "framer-motion";
import {
  Droplets,
  CheckCircle,
  Send,
  X,
} from "lucide-react";
import { useToast } from "@/context/ToastContext";

export default function FloodMapPage() {
  const { showToast } = useToast();
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedPoint, setSelectedPoint] = useState<FloodPoint | null>(null);
  const [severityFilter, setSeverityFilter] = useState<string>("all");
  const [verifyFilter, setVerifyFilter] = useState<string>("all");

  useEffect(() => {
    let cancelled = false;

    const loadFloodPoints = async () => {
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

    loadFloodPoints();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  // Filtered flood points
  const filteredFloodPoints = useMemo(() => {
    return floodPoints.filter((p) => {
      // 1. Severity filter
      if (severityFilter !== "all" && p.severity !== severityFilter) return false;

      // 2. Verify filter
      if (verifyFilter === "verified" && !p.verified) return false;
      if (verifyFilter === "unverified" && p.verified) return false;

      return true;
    });
  }, [floodPoints, severityFilter, verifyFilter]);

  const SEVERITY_VI: Record<FloodSeverity, string> = {
    light: "Ngập nhẹ",
    moderate: "Ngập vừa",
    heavy: "Ngập nặng",
    impassable: "Không thể đi qua",
  };

  const updateFloodPoint = (next: FloodPoint) => {
    setFloodPoints((prev) => prev.map((point) => (point.id === next.id ? next : point)));
    setSelectedPoint(next);
  };

  const handleVerify = async (id: string) => {
    try {
      updateFloodPoint(await safeFleetApi.verifyFloodPoint(id));
      showToast("Đã xác minh điểm ngập.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể xác minh điểm ngập.", "error");
    }
  };

  const handleClearFlood = async (id: string) => {
    try {
      updateFloodPoint(await safeFleetApi.resolveFloodPoint(id));
      showToast("Đã đánh dấu hết ngập.", "info");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể cập nhật điểm ngập.", "error");
    }
  };

  const handleSendWarning = (point: FloodPoint) => {
    showToast(`Đã gửi cảnh báo ngập lụt tới các phương tiện gần khu vực ${point.location}`, "info");
  };

  return (
    <div className="relative w-full h-[calc(100vh-64px)] flex overflow-hidden bg-slate-100 dark:bg-slate-950">
      
      {/* ===== Fullscreen Map background ===== */}
      <div className="absolute inset-0 z-0">
        <MapView
          floodPoints={filteredFloodPoints}
          onFloodPointClick={(p) => setSelectedPoint(p)}
          selectedVehicleId={null}
        />
      </div>

      {/* ===== Floating Control Toolbar (Top Center) ===== */}
      <div className="absolute top-4 left-4 right-4 md:left-4 md:right-4 z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-3 pointer-events-none">
        
        {/* Left: Filters bar */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 max-w-full pointer-events-auto select-none">
          {isLoading && (
            <span className="px-3 py-1.5 rounded-full text-xs font-semibold bg-white/90 dark:bg-slate-900/90 text-blue-600 border border-blue-200/50">
              Đang tải điểm ngập...
            </span>
          )}
          {[
            { key: "all", label: "Tất cả mức ngập" },
            { key: "light", label: "Ngập nhẹ" },
            { key: "moderate", label: "Ngập vừa" },
            { key: "heavy", label: "Ngập nặng" },
            { key: "impassable", label: "Không thể đi qua" },
          ].map((f) => (
            <button
              key={f.key}
              onClick={() => setSeverityFilter(f.key)}
              className={cn(
                "px-3 py-1.5 rounded-full text-xs font-semibold backdrop-blur shadow border transition-all cursor-pointer whitespace-nowrap",
                severityFilter === f.key
                  ? "bg-purple-600 text-white border-purple-500 shadow-purple-500/10"
                  : "bg-white/90 dark:bg-slate-900/90 text-slate-600 dark:text-slate-300 border-slate-200/50 dark:border-slate-800/50 hover:bg-slate-50 dark:hover:bg-slate-800"
              )}
            >
              {f.label}
            </button>
          ))}
        </div>

        {/* Right: Verification Filter tab group */}
        <div className="flex items-center gap-1 bg-white/90 dark:bg-slate-900/90 backdrop-blur p-1 rounded-lg border border-slate-200/50 dark:border-slate-800/50 shadow pointer-events-auto">
          {[
            { key: "all", label: "Tất cả" },
            { key: "verified", label: "Đã xác minh" },
            { key: "unverified", label: "Chưa xác minh" },
          ].map((tab) => (
            <button
              key={tab.key}
              onClick={() => setVerifyFilter(tab.key)}
              className={cn(
                "px-2.5 py-1 rounded-md text-[10px] font-bold uppercase transition cursor-pointer whitespace-nowrap",
                verifyFilter === tab.key
                  ? "bg-slate-100 dark:bg-slate-700 text-slate-900 dark:text-white"
                  : "text-slate-500 hover:text-slate-800 dark:hover:text-slate-300"
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* ===== Floating Right Drawer: Flood Point Details ===== */}
      <AnimatePresence>
        {selectedPoint && (
          <motion.div
            initial={{ opacity: 0, x: 360 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 360 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className="absolute right-4 top-4 bottom-4 w-80 bg-white/95 dark:bg-slate-900/95 backdrop-blur border border-slate-200/50 dark:border-slate-800/50 rounded-2xl shadow-2xl flex flex-col z-20 overflow-hidden"
          >
            {/* Header */}
            <div className="px-4 py-3.5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between flex-shrink-0">
              <h3 className="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-1.5">
                <Droplets className="w-4.5 h-4.5 text-purple-500" />
                Thông tin điểm ngập
              </h3>
              <button
                onClick={() => setSelectedPoint(null)}
                className="p-1 rounded-md text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Content Body */}
            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              {/* Location Name */}
              <div>
                <div className="flex items-center gap-1.5">
                  <span
                    className={cn(
                      "px-2 py-0.5 rounded text-[10px] font-bold text-white uppercase",
                      selectedPoint.severity === "impassable" && "bg-red-600 animate-pulse",
                      selectedPoint.severity === "heavy" && "bg-orange-500",
                      selectedPoint.severity === "moderate" && "bg-amber-500",
                      selectedPoint.severity === "light" && "bg-cyan-500"
                    )}
                  >
                    {SEVERITY_VI[selectedPoint.severity]}
                  </span>
                  
                  {selectedPoint.verified ? (
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold text-emerald-700 bg-emerald-100 dark:bg-emerald-950/30 dark:text-emerald-400">
                      Đã xác minh
                    </span>
                  ) : (
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold text-amber-700 bg-amber-100 dark:bg-amber-950/30 dark:text-amber-400">
                      Chờ xác minh
                    </span>
                  )}
                </div>

                <h4 className="text-lg font-bold text-slate-950 dark:text-white leading-tight mt-2.5">
                  {selectedPoint.location}
                </h4>
                <p className="text-[10px] text-slate-400 dark:text-slate-500 mt-1">
                  GPS: {selectedPoint.lat.toFixed(5)}, {selectedPoint.lng.toFixed(5)} · Cập nhật {formatTimeAgo(selectedPoint.lastUpdated)}
                </p>
              </div>

              {/* Reports metadata */}
              <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl space-y-2 text-xs">
                <div className="flex justify-between">
                  <span className="text-slate-500">Nguồn tin:</span>
                  <span className="font-semibold text-slate-900 dark:text-white">{selectedPoint.source}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Số báo cáo trùng khớp:</span>
                  <span className="font-semibold text-slate-900 dark:text-white">{selectedPoint.reportCount} lần</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Độ tin cậy dữ liệu:</span>
                  <span className="font-bold text-emerald-500">{selectedPoint.confidence}%</span>
                </div>
              </div>

              {/* Affected details */}
              <div className="space-y-3">
                <span className="text-xs font-bold text-slate-500 uppercase block tracking-wider">
                  Tác động đội xe
                </span>

                <div className="grid grid-cols-2 gap-3 text-xs">
                  <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl">
                    <span className="text-[10px] text-slate-500 block">Xe bị ảnh hưởng</span>
                    <span className="text-sm font-bold text-slate-900 dark:text-white">
                      {selectedPoint.affectedVehicles} xe gần đó
                    </span>
                  </div>
                  <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl">
                    <span className="text-[10px] text-slate-500 block">Tuyến bị cắt</span>
                    <span className="text-sm font-bold text-slate-900 dark:text-white">
                      {selectedPoint.affectedRoutes.length} tuyến
                    </span>
                  </div>
                </div>

                {selectedPoint.affectedRoutes.length > 0 && (
                  <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl space-y-1">
                    <span className="text-[10px] text-slate-500 block font-semibold">Chi tiết các mã tuyến:</span>
                    <div className="flex gap-1.5 flex-wrap pt-0.5">
                      {selectedPoint.affectedRoutes.map((routeCode) => (
                        <span
                          key={routeCode}
                          className="px-2 py-0.5 rounded bg-blue-100 text-blue-800 dark:bg-blue-950/40 dark:text-blue-400 text-[10px] font-mono font-semibold"
                        >
                          {routeCode}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Actions panel */}
              <div className="pt-4 border-t border-slate-100 dark:border-slate-800 space-y-2">
                {!selectedPoint.verified && (
                  <button
                    onClick={() => handleVerify(selectedPoint.id)}
                    className="w-full py-2 bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs rounded-xl shadow transition cursor-pointer flex items-center justify-center gap-1"
                  >
                    <CheckCircle className="w-3.5 h-3.5" /> XÁC MINH ĐIỂM NGẬP
                  </button>
                )}
                <button
                  onClick={() => handleSendWarning(selectedPoint)}
                  className="w-full py-2 bg-purple-600 hover:bg-purple-700 text-white font-bold text-xs rounded-xl shadow-md shadow-purple-500/10 transition cursor-pointer flex items-center justify-center gap-1"
                >
                  <Send className="w-3.5 h-3.5" /> GỬI CẢNH BÁO XE GẦN ĐÓ
                </button>
                <button
                  onClick={() => handleClearFlood(selectedPoint.id)}
                  className="w-full py-2 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-bold text-xs rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800 transition cursor-pointer"
                >
                  ĐÁNH DẤU HẾT NGẬP
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
