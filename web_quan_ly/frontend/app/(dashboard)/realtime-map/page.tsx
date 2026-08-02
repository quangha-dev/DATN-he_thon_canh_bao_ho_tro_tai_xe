"use client";

import { useEffect, useState, useMemo } from "react";
import MapView from "@/components/map/MapView";
import { Vehicle, FloodPoint, Incident } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { cn } from "@/lib/utils";
import { AnimatePresence, motion } from "framer-motion";
import {
  Search,
  ChevronLeft,
  ChevronRight,
  Phone,
  MessageSquare,
  Siren,
  X,
  Truck,
  Droplets,
} from "lucide-react";

// =============================================================================
// TYPES & CONSTANTS
// =============================================================================
type DetailItem =
  | { type: "vehicle"; data: Vehicle }
  | { type: "flood"; data: FloodPoint }
  | { type: "incident"; data: Incident };

export default function RealtimeMapPage() {
  const { showToast } = useToast();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [floodPoints, setFloodPoints] = useState<FloodPoint[]>([]);
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [activeFilter, setActiveFilter] = useState("all");
  const [isLeftPanelOpen, setIsLeftPanelOpen] = useState(true);
  const [selectedItem, setSelectedItem] = useState<DetailItem | null>(null);

  useEffect(() => {
    let cancelled = false;

    const loadMapData = async () => {
      setIsLoading(true);
      try {
        const [vehicleData, floodData, incidentData] = await Promise.all([
          safeFleetApi.vehicles(),
          safeFleetApi.floodPoints(),
          safeFleetApi.incidents(),
        ]);
        if (!cancelled) {
          setVehicles(vehicleData);
          setFloodPoints(floodData);
          setIncidents(incidentData);
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được dữ liệu bản đồ.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadMapData();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  // Filter & Search logic
  const filteredVehicles = useMemo(() => {
    return vehicles.filter((v) => {
      // 1. Filter status
      if (activeFilter === "running" && v.status !== "running") return false;
      if (activeFilter === "offline" && v.status !== "offline") return false;
      if (activeFilter === "alert" && v.totalAlerts === 0) return false;
      if (activeFilter === "maintenance" && v.status !== "maintenance") return false;
      
      // 2. Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        return (
          v.plate.toLowerCase().includes(q) ||
          (v.currentDriverName && v.currentDriverName.toLowerCase().includes(q)) ||
          v.type.toLowerCase().includes(q)
        );
      }
      return true;
    });
  }, [vehicles, activeFilter, searchQuery]);

  // Handle marker clicks
  const handleVehicleClick = (vehicle: Vehicle) => {
    setSelectedItem({ type: "vehicle", data: vehicle });
  };

  const handleFloodPointClick = (point: FloodPoint) => {
    setSelectedItem({ type: "flood", data: point });
  };

  const handleIncidentClick = (incident: Incident) => {
    setSelectedItem({ type: "incident", data: incident });
  };

  return (
    <div className="relative w-full h-[calc(100vh-64px)] flex overflow-hidden bg-slate-100 dark:bg-slate-950">
      
      {/* ===== Map Component (MapLibre GL) ===== */}
      <div className="absolute inset-0 z-0">
        <MapView
          vehicles={filteredVehicles}
          floodPoints={floodPoints}
          incidents={incidents}
          onVehicleClick={handleVehicleClick}
          onFloodPointClick={handleFloodPointClick}
          onIncidentClick={handleIncidentClick}
          selectedVehicleId={selectedItem?.type === "vehicle" ? selectedItem.data.id : null}
        />
      </div>

      {/* ===== Floating Search & Filters (Top Center) ===== */}
      <div className="absolute top-4 left-4 right-4 md:left-[300px] md:right-4 z-10 flex flex-col gap-2 pointer-events-none">
        <div className="flex gap-2 max-w-xl w-full pointer-events-auto">
          {/* Search bar */}
          <div className="relative flex-1 shadow-lg rounded-xl">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4.5 h-4.5 text-slate-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Tìm xe, tài xế, loại xe..."
              className="w-full pl-11 pr-4 py-3 bg-white/95 dark:bg-slate-900/95 backdrop-blur border border-slate-200/50 dark:border-slate-800/50 rounded-xl text-sm shadow-md text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/40"
            />
          </div>
          {isLoading && (
            <span className="px-3 py-3 rounded-xl bg-white/95 dark:bg-slate-900/95 border border-slate-200/50 dark:border-slate-800/50 text-xs font-semibold text-blue-600 shadow-md">
              Đang tải...
            </span>
          )}
        </div>

        {/* Filters bar */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 max-w-full pointer-events-auto select-none">
          {[
            { key: "all", label: "Tất cả" },
            { key: "running", label: "Đang chạy" },
            { key: "alert", label: "Cảnh báo" },
            { key: "maintenance", label: "Bảo trì" },
            { key: "offline", label: "Mất GPS" },
          ].map((f) => (
            <button
              key={f.key}
              onClick={() => setActiveFilter(f.key)}
              className={cn(
                "px-3 py-1.5 rounded-full text-xs font-semibold backdrop-blur shadow border transition-all cursor-pointer whitespace-nowrap",
                activeFilter === f.key
                  ? "bg-blue-600 text-white border-blue-500 shadow-blue-500/10"
                  : "bg-white/90 dark:bg-slate-900/90 text-slate-600 dark:text-slate-300 border-slate-200/50 dark:border-slate-800/50 hover:bg-slate-50 dark:hover:bg-slate-800"
              )}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {/* ===== Left Panel: Vehicles List ===== */}
      <div className="absolute left-4 top-4 bottom-4 z-10 pointer-events-none flex items-stretch">
        <AnimatePresence initial={false}>
          {isLeftPanelOpen && (
            <motion.div
              initial={{ opacity: 0, x: -300 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -300 }}
              transition={{ type: "spring", stiffness: 300, damping: 30 }}
              className="w-72 bg-white/95 dark:bg-slate-900/95 backdrop-blur border border-slate-200/50 dark:border-slate-800/50 rounded-2xl shadow-xl flex flex-col overflow-hidden pointer-events-auto"
            >
              {/* Header */}
              <div className="px-4 py-3 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between flex-shrink-0">
                <div>
                  <h3 className="font-bold text-sm text-slate-900 dark:text-white">Danh sách đội xe</h3>
                  <p className="text-[10px] text-slate-500 mt-0.5">Hiển thị {filteredVehicles.length} xe</p>
                </div>
              </div>

              {/* List */}
              <div className="flex-1 overflow-y-auto divide-y divide-slate-100 dark:divide-slate-800/50">
                {filteredVehicles.map((vehicle) => {
                  const hasAlert = vehicle.totalAlerts > 0;
                  return (
                    <button
                      key={vehicle.id}
                      onClick={() => handleVehicleClick(vehicle)}
                      className={cn(
                        "w-full px-4 py-3 text-left hover:bg-slate-50 dark:hover:bg-slate-800/40 transition flex items-center gap-3",
                        selectedItem?.type === "vehicle" && selectedItem.data.id === vehicle.id && "bg-blue-50/50 dark:bg-blue-950/20 border-r-2 border-blue-500"
                      )}
                    >
                      {/* Status indicator */}
                      <div className="relative">
                        <div
                          className={cn(
                            "w-8 h-8 rounded-lg flex items-center justify-center text-white",
                            vehicle.status === "running" && "bg-emerald-500",
                            vehicle.status === "idle" && "bg-blue-500",
                            vehicle.status === "maintenance" && "bg-amber-500",
                            vehicle.status === "offline" && "bg-slate-400"
                          )}
                        >
                          <Truck className="w-4 h-4" />
                        </div>
                        {hasAlert && (
                          <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-red-500 border border-white rounded-full animate-pulse-dot" />
                        )}
                      </div>

                      {/* Info */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <p className="text-xs font-bold text-slate-950 dark:text-white">{vehicle.plate}</p>
                          <span className="text-[9px] text-slate-400 font-medium">
                            {vehicle.status === "running" ? `${vehicle.currentSpeed} km/h` : "Dừng"}
                          </span>
                        </div>
                        <p className="text-[10px] text-slate-500 truncate mt-0.5">
                          {vehicle.currentDriverName || "Chưa giao xe"}
                        </p>
                      </div>
                    </button>
                  );
                })}

                {filteredVehicles.length === 0 && (
                  <div className="p-8 text-center text-slate-400 text-xs">Không tìm thấy xe phù hợp</div>
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Toggle Panel button */}
        <div className="flex items-center ml-2 pointer-events-auto">
          <button
            onClick={() => setIsLeftPanelOpen(!isLeftPanelOpen)}
            className="w-7 h-10 rounded-lg bg-white/95 dark:bg-slate-900/95 border border-slate-200/50 dark:border-slate-800/50 shadow-md flex items-center justify-center text-slate-500 hover:text-slate-800 dark:hover:text-white transition cursor-pointer"
          >
            {isLeftPanelOpen ? <ChevronLeft className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
          </button>
        </div>
      </div>

      {/* ===== Right Drawer: Details ===== */}
      <AnimatePresence>
        {selectedItem && (
          <motion.div
            initial={{ opacity: 0, x: 360 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 360 }}
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className="absolute right-4 top-4 bottom-4 w-80 bg-white/95 dark:bg-slate-900/95 backdrop-blur border border-slate-200/50 dark:border-slate-800/50 rounded-2xl shadow-2xl flex flex-col z-25 overflow-hidden"
          >
            {/* Header */}
            <div className="px-4 py-3.5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between flex-shrink-0">
              <h3 className="font-bold text-sm text-slate-900 dark:text-white flex items-center gap-1.5">
                {selectedItem.type === "vehicle" && <Truck className="w-4 h-4 text-blue-500" />}
                {selectedItem.type === "flood" && <Droplets className="w-4 h-4 text-purple-500" />}
                {selectedItem.type === "incident" && <Siren className="w-4 h-4 text-red-500 animate-pulse-dot" />}
                Chi tiết thông tin
              </h3>
              <button
                onClick={() => setSelectedItem(null)}
                className="p-1 rounded-md text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Content body */}
            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              {/* VEHICLE CONTENT */}
              {selectedItem.type === "vehicle" && (
                <>
                  <div>
                    <h4 className="text-xl font-bold text-slate-950 dark:text-white leading-none">
                      {selectedItem.data.plate}
                    </h4>
                    <p className="text-xs text-slate-500 mt-1">
                      {selectedItem.data.brand} {selectedItem.data.model} · {selectedItem.data.type}
                    </p>
                  </div>

                  {/* Status Box */}
                  <div
                    className={cn(
                      "p-3 rounded-xl border flex items-center justify-between",
                      selectedItem.data.status === "running" && "bg-emerald-50/50 border-emerald-200 dark:bg-emerald-950/20 dark:border-emerald-800 text-emerald-800 dark:text-emerald-400",
                      selectedItem.data.status === "idle" && "bg-blue-50/50 border-blue-200 dark:bg-blue-950/20 dark:border-blue-800 text-blue-800 dark:text-blue-400",
                      selectedItem.data.status === "maintenance" && "bg-amber-50/50 border-amber-200 dark:bg-amber-950/20 dark:border-amber-800 text-amber-800 dark:text-amber-400",
                      selectedItem.data.status === "offline" && "bg-slate-50/50 border-slate-200 dark:bg-slate-800/50 dark:border-slate-700 text-slate-800 dark:text-slate-400"
                    )}
                  >
                    <span className="text-xs font-semibold">Trạng thái</span>
                    <span className="text-xs font-bold uppercase">
                      {selectedItem.data.status === "running" && "Đang chạy"}
                      {selectedItem.data.status === "idle" && "Sẵn sàng"}
                      {selectedItem.data.status === "maintenance" && "Bảo trì"}
                      {selectedItem.data.status === "offline" && "Mất kết nối"}
                    </span>
                  </div>

                  {/* Driver Box */}
                  {selectedItem.data.currentDriverName ? (
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-slate-500">Tài xế hiện tại</span>
                        <span className="text-xs font-bold text-slate-900 dark:text-white">
                          {selectedItem.data.currentDriverName}
                        </span>
                      </div>
                      <div className="flex justify-between items-center pt-2 border-t border-slate-200/50 dark:border-slate-800/50">
                        <span className="text-[10px] text-slate-500">Gọi tài xế</span>
                        <div className="flex gap-1.5">
                          <button className="p-1.5 rounded-lg bg-emerald-50 dark:bg-emerald-950/30 text-emerald-600 dark:text-emerald-400 hover:bg-emerald-100 dark:hover:bg-emerald-900/30 transition">
                            <Phone className="w-3.5 h-3.5" />
                          </button>
                          <button className="p-1.5 rounded-lg bg-blue-50 dark:bg-blue-950/30 text-blue-600 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/30 transition">
                            <MessageSquare className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    </div>
                  ) : (
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-dashed border-slate-200 dark:border-slate-800 text-center rounded-xl text-xs text-slate-400">
                      Chưa giao xe cho tài xế nào
                    </div>
                  )}

                  {/* Stats Grid */}
                  <div className="grid grid-cols-2 gap-3">
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl">
                      <span className="text-[10px] text-slate-500 block">Tốc độ hiện tại</span>
                      <span className="text-sm font-bold text-slate-900 dark:text-white">
                        {selectedItem.data.currentSpeed} km/h
                      </span>
                    </div>
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl">
                      <span className="text-[10px] text-slate-500 block">Cảnh báo gần đây</span>
                      <span className="text-sm font-bold text-rose-500">
                        {selectedItem.data.totalAlerts} lần
                      </span>
                    </div>
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl">
                      <span className="text-[10px] text-slate-500 block">Tổng km hoạt động</span>
                      <span className="text-sm font-bold text-slate-900 dark:text-white">
                        {selectedItem.data.totalKm} km
                      </span>
                    </div>
                    <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl">
                      <span className="text-[10px] text-slate-500 block">Số chuyến đã đi</span>
                      <span className="text-sm font-bold text-slate-900 dark:text-white">
                        {selectedItem.data.totalTrips} chuyến
                      </span>
                    </div>
                  </div>
                </>
              )}

              {/* FLOOD POINT CONTENT */}
              {selectedItem.type === "flood" && (
                <>
                  <div>
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold text-white bg-purple-500">
                      ĐIỂM NGẬP LỤT
                    </span>
                    <h4 className="text-lg font-bold text-slate-950 dark:text-white leading-tight mt-2">
                      {selectedItem.data.location}
                    </h4>
                  </div>

                  <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl space-y-2 text-xs">
                    <div className="flex justify-between">
                      <span className="text-slate-500">Mức độ ngập:</span>
                      <span className="font-bold text-red-500">Ngập nặng</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Số tài xế báo cáo:</span>
                      <span className="font-bold text-slate-900 dark:text-white">
                        {selectedItem.data.reportCount} người
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Độ tin cậy:</span>
                      <span className="font-bold text-emerald-500">{selectedItem.data.confidence}%</span>
                    </div>
                  </div>

                  <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl text-xs space-y-1">
                    <span className="text-slate-500 block font-medium">Xe bị ảnh hưởng:</span>
                    <p className="text-slate-800 dark:text-slate-200">
                      Có {selectedItem.data.affectedVehicles} phương tiện gần đó.
                    </p>
                  </div>
                </>
              )}

              {/* INCIDENT CONTENT */}
              {selectedItem.type === "incident" && (
                <>
                  <div>
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold text-white bg-red-600 animate-pulse">
                      SOS KHẨN CẤP
                    </span>
                    <h4 className="text-lg font-bold text-slate-950 dark:text-white leading-tight mt-2">
                      Sự cố: {selectedItem.data.vehiclePlate}
                    </h4>
                  </div>

                  <div className="p-3 bg-slate-50 dark:bg-slate-800/40 border border-slate-100 dark:border-slate-800/80 rounded-xl space-y-2 text-xs">
                    <div className="flex justify-between">
                      <span className="text-slate-500">Tài xế:</span>
                      <span className="font-bold text-slate-900 dark:text-white">{selectedItem.data.driverName}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Vị trí sự cố:</span>
                      <span className="font-bold text-slate-900 dark:text-white text-right">{selectedItem.data.location}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Trạng thái xử lý:</span>
                      <span className="font-bold text-red-500">Chưa tiếp nhận</span>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="pt-2">
                    <button className="w-full py-2.5 rounded-xl bg-red-600 hover:bg-red-700 text-white font-bold text-xs shadow-md shadow-red-500/20 transition flex items-center justify-center gap-1.5 cursor-pointer">
                      <Siren className="w-4 h-4 animate-bounce" /> TIẾP NHẬN SỰ CỐ NGAY
                    </button>
                  </div>
                </>
              )}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
