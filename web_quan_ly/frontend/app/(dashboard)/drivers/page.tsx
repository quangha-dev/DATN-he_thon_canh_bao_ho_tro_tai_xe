"use client";

import { useEffect, useState, useMemo } from "react";
import { Driver } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { cn, formatDrivingTime, getSafetyScoreInfo } from "@/lib/utils";
import {
  Search,
  Plus,
  Eye,
  Phone,
  Mail,
} from "lucide-react";

export default function DriversPage() {
  const { showToast } = useToast();
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [scoreFilter, setScoreFilter] = useState<string>("all");

  useEffect(() => {
    let cancelled = false;

    const loadDrivers = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.drivers();
        if (!cancelled) setDrivers(data);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được danh sách tài xế.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadDrivers();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  // Summary stats
  const stats = useMemo(() => {
    return {
      total: drivers.length,
      driving: drivers.filter((d) => d.status === "driving").length,
      available: drivers.filter((d) => d.status === "available").length,
      resting: drivers.filter((d) => d.status === "resting").length,
      highRisk: drivers.filter((d) => d.safetyScore < 60 || d.status === "high_risk").length,
    };
  }, [drivers]);

  // Filtered drivers
  const filteredDrivers = useMemo(() => {
    return drivers.filter((d) => {
      // 1. Status filter
      if (statusFilter !== "all" && d.status !== statusFilter) return false;

      // 2. Safety score filter
      if (scoreFilter === "excellent" && d.safetyScore < 90) return false;
      if (scoreFilter === "good" && (d.safetyScore < 75 || d.safetyScore >= 90)) return false;
      if (scoreFilter === "monitor" && (d.safetyScore < 60 || d.safetyScore >= 75)) return false;
      if (scoreFilter === "high_risk" && d.safetyScore >= 60) return false;

      // 3. Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        return (
          d.fullName.toLowerCase().includes(q) ||
          d.phone.includes(q) ||
          d.email.toLowerCase().includes(q) ||
          (d.currentVehiclePlate && d.currentVehiclePlate.toLowerCase().includes(q))
        );
      }
      return true;
    });
  }, [drivers, searchQuery, statusFilter, scoreFilter]);

  const DRIVER_STATUS_LABELS: Record<string, string> = {
    driving: "Đang lái",
    available: "Sẵn sàng",
    resting: "Đang nghỉ",
    off_duty: "Nghỉ phép",
    suspended: "Tạm khóa",
    high_risk: "Rủi ro cao",
    inactive: "Ngừng hoạt động",
  };

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* ===== Stat Cards ===== */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        {/* Total Drivers */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Tổng tài xế
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.total}
          </span>
        </div>

        {/* Driving */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-blue-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Đang cầm lái
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.driving}
          </span>
        </div>

        {/* Available */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-emerald-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Đang sẵn sàng
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.available}
          </span>
        </div>

        {/* Resting */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-amber-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Đang nghỉ ngơi
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.resting}
          </span>
        </div>

        {/* High Risk */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-red-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Rủi ro cao
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
            placeholder="Tìm tên tài xế, SĐT, biển số xe..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 dark:bg-slate-800 border border-transparent rounded-lg text-sm text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:bg-white dark:focus:bg-slate-800 focus:border-slate-200 dark:focus:border-slate-700 transition"
          />
        </div>

        {/* Filters */}
        <div className="flex items-center gap-2 flex-wrap">
          {/* Safety Score filter dropdown */}
          <select
            value={scoreFilter}
            onChange={(e) => setScoreFilter(e.target.value)}
            className="px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs font-semibold text-slate-700 dark:text-slate-200 focus:outline-none"
          >
            <option value="all">Tất cả điểm an toàn</option>
            <option value="excellent">Rất tốt (90-100)</option>
            <option value="good">Tốt (75-89)</option>
            <option value="monitor">Cần theo dõi (60-74)</option>
            <option value="high_risk">Rủi ro cao (&lt;60)</option>
          </select>

          {/* Status filters */}
          <div className="flex items-center gap-1 bg-slate-50 dark:bg-slate-800 p-1 rounded-lg border border-slate-200/50 dark:border-slate-700/50">
            {["all", "driving", "available", "resting"].map((status) => (
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
                {status === "all" ? "Tất cả" : DRIVER_STATUS_LABELS[status]}
              </button>
            ))}
          </div>

          {/* Add Driver Button */}
          <button className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-lg shadow transition cursor-pointer">
            <Plus className="w-3.5 h-3.5" /> Thêm tài xế
          </button>
        </div>
      </div>

      {/* ===== Drivers Table ===== */}
      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden">
        {isLoading && (
          <div className="px-4 py-2 text-xs text-blue-600 dark:text-blue-400 border-b border-slate-100 dark:border-slate-800">
            Đang tải dữ liệu tài xế từ backend...
          </div>
        )}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/50 dark:bg-slate-800/30 border-b border-slate-100 dark:border-slate-800 text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                <th className="py-3.5 px-4">Tài xế</th>
                <th className="py-3.5 px-4">Liên hệ</th>
                <th className="py-3.5 px-4">Hạng bằng</th>
                <th className="py-3.5 px-4">Xe phụ trách</th>
                <th className="py-3.5 px-4">Trạng thái</th>
                <th className="py-3.5 px-4 text-center">Giờ lái hôm nay</th>
                <th className="py-3.5 px-4 text-center">Điểm an toàn</th>
                <th className="py-3.5 px-4 text-center">Hành động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-800/60">
              {filteredDrivers.map((driver) => {
                const scoreInfo = getSafetyScoreInfo(driver.safetyScore);
                const overtime = driver.drivingTimeToday >= 240; // > 4h
                
                return (
                  <tr
                    key={driver.id}
                    className="hover:bg-slate-50/50 dark:hover:bg-slate-800/20 transition-colors"
                  >
                    {/* Name */}
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-2.5">
                        <div className="w-8 h-8 rounded-lg bg-blue-500/10 text-blue-600 dark:text-blue-400 flex items-center justify-center font-bold text-sm">
                          {driver.fullName.charAt(0)}
                        </div>
                        <div>
                          <p className="text-xs font-bold text-slate-900 dark:text-white leading-none">
                            {driver.fullName}
                          </p>
                          <p className="text-[10px] text-slate-400 dark:text-slate-500 mt-0.5">
                            Mã: {driver.id}
                          </p>
                        </div>
                      </div>
                    </td>

                    {/* Contact */}
                    <td className="py-3 px-4">
                      <div className="space-y-0.5 text-xs text-slate-600 dark:text-slate-400">
                        <p className="flex items-center gap-1">
                          <Phone className="w-3 h-3 text-slate-400" />
                          {driver.phone}
                        </p>
                        <p className="flex items-center gap-1 text-[10px] text-slate-400 dark:text-slate-500">
                          <Mail className="w-3 h-3" />
                          {driver.email}
                        </p>
                      </div>
                    </td>

                    {/* License */}
                    <td className="py-3 px-4 text-xs text-slate-700 dark:text-slate-300">
                      Bằng {driver.licenseClass}
                    </td>

                    {/* Vehicle */}
                    <td className="py-3 px-4 text-xs font-semibold text-slate-700 dark:text-slate-300">
                      {driver.currentVehiclePlate || (
                        <span className="text-slate-400 italic font-normal">Sẵn sàng điều phối</span>
                      )}
                    </td>

                    {/* Status */}
                    <td className="py-3 px-4 text-xs">
                      <span
                        className={cn(
                          "px-2 py-0.5 rounded-full text-[10px] font-bold uppercase",
                          driver.status === "driving" && "bg-blue-50 dark:bg-blue-950/30 text-blue-600 dark:text-blue-400",
                          driver.status === "available" && "bg-emerald-50 dark:bg-emerald-950/30 text-emerald-600 dark:text-emerald-400",
                          driver.status === "resting" && "bg-amber-50 dark:bg-amber-950/30 text-amber-600 dark:text-amber-400"
                        )}
                      >
                        {DRIVER_STATUS_LABELS[driver.status] || driver.status}
                      </span>
                    </td>

                    {/* Driving Time Today */}
                    <td className="py-3 px-4 text-center text-xs">
                      <span
                        className={cn(
                          "font-semibold",
                          overtime ? "text-red-500 animate-pulse font-bold" : "text-slate-700 dark:text-slate-300"
                        )}
                      >
                        {formatDrivingTime(driver.drivingTimeToday)}
                      </span>
                    </td>

                    {/* Safety Score */}
                    <td className="py-3 px-4 text-center">
                      <div className="flex flex-col items-center gap-0.5">
                        <span
                          className="px-2 py-0.5 rounded text-[10px] font-bold text-white shadow-sm"
                          style={{ backgroundColor: scoreInfo.color }}
                        >
                          {driver.safetyScore} - {scoreInfo.label}
                        </span>
                      </div>
                    </td>

                    {/* Actions */}
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

              {filteredDrivers.length === 0 && (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-slate-400 text-xs">
                    Không tìm thấy tài xế nào phù hợp
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
