"use client";

import { useEffect, useState, useMemo } from "react";
import { Trip } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { cn, formatDateTime, STATUS_COLORS, TRIP_STATUS_LABELS } from "@/lib/utils";
import {
  Navigation,
  Search,
  Eye,
} from "lucide-react";

export default function TripsPage() {
  const { showToast } = useToast();
  const [trips, setTrips] = useState<Trip[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [riskFilter, setRiskFilter] = useState<string>("all");

  useEffect(() => {
    let cancelled = false;

    const loadTrips = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.trips();
        if (!cancelled) setTrips(data);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được danh sách chuyến.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadTrips();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  // Summary stats
  const stats = useMemo(() => {
    return {
      total: trips.length,
      in_progress: trips.filter((t) => t.status === "in_progress").length,
      pending: trips.filter((t) => t.status === "pending").length,
      completed: trips.filter((t) => t.status === "completed").length,
      incident: trips.filter((t) => t.status === "incident").length,
      highRisk: trips.filter((t) => t.riskLevel === "high" || t.riskLevel === "critical").length,
    };
  }, [trips]);

  // Filtered trips
  const filteredTrips = useMemo(() => {
    return trips.filter((t) => {
      // 1. Status filter
      if (statusFilter !== "all" && t.status !== statusFilter) return false;

      // 2. Risk filter
      if (riskFilter !== "all" && t.riskLevel !== riskFilter) return false;

      // 3. Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        return (
          t.code.toLowerCase().includes(q) ||
          t.vehiclePlate.toLowerCase().includes(q) ||
          t.driverName.toLowerCase().includes(q) ||
          t.origin.toLowerCase().includes(q) ||
          t.destination.toLowerCase().includes(q)
        );
      }
      return true;
    });
  }, [trips, searchQuery, statusFilter, riskFilter]);

  const RISK_LEVEL_LABELS: Record<string, string> = {
    low: "Thấp",
    medium: "Trung bình",
    high: "Cao",
    critical: "Nguy hiểm",
  };

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* ===== Stat Cards ===== */}
      <div className="grid grid-cols-2 lg:grid-cols-6 gap-4">
        {/* Total Trips */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Tổng chuyến hôm nay
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.total}
          </span>
        </div>

        {/* In Progress */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-blue-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Đang thực hiện
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.in_progress}
          </span>
        </div>

        {/* Pending */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-slate-400">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Chưa bắt đầu
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.pending}
          </span>
        </div>

        {/* Completed */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-emerald-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Đã hoàn thành
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.completed}
          </span>
        </div>

        {/* Incident */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-red-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Gặp sự cố SOS
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.incident}
          </span>
        </div>

        {/* High Risk */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-orange-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Tuyến rủi ro cao
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.highRisk}
          </span>
        </div>
      </div>

      {/* ===== Toolbar & Filters ===== */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
        {/* Search */}
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Tìm mã chuyến, biển số, tài xế, điểm đi/đến..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 dark:bg-slate-800 border border-transparent rounded-lg text-sm text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:bg-white dark:focus:bg-slate-800 focus:border-slate-200 dark:focus:border-slate-700 transition"
          />
        </div>

        {/* Filters */}
        <div className="flex items-center gap-2 flex-wrap">
          {/* Risk Level Filter dropdown */}
          <select
            value={riskFilter}
            onChange={(e) => setRiskFilter(e.target.value)}
            className="px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs font-semibold text-slate-700 dark:text-slate-200 focus:outline-none"
          >
            <option value="all">Tất cả mức rủi ro</option>
            <option value="low">Rủi ro Thấp</option>
            <option value="medium">Rủi ro Trung bình</option>
            <option value="high">Rủi ro Cao</option>
            <option value="critical">Nguy hiểm khẩn cấp</option>
          </select>

          {/* Status buttons */}
          <div className="flex items-center gap-1 bg-slate-50 dark:bg-slate-800 p-1 rounded-lg border border-slate-200/50 dark:border-slate-700/50">
            {["all", "pending", "in_progress", "completed", "cancelled", "incident"].map((status) => (
              <button
                key={status}
                onClick={() => setStatusFilter(status)}
                className={cn(
                  "px-2.5 py-1 rounded-md text-[10px] font-bold uppercase transition cursor-pointer",
                  statusFilter === status
                    ? "bg-white dark:bg-slate-700 text-slate-900 dark:text-white shadow-sm"
                    : "text-slate-500 hover:text-slate-800 dark:hover:text-slate-300"
                )}
              >
                {status === "all" ? "Tất cả" : TRIP_STATUS_LABELS[status] || status}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* ===== Trips Table ===== */}
      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden">
        {isLoading && (
          <div className="px-4 py-2 text-xs text-blue-600 dark:text-blue-400 border-b border-slate-100 dark:border-slate-800">
            Đang tải dữ liệu chuyến đi từ backend...
          </div>
        )}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/50 dark:bg-slate-800/30 border-b border-slate-100 dark:border-slate-800 text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                <th className="py-3.5 px-4">Mã chuyến</th>
                <th className="py-3.5 px-4">Lộ trình (Đi → Đến)</th>
                <th className="py-3.5 px-4">Phương tiện</th>
                <th className="py-3.5 px-4">Tài xế</th>
                <th className="py-3.5 px-4">Khởi hành dự kiến</th>
                <th className="py-3.5 px-4 text-center">Tiến độ</th>
                <th className="py-3.5 px-4 text-center">Mức rủi ro</th>
                <th className="py-3.5 px-4">Trạng thái</th>
                <th className="py-3.5 px-4 text-center">Hành động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-800/60">
              {filteredTrips.map((trip) => {
                return (
                  <tr
                    key={trip.id}
                    className="hover:bg-slate-50/50 dark:hover:bg-slate-800/20 transition-colors"
                  >
                    {/* Code */}
                    <td className="py-3 px-4 font-bold text-slate-900 dark:text-white text-xs">
                      <div className="flex items-center gap-2">
                        <Navigation className="w-4 h-4 text-slate-400" />
                        <span>{trip.code}</span>
                      </div>
                    </td>

                    {/* Route */}
                    <td className="py-3 px-4 text-xs font-medium text-slate-700 dark:text-slate-300">
                      {trip.origin} → {trip.destination}
                    </td>

                    {/* Vehicle */}
                    <td className="py-3 px-4 text-xs text-slate-600 dark:text-slate-400">
                      {trip.vehiclePlate}
                    </td>

                    {/* Driver */}
                    <td className="py-3 px-4 text-xs text-slate-700 dark:text-slate-300">
                      {trip.driverName}
                    </td>

                    {/* Scheduled Start */}
                    <td className="py-3 px-4 text-xs text-slate-600 dark:text-slate-400">
                      {formatDateTime(trip.scheduledStart)}
                    </td>

                    {/* Progress bar */}
                    <td className="py-3 px-4">
                      <div className="flex flex-col items-center justify-center w-24 mx-auto">
                        <div className="w-full flex items-center justify-between text-[10px] text-slate-500 mb-1">
                          <span>{trip.progress}%</span>
                        </div>
                        <div className="w-full h-1.5 bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
                          <div
                            className={cn(
                              "h-full rounded-full bg-gradient-to-r transition-all duration-300",
                              trip.status === "completed" ? "from-emerald-500 to-emerald-600" : "from-blue-500 to-blue-600"
                            )}
                            style={{ width: `${trip.progress}%` }}
                          />
                        </div>
                      </div>
                    </td>

                    {/* Risk level */}
                    <td className="py-3 px-4 text-center">
                      <span
                        className="px-2 py-0.5 rounded-full text-[10px] font-bold text-white shadow-sm"
                        style={{ backgroundColor: STATUS_COLORS[trip.riskLevel] }}
                      >
                        {RISK_LEVEL_LABELS[trip.riskLevel] || trip.riskLevel}
                      </span>
                    </td>

                    {/* Status */}
                    <td className="py-3 px-4 text-xs">
                      <span
                        className={cn(
                          "px-2 py-0.5 rounded-full text-[10px] font-bold uppercase",
                          trip.status === "in_progress" && "bg-blue-50 dark:bg-blue-950/30 text-blue-600 dark:text-blue-400",
                          trip.status === "completed" && "bg-emerald-50 dark:bg-emerald-950/30 text-emerald-600 dark:text-emerald-400",
                          trip.status === "pending" && "bg-slate-50 dark:bg-slate-800/50 text-slate-600 dark:text-slate-400",
                          trip.status === "cancelled" && "bg-slate-50 dark:bg-slate-800/50 text-slate-400 dark:text-slate-500",
                          trip.status === "incident" && "bg-red-50 dark:bg-red-950/30 text-red-600 dark:text-red-400 animate-pulse"
                        )}
                      >
                        {TRIP_STATUS_LABELS[trip.status] || trip.status}
                      </span>
                    </td>

                    {/* Action */}
                    <td className="py-3 px-4 text-center">
                      <button
                        className="p-1 rounded text-slate-500 hover:text-slate-800 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition"
                        title="Xem chi tiết"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                );
              })}

              {filteredTrips.length === 0 && (
                <tr>
                  <td colSpan={9} className="py-10 text-center text-slate-400 text-xs">
                    Không tìm thấy chuyến đi nào phù hợp
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
