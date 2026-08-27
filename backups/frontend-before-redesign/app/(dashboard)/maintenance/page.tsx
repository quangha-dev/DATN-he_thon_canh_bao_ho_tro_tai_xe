"use client";

import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  CalendarClock,
  CheckCircle2,
  CircleDollarSign,
  Pencil,
  Plus,
  Wrench,
} from "lucide-react";
import { MaintenanceOrder, MaintenanceOrderInput, safeFleetApi } from "@/lib/safeFleetApi";
import { Vehicle } from "@/types";
import { useToast } from "@/context/ToastContext";
import {
  Badge,
  Button,
  Card,
  EmptyState,
  IconButton,
  Modal,
  SearchInput,
  Segmented,
  SkeletonRows,
  Stagger,
  StatCard,
  StatSkeletonGrid,
  StatusLabel,
  Table,
  TableShell,
  Td,
  Toolbar,
  Tr,
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

const STATUS_KEYS = ["ALL", ...(Object.keys(STATUS_LABELS) as MaintenanceOrder["status"][])] as const;
type StatusKey = (typeof STATUS_KEYS)[number];

function money(value?: number | null) {
  if (value == null) return "—";
  return new Intl.NumberFormat("vi-VN", {
    style: "currency",
    currency: "VND",
    maximumFractionDigits: 0,
  }).format(value);
}

export default function MaintenancePage() {
  const { showToast } = useToast();
  const [orders, setOrders] = useState<MaintenanceOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<StatusKey>("ALL");
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

  const stats = useMemo(
    () => ({
      total: orders.length,
      urgent: orders.filter(
        (o) => o.priority === "URGENT" && o.status !== "COMPLETED" && o.status !== "CANCELLED"
      ).length,
      active: orders.filter(
        (o) => o.status === "OPEN" || o.status === "SCHEDULED" || o.status === "IN_PROGRESS"
      ).length,
      completed: orders.filter((o) => o.status === "COMPLETED").length,
      cost: orders.reduce((sum, o) => sum + (o.cost ?? 0), 0),
    }),
    [orders]
  );

  const filtered = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    return orders.filter((item) => {
      if (status !== "ALL" && item.status !== status) return false;
      if (!keyword) return true;
      return [item.maintenanceCode, item.vehiclePlateNumber, item.title, item.assignedToName]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(keyword));
    });
  }, [orders, query, status]);

  return (
    <div className="space-y-5">
      <Stagger className="grid grid-cols-2 gap-3.5 lg:grid-cols-5">
        {loading && orders.length === 0 ? (
          <StatSkeletonGrid count={5} />
        ) : (
          <>
            <StatCard label="Tổng phiếu" value={stats.total} icon={Wrench} tone="primary" />
            <StatCard
              label="Đang xử lý"
              value={stats.active}
              icon={CalendarClock}
              tone="primary"
            />
            <StatCard
              label="Khẩn cấp"
              value={stats.urgent}
              icon={AlertTriangle}
              tone="danger"
              pulse
            />
            <StatCard
              label="Hoàn thành"
              value={stats.completed}
              icon={CheckCircle2}
              tone="success"
              onClick={() => setStatus(status === "COMPLETED" ? "ALL" : "COMPLETED")}
              active={status === "COMPLETED"}
            />
            <Card padding="sm" className="flex flex-col justify-center">
              <p className="sf-eyebrow flex items-center gap-1.5">
                <CircleDollarSign className="h-3.5 w-3.5" style={{ color: "var(--sf-accent)" }} />
                Tổng chi phí
              </p>
              <p
                className="sf-metric mt-2 text-[20px]"
                style={{ color: "var(--sf-accent-hover)" }}
              >
                {money(stats.cost)}
              </p>
            </Card>
          </>
        )}
      </Stagger>

      <Toolbar>
        <SearchInput
          value={query}
          onChange={setQuery}
          placeholder="Tìm mã phiếu, biển số, nội dung…"
          className="sm:max-w-sm"
        />
        <div className="flex flex-wrap items-center gap-2">
          <Segmented
            value={status}
            onChange={setStatus}
            options={STATUS_KEYS.map((s) => ({
              value: s,
              label: s === "ALL" ? "Tất cả" : STATUS_LABELS[s as MaintenanceOrder["status"]],
            }))}
          />
          <Button icon={Plus} size="sm" onClick={openCreate}>Tạo phiếu</Button>
        </div>
      </Toolbar>

      <TableShell loading={loading}>
        <Table
          head={["Phiếu / Phương tiện", "Công việc", "Lịch", "Phụ trách", "Chi phí", "Trạng thái", ""]}
        >
          {loading && orders.length === 0 ? (
            <SkeletonRows rows={6} cols={6} />
          ) : filtered.length === 0 ? (
            <tr>
              <Td colSpan={7}>
                <EmptyState
                  icon={Wrench}
                  title="Không có phiếu bảo trì"
                  description="Thử đổi từ khóa tìm kiếm hoặc chọn trạng thái khác."
                />
              </Td>
            </tr>
          ) : (
            filtered.map((item) => (
              <Tr key={item.id}>
                <Td>
                  <span className="block text-[13px] font-extrabold text-sf-text">
                    {item.maintenanceCode}
                  </span>
                  <span className="block text-[12.5px] font-semibold text-sf-text-muted">
                    {item.vehiclePlateNumber}
                  </span>
                </Td>
                <Td className="max-w-sm">
                  <span className="block truncate text-[12.5px] font-bold text-sf-text-secondary">
                    {item.title}
                  </span>
                  <span className="mt-1 flex items-center gap-1.5">
                    <span className="text-[12px] text-sf-text-muted">
                      {TYPE_LABELS[item.type]}
                    </span>
                    <Badge tone={PRIORITY_TONE[item.priority]} size="sm">
                      {PRIORITY_LABELS[item.priority]}
                    </Badge>
                  </span>
                </Td>
                <Td>
                  {item.completedDate
                    ? `Hoàn tất ${item.completedDate}`
                    : item.scheduledDate
                      ? `Dự kiến ${item.scheduledDate}`
                      : "Chưa xếp lịch"}
                </Td>
                <Td>{item.assignedToName || <span className="italic text-sf-text-muted">Chưa phân công</span>}</Td>
                <Td className="sf-tnum font-bold">{money(item.cost)}</Td>
                <Td>
                  <StatusLabel
                    status={STATUS_KEY[item.status]}
                    label={STATUS_LABELS[item.status]}
                    pulse={item.status === "IN_PROGRESS"}
                  />
                </Td>
                <Td align="center">
                  <IconButton icon={Pencil} label="Chỉnh sửa phiếu" size="sm" tone="primary" onClick={() => openEdit(item)} />
                </Td>
              </Tr>
            ))
          )}
        </Table>
      </TableShell>

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
