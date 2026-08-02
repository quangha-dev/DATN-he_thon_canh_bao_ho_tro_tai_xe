"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, CalendarClock, CheckCircle2, CircleDollarSign, Search, Wrench, type LucideIcon } from "lucide-react";
import { MaintenanceOrder, safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { cn } from "@/lib/utils";

const STATUS_LABELS: Record<MaintenanceOrder["status"], string> = { OPEN: "Mới mở", SCHEDULED: "Đã lên lịch", IN_PROGRESS: "Đang thực hiện", COMPLETED: "Hoàn thành", CANCELLED: "Đã hủy" };
const PRIORITY_LABELS: Record<MaintenanceOrder["priority"], string> = { LOW: "Thấp", MEDIUM: "Trung bình", HIGH: "Cao", URGENT: "Khẩn cấp" };
const TYPE_LABELS: Record<MaintenanceOrder["type"], string> = { PERIODIC: "Định kỳ", REPAIR: "Sửa chữa", INSPECTION: "Đăng kiểm", INSURANCE: "Bảo hiểm", EMERGENCY: "Khẩn cấp" };
const STATUS_STYLE: Record<MaintenanceOrder["status"], string> = { OPEN: "bg-blue-50 text-blue-700", SCHEDULED: "bg-violet-50 text-violet-700", IN_PROGRESS: "bg-amber-50 text-amber-700", COMPLETED: "bg-emerald-50 text-emerald-700", CANCELLED: "bg-slate-100 text-slate-500" };
const PRIORITY_STYLE: Record<MaintenanceOrder["priority"], string> = { LOW: "text-slate-500", MEDIUM: "text-blue-600", HIGH: "text-amber-600", URGENT: "text-rose-600" };

function money(value?: number | null) {
  if (value == null) return "Chưa cập nhật";
  return new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND", maximumFractionDigits: 0 }).format(value);
}

export default function MaintenancePage() {
  const { showToast } = useToast();
  const [orders, setOrders] = useState<MaintenanceOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<"ALL" | MaintenanceOrder["status"]>("ALL");

  useEffect(() => {
    let cancelled = false;
    safeFleetApi.maintenanceOrders().then((items) => !cancelled && setOrders(items)).catch((error) => {
      if (!cancelled) showToast(error instanceof Error ? error.message : "Không tải được lịch bảo trì.", "error");
    }).finally(() => !cancelled && setLoading(false));
    return () => { cancelled = true; };
  }, [showToast]);

  const stats = useMemo(() => ({
    total: orders.length,
    urgent: orders.filter((item) => item.priority === "URGENT" && item.status !== "COMPLETED" && item.status !== "CANCELLED").length,
    active: orders.filter((item) => item.status === "OPEN" || item.status === "SCHEDULED" || item.status === "IN_PROGRESS").length,
    completed: orders.filter((item) => item.status === "COMPLETED").length,
    cost: orders.reduce((sum, item) => sum + (item.cost ?? 0), 0),
  }), [orders]);

  const filtered = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    return orders.filter((item) => {
      if (status !== "ALL" && item.status !== status) return false;
      if (!keyword) return true;
      return [item.maintenanceCode, item.vehiclePlateNumber, item.title, item.assignedToName].filter(Boolean).some((value) => value!.toLowerCase().includes(keyword));
    });
  }, [orders, query, status]);

  const cards: { label: string; value: string | number; icon: LucideIcon; color: string }[] = [
    { label: "Tổng phiếu", value: stats.total, icon: Wrench, color: "text-slate-700" },
    { label: "Đang xử lý", value: stats.active, icon: CalendarClock, color: "text-blue-600" },
    { label: "Khẩn cấp", value: stats.urgent, icon: AlertTriangle, color: "text-rose-600" },
    { label: "Hoàn thành", value: stats.completed, icon: CheckCircle2, color: "text-emerald-600" },
    { label: "Tổng chi phí", value: money(stats.cost), icon: CircleDollarSign, color: "text-teal-600" },
  ];

  return <div className="space-y-6 animate-fadeIn">
    <div className="grid grid-cols-2 gap-4 lg:grid-cols-5">
      {cards.map(({ label, value, icon: Icon, color }) => <div key={label} className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm"><div className="flex items-center justify-between"><span className="text-[10px] font-bold uppercase tracking-wider text-slate-500">{label}</span><Icon className={cn("h-4 w-4", color)} /></div><strong className="mt-2 block text-xl text-slate-900">{value}</strong></div>)}
    </div>

    <div className="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm sm:flex-row">
      <label className="relative flex-1"><span className="sr-only">Tìm phiếu bảo trì</span><Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Tìm mã phiếu, biển số, nội dung..." className="w-full rounded-lg border border-slate-200 bg-slate-50 py-2 pl-9 pr-3 text-sm outline-none focus:border-teal-500 focus:bg-white" /></label>
      <select value={status} onChange={(event) => setStatus(event.target.value as typeof status)} className="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm font-medium text-slate-700 outline-none focus:border-teal-500"><option value="ALL">Tất cả trạng thái</option>{Object.entries(STATUS_LABELS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select>
    </div>

    <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
      {loading && <div className="border-b border-slate-100 px-4 py-2 text-xs text-blue-600">Đang tải dữ liệu bảo trì từ backend...</div>}
      <div className="overflow-x-auto"><table className="w-full text-left"><thead className="border-b border-slate-200 bg-slate-50 text-[10px] font-bold uppercase tracking-wider text-slate-500"><tr><th className="px-4 py-3">Phiếu / Phương tiện</th><th className="px-4 py-3">Công việc</th><th className="px-4 py-3">Lịch</th><th className="px-4 py-3">Phụ trách</th><th className="px-4 py-3">Chi phí</th><th className="px-4 py-3">Trạng thái</th></tr></thead>
      <tbody className="divide-y divide-slate-100">{filtered.map((item) => <tr key={item.id} className="hover:bg-slate-50/70"><td className="px-4 py-3"><div className="text-sm font-bold text-slate-900">{item.maintenanceCode}</div><div className="text-xs font-medium text-slate-500">{item.vehiclePlateNumber}</div></td><td className="max-w-sm px-4 py-3"><div className="text-sm font-semibold text-slate-800">{item.title}</div><div className="mt-0.5 text-xs text-slate-500">{TYPE_LABELS[item.type]} · <span className={cn("font-bold", PRIORITY_STYLE[item.priority])}>{PRIORITY_LABELS[item.priority]}</span></div></td><td className="px-4 py-3 text-xs text-slate-600">{item.completedDate ? `Hoàn tất ${item.completedDate}` : item.scheduledDate ? `Dự kiến ${item.scheduledDate}` : "Chưa xếp lịch"}</td><td className="px-4 py-3 text-xs text-slate-600">{item.assignedToName || "Chưa phân công"}</td><td className="px-4 py-3 text-xs font-semibold text-slate-700">{money(item.cost)}</td><td className="px-4 py-3"><span className={cn("inline-flex rounded-full px-2 py-1 text-[10px] font-bold", STATUS_STYLE[item.status])}>{STATUS_LABELS[item.status]}</span></td></tr>)}{!loading && filtered.length === 0 && <tr><td colSpan={6} className="px-4 py-12 text-center text-sm text-slate-400">Không có phiếu bảo trì phù hợp.</td></tr>}</tbody></table></div>
    </div>
  </div>;
}
