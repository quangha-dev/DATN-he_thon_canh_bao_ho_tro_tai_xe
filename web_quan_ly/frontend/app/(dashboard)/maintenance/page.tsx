"use client";

import { useEffect, useMemo, useState } from "react";
import { CalendarClock, CircleDollarSign, Plus, TriangleAlert, Wrench } from "lucide-react";
import { MaintenanceOrder, MaintenanceOrderInput, safeFleetApi } from "@/lib/safeFleetApi";
import { Vehicle } from "@/types";
import { useToast } from "@/context/ToastContext";
import {
  Badge,
  Button,
  CellText,
  DataTable,
  FilterChips,
  Modal,
  StatCard,
  TableCard,
  TableToolbar,
  toneOf,
  type FilterChip,
  type Tone,
} from "@/components/ui";

const STATUS_LABELS: Record<MaintenanceOrder["status"], string> = {
  OPEN: "Mới mở",
  SCHEDULED: "Đã lên lịch",
  IN_PROGRESS: "Đang thực hiện",
  COMPLETED: "Hoàn thành",
  CANCELLED: "Đã hủy",
};

const PRIORITY_LABELS: Record<MaintenanceOrder["priority"], string> = {
  LOW: "Thấp",
  MEDIUM: "Trung bình",
  HIGH: "Cao",
  URGENT: "Khẩn cấp",
};

const TYPE_LABELS: Record<MaintenanceOrder["type"], string> = {
  PERIODIC: "Định kỳ",
  REPAIR: "Sửa chữa",
  INSPECTION: "Đăng kiểm",
  INSURANCE: "Bảo hiểm",
  EMERGENCY: "Khẩn cấp",
};

/** Trạng thái phiếu → khóa tone dùng chung */
const STATUS_KEY: Record<MaintenanceOrder["status"], string> = {
  OPEN: "open",
  SCHEDULED: "assigned",
  IN_PROGRESS: "in_progress",
  COMPLETED: "completed",
  CANCELLED: "cancelled",
};

const PRIORITY_TONE: Record<MaintenanceOrder["priority"], Tone> = {
  LOW: "neutral",
  MEDIUM: "primary",
  HIGH: "warning",
  URGENT: "danger",
};

/** Phiếu còn phải xử lý — dùng để đếm "đang xử lý" và xét quá hạn/sắp tới hạn */
const ACTIVE_STATUSES: MaintenanceOrder["status"][] = ["OPEN", "SCHEDULED", "IN_PROGRESS"];

type StatusFilter = "ALL" | MaintenanceOrder["status"];

function money(value?: number | null) {
  if (value == null) return "—";
  return new Intl.NumberFormat("vi-VN", {
    style: "currency",
    currency: "VND",
    maximumFractionDigits: 0,
  }).format(value);
}

/** true nếu dateStr rơi vào tháng hiện tại (theo giờ trình duyệt) */
function inCurrentMonth(dateStr?: string | null): boolean {
  if (!dateStr) return false;
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) return false;
  const now = new Date();
  return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
}

/** Số ngày từ hôm nay tới dateStr (âm nghĩa là đã qua) */
function daysFromNow(dateStr?: string | null): number | null {
  if (!dateStr) return null;
  const d = new Date(dateStr);
  if (Number.isNaN(d.getTime())) return null;
  const startOfDay = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  return Math.round((startOfDay(d) - startOfDay(new Date())) / 86400000);
}

export default function MaintenancePage() {
  const { showToast } = useToast();
  const [orders, setOrders] = useState<MaintenanceOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("ALL");
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editing, setEditing] = useState<MaintenanceOrder | null>(null);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    vehicleId: "",
    type: "PERIODIC" as MaintenanceOrder["type"],
    title: "",
    description: "",
    scheduledDate: "",
    completedDate: "",
    cost: "",
    status: "OPEN" as MaintenanceOrder["status"],
    priority: "MEDIUM" as MaintenanceOrder["priority"],
    note: "",
  });

  useEffect(() => {
    let cancelled = false;
    Promise.all([safeFleetApi.maintenanceOrders(), safeFleetApi.vehicles()])
      .then(([items, vehicleItems]) => {
        if (!cancelled) {
          setOrders(items);
          setVehicles(vehicleItems);
        }
      })
      .catch((error) => {
        if (!cancelled)
          showToast(
            error instanceof Error ? error.message : "Không tải được lịch bảo trì.",
            "error"
          );
      })
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [showToast]);

  const openCreate = () => {
    setEditing(null);
    setForm({ vehicleId: vehicles[0]?.id || "", type: "PERIODIC", title: "", description: "", scheduledDate: "", completedDate: "", cost: "", status: "OPEN", priority: "MEDIUM", note: "" });
    setEditorOpen(true);
  };

  const openEdit = (order: MaintenanceOrder) => {
    setEditing(order);
    setForm({
      vehicleId: String(order.vehicleId), type: order.type, title: order.title,
      description: order.description || "", scheduledDate: order.scheduledDate || "",
      completedDate: order.completedDate || "", cost: order.cost == null ? "" : String(order.cost),
      status: order.status, priority: order.priority, note: order.note || "",
    });
    setEditorOpen(true);
  };

  const saveOrder = async () => {
    if (!form.vehicleId || !form.title.trim()) {
      showToast("Vui lòng chọn xe và nhập nội dung công việc.", "error");
      return;
    }
    const input: MaintenanceOrderInput = {
      vehicleId: Number(form.vehicleId), type: form.type, title: form.title.trim(),
      description: form.description.trim() || null, scheduledDate: form.scheduledDate || null,
      completedDate: form.completedDate || null, cost: form.cost ? Number(form.cost) : null,
      status: form.status, priority: form.priority, assignedTo: editing?.assignedTo || null,
      note: form.note.trim() || null,
    };
    setSaving(true);
    try {
      const saved = editing
        ? await safeFleetApi.updateMaintenanceOrder(editing.id, input)
        : await safeFleetApi.createMaintenanceOrder(input);
      setOrders((items) => editing ? items.map((item) => item.id === saved.id ? saved : item) : [saved, ...items]);
      setEditorOpen(false);
      showToast(editing ? "Đã cập nhật phiếu bảo trì." : "Đã tạo phiếu bảo trì.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không lưu được phiếu bảo trì.", "error");
    } finally {
      setSaving(false);
    }
  };

  const vehicleById = useMemo(() => new Map(vehicles.map((v) => [v.id, v])), [vehicles]);

  const stats = useMemo(() => {
    const active = orders.filter((o) => ACTIVE_STATUSES.includes(o.status));
    const urgentActive = active.filter((o) => o.priority === "URGENT").length;
    const completedThisMonth = orders.filter(
      (o) => o.status === "COMPLETED" && inCurrentMonth(o.completedDate)
    ).length;
    const costThisMonth = orders
      .filter((o) => inCurrentMonth(o.completedDate || o.scheduledDate))
      .reduce((sum, o) => sum + (o.cost ?? 0), 0);
    const dueSoonVehicles = new Set(
      active
        .filter((o) => {
          const days = daysFromNow(o.scheduledDate);
          return days != null && days <= 7;
        })
        .map((o) => o.vehicleId)
    ).size;
    return {
      active: active.length,
      urgentActive,
      completedThisMonth,
      totalCompleted: orders.filter((o) => o.status === "COMPLETED").length,
      costThisMonth,
      dueSoonVehicles,
    };
  }, [orders]);

  const filtered = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    return orders.filter((item) => {
      if (statusFilter !== "ALL" && item.status !== statusFilter) return false;
      if (!keyword) return true;
      return [item.maintenanceCode, item.vehiclePlateNumber, item.title, item.assignedToName]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(keyword));
    });
  }, [orders, query, statusFilter]);

  /* Chip lọc dựng theo đúng năm trạng thái phiếu bảo trì của backend
     (bản thiết kế chỉ vẽ ba), chỉ hiện giá trị thực sự có dữ liệu. */
  const statusChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "ALL", label: "Tất cả", count: orders.length }];
    (Object.keys(STATUS_LABELS) as MaintenanceOrder["status"][]).forEach((key) => {
      const count = orders.filter((o) => o.status === key).length;
      if (count > 0) chips.push({ key, label: STATUS_LABELS[key], count });
    });
    return chips;
  }, [orders]);

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Phiếu đang xử lý"
          value={stats.active}
          icon={Wrench}
          delta={stats.urgentActive > 0 ? `${stats.urgentActive} khẩn cấp` : "không có khẩn cấp"}
          delay={0}
        />
        <StatCard
          label="Hoàn thành tháng"
          value={stats.completedThisMonth}
          icon={CalendarClock}
          tone="success"
          delta={`${stats.totalCompleted} tổng cộng`}
          onClick={() => setStatusFilter(statusFilter === "COMPLETED" ? "ALL" : "COMPLETED")}
          active={statusFilter === "COMPLETED"}
          delay={70}
        />
        <StatCard
          label="Chi phí tháng"
          value={money(stats.costThisMonth)}
          icon={CircleDollarSign}
          tone="info"
          delta="theo phiếu trong tháng"
          delay={140}
        />
        <StatCard
          label="Xe sắp tới hạn"
          value={stats.dueSoonVehicles}
          icon={TriangleAlert}
          tone="warning"
          deltaTone="warning"
          delta="trong 7 ngày"
          delay={210}
        />
      </div>

      {/* ===== Thẻ bảng: thanh công cụ + bảng dạng thẻ ===== */}
      <TableCard
        toolbar={
          <TableToolbar
            search={{
              value: query,
              onChange: setQuery,
              placeholder: "Mã phiếu, biển số, nội dung…",
            }}
            filters={
              <FilterChips
                items={statusChips}
                value={statusFilter}
                onChange={(k) => setStatusFilter(k as StatusFilter)}
              />
            }
            action={
              <button type="button" className="sf-pill-primary" onClick={openCreate}>
                <Plus className="h-[17px] w-[17px]" />
                Tạo phiếu
              </button>
            }
          />
        }
      >
        <DataTable
          grid="1fr 1.1fr 1.4fr 1.1fr 1fr"
          columns={["Mã phiếu", "Xe", "Nội dung công việc", "Lịch & chi phí", "Trạng thái"]}
          loading={loading}
          empty={{
            icon: Wrench,
            title: "Không có phiếu bảo trì",
            description: "Thử đổi từ khóa tìm kiếm hoặc bỏ bớt bộ lọc đang áp dụng.",
          }}
          rows={filtered.map((item) => {
            const vehicle = vehicleById.get(String(item.vehicleId));
            const isActive = ACTIVE_STATUSES.includes(item.status);
            const days = daysFromNow(item.scheduledDate);
            const overdue = isActive && !item.completedDate && days != null && days < 0;

            const scheduleText = item.completedDate
              ? `Hoàn tất ${item.completedDate}`
              : item.scheduledDate
                ? `Dự kiến ${item.scheduledDate}`
                : "Chưa xếp lịch";

            return {
              key: String(item.id),
              onClick: () => openEdit(item),
              cells: [
                <CellText
                  key="code"
                  mono
                  strong
                  text={item.maintenanceCode}
                  sub={TYPE_LABELS[item.type]}
                />,
                <CellText
                  key="vehicle"
                  mono
                  text={item.vehiclePlateNumber}
                  sub={vehicle ? `${vehicle.brand} ${vehicle.model}` : undefined}
                />,
                <div key="work" className="min-w-0">
                  <div className="truncate text-[13.5px] font-semibold text-sf-text">
                    {item.title}
                  </div>
                  <div className="mt-1.5 flex items-center gap-1.5">
                    <Badge tone={PRIORITY_TONE[item.priority]} size="sm">
                      {PRIORITY_LABELS[item.priority]}
                    </Badge>
                    {item.description && (
                      <span className="truncate text-[11.5px] text-sf-text-muted">
                        {item.description}
                      </span>
                    )}
                  </div>
                </div>,
                <CellText
                  key="schedule"
                  mono
                  text={scheduleText}
                  sub={`${money(item.cost)}${overdue ? " · quá hạn" : ""}`}
                  color={overdue ? "var(--sf-danger)" : undefined}
                />,
                <Badge key="status" tone={toneOf(STATUS_KEY[item.status])} dot size="sm">
                  {STATUS_LABELS[item.status].toUpperCase()}
                </Badge>,
              ],
            };
          })}
        />
      </TableCard>

      <Modal
        open={editorOpen}
        onClose={() => !saving && setEditorOpen(false)}
        title={editing ? `Cập nhật ${editing.maintenanceCode}` : "Tạo phiếu bảo trì"}
        subtitle="Theo dõi công việc, lịch dự kiến, chi phí và trạng thái xử lý."
        footer={<><Button variant="outline" size="sm" disabled={saving} onClick={() => setEditorOpen(false)}>Hủy</Button><Button size="sm" loading={saving} onClick={() => void saveOrder()}>Lưu phiếu</Button></>}
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <MaintenanceSelect label="Phương tiện *" value={form.vehicleId} onChange={(value) => setForm((old) => ({ ...old, vehicleId: value }))} options={vehicles.map((vehicle) => [vehicle.id, vehicle.plate])} />
          <MaintenanceSelect label="Loại công việc" value={form.type} onChange={(value) => setForm((old) => ({ ...old, type: value as MaintenanceOrder["type"] }))} options={Object.entries(TYPE_LABELS)} />
          <MaintenanceField className="sm:col-span-2" label="Nội dung công việc *" value={form.title} onChange={(value) => setForm((old) => ({ ...old, title: value }))} />
          <MaintenanceField className="sm:col-span-2" label="Mô tả" value={form.description} onChange={(value) => setForm((old) => ({ ...old, description: value }))} />
          <MaintenanceField label="Ngày dự kiến" type="date" value={form.scheduledDate} onChange={(value) => setForm((old) => ({ ...old, scheduledDate: value }))} />
          <MaintenanceField label="Chi phí (VND)" type="number" value={form.cost} onChange={(value) => setForm((old) => ({ ...old, cost: value }))} />
          <MaintenanceSelect label="Ưu tiên" value={form.priority} onChange={(value) => setForm((old) => ({ ...old, priority: value as MaintenanceOrder["priority"] }))} options={Object.entries(PRIORITY_LABELS)} />
          <MaintenanceSelect label="Trạng thái" value={form.status} onChange={(value) => setForm((old) => ({ ...old, status: value as MaintenanceOrder["status"] }))} options={Object.entries(STATUS_LABELS)} />
          {form.status === "COMPLETED" && <MaintenanceField label="Ngày hoàn thành" type="date" value={form.completedDate} onChange={(value) => setForm((old) => ({ ...old, completedDate: value }))} />}
          <MaintenanceField className="sm:col-span-2" label="Ghi chú" value={form.note} onChange={(value) => setForm((old) => ({ ...old, note: value }))} />
        </div>
      </Modal>
    </div>
  );
}

function MaintenanceField({ label, value, onChange, type = "text", className = "" }: { label: string; value: string; onChange: (value: string) => void; type?: string; className?: string }) {
  return <label className={`space-y-1.5 ${className}`}><span className="text-xs font-bold text-sf-text-secondary">{label}</span><input className="sf-input w-full" type={type} min={type === "number" ? 0 : undefined} value={value} onChange={(event) => onChange(event.target.value)} /></label>;
}

function MaintenanceSelect({ label, value, onChange, options }: { label: string; value: string; onChange: (value: string) => void; options: [string, string][] }) {
  return <label className="space-y-1.5"><span className="text-xs font-bold text-sf-text-secondary">{label}</span><select className="sf-input w-full" value={value} onChange={(event) => onChange(event.target.value)}><option value="">Chọn</option>{options.map(([optionValue, optionLabel]) => <option key={optionValue} value={optionValue}>{optionLabel}</option>)}</select></label>;
}
