"use client";

import { useEffect, useState, useMemo } from "react";
import { useRouter } from "next/navigation";
import { Driver, DriverStatus, Trip } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import {
  formatDrivingTime,
  getSafetyScoreInfo,
  DRIVER_STATUS_LABELS,
  DRIVING_LIMITS,
  formatDateTime,
  TRIP_STATUS_LABELS,
} from "@/lib/utils";
import {
  Badge,
  Button,
  CellText,
  DataTable,
  Drawer,
  FilterChips,
  InfoRow,
  Modal,
  ScoreRing,
  Select,
  StatCard,
  TableCard,
  TableToolbar,
  toneOf,
  type FilterChip,
} from "@/components/ui";
import {
  ArrowRight,
  Car,
  CircleCheck,
  Navigation,
  Pencil,
  ShieldAlert,
  UserPlus,
  Users,
  UserX,
} from "lucide-react";

/** "all" hoặc một trong bảy trạng thái tài xế của backend */
type StatusFilter = "all" | DriverStatus;

const SCORE_OPTIONS = [
  { value: "all", label: "Tất cả điểm an toàn" },
  { value: "excellent", label: "Rất tốt (90–100)" },
  { value: "good", label: "Tốt (75–89)" },
  { value: "monitor", label: "Cần theo dõi (60–74)" },
  { value: "high_risk", label: "Rủi ro cao (<60)" },
];

export default function DriversPage() {
  const router = useRouter();
  const { showToast } = useToast();
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [scoreFilter, setScoreFilter] = useState("all");
  const [selected, setSelected] = useState<Driver | null>(null);
  const [driverTrips, setDriverTrips] = useState<Trip[]>([]);
  const [selectedTrip, setSelectedTrip] = useState<Trip | null>(null);
  const [loadingTrips, setLoadingTrips] = useState(false);
  const [editing, setEditing] = useState<Driver | null>(null);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    fullName: "",
    phone: "",
    email: "",
    address: "",
    licenseClass: "",
    licenseExpiredAt: "",
    status: "AVAILABLE",
  });

  const openEdit = (driver: Driver) => {
    setEditing(driver);
    setForm({
      fullName: driver.fullName,
      phone: driver.phone === "Chưa cập nhật" ? "" : driver.phone,
      email: driver.email === "Chưa cập nhật" ? "" : driver.email,
      address: driver.address || "",
      licenseClass: driver.licenseClass,
      licenseExpiredAt: driver.licenseExpiry,
      status: driver.backendStatus || "AVAILABLE",
    });
  };

  const updateDriver = async (statusOverride?: string) => {
    if (!editing) return;
    if (!form.fullName.trim() || !form.phone.trim() || !form.licenseClass.trim() || !form.licenseExpiredAt) {
      showToast("Vui lòng nhập đủ họ tên, số điện thoại, hạng và hạn bằng lái.", "error");
      return;
    }
    setSaving(true);
    try {
      const updated = await safeFleetApi.updateDriver(editing.id, {
        fullName: form.fullName.trim(),
        phone: form.phone.trim(),
        email: form.email.trim() || null,
        address: form.address.trim() || null,
        licenseClass: form.licenseClass.trim(),
        licenseExpiredAt: form.licenseExpiredAt,
        status: statusOverride || form.status,
        currentVehicleId: editing.currentVehicleId ? Number(editing.currentVehicleId) : null,
      });
      setDrivers((items) => items.map((item) => item.id === updated.id ? updated : item));
      setSelected((item) => item?.id === updated.id ? updated : item);
      setEditing(null);
      showToast(statusOverride === "INACTIVE" ? "Đã ngừng hoạt động tài xế." : "Đã cập nhật tài xế.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không cập nhật được tài xế.", "error");
    } finally {
      setSaving(false);
    }
  };

  useEffect(() => {
    if (!selected) {
      setDriverTrips([]);
      setSelectedTrip(null);
      return;
    }
    let cancelled = false;
    setLoadingTrips(true);
    setSelectedTrip(null);
    safeFleetApi
      .driverTrips(selected.id)
      .then((items) => {
        if (!cancelled) setDriverTrips(items);
      })
      .catch((error) => {
        if (!cancelled) {
          showToast(error instanceof Error ? error.message : "Không tải được lịch sử chuyến.", "error");
        }
      })
      .finally(() => {
        if (!cancelled) setLoadingTrips(false);
      });
    return () => {
      cancelled = true;
    };
  }, [selected, showToast]);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.drivers();
        if (!cancelled) setDrivers(data);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "Không tải được danh sách tài xế.";
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
      total: drivers.length,
      driving: drivers.filter((d) => d.status === "driving").length,
      available: drivers.filter((d) => d.status === "available").length,
      resting: drivers.filter((d) => d.status === "resting").length,
      highRisk: drivers.filter((d) => d.safetyScore < 60 || d.status === "high_risk").length,
    }),
    [drivers]
  );

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return drivers.filter((d) => {
      if (statusFilter !== "all" && d.status !== statusFilter) return false;
      if (scoreFilter === "excellent" && d.safetyScore < 90) return false;
      if (scoreFilter === "good" && (d.safetyScore < 75 || d.safetyScore >= 90)) return false;
      if (scoreFilter === "monitor" && (d.safetyScore < 60 || d.safetyScore >= 75)) return false;
      if (scoreFilter === "high_risk" && d.safetyScore >= 60) return false;
      if (!q) return true;
      return (
        d.fullName.toLowerCase().includes(q) ||
        d.phone.includes(q) ||
        d.email.toLowerCase().includes(q) ||
        (d.currentVehiclePlate?.toLowerCase().includes(q) ?? false)
      );
    });
  }, [drivers, searchQuery, statusFilter, scoreFilter]);

  /* Chip lọc dựng theo đúng bảy trạng thái tài xế của backend
     (bản thiết kế chỉ vẽ bốn) — thêm chip "Rủi ro cao" theo điểm an toàn. */
  const statusChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "all", label: "Tất cả", count: drivers.length }];
    (Object.keys(DRIVER_STATUS_LABELS) as DriverStatus[]).forEach((key) => {
      const count = drivers.filter((d) => d.status === key).length;
      if (count > 0) chips.push({ key, label: DRIVER_STATUS_LABELS[key], count });
    });
    return chips;
  }, [drivers]);

  const avgScore = drivers.length
    ? Math.round(drivers.reduce((sum, d) => sum + d.safetyScore, 0) / drivers.length)
    : 0;

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Tổng tài xế"
          value={stats.total}
          icon={Users}
          delta={`${stats.driving} đang lái`}
          delay={0}
        />
        <StatCard
          label="Đang cầm lái"
          value={stats.driving}
          icon={Car}
          tone="primary"
          delta={stats.total ? `${Math.round((stats.driving / stats.total) * 100)}% đội` : ""}
          onClick={() => setStatusFilter(statusFilter === "driving" ? "all" : "driving")}
          active={statusFilter === "driving"}
          delay={70}
        />
        <StatCard
          label="Rủi ro cao"
          value={stats.highRisk}
          icon={ShieldAlert}
          tone="warning"
          deltaTone="warning"
          delta="cần theo dõi"
          onClick={() => setScoreFilter(scoreFilter === "high_risk" ? "all" : "high_risk")}
          active={scoreFilter === "high_risk"}
          delay={140}
        />
        <StatCard
          label="Điểm an toàn TB"
          value={avgScore}
          icon={CircleCheck}
          tone="success"
          delta={getSafetyScoreInfo(avgScore).label}
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
              placeholder: "Tên, điện thoại, biển số phụ trách…",
            }}
            filters={
              <FilterChips items={statusChips} value={statusFilter} onChange={(k) => setStatusFilter(k as StatusFilter)} />
            }
            extra={
              <Select
                ariaLabel="Lọc theo điểm an toàn"
                value={scoreFilter}
                onChange={setScoreFilter}
                options={SCORE_OPTIONS}
                className="min-w-[11rem] max-w-[13rem]"
              />
            }
            action={
              <button
                type="button"
                className="sf-pill-primary"
                onClick={() => router.push("/accounts?create=driver")}
              >
                <UserPlus className="h-[17px] w-[17px]" />
                Thêm tài xế
              </button>
            }
          />
        }
      >
        <DataTable
          grid="1.5fr 1.1fr 1fr .9fr 1.1fr"
          columns={["Tài xế", "Liên hệ", "Xe phụ trách", "Giờ lái hôm nay", "Điểm an toàn"]}
          loading={isLoading}
          empty={{
            icon: Users,
            title: "Không tìm thấy tài xế",
            description: "Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng.",
          }}
          rows={filtered.map((driver) => {
            const scoreInfo = getSafetyScoreInfo(driver.safetyScore);
            const overtime = driver.drivingTimeToday >= DRIVING_LIMITS.MAX_CONTINUOUS;
            const nearLimit = !overtime && driver.drivingTimeToday >= DRIVING_LIMITS.WARNING_1;

            return {
              key: driver.id,
              onClick: () => setSelected(driver),
              cells: [
                <CellText
                  key="name"
                  strong
                  text={driver.fullName}
                  sub={`Bằng ${driver.licenseClass}${driver.licenseExpiry ? ` · hết hạn ${driver.licenseExpiry}` : ""}`}
                />,
                <CellText key="contact" mono text={driver.phone} sub={driver.email} />,
                <CellText
                  key="vehicle"
                  mono
                  text={driver.currentVehiclePlate || "—"}
                  sub={driver.currentVehiclePlate ? "gắn cố định" : "chưa gắn xe"}
                />,
                <CellText
                  key="hours"
                  mono
                  text={formatDrivingTime(driver.drivingTimeToday)}
                  sub={overtime ? "vượt ngưỡng" : nearLimit ? "gần ngưỡng" : ""}
                  color={
                    overtime
                      ? "var(--sf-danger)"
                      : nearLimit
                        ? "var(--sf-accent-hover)"
                        : undefined
                  }
                />,
                <span key="score" className="inline-flex items-center gap-2.5">
                  <ScoreRing score={driver.safetyScore} size={36} />
                  <Badge tone={toneOf(driver.status)} dot size="sm">
                    {scoreInfo.label.toUpperCase()}
                  </Badge>
                </span>,
              ],
            };
          })}
        />
      </TableCard>

      {/* ===== Panel chi tiết ===== */}
      <Drawer
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        title={selected?.fullName ?? ""}
        subtitle={selected ? `Bằng ${selected.licenseClass} · Mã ${selected.code}` : undefined}
        footer={
          <>
            {selected?.status !== "inactive" && (
              <Button variant="outline" size="sm" icon={UserX} onClick={() => selected && openEdit(selected)}>
                Chỉnh sửa / ngừng
              </Button>
            )}
            <Button variant="outline" size="sm" onClick={() => setSelected(null)}>Đóng</Button>
          </>
        }
      >
        {selected && (
          <div className="space-y-5">
            <div className="flex items-center gap-4">
              <ScoreRing score={selected.safetyScore} size={64} />
              <div className="min-w-0">
                <p className="text-[13px] font-extrabold text-sf-text">
                  Điểm an toàn {selected.safetyScore}
                </p>
                <p className="text-[12.5px] text-sf-text-muted">
                  {getSafetyScoreInfo(selected.safetyScore).label}
                </p>
                <Badge tone={toneOf(selected.status)} size="sm" className="mt-1.5">
                  {DRIVER_STATUS_LABELS[selected.status] || selected.status}
                </Badge>
              </div>
            </div>

            <div>
              <InfoRow label="Điện thoại" value={selected.phone} />
              <InfoRow label="Email" value={selected.email} />
              <InfoRow label="Hạn bằng lái" value={selected.licenseExpiry || "—"} />
              <InfoRow
                label="Xe phụ trách"
                value={selected.currentVehiclePlate ?? "Chưa giao"}
              />
              <InfoRow
                label="Giờ lái hôm nay"
                value={formatDrivingTime(selected.drivingTimeToday)}
              />
              <InfoRow label="Tổng chuyến" value={selected.totalTrips} />
              <InfoRow label="Tổng giờ lái" value={`${selected.totalDrivingHours} giờ`} />
            </div>

            <div>
              <div className="mb-2 flex items-center justify-between">
                <p className="sf-eyebrow">Các chuyến đã được giao</p>
                <Badge tone="neutral" size="sm">{driverTrips.length} chuyến</Badge>
              </div>
              {loadingTrips ? (
                <div className="rounded-xl border border-[var(--sf-border)] p-4 text-sm text-sf-text-muted">
                  Đang tải lịch sử chuyến…
                </div>
              ) : driverTrips.length === 0 ? (
                <div className="rounded-xl border border-dashed border-[var(--sf-border)] p-4 text-center text-sm text-sf-text-muted">
                  Tài xế chưa có chuyến nào.
                </div>
              ) : (
                <div className="space-y-2">
                  {driverTrips.map((trip) => (
                    <button
                      key={trip.id}
                      type="button"
                      onClick={() => setSelectedTrip(trip)}
                      className="w-full rounded-xl border border-[var(--sf-border)] bg-[var(--sf-bg-card)] p-3 text-left transition hover:border-[var(--sf-primary)]"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="flex items-center gap-2 font-extrabold text-sf-text">
                          <Navigation className="h-4 w-4 text-sf-primary" />
                          {trip.code}
                        </span>
                        <Badge tone={toneOf(trip.status)} size="sm">
                          {TRIP_STATUS_LABELS[trip.status] || trip.status}
                        </Badge>
                      </div>
                      <div className="mt-2 flex items-center gap-1.5 text-xs text-sf-text-secondary">
                        <span className="truncate">{trip.origin}</span>
                        <ArrowRight className="h-3 w-3 flex-shrink-0" />
                        <span className="truncate">{trip.destination}</span>
                      </div>
                      <p className="mt-1 text-xs text-sf-text-muted">
                        {trip.scheduledStart ? formatDateTime(trip.scheduledStart) : "Chưa có lịch"} · {trip.vehiclePlate}
                      </p>
                    </button>
                  ))}
                </div>
              )}
            </div>

            {selectedTrip && (
              <div className="rounded-xl border border-[var(--sf-primary)] bg-[var(--sf-primary-soft)] p-4">
                <div className="mb-3 flex items-center justify-between">
                  <p className="font-extrabold text-sf-text">Chi tiết {selectedTrip.code}</p>
                  <button type="button" className="text-xs font-bold text-sf-primary" onClick={() => setSelectedTrip(null)}>
                    Thu gọn
                  </button>
                </div>
                <InfoRow label="Biển số" value={selectedTrip.vehiclePlate} />
                <InfoRow label="Điểm đi" value={selectedTrip.origin} />
                <InfoRow label="Điểm đến" value={selectedTrip.destination} />
                <InfoRow label="Tiến độ" value={`${selectedTrip.progress}%`} />
                <InfoRow label="Bắt đầu thực tế" value={selectedTrip.actualStart ? formatDateTime(selectedTrip.actualStart) : "—"} />
                <InfoRow label="Kết thúc thực tế" value={selectedTrip.actualEnd ? formatDateTime(selectedTrip.actualEnd) : "—"} />
              </div>
            )}
          </div>
        )}
      </Drawer>

      <Modal
        open={Boolean(editing)}
        onClose={() => !saving && setEditing(null)}
        title="Cập nhật tài xế"
        subtitle="Thông tin vận hành; tài khoản đăng nhập được quản lý tại mục Tài khoản."
        footer={
          <>
            <Button
              variant="outline"
              size="sm"
              icon={UserX}
              disabled={saving}
              onClick={() => void updateDriver("INACTIVE")}
            >
              Ngừng hoạt động
            </Button>
            <Button variant="outline" size="sm" disabled={saving} onClick={() => setEditing(null)}>Hủy</Button>
            <Button size="sm" icon={Pencil} loading={saving} onClick={() => void updateDriver()}>Lưu thay đổi</Button>
          </>
        }
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <DriverField label="Họ và tên" required value={form.fullName} onChange={(value) => setForm((old) => ({ ...old, fullName: value }))} />
          <DriverField label="Số điện thoại" required value={form.phone} onChange={(value) => setForm((old) => ({ ...old, phone: value }))} />
          <DriverField label="Email" type="email" value={form.email} onChange={(value) => setForm((old) => ({ ...old, email: value }))} />
          <DriverField label="Địa chỉ" value={form.address} onChange={(value) => setForm((old) => ({ ...old, address: value }))} />
          <DriverField label="Hạng bằng lái" required value={form.licenseClass} onChange={(value) => setForm((old) => ({ ...old, licenseClass: value }))} />
          <DriverField label="Hạn bằng lái" required type="date" value={form.licenseExpiredAt} onChange={(value) => setForm((old) => ({ ...old, licenseExpiredAt: value }))} />
          <label className="space-y-1.5 sm:col-span-2">
            <span className="text-xs font-bold text-sf-text-secondary">Trạng thái vận hành</span>
            <select className="sf-input w-full" value={form.status} onChange={(event) => setForm((old) => ({ ...old, status: event.target.value }))}>
              <option value="AVAILABLE">Sẵn sàng</option>
              <option value="DRIVING">Đang cầm lái</option>
              <option value="RESTING">Đang nghỉ</option>
              <option value="OFF_DUTY">Ngoài ca</option>
              <option value="SUSPENDED">Tạm đình chỉ</option>
              <option value="HIGH_RISK">Rủi ro cao</option>
            </select>
          </label>
        </div>
      </Modal>
    </div>
  );
}

function DriverField({ label, value, onChange, type = "text", required = false }: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  required?: boolean;
}) {
  return (
    <label className="space-y-1.5">
      <span className="text-xs font-bold text-sf-text-secondary">{label}{required ? " *" : ""}</span>
      <input className="sf-input w-full" type={type} value={value} required={required} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}
