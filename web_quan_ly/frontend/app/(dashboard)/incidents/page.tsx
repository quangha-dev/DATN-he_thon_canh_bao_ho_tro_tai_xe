"use client";

import { useEffect, useState, useMemo } from "react";
import { Incident, IncidentStatus, IncidentPriority } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { cn, formatTimeAgo } from "@/lib/utils";
import MapView from "@/components/map/MapView";
import {
  Siren,
  CheckCircle,
  MessageSquare,
  Phone,
} from "lucide-react";
import { useToast } from "@/context/ToastContext";

export default function IncidentsPage() {
  const { showToast } = useToast();
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedIncidentId, setSelectedIncidentId] = useState<string>("");
  const [statusFilter, setStatusFilter] = useState<string>("open");

  useEffect(() => {
    let cancelled = false;

    const loadIncidents = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.incidents();
        if (!cancelled) {
          setIncidents(data);
          setSelectedIncidentId((current) => current || data[0]?.id || "");
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được danh sách sự cố.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadIncidents();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  useEffect(() => {
    if (!selectedIncidentId) return;
    let cancelled = false;

    const loadTimeline = async () => {
      try {
        const timeline = await safeFleetApi.incidentTimeline(selectedIncidentId);
        if (!cancelled && timeline.length > 0) {
          setIncidents((prev) =>
            prev.map((incident) =>
              incident.id === selectedIncidentId ? { ...incident, timeline } : incident
            )
          );
        }
      } catch {
        // Timeline is secondary; keep fallback timeline if backend denies or has no data.
      }
    };

    loadTimeline();

    return () => {
      cancelled = true;
    };
  }, [selectedIncidentId]);

  // Selected incident details
  const selectedIncident = useMemo(() => {
    return incidents.find((i) => i.id === selectedIncidentId);
  }, [incidents, selectedIncidentId]);

  // Filtered incidents
  const filteredIncidents = useMemo(() => {
    return incidents.filter((i) => {
      if (statusFilter !== "all" && i.status !== statusFilter) return false;
      return true;
    });
  }, [incidents, statusFilter]);

  const PRIORITY_VI: Record<IncidentPriority, string> = {
    critical: "Khẩn cấp",
    high: "Cao",
    medium: "Trung bình",
    low: "Thấp",
  };

  const STATUS_VI: Record<IncidentStatus, string> = {
    open: "Chưa tiếp nhận",
    in_progress: "Đang xử lý",
    resolved: "Đã xử lý",
    overdue: "Quá hạn",
  };

  const updateIncident = (next: Incident) => {
    setIncidents((prev) => prev.map((incident) => (incident.id === next.id ? next : incident)));
    setSelectedIncidentId(next.id);
  };

  const handleAcknowledge = async (id: string) => {
    try {
      updateIncident(await safeFleetApi.acceptIncident(id));
      showToast("Đã tiếp nhận sự cố.", "info");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể tiếp nhận sự cố.", "error");
    }
  };

  const handleResolve = async (id: string) => {
    try {
      updateIncident(await safeFleetApi.closeIncident(id));
      showToast("Đã đóng sự cố.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể đóng sự cố.", "error");
    }
  };

  return (
    <div className="flex flex-col h-[calc(100vh-130px)] space-y-4 animate-fadeIn">
      {/* ===== Toolbar Filter ===== */}
      <div className="flex items-center justify-between gap-4 bg-white dark:bg-slate-900 p-3 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm flex-shrink-0">
        <div className="flex items-center gap-1 bg-slate-50 dark:bg-slate-800 p-1 rounded-lg border border-slate-200/50 dark:border-slate-700/50">
          {[
            { key: "all", label: "Tất cả" },
            { key: "open", label: "Chưa tiếp nhận" },
            { key: "in_progress", label: "Đang xử lý" },
            { key: "resolved", label: "Đã xử lý" },
          ].map((tab) => (
            <button
              key={tab.key}
              onClick={() => setStatusFilter(tab.key)}
              className={cn(
                "px-3 py-1 rounded-md text-[10px] font-bold uppercase transition cursor-pointer",
                statusFilter === tab.key
                  ? "bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm"
                  : "text-slate-500 hover:text-slate-800 dark:hover:text-slate-300"
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>

        <span className="text-xs text-slate-500 dark:text-slate-400">
          Hiện có {filteredIncidents.filter((i) => i.status === "open").length} sự cố khẩn cấp đang mở
        </span>
      </div>

      {/* ===== Main Split layout ===== */}
      <div className="flex-1 grid grid-cols-1 lg:grid-cols-3 gap-6 min-h-0 overflow-y-auto lg:overflow-hidden pb-2">
        {/* Left Column: Incidents List */}
        <div className="lg:col-span-1 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 overflow-hidden shadow-sm flex flex-col min-h-0">
          <div className="px-4 py-3 border-b border-slate-100 dark:border-slate-800 flex-shrink-0">
            <h3 className="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-1.5">
              <Siren className="w-4.5 h-4.5 text-red-500 animate-pulse-dot" />
              Incident Room
            </h3>
            {isLoading && (
              <p className="text-[10px] text-blue-500 mt-1">Đang tải sự cố từ backend...</p>
            )}
          </div>

          <div className="flex-1 overflow-y-auto divide-y divide-slate-100 dark:divide-slate-800/60 p-2 space-y-1">
            {filteredIncidents.map((incident) => {
              const active = incident.id === selectedIncidentId;
              const isSos = incident.type === "sos";

              return (
                <button
                  key={incident.id}
                  onClick={() => setSelectedIncidentId(incident.id)}
                  className={cn(
                    "w-full p-4 text-left rounded-xl transition-all border border-transparent flex items-start gap-3 relative cursor-pointer",
                    active
                      ? "bg-blue-50/50 dark:bg-blue-950/20 border-blue-200 dark:border-blue-800"
                      : "hover:bg-slate-50/80 dark:hover:bg-slate-800/30",
                    incident.status === "open" && "bg-red-500/5 dark:bg-red-950/5"
                  )}
                >
                  {/* Status outline indicator */}
                  <span
                    className={cn(
                      "absolute left-0 top-3.5 bottom-3.5 w-1 rounded-r-full",
                      incident.status === "open" ? "bg-red-500" : "bg-blue-500"
                    )}
                  />

                  {/* Icon */}
                  <div className="w-8 h-8 rounded-lg bg-red-100 dark:bg-red-950/50 flex items-center justify-center flex-shrink-0 text-red-600 dark:text-red-400">
                    <Siren className={cn("w-4.5 h-4.5", incident.status === "open" && "animate-pulse")} />
                  </div>

                  {/* Content details */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-0.5">
                      <span className="text-xs font-bold text-red-600 dark:text-red-400 uppercase tracking-wider">
                        {isSos ? "SOS khẩn cấp" : "Sự cố kỹ thuật"}
                      </span>
                      <span className="text-[10px] text-slate-400 dark:text-slate-500">
                        {formatTimeAgo(incident.timestamp)}
                      </span>
                    </div>
                    <p className="text-xs font-semibold text-slate-900 dark:text-white">
                      Xe: {incident.vehiclePlate} · {incident.driverName}
                    </p>
                    <p className="text-[10px] text-slate-500 dark:text-slate-400 mt-1 truncate">
                      {incident.location}
                    </p>
                  </div>
                </button>
              );
            })}

            {filteredIncidents.length === 0 && (
              <div className="p-8 text-center text-slate-400 text-xs">
                Không có sự cố nào đang xử lý
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Detailed Incident Map + Timeline */}
        <div className="lg:col-span-2 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 overflow-hidden shadow-sm flex flex-col min-h-0">
          {selectedIncident ? (
            <div className="flex-1 flex flex-col min-h-0 overflow-y-auto">
              
              {/* Map view at top of details (smaller height) */}
              <div className="h-56 relative bg-slate-100 border-b border-slate-200 dark:border-slate-800 flex-shrink-0">
                <MapView
                  incidents={[selectedIncident]}
                  interactive={false}
                />
                <div className="absolute inset-0 bg-slate-900/10 pointer-events-none" />
                <div className="absolute bottom-3 left-3 bg-white/95 dark:bg-slate-900/95 p-2 rounded-lg border border-slate-200/50 dark:border-slate-800/50 text-[10px] text-slate-600 dark:text-slate-400 font-semibold shadow">
                  📍 {selectedIncident.location}
                </div>
              </div>

              {/* Specs & timeline details */}
              <div className="flex-1 p-5 space-y-6">
                
                {/* Meta details review */}
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-100 dark:border-slate-800 pb-4">
                  <div>
                    <h3 className="text-base font-bold text-slate-900 dark:text-white leading-none">
                      Sự cố xe {selectedIncident.vehiclePlate}
                    </h3>
                    <p className="text-xs text-slate-500 dark:text-slate-400 mt-1.5">
                      Tài xế: {selectedIncident.driverName} · Vị trí GPS: {selectedIncident.lat.toFixed(5)}, {selectedIncident.lng.toFixed(5)}
                    </p>
                  </div>

                  <div className="flex items-center gap-2">
                    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold text-white bg-red-600 animate-pulse uppercase tracking-wider">
                      Mức {PRIORITY_VI[selectedIncident.priority]}
                    </span>
                    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold text-slate-700 bg-slate-100 dark:text-slate-300 dark:bg-slate-800 uppercase tracking-wider border border-slate-200/50 dark:border-slate-700/50">
                      {STATUS_VI[selectedIncident.status]}
                    </span>
                  </div>
                </div>

                {/* Description */}
                {selectedIncident.description && (
                  <div className="p-3 bg-red-50 dark:bg-red-950/20 border border-red-200/50 dark:border-red-800/50 rounded-xl">
                    <span className="text-xs font-bold text-red-700 dark:text-red-400 block mb-1">
                      Mô tả sự cố:
                    </span>
                    <p className="text-xs text-red-800 dark:text-red-300 leading-relaxed font-medium">
                      {selectedIncident.description}
                    </p>
                  </div>
                )}

                {/* Processing Timeline */}
                <div className="space-y-3.5">
                  <span className="text-xs font-bold text-slate-500 uppercase block tracking-wider">
                    Nhật ký xử lý sự cố (Timeline)
                  </span>

                  <div className="relative pl-6 space-y-4">
                    {/* Vertical line connector */}
                    <div className="absolute left-[7px] top-2 bottom-2 w-0.5 bg-slate-200 dark:bg-slate-800" />

                    {selectedIncident.timeline.map((entry, idx) => {
                      const isLast = idx === selectedIncident.timeline.length - 1;
                      return (
                        <div key={idx} className="relative text-xs">
                          {/* Circle dot on line */}
                          <div className={cn(
                            "absolute -left-[23px] top-1 w-3 h-3 rounded-full border border-white dark:border-slate-900 shadow-sm",
                            isLast ? "bg-red-600 animate-pulse-sos scale-110" : "bg-slate-300 dark:bg-slate-700"
                          )} />

                          <div className="flex items-start justify-between gap-4">
                            <div>
                              <p className={cn(
                                "font-semibold",
                                isLast ? "text-slate-950 dark:text-white" : "text-slate-500 dark:text-slate-400"
                              )}>
                                {entry.action}
                              </p>
                              {entry.actor && (
                                <p className="text-[10px] text-slate-400 dark:text-slate-500 mt-0.5">
                                  Người thực hiện: {entry.actor}
                                </p>
                              )}
                            </div>
                            <span className="text-[10px] text-slate-400 dark:text-slate-500 font-mono">
                              {entry.time}
                            </span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Operations responses */}
                <div className="pt-4 border-t border-slate-100 dark:border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
                  <div className="flex items-center gap-2">
                    {selectedIncident.status === "open" && (
                      <button
                        onClick={() => handleAcknowledge(selectedIncident.id)}
                        className="px-4 py-2 rounded-lg bg-red-600 hover:bg-red-700 text-white text-xs font-bold shadow-md shadow-red-500/10 transition cursor-pointer flex items-center gap-1"
                      >
                        <CheckCircle className="w-3.5 h-3.5" /> TIẾP NHẬN SỰ CỐ
                      </button>
                    )}
                    {selectedIncident.status === "in_progress" && (
                      <button
                        onClick={() => handleResolve(selectedIncident.id)}
                        className="px-4 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow transition cursor-pointer flex items-center gap-1"
                      >
                        <CheckCircle className="w-3.5 h-3.5" /> ĐÓNG SỰ CỐ (ĐÃ XỬ LÝ)
                      </button>
                    )}
                  </div>

                  <div className="flex items-center gap-2">
                    <button className="p-2 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 transition">
                      <Phone className="w-4 h-4" />
                    </button>
                    <button className="p-2 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 transition">
                      <MessageSquare className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="flex-1 flex items-center justify-center p-8 text-center text-slate-400 dark:text-slate-500">
              Vui lòng chọn sự cố ở cột trái để bắt đầu điều phối cứu hộ
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
