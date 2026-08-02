"use client";

import { useState, useEffect } from "react";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  LineChart,
  Line,
  Cell,
} from "recharts";
import {
  TrendingUp,
  AlertTriangle,
  Sparkles,
  Download,
} from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { ALERT_TYPE_LABELS, cn } from "@/lib/utils";

// =============================================================================
// MOCK CHART DATA
// =============================================================================
const ALERT_BY_TYPE_DATA = [
  { name: "Ngủ gật", count: 24, fill: "#ef4444" },
  { name: "Điện thoại", count: 48, fill: "#f97316" },
  { name: "Mất tập trung", count: 32, fill: "#f59e0b" },
  { name: "Quá giờ lái", count: 12, fill: "#8b5cf6" },
  { name: "Vượt tốc độ", count: 18, fill: "#3b82f6" },
  { name: "Điểm ngập", count: 15, fill: "#06b6d4" },
];

const TRIP_TREND_DATA = [
  { date: "T2", totalTrips: 0 },
  { date: "T3", totalTrips: 0 },
  { date: "T4", totalTrips: 0 },
  { date: "T5", totalTrips: 0 },
  { date: "T6", totalTrips: 0 },
  { date: "T7", totalTrips: 0 },
];

export default function ReportsPage() {
  const { showToast } = useToast();
  const [activeTab, setActiveTab] = useState("overview");
  const [isClient, setIsClient] = useState(false);
  const [alertByTypeData, setAlertByTypeData] = useState(ALERT_BY_TYPE_DATA);
  const [tripTrendData, setTripTrendData] = useState(TRIP_TREND_DATA);
  const [isLoadingReports, setIsLoadingReports] = useState(true);

  // Fix Recharts SSR issue
  useEffect(() => {
    setIsClient(true);
  }, []);

  useEffect(() => {
    let cancelled = false;
    const fills = ["#ef4444", "#f97316", "#f59e0b", "#8b5cf6", "#3b82f6", "#06b6d4", "#22c55e"];

    const loadReports = async () => {
      setIsLoadingReports(true);
      try {
        const [alertsByType, tripsByDay] = await Promise.all([
          safeFleetApi.reportSafetyEventsByType(),
          safeFleetApi.reportTripsByDay(),
        ]);
        if (!cancelled) {
          const nextAlerts = Object.entries(alertsByType).map(([key, count], index) => ({
            name: ALERT_TYPE_LABELS[key.toLowerCase()] || key.replaceAll("_", " "),
            count,
            fill: fills[index % fills.length],
          }));
          setAlertByTypeData(nextAlerts.length > 0 ? nextAlerts : ALERT_BY_TYPE_DATA);
          setTripTrendData(
            tripsByDay.length > 0
              ? tripsByDay.map((item) => ({
                  date: new Date(item.date).toLocaleDateString("vi-VN", { day: "2-digit", month: "2-digit" }),
                  totalTrips: item.totalTrips,
                }))
              : TRIP_TREND_DATA
          );
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được báo cáo.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoadingReports(false);
      }
    };

    loadReports();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  const handleExport = () => {
    showToast("Đang chuẩn bị xuất dữ liệu báo cáo PDF...", "info");
    setTimeout(() => {
      showToast("Đã tải xuống báo cáo Fleet Intelligence!", "success");
    }, 1500);
  };

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* ===== Toolbar header ===== */}
      <div className="flex items-center justify-between gap-4 bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm flex-shrink-0">
        <div className="flex items-center gap-1.5 bg-slate-50 dark:bg-slate-800 p-1 rounded-lg border border-slate-200/50 dark:border-slate-700/50">
          {[
            { key: "overview", label: "Tổng quan" },
            { key: "safety", label: "Chỉ số an toàn" },
            { key: "operations", label: "Vận hành" },
          ].map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={cn(
                "px-4 py-1.5 rounded-md text-xs font-semibold transition cursor-pointer",
                activeTab === tab.key
                  ? "bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm"
                  : "text-slate-500 hover:text-slate-800 dark:hover:text-slate-300"
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>

        <button
          onClick={handleExport}
          className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-lg shadow transition cursor-pointer"
        >
          <Download className="w-3.5 h-3.5" /> Xuất báo cáo PDF
        </button>
      </div>

      {isLoadingReports && (
        <div className="px-4 py-3 rounded-xl bg-blue-50 dark:bg-blue-950/30 border border-blue-100 dark:border-blue-900/50 text-xs font-semibold text-blue-700 dark:text-blue-300">
          Đang tải dữ liệu báo cáo từ backend...
        </div>
      )}

      {/* ===== AI Insight Box ===== */}
      <div className="p-5 rounded-2xl bg-gradient-to-br from-blue-600 to-indigo-700 text-white shadow-lg shadow-blue-500/25 relative overflow-hidden">
        {/* Decorative background grid */}
        <div className="absolute inset-0 opacity-10 bg-[radial-gradient(circle_at_1px_1px,white_1px,transparent_0)] bg-[length:24px_24px]" />

        <div className="relative z-10 space-y-4">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-white/20 backdrop-blur-sm flex items-center justify-center">
              <Sparkles className="w-4.5 h-4.5 text-blue-100 animate-pulse" />
            </div>
            <div>
              <h3 className="font-bold text-sm leading-none">SafeFleet AI Insight</h3>
              <p className="text-[10px] text-blue-200 mt-1 leading-none">Báo cáo phân tích tự động tuần này</p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs text-blue-100">
            <div className="space-y-2.5">
              <p className="flex items-start gap-2">
                <span className="w-1.5 h-1.5 rounded-full bg-amber-400 mt-1.5 flex-shrink-0" />
                <span>
                  <strong className="text-white">Cảnh báo mất tập trung tăng 18%</strong> so với tuần trước, đặc biệt lặp lại vào khung giờ chiều <span className="underline">13:00 - 15:00</span>. Đề xuất bố trí thời gian nghỉ ngắn cho tài xế.
                </span>
              </p>
              <p className="flex items-start gap-2">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 mt-1.5 flex-shrink-0" />
                <span>
                  <strong className="text-white">Điểm an toàn trung bình đạt 91/100</strong>, tăng 3 điểm nhờ cải thiện hành vi giảm thiểu sử dụng điện thoại khi lái xe.
                </span>
              </p>
            </div>

            <div className="space-y-2.5">
              <p className="flex items-start gap-2">
                <span className="w-1.5 h-1.5 rounded-full bg-purple-400 mt-1.5 flex-shrink-0" />
                <span>
                  <strong className="text-white">Tuyến Hà Đông - Cầu Giấy</strong> ghi nhận tần suất xuất hiện 4 điểm ngập nghiêm trọng gây tắc nghẽn. AI khuyến nghị định tuyến lại qua Đại lộ Thăng Long.
                </span>
              </p>
              <p className="flex items-start gap-2">
                <span className="w-1.5 h-1.5 rounded-full bg-red-400 mt-1.5 flex-shrink-0" />
                <span>
                  <strong className="text-white">Xe container 30E-22222</strong> có số lần mất tín hiệu GPS 4 lần trong tuần. Đề nghị bộ phận kỹ thuật kiểm tra cổng kết nối OBD.
                </span>
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* ===== Charts Dashboard Area ===== */}
      {isClient && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          
          {/* Chart 1: Alerts frequency by type */}
          <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-4">
            <h4 className="font-bold text-xs text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
              <AlertTriangle className="w-4 h-4 text-amber-500" />
              Tần suất cảnh báo theo loại lỗi
            </h4>
            <div className="h-72 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={alertByTypeData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} className="stroke-slate-100 dark:stroke-slate-800" />
                  <XAxis dataKey="name" stroke="#94a3b8" fontSize={10} tickLine={false} />
                  <YAxis stroke="#94a3b8" fontSize={10} tickLine={false} />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "rgba(30, 41, 59, 0.95)",
                      borderColor: "#334155",
                      borderRadius: "8px",
                      color: "#fff",
                      fontSize: "11px",
                    }}
                  />
                  <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                    {alertByTypeData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.fill} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Chart 2: Safety score average trend */}
          <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-4">
            <h4 className="font-bold text-xs text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
              <TrendingUp className="w-4 h-4 text-emerald-500" />
              Số chuyến theo ngày
            </h4>
            <div className="h-72 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={tripTrendData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} className="stroke-slate-100 dark:stroke-slate-800" />
                  <XAxis dataKey="date" stroke="#94a3b8" fontSize={10} tickLine={false} />
                  <YAxis stroke="#94a3b8" fontSize={10} tickLine={false} />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: "rgba(30, 41, 59, 0.95)",
                      borderColor: "#334155",
                      borderRadius: "8px",
                      color: "#fff",
                      fontSize: "11px",
                    }}
                  />
                  <Line type="monotone" dataKey="totalTrips" stroke="#3b82f6" strokeWidth={3} activeDot={{ r: 6 }} dot={{ strokeWidth: 2, r: 4 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
