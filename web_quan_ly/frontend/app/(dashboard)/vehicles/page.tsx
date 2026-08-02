"use client";

import { useEffect, useState, useMemo } from "react";
import { Vehicle } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { cn, STATUS_COLORS, VEHICLE_STATUS_LABELS } from "@/lib/utils";
import {
  Truck,
  Plus,
  Search,
  Eye,
} from "lucide-react";

export default function VehiclesPage() {
  const { showToast } = useToast();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [vehicleTypeFilter, setVehicleTypeFilter] = useState<string>("all");

  useEffect(() => {
    let cancelled = false;

    const loadVehicles = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.vehicles();
        if (!cancelled) setVehicles(data);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được danh sách xe.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadVehicles();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  // Summary stats
  const stats = useMemo(() => {
    return {
      total: vehicles.length,
      running: vehicles.filter((v) => v.status === "running").length,
      idle: vehicles.filter((v) => v.status === "idle").length,
      maintenance: vehicles.filter((v) => v.status === "maintenance").length,
      offline: vehicles.filter((v) => v.status === "offline").length,
    };
  }, [vehicles]);

  // Filtered vehicles
  const filteredVehicles = useMemo(() => {
    return vehicles.filter((v) => {
      if (statusFilter !== "all" && v.status !== statusFilter) return false;
      if (vehicleTypeFilter !== "all" && v.type !== vehicleTypeFilter) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        return (
          v.plate.toLowerCase().includes(q) ||
          v.brand.toLowerCase().includes(q) ||
          v.model.toLowerCase().includes(q) ||
          (v.currentDriverName && v.currentDriverName.toLowerCase().includes(q))
        );
      }
      return true;
    });
  }, [vehicles, searchQuery, statusFilter, vehicleTypeFilter]);

  // Unique vehicle types for dropdown filter
  const vehicleTypes = useMemo(() => {
    return Array.from(new Set(vehicles.map((v) => v.type)));
  }, [vehicles]);

  return (
    <div className="space-y-6 animate-fadeIn">
      
      {/* ===== Stat Cards ===== */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        {/* Total */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Tổng phương tiện
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.total}
          </span>
        </div>

        {/* Running */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-emerald-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Đang hoạt động
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.running}
          </span>
        </div>

        {/* Idle */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-blue-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Đang sẵn sàng
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.idle}
          </span>
        </div>

        {/* Maintenance */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-amber-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Đang bảo trì
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.maintenance}
          </span>
        </div>

        {/* Offline */}
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-slate-400">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">
            Mất kết nối
          </span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">
            {stats.offline}
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
            placeholder="Tìm biển số, tài xế, hãng xe..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 dark:bg-slate-800 border border-transparent rounded-lg text-sm text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:bg-white dark:focus:bg-slate-800 focus:border-slate-200 dark:focus:border-slate-700 transition"
          />
        </div>

        {/* Status & Type filters */}
        <div className="flex items-center gap-2 flex-wrap">
          {/* Type dropdown */}
          <select
            value={vehicleTypeFilter}
            onChange={(e) => setVehicleTypeFilter(e.target.value)}
            className="px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs font-semibold text-slate-700 dark:text-slate-200 focus:outline-none"
          >
            <option value="all">Tất cả loại xe</option>
            {vehicleTypes.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>

          {/* Status buttons */}
          <div className="flex items-center gap-1 bg-slate-50 dark:bg-slate-800 p-1 rounded-lg border border-slate-200/50 dark:border-slate-700/50">
            {["all", "running", "idle", "maintenance", "offline"].map((status) => (
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
                {status === "all" ? "Tất cả" : VEHICLE_STATUS_LABELS[status]}
              </button>
            ))}
          </div>

          {/* Add Vehicle Button */}
          <button className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-lg shadow transition cursor-pointer">
            <Plus className="w-3.5 h-3.5" /> Thêm xe
          </button>
        </div>
      </div>

      {/* ===== Vehicles Table ===== */}
      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden">
        {isLoading && (
          <div className="px-4 py-2 text-xs text-blue-600 dark:text-blue-400 border-b border-slate-100 dark:border-slate-800">
            Đang tải dữ liệu phương tiện từ backend...
          </div>
        )}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/50 dark:bg-slate-800/30 border-b border-slate-100 dark:border-slate-800 text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                <th className="py-3.5 px-4">Biển số</th>
                <th className="py-3.5 px-4">Hãng & Model</th>
                <th className="py-3.5 px-4">Loại xe</th>
                <th className="py-3.5 px-4">Tài xế hiện tại</th>
                <th className="py-3.5 px-4">GPS / Trạng thái</th>
                <th className="py-3.5 px-4 text-center">Cảnh báo</th>
                <th className="py-3.5 px-4">Đăng kiểm còn hạn</th>
                <th className="py-3.5 px-4 text-center">Hành động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-800/60">
              {filteredVehicles.map((vehicle) => {
                const hasAlert = vehicle.totalAlerts > 0;
                return (
                  <tr
                    key={vehicle.id}
                    className="hover:bg-slate-50/50 dark:hover:bg-slate-800/20 transition-colors"
                  >
                    {/* Plate */}
                    <td className="py-3 px-4 font-bold text-slate-900 dark:text-white text-xs">
                      <div className="flex items-center gap-2">
                        <Truck className="w-4 h-4 text-slate-400" />
                        <span>{vehicle.plate}</span>
                      </div>
                    </td>

                    {/* Brand & Model */}
                    <td className="py-3 px-4 text-xs text-slate-700 dark:text-slate-300">
                      {vehicle.brand} {vehicle.model}
                    </td>

                    {/* Type */}
                    <td className="py-3 px-4 text-xs text-slate-600 dark:text-slate-400">
                      {vehicle.type}
                    </td>

                    {/* Driver */}
                    <td className="py-3 px-4 text-xs font-medium text-slate-700 dark:text-slate-300">
                      {vehicle.currentDriverName || (
                        <span className="text-slate-400 italic">Chưa giao</span>
                      )}
                    </td>

                    {/* GPS / Status */}
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-1.5">
                        <span
                          className="w-2 h-2 rounded-full"
                          style={{ backgroundColor: STATUS_COLORS[vehicle.status] }}
                        />
                        <span className="text-xs text-slate-700 dark:text-slate-300">
                          {VEHICLE_STATUS_LABELS[vehicle.status]}
                        </span>
                      </div>
                    </td>

                    {/* Alerts count */}
                    <td className="py-3 px-4 text-center">
                      {hasAlert ? (
                        <span className="px-2 py-0.5 rounded bg-red-100 dark:bg-red-950/30 text-[10px] font-bold text-red-600 dark:text-red-400">
                          {vehicle.totalAlerts} lần
                        </span>
                      ) : (
                        <span className="text-slate-400 text-xs">-</span>
                      )}
                    </td>

                    {/* Expiry */}
                    <td className="py-3 px-4 text-xs text-slate-600 dark:text-slate-400">
                      {vehicle.registrationExpiry}
                    </td>

                    {/* Action */}
                    <td className="py-3 px-4 text-center">
                      <div className="flex items-center justify-center gap-1.5">
                        <button
                          className="p-1 rounded text-slate-500 hover:text-slate-800 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 transition"
                          title="Xem chi tiết"
                        >
                          <Eye className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}

              {filteredVehicles.length === 0 && (
                <tr>
                  <td colSpan={8} className="py-10 text-center text-slate-400 text-xs">
                    Không tìm thấy phương tiện nào phù hợp
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
