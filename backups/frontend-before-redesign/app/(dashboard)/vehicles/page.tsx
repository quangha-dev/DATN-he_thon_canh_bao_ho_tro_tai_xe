"use client";

import { useEffect, useState, useMemo } from "react";
import { Driver, Vehicle } from "@/types";
import { safeFleetApi, VehicleMutationInput } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { VEHICLE_STATUS_LABELS } from "@/lib/utils";
import {
  Badge,
  Button,
  Drawer,
  EmptyState,
  IconButton,
  InfoRow,
  Modal,
  SearchInput,
  Segmented,
  Select,
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
  toneOf,
} from "@/components/ui";
import {
  Truck,
  Plus,
  Eye,
  CircleCheck,
  Wrench,
  WifiOff,
  CalendarClock,
  AlertTriangle,
  Pencil,
  Ban,
} from "lucide-react";

const STATUS_FILTERS = ["all", "running", "idle", "maintenance", "offline"] as const;
type StatusFilter = (typeof STATUS_FILTERS)[number];

const EMPTY_FORM = {
  plateNumber: "",
  vehicleType: "TRUCK",
  brand: "",
  model: "",
  year: "",
  loadCapacity: "",
  seatCount: "",
  fuelType: "DIESEL",
  status: "AVAILABLE",
  currentDriverId: "",
  inspectionExpiredAt: "",
  insuranceExpiredAt: "",
};

export default function VehiclesPage() {
  const { showToast } = useToast();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [typeFilter, setTypeFilter] = useState("all");
  const [selected, setSelected] = useState<Vehicle | null>(null);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [editorOpen, setEditorOpen] = useState(false);
  const [editing, setEditing] = useState<Vehicle | null>(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const [data, driverData] = await Promise.all([
          safeFleetApi.vehicles(),
          safeFleetApi.drivers().catch(() => []),
        ]);
        if (!cancelled) {
          setVehicles(data);
          setDrivers(driverData);
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được danh sách xe.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [showToast]);

  const stats = useMemo(
    () => ({
      total: vehicles.length,
      running: vehicles.filter((v) => v.status === "running").length,
      idle: vehicles.filter((v) => v.status === "idle").length,
      maintenance: vehicles.filter((v) => v.status === "maintenance").length,
      offline: vehicles.filter((v) => v.status === "offline").length,
    }),
    [vehicles]
  );

  const vehicleTypes = useMemo(() => Array.from(new Set(vehicles.map((v) => v.type))), [vehicles]);

  const openCreate = () => {
    setEditing(null);
    setForm(EMPTY_FORM);
    setEditorOpen(true);
  };

  const openEdit = (vehicle: Vehicle) => {
    setEditing(vehicle);
    setForm({
      plateNumber: vehicle.plate,
      vehicleType: vehicle.backendType || "TRUCK",
      brand: vehicle.brand || "",
      model: vehicle.model || "",
      year: vehicle.year ? String(vehicle.year) : "",
      loadCapacity: vehicle.capacity ? String(vehicle.capacity) : "",
      seatCount: vehicle.seatCount ? String(vehicle.seatCount) : "",
      fuelType: vehicle.fuelType || "DIESEL",
      status: vehicle.backendStatus || "AVAILABLE",
      currentDriverId: vehicle.currentDriverId || "",
      inspectionExpiredAt: vehicle.registrationExpiry || "",
      insuranceExpiredAt: vehicle.insuranceExpiry || "",
    });
    setEditorOpen(true);
  };

  const mutationPayload = (): VehicleMutationInput => ({
    vehicleType: form.vehicleType,
    brand: form.brand.trim() || undefined,
    model: form.model.trim() || undefined,
    year: form.year ? Number(form.year) : null,
    loadCapacity: form.loadCapacity ? Number(form.loadCapacity) : null,
    seatCount: form.seatCount ? Number(form.seatCount) : null,
    fuelType: form.fuelType || null,
    status: form.status,
    currentDriverId: form.currentDriverId ? Number(form.currentDriverId) : null,
    gpsDeviceId: editing?.gpsDeviceId ? Number(editing.gpsDeviceId) : null,
    cameraDeviceId: editing?.cameraDeviceId ? Number(editing.cameraDeviceId) : null,
    inspectionExpiredAt: form.inspectionExpiredAt || null,
    insuranceExpiredAt: form.insuranceExpiredAt || null,
  });

  const saveVehicle = async () => {
    setSaving(true);
    try {
      const saved = editing
        ? await safeFleetApi.updateVehicle(editing.id, mutationPayload())
        : await safeFleetApi.createVehicle({ ...mutationPayload(), plateNumber: form.plateNumber.trim().toUpperCase() });
      setVehicles((prev) => editing
        ? prev.map((item) => item.id === saved.id ? saved : item)
        : [saved, ...prev]);
      setSelected(saved);
      setEditorOpen(false);
      showToast(editing ? "Đã cập nhật phương tiện." : "Đã thêm phương tiện.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể lưu phương tiện.", "error");
    } finally {
      setSaving(false);
    }
  };

  const deactivateVehicle = async (vehicle: Vehicle) => {
    setSaving(true);
    try {
      const saved = await safeFleetApi.updateVehicle(vehicle.id, {
        vehicleType: vehicle.backendType || "TRUCK",
        brand: vehicle.brand || undefined,
        model: vehicle.model || undefined,
        year: vehicle.year || null,
        loadCapacity: vehicle.capacity || null,
        seatCount: vehicle.seatCount || null,
        fuelType: vehicle.fuelType || null,
        status: "INACTIVE",
        currentDriverId: vehicle.currentDriverId ? Number(vehicle.currentDriverId) : null,
        gpsDeviceId: vehicle.gpsDeviceId ? Number(vehicle.gpsDeviceId) : null,
        cameraDeviceId: vehicle.cameraDeviceId ? Number(vehicle.cameraDeviceId) : null,
        inspectionExpiredAt: vehicle.registrationExpiry || null,
        insuranceExpiredAt: vehicle.insuranceExpiry || null,
      });
      setVehicles((prev) => prev.map((item) => item.id === saved.id ? saved : item));
      setSelected(null);
      setEditorOpen(false);
      showToast("Đã ngừng sử dụng phương tiện.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể ngừng sử dụng phương tiện.", "error");
    } finally {
      setSaving(false);
    }
  };

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return vehicles.filter((v) => {
      if (statusFilter !== "all" && v.status !== statusFilter) return false;
      if (typeFilter !== "all" && v.type !== typeFilter) return false;
      if (!q) return true;
      return (
        v.plate.toLowerCase().includes(q) ||
        v.brand.toLowerCase().includes(q) ||
        v.model.toLowerCase().includes(q) ||
        (v.currentDriverName?.toLowerCase().includes(q) ?? false)
      );
    });
  }, [vehicles, searchQuery, statusFilter, typeFilter]);

  return (
    <div className="space-y-5">
      {/* ===== Thống kê ===== */}
      <Stagger className="grid grid-cols-2 gap-3.5 lg:grid-cols-5">
        {isLoading && vehicles.length === 0 ? (
          <StatSkeletonGrid count={5} />
        ) : (
          <>
            <StatCard label="Tổng phương tiện" value={stats.total} icon={Truck} tone="primary" />
            <StatCard
              label="Đang hoạt động"
              value={stats.running}
              icon={CircleCheck}
              tone="success"
              onClick={() => setStatusFilter(statusFilter === "running" ? "all" : "running")}
              active={statusFilter === "running"}
            />
            <StatCard
              label="Sẵn sàng"
              value={stats.idle}
              icon={Truck}
              tone="primary"
              onClick={() => setStatusFilter(statusFilter === "idle" ? "all" : "idle")}
              active={statusFilter === "idle"}
            />
            <StatCard
              label="Đang bảo trì"
              value={stats.maintenance}
              icon={Wrench}
              tone="warning"
              onClick={() =>
                setStatusFilter(statusFilter === "maintenance" ? "all" : "maintenance")
              }
              active={statusFilter === "maintenance"}
            />
            <StatCard
              label="Mất kết nối"
              value={stats.offline}
              icon={WifiOff}
              tone="neutral"
              onClick={() => setStatusFilter(statusFilter === "offline" ? "all" : "offline")}
              active={statusFilter === "offline"}
            />
          </>
        )}
      </Stagger>

      {/* ===== Thanh công cụ ===== */}
      <Toolbar>
        <SearchInput
          value={searchQuery}
          onChange={setSearchQuery}
          placeholder="Tìm biển số, hãng xe, tài xế…"
          className="sm:max-w-sm"
        />
        <div className="flex flex-wrap items-center gap-2">
          <Select
            ariaLabel="Lọc theo loại xe"
            value={typeFilter}
            onChange={setTypeFilter}
            options={[
              { value: "all", label: "Tất cả loại xe" },
              ...vehicleTypes.map((t) => ({ value: t, label: t })),
            ]}
          />
          <Segmented
            value={statusFilter}
            onChange={setStatusFilter}
            options={STATUS_FILTERS.map((s) => ({
              value: s,
              label: s === "all" ? "Tất cả" : VEHICLE_STATUS_LABELS[s],
            }))}
          />
          <Button icon={Plus} size="sm" onClick={openCreate}>
            Thêm xe
          </Button>
        </div>
      </Toolbar>

      {/* ===== Bảng ===== */}
      <TableShell loading={isLoading}>
        <Table
          head={[
            "Biển số",
            "Hãng & model",
            "Loại xe",
            "Tài xế hiện tại",
            "Trạng thái",
            "Cảnh báo",
            "Hạn đăng kiểm",
            "",
          ]}
        >
          {isLoading && vehicles.length === 0 ? (
            <SkeletonRows rows={6} cols={8} />
          ) : filtered.length === 0 ? (
            <tr>
              <Td colSpan={8}>
                <EmptyState
                  icon={Truck}
                  title="Không tìm thấy phương tiện"
                  description="Thử đổi từ khóa tìm kiếm hoặc bỏ bớt bộ lọc đang áp dụng."
                />
              </Td>
            </tr>
          ) : (
            filtered.map((vehicle) => (
              <Tr key={vehicle.id} onClick={() => setSelected(vehicle)}>
                <Td>
                  <span className="flex items-center gap-2.5">
                    <span
                      className="grid h-7 w-7 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)]"
                      style={{ background: "var(--sf-primary-soft)", color: "var(--sf-primary)" }}
                    >
                      <Truck className="h-3.5 w-3.5" />
                    </span>
                    <span className="text-[13px] font-extrabold tracking-tight text-sf-text">
                      {vehicle.plate}
                    </span>
                  </span>
                </Td>
                <Td className="font-semibold text-sf-text-secondary">
                  {vehicle.brand} {vehicle.model}
                </Td>
                <Td>{vehicle.type}</Td>
                <Td>
                  {vehicle.currentDriverName ? (
                    <span className="font-semibold text-sf-text-secondary">
                      {vehicle.currentDriverName}
                    </span>
                  ) : (
                    <span className="italic text-sf-text-muted">Chưa giao</span>
                  )}
                </Td>
                <Td>
                  <StatusLabel
                    status={vehicle.status}
                    label={VEHICLE_STATUS_LABELS[vehicle.status]}
                    pulse={vehicle.status === "running"}
                  />
                </Td>
                <Td align="center">
                  {vehicle.totalAlerts > 0 ? (
                    <Badge tone="danger" size="sm" icon={AlertTriangle}>
                      {vehicle.totalAlerts}
                    </Badge>
                  ) : (
                    <span className="text-sf-text-muted">—</span>
                  )}
                </Td>
                <Td>
                  <span className="flex items-center gap-1.5 text-sf-text-secondary">
                    <CalendarClock className="h-3.5 w-3.5 text-sf-text-muted" />
                    {vehicle.registrationExpiry || "—"}
                  </span>
                </Td>
                <Td align="center">
                  <IconButton
                    icon={Eye}
                    label="Xem chi tiết"
                    size="sm"
                    tone="primary"
                    onClick={(e) => {
                      e.stopPropagation();
                      setSelected(vehicle);
                    }}
                  />
                </Td>
              </Tr>
            ))
          )}
        </Table>
      </TableShell>

      {/* ===== Panel chi tiết ===== */}
      <Drawer
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        title={selected?.plate ?? ""}
        subtitle={selected ? `${selected.brand} ${selected.model} · ${selected.type}` : undefined}
        footer={
          <>
            {selected && <Button variant="danger" size="sm" icon={Ban} onClick={() => void deactivateVehicle(selected)}>Ngừng sử dụng</Button>}
            {selected && <Button size="sm" icon={Pencil} onClick={() => openEdit(selected)}>Chỉnh sửa</Button>}
            <Button variant="outline" size="sm" onClick={() => setSelected(null)}>Đóng</Button>
          </>
        }
      >
        {selected && (
          <div className="space-y-4">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={toneOf(selected.status)}>
                {VEHICLE_STATUS_LABELS[selected.status]}
              </Badge>
              {selected.totalAlerts > 0 && (
                <Badge tone="danger" icon={AlertTriangle}>
                  {selected.totalAlerts} cảnh báo
                </Badge>
              )}
            </div>

            <div>
              <InfoRow label="Biển số" value={selected.plate} />
              <InfoRow label="Hãng / model" value={`${selected.brand} ${selected.model}`} />
              <InfoRow label="Loại xe" value={selected.type} />
              <InfoRow label="Tài xế" value={selected.currentDriverName ?? "Chưa giao"} />
              <InfoRow label="Hạn đăng kiểm" value={selected.registrationExpiry || "—"} />
              <InfoRow
                label="Vị trí"
                value={
                  <span className="sf-tnum">
                    {selected.lat !== null && selected.lng !== null
                      ? `${selected.lat.toFixed(5)}, ${selected.lng.toFixed(5)}`
                      : "Chưa có dữ liệu GPS"}
                  </span>
                }
              />
            </div>
          </div>
        )}
      </Drawer>

      <Modal
        open={editorOpen}
        onClose={() => !saving && setEditorOpen(false)}
        title={editing ? `Chỉnh sửa ${editing.plate}` : "Thêm phương tiện"}
        subtitle="Thông tin hồ sơ, phân công tài xế và hạn giấy tờ."
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setEditorOpen(false)} disabled={saving}>Hủy</Button>
            <Button loading={saving} disabled={!form.plateNumber || !form.vehicleType} onClick={() => void saveVehicle()}>Lưu phương tiện</Button>
          </>
        }
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <VehicleField label="Biển số" required disabled={Boolean(editing)} value={form.plateNumber} onChange={(value) => setForm((prev) => ({ ...prev, plateNumber: value }))} />
          <VehicleSelect label="Loại xe" value={form.vehicleType} onChange={(value) => setForm((prev) => ({ ...prev, vehicleType: value }))} options={[
            ["TRUCK", "Xe tải"], ["VAN", "Xe van"], ["BUS", "Xe khách"], ["CAR", "Xe con"], ["PICKUP", "Xe bán tải"], ["MOTORBIKE", "Xe máy"],
          ]} />
          <VehicleField label="Hãng" value={form.brand} onChange={(value) => setForm((prev) => ({ ...prev, brand: value }))} />
          <VehicleField label="Model" value={form.model} onChange={(value) => setForm((prev) => ({ ...prev, model: value }))} />
          <VehicleField label="Năm sản xuất" type="number" value={form.year} onChange={(value) => setForm((prev) => ({ ...prev, year: value }))} />
          <VehicleField label="Tải trọng" type="number" value={form.loadCapacity} onChange={(value) => setForm((prev) => ({ ...prev, loadCapacity: value }))} />
          <VehicleField label="Số chỗ" type="number" value={form.seatCount} onChange={(value) => setForm((prev) => ({ ...prev, seatCount: value }))} />
          <VehicleSelect label="Nhiên liệu" value={form.fuelType} onChange={(value) => setForm((prev) => ({ ...prev, fuelType: value }))} options={[["DIESEL", "Dầu"], ["GASOLINE", "Xăng"], ["ELECTRIC", "Điện"], ["HYBRID", "Hybrid"]]} />
          <VehicleSelect label="Trạng thái" value={form.status} onChange={(value) => setForm((prev) => ({ ...prev, status: value }))} options={[["AVAILABLE", "Sẵn sàng"], ["RESTING", "Đang nghỉ"], ["MAINTENANCE", "Bảo trì"], ["OFFLINE", "Mất kết nối"], ["INACTIVE", "Ngừng sử dụng"]]} />
          <VehicleSelect label="Tài xế phụ trách" value={form.currentDriverId} onChange={(value) => setForm((prev) => ({ ...prev, currentDriverId: value }))} options={[["", "Chưa giao"], ...drivers.map((driver) => [driver.id, `${driver.fullName} · ${driver.licenseClass}`])]} />
          <VehicleField label="Hạn đăng kiểm" type="date" value={form.inspectionExpiredAt} onChange={(value) => setForm((prev) => ({ ...prev, inspectionExpiredAt: value }))} />
          <VehicleField label="Hạn bảo hiểm" type="date" value={form.insuranceExpiredAt} onChange={(value) => setForm((prev) => ({ ...prev, insuranceExpiredAt: value }))} />
        </div>
      </Modal>
    </div>
  );
}

function VehicleField({ label, value, onChange, type = "text", required = false, disabled = false }: { label: string; value: string; onChange: (value: string) => void; type?: string; required?: boolean; disabled?: boolean }) {
  return <label className="space-y-1.5 text-sm font-semibold text-sf-text-secondary">{label}{required && " *"}<input className="sf-input" type={type} value={value} required={required} disabled={disabled} onChange={(event) => onChange(event.target.value)} /></label>;
}

function VehicleSelect({ label, value, onChange, options }: { label: string; value: string; onChange: (value: string) => void; options: string[][] }) {
  return <label className="space-y-1.5 text-sm font-semibold text-sf-text-secondary">{label}<select className="sf-input sf-select" value={value} onChange={(event) => onChange(event.target.value)}>{options.map(([optionValue, optionLabel]) => <option key={optionValue} value={optionValue}>{optionLabel}</option>)}</select></label>;
}
