"use client";

import { useEffect, useState, useMemo } from "react";
import { Alert, AlertSeverity, AlertType } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { cn, formatDateTime, formatTimeAgo, STATUS_COLORS } from "@/lib/utils";
import {
  ShieldAlert,
  Phone,
  MessageSquare,
  AlertTriangle,
  MapPin,
  Clock,
  User,
  Truck,
  Video,
} from "lucide-react";
import { useToast } from "@/context/ToastContext";

export default function AlertsPage() {
  const { showToast } = useToast();
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedAlertId, setSelectedAlertId] = useState<string>("");
  const [severityFilter, setSeverityFilter] = useState<string>("all");
  const [typeFilter, setTypeFilter] = useState<string>("all");

  useEffect(() => {
    let cancelled = false;

    const loadAlerts = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.safetyEvents();
        if (!cancelled) {
          setAlerts(data);
          setSelectedAlertId((current) => current || data[0]?.id || "");
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được cảnh báo.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadAlerts();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  // Selected alert details
  const selectedAlert = useMemo(() => {
    return alerts.find((a) => a.id === selectedAlertId);
  }, [alerts, selectedAlertId]);

  // Filtered alerts feed
  const filteredAlerts = useMemo(() => {
    return alerts.filter((a) => {
      if (severityFilter !== "all" && a.severity !== severityFilter) return false;
      if (typeFilter !== "all" && a.type !== typeFilter) return false;
      return true;
    });
  }, [alerts, severityFilter, typeFilter]);

  const ALERT_TYPE_VI: Record<AlertType, string> = {
    drowsy: "Ngủ gật",
    phone_usage: "Dùng điện thoại",
    distraction: "Mất tập trung",
    overtime: "Quá giờ lái",
    speeding: "Vượt tốc độ",
    route_deviation: "Lệch tuyến",
    abnormal_stop: "Dừng bất thường",
    connection_lost: "Mất kết nối",
    near_flood: "Gần điểm ngập",
  };

  const SEVERITY_VI: Record<AlertSeverity, string> = {
    low: "Thấp",
    medium: "Trung bình",
    high: "Cao",
    critical: "Nghiêm trọng",
  };

  const updateAlert = (next: Alert) => {
    setAlerts((prev) => prev.map((alert) => (alert.id === next.id ? next : alert)));
    setSelectedAlertId(next.id);
  };

  const handleAcknowledge = async (id: string) => {
    try {
      updateAlert(await safeFleetApi.acknowledgeSafetyEvent(id));
      showToast("Đã tiếp nhận cảnh báo.", "info");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể tiếp nhận cảnh báo.", "error");
    }
  };

  const handleResolve = async (id: string) => {
    try {
      updateAlert(await safeFleetApi.resolveSafetyEvent(id));
      showToast("Đã đánh dấu cảnh báo đã xử lý.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể xử lý cảnh báo.", "error");
    }
  };

  return (
    <div className="flex flex-col h-[calc(100vh-130px)] space-y-4 animate-fadeIn">
      {/* ===== Top filter toolbar ===== */}
      <div className="flex items-center justify-between gap-4 bg-white dark:bg-slate-900 p-3 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm flex-shrink-0">
        <div className="flex items-center gap-2 flex-wrap">
          {/* Severity dropdown */}
          <select
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value)}
            className="px-3 py-1.5 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs font-semibold text-slate-700 dark:text-slate-200 focus:outline-none"
          >
            <option value="all">Tất cả mức độ</option>
            <option value="low">Thấp</option>
            <option value="medium">Trung bình</option>
            <option value="high">Cao</option>
            <option value="critical">Nghiêm trọng</option>
          </select>

          {/* Type dropdown */}
          <select
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            className="px-3 py-1.5 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs font-semibold text-slate-700 dark:text-slate-200 focus:outline-none"
          >
            <option value="all">Tất cả loại cảnh báo</option>
            {Object.entries(ALERT_TYPE_VI).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
        </div>

        <span className="text-xs text-slate-500 dark:text-slate-400">
          Tổng cộng {filteredAlerts.length} cảnh báo phù hợp
        </span>
      </div>

      {/* ===== Main Split: Left Feed, Right details ===== */}
      <div className="flex-1 grid grid-cols-1 lg:grid-cols-3 gap-6 min-h-0 overflow-y-auto lg:overflow-hidden pb-2">
        {/* Left Column: Alert Feed (Timeline) */}
        <div className="lg:col-span-1 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 overflow-hidden shadow-sm flex flex-col min-h-0">
          <div className="px-4 py-3 border-b border-slate-100 dark:border-slate-800 flex-shrink-0">
            <h3 className="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-1.5">
              <ShieldAlert className="w-4.5 h-4.5 text-amber-500" />
              Realtime Alert Feed
            </h3>
            {isLoading && (
              <p className="text-[10px] text-blue-500 mt-1">Đang tải cảnh báo từ backend...</p>
            )}
          </div>

          <div className="flex-1 overflow-y-auto divide-y divide-slate-100 dark:divide-slate-800/60 p-2 space-y-1">
            {filteredAlerts.map((alert) => {
              const active = alert.id === selectedAlertId;
              return (
                <button
                  key={alert.id}
                  onClick={() => setSelectedAlertId(alert.id)}
                  className={cn(
                    "w-full p-3.5 text-left rounded-xl transition-all border border-transparent flex items-start gap-3 relative cursor-pointer",
                    active
                      ? "bg-blue-50/50 dark:bg-blue-950/20 border-blue-200 dark:border-blue-800"
                      : "hover:bg-slate-50/80 dark:hover:bg-slate-800/30"
                  )}
                >
                  {/* Severity indicator block left */}
                  <span
                    className="absolute left-0 top-3 bottom-3 w-1 rounded-r-full"
                    style={{ backgroundColor: STATUS_COLORS[alert.severity] }}
                  />

                  {/* Icon severity based */}
                  <div className="w-8 h-8 rounded-lg bg-slate-100 dark:bg-slate-800 flex items-center justify-center flex-shrink-0 text-slate-400">
                    <AlertTriangle
                      className="w-4.5 h-4.5"
                      style={{ color: STATUS_COLORS[alert.severity] }}
                    />
                  </div>

                  {/* Details summary */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-0.5">
                      <span className="text-xs font-bold text-slate-950 dark:text-white">
                        {ALERT_TYPE_VI[alert.type] || alert.type}
                      </span>
                      <span className="text-[10px] text-slate-400 dark:text-slate-500">
                        {formatTimeAgo(alert.timestamp)}
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-700 dark:text-slate-300 font-medium">
                      Xe: {alert.vehiclePlate} · Tài xế: {alert.driverName}
                    </p>
                    {alert.repeatCount && alert.repeatCount > 1 && (
                      <span className="inline-block mt-1 text-[9px] px-1.5 py-0.5 rounded bg-red-100 text-red-700 dark:bg-red-950/30 dark:text-red-400 font-bold uppercase">
                        Lặp lại {alert.repeatCount} lần
                      </span>
                    )}
                  </div>
                </button>
              );
            })}

            {filteredAlerts.length === 0 && (
              <div className="p-8 text-center text-slate-400 text-xs">
                Không tìm thấy cảnh báo nào
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Alert Detail */}
        <div className="lg:col-span-2 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 overflow-hidden shadow-sm flex flex-col min-h-0">
          {selectedAlert ? (
            <div className="flex-1 flex flex-col min-h-0">
              {/* Header details review */}
              <div className="px-5 py-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between flex-shrink-0">
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="font-bold text-base text-slate-900 dark:text-white">
                      {ALERT_TYPE_VI[selectedAlert.type] || selectedAlert.type}
                    </h3>
                    <span
                      className="px-2 py-0.5 rounded-full text-[10px] font-bold text-white uppercase"
                      style={{ backgroundColor: STATUS_COLORS[selectedAlert.severity] }}
                    >
                      Mức độ {SEVERITY_VI[selectedAlert.severity]}
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
                    Cảnh báo ID: {selectedAlert.id} · Phát hiện lúc {formatDateTime(selectedAlert.timestamp)}
                  </p>
                </div>
              </div>

              {/* Main detail content */}
              <div className="flex-1 overflow-y-auto p-5 space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  
                  {/* Left sub-column: Evidence media */}
                  <div className="space-y-4">
                    <span className="text-xs font-bold text-slate-500 uppercase block tracking-wider">
                      Hình ảnh/Video bằng chứng
                    </span>

                    {/* Camera view placeholder */}
                    <div className="relative aspect-video bg-slate-950 rounded-xl overflow-hidden flex items-center justify-center border border-slate-800 group shadow">
                      {/* Grid overlay for simulation */}
                      <div className="absolute inset-0 opacity-10 bg-[linear-gradient(rgba(18,16,16,0)_50%,rgba(0,0,0,0.25)_50%),linear-gradient(90deg,rgba(255,0,0,0.06),rgba(0,255,0,0.02),rgba(0,0,255,0.06))] bg-[length:100%_4px,3px_100%]" />
                      
                      {/* Video source simulator */}
                      <div className="text-center p-4">
                        <Video className="w-10 h-10 text-slate-600 dark:text-slate-700 mx-auto mb-2" />
                        <span className="text-xs text-slate-500 font-mono">
                          CABIN_CAMERA_STREAM_{selectedAlert.vehicleId}.raw
                        </span>
                      </div>

                      {/* Floating tag */}
                      <span className="absolute top-2.5 left-2.5 px-2 py-0.5 rounded bg-red-600/90 text-[10px] text-white font-mono uppercase tracking-wider flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-white animate-ping" />
                        REC LIVE
                      </span>
                    </div>

                    <p className="text-[11px] text-slate-400 dark:text-slate-500 text-center leading-relaxed">
                      * Dữ liệu hình ảnh được truyền trực tiếp từ camera AI lắp đặt trong cabin phương tiện.
                    </p>
                  </div>

                  {/* Right sub-column: Telemetry specs & driver info */}
                  <div className="space-y-4">
                    <span className="text-xs font-bold text-slate-500 uppercase block tracking-wider">
                      Thông tin kỹ thuật liên quan
                    </span>

                    <div className="divide-y divide-slate-100 dark:divide-slate-800 border border-slate-200/50 dark:border-slate-800/80 rounded-xl bg-slate-50/50 dark:bg-slate-800/20 overflow-hidden text-xs">
                      {/* Driver */}
                      <div className="flex justify-between items-center px-4 py-3">
                        <span className="text-slate-500 flex items-center gap-1.5">
                          <User className="w-4 h-4 text-slate-400" /> Tài xế:
                        </span>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {selectedAlert.driverName}
                        </span>
                      </div>
                      
                      {/* Vehicle */}
                      <div className="flex justify-between items-center px-4 py-3">
                        <span className="text-slate-500 flex items-center gap-1.5">
                          <Truck className="w-4 h-4 text-slate-400" /> Phương tiện:
                        </span>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {selectedAlert.vehiclePlate}
                        </span>
                      </div>

                      {/* Speed */}
                      <div className="flex justify-between items-center px-4 py-3">
                        <span className="text-slate-500 flex items-center gap-1.5">
                          <Clock className="w-4 h-4 text-slate-400" /> Tốc độ ghi nhận:
                        </span>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {selectedAlert.speed ? `${selectedAlert.speed} km/h` : "N/A"}
                        </span>
                      </div>

                      {/* GPS position */}
                      <div className="flex justify-between items-center px-4 py-3">
                        <span className="text-slate-500 flex items-center gap-1.5">
                          <MapPin className="w-4 h-4 text-slate-400" /> Tọa độ GPS:
                        </span>
                        <span className="font-mono text-slate-950 dark:text-white font-semibold">
                          {selectedAlert.lat.toFixed(5)}, {selectedAlert.lng.toFixed(5)}
                        </span>
                      </div>
                    </div>

                    <div className="p-3 bg-red-50 dark:bg-red-950/20 border border-red-200/50 dark:border-red-800/50 rounded-xl">
                      <span className="text-xs font-bold text-red-700 dark:text-red-400 block mb-1">
                        Chi tiết lỗi phát hiện:
                      </span>
                      <p className="text-xs text-red-800 dark:text-red-300 font-medium">
                        {selectedAlert.message}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Dispatch actions panel */}
                <div className="pt-4 border-t border-slate-100 dark:border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => handleAcknowledge(selectedAlert.id)}
                      className="px-4 py-2 rounded-lg bg-blue-50 dark:bg-blue-950/30 border border-blue-200/50 dark:border-blue-800 text-xs font-bold text-blue-600 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/30 transition cursor-pointer"
                    >
                      Tiếp nhận xử lý
                    </button>
                    <button
                      onClick={() => handleResolve(selectedAlert.id)}
                      className="px-4 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow transition cursor-pointer"
                    >
                      Đánh dấu Đã giải quyết
                    </button>
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
              Vui lòng chọn một cảnh báo ở danh sách bên trái để xem chi tiết
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
