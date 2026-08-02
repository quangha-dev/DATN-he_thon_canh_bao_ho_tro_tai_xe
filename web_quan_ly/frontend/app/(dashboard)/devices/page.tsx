"use client";

import { useEffect, useMemo, useState } from "react";
import { Activity, Camera, Radio, Search, Smartphone, Wifi, WifiOff, type LucideIcon } from "lucide-react";
import { FleetDevice, safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { cn, formatTimeAgo } from "@/lib/utils";

const TYPE_LABELS: Record<FleetDevice["type"], string> = {
  GPS_TRACKER: "Định vị GPS",
  CABIN_CAMERA: "Camera cabin",
  DASH_CAMERA: "Camera hành trình",
  DRIVER_PHONE: "Điện thoại tài xế",
  IOT_FLOOD_SENSOR: "Cảm biến ngập",
};

const STATUS_LABELS: Record<FleetDevice["status"], string> = {
  ONLINE: "Trực tuyến",
  OFFLINE: "Mất kết nối",
  MAINTENANCE: "Bảo trì",
  INACTIVE: "Ngừng dùng",
};

const STATUS_STYLE: Record<FleetDevice["status"], string> = {
  ONLINE: "bg-emerald-50 text-emerald-700 ring-emerald-200",
  OFFLINE: "bg-rose-50 text-rose-700 ring-rose-200",
  MAINTENANCE: "bg-amber-50 text-amber-700 ring-amber-200",
  INACTIVE: "bg-slate-100 text-slate-600 ring-slate-200",
};

function deviceIcon(type: FleetDevice["type"]) {
  if (type === "CABIN_CAMERA" || type === "DASH_CAMERA") return Camera;
  if (type === "DRIVER_PHONE") return Smartphone;
  return Radio;
}

export default function DevicesPage() {
  const { showToast } = useToast();
  const [devices, setDevices] = useState<FleetDevice[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<"ALL" | FleetDevice["status"]>("ALL");

  useEffect(() => {
    let cancelled = false;
    safeFleetApi
      .devices()
      .then((items) => !cancelled && setDevices(items))
      .catch((error) => {
        if (!cancelled) showToast(error instanceof Error ? error.message : "Không tải được thiết bị.", "error");
      })
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [showToast]);

  const stats = useMemo(
    () => ({
      total: devices.length,
      online: devices.filter((item) => item.status === "ONLINE").length,
      offline: devices.filter((item) => item.status === "OFFLINE").length,
      assigned: devices.filter((item) => item.vehicleId != null).length,
    }),
    [devices]
  );

  const filtered = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    return devices.filter((item) => {
      if (status !== "ALL" && item.status !== status) return false;
      if (!keyword) return true;
      return [item.deviceCode, item.name, item.vehiclePlateNumber, item.serialNumber]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(keyword));
    });
  }, [devices, query, status]);

  const cards: { label: string; value: number; icon: LucideIcon; color: string }[] = [
    { label: "Tổng thiết bị", value: stats.total, icon: Activity, color: "text-slate-700" },
    { label: "Trực tuyến", value: stats.online, icon: Wifi, color: "text-emerald-600" },
    { label: "Mất kết nối", value: stats.offline, icon: WifiOff, color: "text-rose-600" },
    { label: "Đã gắn xe", value: stats.assigned, icon: Radio, color: "text-blue-600" },
  ];

  return (
    <div className="space-y-6 animate-fadeIn">
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {cards.map(({ label, value, icon: Icon, color }) => (
          <div key={label} className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500">{label}</span>
              <Icon className={cn("h-4 w-4", color)} />
            </div>
            <strong className="mt-2 block text-2xl text-slate-900">{value}</strong>
          </div>
        ))}
      </div>

      <div className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm sm:flex-row">
        <label className="relative flex-1">
          <span className="sr-only">Tìm thiết bị</span>
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tìm mã, tên, serial hoặc biển số..." className="w-full rounded-lg border border-slate-200 bg-slate-50 py-2 pl-9 pr-3 text-sm outline-none focus:border-teal-500 focus:bg-white" />
        </label>
        <select value={status} onChange={(event) => setStatus(event.target.value as typeof status)} className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm font-medium text-slate-700 outline-none focus:border-teal-500">
          <option value="ALL">Tất cả trạng thái</option>
          {Object.entries(STATUS_LABELS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
      </div>

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
        {loading && <div className="border-b border-slate-100 px-4 py-2 text-xs text-blue-600">Đang tải thiết bị từ backend...</div>}
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead className="border-b border-slate-200 bg-slate-50 text-[10px] font-bold uppercase tracking-wider text-slate-500">
              <tr><th className="px-4 py-3">Thiết bị</th><th className="px-4 py-3">Loại</th><th className="px-4 py-3">Phương tiện</th><th className="px-4 py-3">Firmware / Serial</th><th className="px-4 py-3">Kết nối cuối</th><th className="px-4 py-3">Trạng thái</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.map((item) => {
                const Icon = deviceIcon(item.type);
                return <tr key={item.id} className="hover:bg-slate-50/70">
                  <td className="px-4 py-3"><div className="flex items-center gap-3"><span className="rounded-lg bg-slate-100 p-2"><Icon className="h-4 w-4 text-slate-600" /></span><div><div className="text-sm font-bold text-slate-900">{item.name}</div><div className="text-xs text-slate-500">{item.deviceCode}</div></div></div></td>
                  <td className="px-4 py-3 text-xs font-medium text-slate-700">{TYPE_LABELS[item.type]}</td>
                  <td className="px-4 py-3 text-xs text-slate-700">{item.vehiclePlateNumber || <span className="italic text-slate-400">Chưa gắn xe</span>}</td>
                  <td className="px-4 py-3 text-xs text-slate-600"><div>{item.firmwareVersion || "—"}</div><div className="text-[11px] text-slate-400">{item.serialNumber || "Không có serial"}</div></td>
                  <td className="px-4 py-3 text-xs text-slate-600">{item.lastSeenAt ? formatTimeAgo(item.lastSeenAt) : "Chưa ghi nhận"}</td>
                  <td className="px-4 py-3"><span className={cn("inline-flex rounded-full px-2 py-1 text-[10px] font-bold ring-1 ring-inset", STATUS_STYLE[item.status])}>{STATUS_LABELS[item.status]}</span></td>
                </tr>;
              })}
              {!loading && filtered.length === 0 && <tr><td colSpan={6} className="px-4 py-12 text-center text-sm text-slate-400">Không có thiết bị phù hợp.</td></tr>}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
