"use client";

import { useEffect, useState, useMemo } from "react";
import { Driver, Vehicle, VehicleStatus } from "@/types";
import { safeFleetApi, VehicleMutationInput } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { cn, VEHICLE_STATUS_LABELS } from "@/lib/utils";
import {
  Badge,
  Button,
  CellText,
  DataTable,
  Drawer,
  FilterChips,
  InfoRow,
  Modal,
  Select,
  StatCard,
  TableCard,
  TableToolbar,
  toneOf,
  type FilterChip,
} from "@/components/ui";
import {
  AlertTriangle,
  Ban,
  CalendarClock,
  CircleCheck,
  Pencil,
  Plus,
  Truck,
  WifiOff,
} from "lucide-react";

/** "all" hoặc một trong bốn trạng thái vận hành của backend */
type StatusFilter = "all" | VehicleStatus;
/** "all" hoặc một trong ba trạng thái tín hiệu GPS của backend */
type GpsFilter = "all" | Vehicle["gpsStatus"];

/** Bản thiết kế không vẽ nhãn GPS — tự đặt nhãn tiếng Việt cho ba giá trị thật của backend */
const GPS_STATUS_LABELS: Record<Vehicle["gpsStatus"], string> = {
  online: "Online",
  offline: "Mất kết nối",
  weak: "Tín hiệu yếu",
};

const EMPTY_FORM = {
  plateNumber: "",
  vehicleType: "TRUCK",
  brand: "",
  model: "",
  year: "",
  loadCapacity: "",
  heightMeters: "",
  widthMeters: "",
  lengthMeters: "",
  grossWeightTons: "",
  axleLoadTons: "",
  axleCount: "",
  topSpeedKph: "",
  hazardousGoods: "false",
  seatCount: "",
  fuelType: "DIESEL",
  status: "AVAILABLE",
  currentDriverId: "",
  inspectionExpiredAt: "",
  insuranceExpiredAt: "",
};

const DAY_MS = 24 * 60 * 60 * 1000;

/** Số ngày còn lại tới hạn (âm = đã quá hạn); null nếu không có/không đọc được ngày */
function daysUntil(dateStr?: string | null): number | null {
  if (!dateStr) return null;
  const date = new Date(dateStr);
  if (Number.isNaN(date.getTime())) return null;
  return Math.round((date.getTime() - Date.now()) / DAY_MS);
}

/** Đăng kiểm hoặc bảo hiểm còn ≤ 60 ngày (hoặc đã quá hạn) */
function isDocExpiringSoon(vehicle: Vehicle): boolean {
  const reg = daysUntil(vehicle.registrationExpiry);
  const ins = daysUntil(vehicle.insuranceExpiry);
  return (reg !== null && reg <= 60) || (ins !== null && ins <= 60);
}

function formatMonthYear(dateStr?: string | null): string {
  if (!dateStr) return "—";
  const date = new Date(dateStr);
  if (Number.isNaN(date.getTime())) return dateStr;
  return `${String(date.getMonth() + 1).padStart(2, "0")}/${date.getFullYear()}`;
}

export default function VehiclesPage() {
  const { showToast } = useToast();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [typeFilter, setTypeFilter] = useState("all");
  const [gpsFilter, setGpsFilter] = useState<GpsFilter>("all");
  const [docFilter, setDocFilter] = useState(false);
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
      docsExpiring: vehicles.filter(isDocExpiringSoon).length,
      gpsOffline: vehicles.filter((v) => v.gpsStatus === "offline").length,
    }),
    [vehicles]
  );

  const vehicleTypes = useMemo(() => Array.from(new Set(vehicles.map((v) => v.type))), [vehicles]);

  /** Chỉ liệt kê các mức tín hiệu GPS thật sự xuất hiện trong dữ liệu */
  const gpsOptions = useMemo(() => {
    const present = new Set(vehicles.map((v) => v.gpsStatus));
    return (Object.keys(GPS_STATUS_LABELS) as Vehicle["gpsStatus"][])
      .filter((key) => present.has(key))
      .map((key) => ({ value: key, label: GPS_STATUS_LABELS[key] }));
  }, [vehicles]);

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
      heightMeters: vehicle.heightMeters ? String(vehicle.heightMeters) : "",
      widthMeters: vehicle.widthMeters ? String(vehicle.widthMeters) : "",
      lengthMeters: vehicle.lengthMeters ? String(vehicle.lengthMeters) : "",
      grossWeightTons: vehicle.grossWeightTons ? String(vehicle.grossWeightTons) : "",
      axleLoadTons: vehicle.axleLoadTons ? String(vehicle.axleLoadTons) : "",
      axleCount: vehicle.axleCount ? String(vehicle.axleCount) : "",
      topSpeedKph: vehicle.topSpeedKph ? String(vehicle.topSpeedKph) : "",
      hazardousGoods: vehicle.hazardousGoods ? "true" : "false",
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
    heightMeters: form.heightMeters ? Number(form.heightMeters) : null,
    widthMeters: form.widthMeters ? Number(form.widthMeters) : null,
    lengthMeters: form.lengthMeters ? Number(form.lengthMeters) : null,
    grossWeightTons: form.grossWeightTons ? Number(form.grossWeightTons) : null,
    axleLoadTons: form.axleLoadTons ? Number(form.axleLoadTons) : null,
    axleCount: form.axleCount ? Number(form.axleCount) : null,
    topSpeedKph: form.topSpeedKph ? Number(form.topSpeedKph) : null,
    hazardousGoods: form.hazardousGoods === "true",
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
        heightMeters: vehicle.heightMeters || null,
        widthMeters: vehicle.widthMeters || null,
        lengthMeters: vehicle.lengthMeters || null,
        grossWeightTons: vehicle.grossWeightTons || null,
        axleLoadTons: vehicle.axleLoadTons || null,
        axleCount: vehicle.axleCount || null,
        topSpeedKph: vehicle.topSpeedKph || null,
        hazardousGoods: vehicle.hazardousGoods || false,
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
      if (gpsFilter !== "all" && v.gpsStatus !== gpsFilter) return false;
      if (docFilter && !isDocExpiringSoon(v)) return false;
      if (!q) return true;
      return (
        v.plate.toLowerCase().includes(q) ||
        v.brand.toLowerCase().includes(q) ||
        v.model.toLowerCase().includes(q) ||
        (v.currentDriverName?.toLowerCase().includes(q) ?? false)
      );
    });
  }, [vehicles, searchQuery, statusFilter, typeFilter, gpsFilter, docFilter]);

  /* Chip lọc dựng theo đúng bốn trạng thái vận hành của backend — bản thiết kế
     mẫu vẽ đúng bốn nhãn này nên không thiếu, chỉ đổi sang tính động theo dữ liệu. */
  const statusChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "all", label: "Tất cả", count: vehicles.length }];
    (Object.keys(VEHICLE_STATUS_LABELS) as VehicleStatus[]).forEach((key) => {
      const count = vehicles.filter((v) => v.status === key).length;
      if (count > 0) chips.push({ key, label: VEHICLE_STATUS_LABELS[key], count });
    });
    return chips;
  }, [vehicles]);

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Tổng phương tiện"
          value={stats.total}
          icon={Truck}
          delta={`${vehicleTypes.length} loại xe`}
          delay={0}
        />
        <StatCard
          label="Đang hoạt động"
          value={stats.running}
          icon={CircleCheck}
          tone="primary"
          delta={stats.total ? `${Math.round((stats.running / stats.total) * 100)}% đội` : ""}
          onClick={() => setStatusFilter(statusFilter === "running" ? "all" : "running")}
          active={statusFilter === "running"}
          delay={70}
        />
        <StatCard
          label="Giấy tờ sắp hết hạn"
          value={stats.docsExpiring}
          icon={CalendarClock}
          tone="warning"
          deltaTone="warning"
          delta="trong 60 ngày"
          onClick={() => setDocFilter((v) => !v)}
          active={docFilter}
          delay={140}
        />
        <StatCard
          label="Mất kết nối"
          value={stats.gpsOffline}
          icon={WifiOff}
          tone="danger"
          deltaTone="danger"
          delta="GPS ngừng phản hồi"
          onClick={() => setGpsFilter(gpsFilter === "offline" ? "all" : "offline")}
          active={gpsFilter === "offline"}
          delay={210}
        />
      </div>

      {/* ===== Thẻ bảng: thanh công cụ + bảng dạng thẻ ===== */}
      <TableCard
        toolbar={
          <TableToolbar
            search={{
              value: searchQuery,
              onChange: setSearchQuery,
              placeholder: "Biển số, hãng, model, tài xế…",
            }}
            filters={
              <FilterChips items={statusChips} value={statusFilter} onChange={(k) => setStatusFilter(k as StatusFilter)} />
            }
            extra={
              <>
                <Select
                  ariaLabel="Lọc theo loại xe"
                  value={typeFilter}
                  onChange={setTypeFilter}
                  options={[
                    { value: "all", label: "Tất cả loại xe" },
                    ...vehicleTypes.map((t) => ({ value: t, label: t })),
                  ]}
                  className="min-w-[10rem]"
                />
                <Select
                  ariaLabel="Lọc theo tín hiệu GPS"
                  value={gpsFilter}
                  onChange={(v) => setGpsFilter(v as GpsFilter)}
                  options={[{ value: "all", label: "Tất cả GPS" }, ...gpsOptions]}
                  className="min-w-[9.5rem]"
                />
              </>
            }
            action={
              <button type="button" className="sf-pill-primary" onClick={openCreate}>
                <Plus className="h-[17px] w-[17px]" />
                Thêm xe
              </button>
            }
          />
        }
      >
        <DataTable
          grid="1.1fr 1.2fr 1.2fr 1fr 1fr"
          columns={["Biển số", "Loại & tải trọng", "Tài xế phụ trách", "Giấy tờ", "Trạng thái"]}
          loading={isLoading}
          empty={{
            icon: Truck,
            title: "Không tìm thấy phương tiện",
            description: "Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng.",
          }}
          rows={filtered.map((vehicle) => {
            const expiringSoon = isDocExpiringSoon(vehicle);
            return {
              key: vehicle.id,
              onClick: () => setSelected(vehicle),
              cells: [
                <CellText
                  key="plate"
                  strong
                  mono
                  icon={Truck}
                  text={vehicle.plate}
                  sub={`${vehicle.brand} ${vehicle.model}${vehicle.year ? ` · ${vehicle.year}` : ""}`}
                />,
                <CellText
                  key="type"
                  text={`${vehicle.type}${vehicle.capacity ? ` · ${vehicle.capacity} tấn` : ""}`}
                  sub={`${vehicle.totalKm.toLocaleString("vi-VN")} km${vehicle.totalTrips ? ` · ${vehicle.totalTrips} chuyến` : ""}`}
                />,
                <CellText
                  key="driver"
                  text={vehicle.currentDriverName || "—"}
                  sub={vehicle.currentDriverName ? "gắn cố định" : "chưa gán"}
                />,
                <CellText
                  key="docs"
                  mono
                  text={`ĐK ${formatMonthYear(vehicle.registrationExpiry)}`}
                  sub={expiringSoon ? "sắp hết hạn" : `BH ${formatMonthYear(vehicle.insuranceExpiry)}`}
                  color={expiringSoon ? "var(--sf-warning)" : undefined}
                />,
                <div key="status" className="flex flex-col items-start gap-1.5">
                  <Badge tone={toneOf(vehicle.status)} dot size="sm">
                    {(VEHICLE_STATUS_LABELS[vehicle.status] || vehicle.status).toUpperCase()}
                  </Badge>
                  {vehicle.gpsStatus !== "online" && (
                    <span
                      className={cn(
                        "inline-flex items-center gap-1 text-[11px]",
                        vehicle.gpsStatus === "offline" ? "text-[var(--sf-danger)]" : "text-[var(--sf-warning)]"
                      )}
                    >
                      <WifiOff className="h-3 w-3" />
                      {GPS_STATUS_LABELS[vehicle.gpsStatus]}
                    </span>
                  )}
                </div>,
              ],
            };
          })}
        />
      </TableCard>

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
              <Badge tone={selected.gpsStatus === "online" ? "success" : selected.gpsStatus === "weak" ? "warning" : "danger"}>
                GPS {GPS_STATUS_LABELS[selected.gpsStatus]}
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
              <InfoRow label="Hạn bảo hiểm" value={selected.insuranceExpiry || "—"} />
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
        subtitle="Kích thước và tổng tải được dùng để loại các cầu, hầm và đường không an toàn."
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
          <VehicleField label="Chiều cao (m)" type="number" value={form.heightMeters} onChange={(value) => setForm((prev) => ({ ...prev, heightMeters: value }))} />
          <VehicleField label="Chiều rộng (m)" type="number" value={form.widthMeters} onChange={(value) => setForm((prev) => ({ ...prev, widthMeters: value }))} />
          <VehicleField label="Chiều dài (m)" type="number" value={form.lengthMeters} onChange={(value) => setForm((prev) => ({ ...prev, lengthMeters: value }))} />
          <VehicleField label="Tổng tải (tấn)" type="number" value={form.grossWeightTons} onChange={(value) => setForm((prev) => ({ ...prev, grossWeightTons: value }))} />
          <VehicleField label="Tải mỗi trục (tấn)" type="number" value={form.axleLoadTons} onChange={(value) => setForm((prev) => ({ ...prev, axleLoadTons: value }))} />
          <VehicleField label="Số trục" type="number" value={form.axleCount} onChange={(value) => setForm((prev) => ({ ...prev, axleCount: value }))} />
          <VehicleField label="Tốc độ tối đa (km/h)" type="number" value={form.topSpeedKph} onChange={(value) => setForm((prev) => ({ ...prev, topSpeedKph: value }))} />
          <VehicleSelect label="Hàng nguy hiểm" value={form.hazardousGoods} onChange={(value) => setForm((prev) => ({ ...prev, hazardousGoods: value }))} options={[["false", "Không"], ["true", "Có"]]} />
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
