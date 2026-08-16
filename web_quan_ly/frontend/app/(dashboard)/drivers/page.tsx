"use client";

import { useEffect, useState, useMemo } from "react";
import { useRouter } from "next/navigation";
import { Driver, Trip } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import {
  cn,
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
  Drawer,
  EmptyState,
  IconButton,
  InfoRow,
  Modal,
  ProgressBar,
  ScoreRing,
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
import { Users, Plus, Eye, Phone, Mail, Car, Clock, ShieldAlert, CircleCheck, Navigation, ArrowRight, Pencil, UserX } from "lucide-react";

const STATUS_FILTERS = ["all", "driving", "available", "resting"] as const;
type StatusFilter = (typeof STATUS_FILTERS)[number];

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

  return (
    <div className="space-y-5">
      {/* ===== Thống kê ===== */}
      <Stagger className="grid grid-cols-2 gap-3.5 lg:grid-cols-5">
        {isLoading && drivers.length === 0 ? (
          <StatSkeletonGrid count={5} />
        ) : (
          <>
            <StatCard label="Tổng tài xế" value={stats.total} icon={Users} tone="primary" />
            <StatCard
              label="Đang cầm lái"
              value={stats.driving}
              icon={Car}
              tone="primary"
              onClick={() => setStatusFilter(statusFilter === "driving" ? "all" : "driving")}
              active={statusFilter === "driving"}
            />
            <StatCard
              label="Sẵn sàng"
              value={stats.available}
              icon={CircleCheck}
              tone="success"
              onClick={() => setStatusFilter(statusFilter === "available" ? "all" : "available")}
              active={statusFilter === "available"}
            />
            <StatCard
              label="Đang nghỉ"
              value={stats.resting}
              icon={Clock}
              tone="accent"
              onClick={() => setStatusFilter(statusFilter === "resting" ? "all" : "resting")}
              active={statusFilter === "resting"}
            />
            <StatCard
              label="Rủi ro cao"
              value={stats.highRisk}
              icon={ShieldAlert}
              tone="danger"
              hint="Điểm an toàn dưới 60"
              onClick={() => setScoreFilter(scoreFilter === "high_risk" ? "all" : "high_risk")}
              active={scoreFilter === "high_risk"}
            />
          </>
        )}
      </Stagger>

      {/* ===== Thanh công cụ ===== */}
      <Toolbar>
        <SearchInput
          value={searchQuery}
          onChange={setSearchQuery}
          placeholder="Tìm tên tài xế, SĐT, biển số xe…"
          className="sm:max-w-sm"
        />
        <div className="flex flex-wrap items-center gap-2">
          <Select
            ariaLabel="Lọc theo điểm an toàn"
            value={scoreFilter}
            onChange={setScoreFilter}
            options={SCORE_OPTIONS}
            className="min-w-[12rem]"
          />
          <Segmented
            value={statusFilter}
            onChange={setStatusFilter}
            options={STATUS_FILTERS.map((s) => ({
              value: s,
              label: s === "all" ? "Tất cả" : DRIVER_STATUS_LABELS[s],
            }))}
          />
          <Button icon={Plus} size="sm" onClick={() => router.push("/accounts?create=driver") }>
            Thêm tài xế
          </Button>
        </div>
      </Toolbar>

      {/* ===== Bảng ===== */}
      <TableShell loading={isLoading}>
        <Table
          head={[
            "Tài xế",
            "Liên hệ",
            "Hạng bằng",
            "Xe phụ trách",
            "Trạng thái",
            "Giờ lái hôm nay",
            "Điểm an toàn",
            "",
          ]}
        >
          {isLoading && drivers.length === 0 ? (
            <SkeletonRows rows={6} cols={8} />
          ) : filtered.length === 0 ? (
            <tr>
              <Td colSpan={8}>
                <EmptyState
                  icon={Users}
                  title="Không tìm thấy tài xế"
                  description="Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng."
                />
              </Td>
            </tr>
          ) : (
            filtered.map((driver) => {
              const scoreInfo = getSafetyScoreInfo(driver.safetyScore);
              const overtime = driver.drivingTimeToday >= DRIVING_LIMITS.MAX_CONTINUOUS;
              const nearLimit =
                !overtime && driver.drivingTimeToday >= DRIVING_LIMITS.WARNING_1;

              return (
                <Tr key={driver.id} onClick={() => setSelected(driver)}>
                  <Td>
                    <span className="flex items-center gap-2.5">
                      <span
                        className="grid h-8 w-8 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)] text-[12px] font-extrabold"
                        style={{
                          background: "var(--sf-primary-soft)",
                          color: "var(--sf-primary)",
                        }}
                      >
                        {driver.fullName.charAt(0).toUpperCase()}
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate text-[13px] font-bold text-sf-text">
                          {driver.fullName}
                        </span>
                        <span className="block text-[12px] text-sf-text-muted">
                          Mã {driver.code || driver.id}
                        </span>
                      </span>
                    </span>
                  </Td>
                  <Td>
                    <span className="block text-[12px] font-semibold text-sf-text-secondary">
                      <Phone className="mr-1 inline h-3 w-3 text-sf-text-muted" />
                      {driver.phone}
                    </span>
                    <span className="mt-0.5 block truncate text-[12px] text-sf-text-muted">
                      <Mail className="mr-1 inline h-3 w-3" />
                      {driver.email}
                    </span>
                  </Td>
                  <Td>Bằng {driver.licenseClass}</Td>
                  <Td>
                    {driver.currentVehiclePlate ? (
                      <span className="font-bold text-sf-text-secondary">
                        {driver.currentVehiclePlate}
                      </span>
                    ) : (
                      <span className="italic text-sf-text-muted">Sẵn sàng điều phối</span>
                    )}
                  </Td>
                  <Td>
                    <StatusLabel
                      status={driver.status}
                      label={DRIVER_STATUS_LABELS[driver.status] || driver.status}
                      pulse={driver.status === "driving"}
                    />
                  </Td>
                  <Td align="center">
                    <span
                      className={cn("sf-tnum text-[12.5px] font-extrabold")}
                      style={{
                        color: overtime
                          ? "var(--sf-danger)"
                          : nearLimit
                            ? "var(--sf-accent-hover)"
                            : "var(--sf-text-secondary)",
                      }}
                    >
                      {formatDrivingTime(driver.drivingTimeToday)}
                    </span>
                    <ProgressBar
                      className="mt-1.5 w-20"
                      value={(driver.drivingTimeToday / DRIVING_LIMITS.MAX_CONTINUOUS) * 100}
                      tone={overtime ? "danger" : nearLimit ? "warning" : "primary"}
                    />
                  </Td>
                  <Td align="center">
                    <span className="inline-flex items-center gap-2">
                      <ScoreRing score={driver.safetyScore} size={36} />
                      <span className="text-[12.5px] font-bold text-sf-text-muted">
                        {scoreInfo.label}
                      </span>
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
                        setSelected(driver);
                      }}
                    />
                  </Td>
                </Tr>
              );
            })
          )}
        </Table>
      </TableShell>

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
