"use client";

import { useEffect, useState, useMemo } from "react";
import { Account, UserRole } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { Plus, Ban, Lock, Unlock, ShieldCheck, Users, KeyRound } from "lucide-react";
import {
  Badge,
  Button,
  DataTable,
  Drawer,
  FilterChips,
  InfoRow,
  Modal,
  StatCard,
  TableCard,
  TableToolbar,
  toneOf,
  type FilterChip,
  type Tone,
} from "@/components/ui";

/** Nhãn tiếng Việt cho đủ sáu vai trò của backend — bản thiết kế chỉ vẽ hai
    (QUẢN LÝ / TÀI XẾ) nên dùng lại đúng nhãn đã chuẩn hoá ở Header/Hồ sơ. */
const ROLE_LABELS: Record<UserRole, string> = {
  ADMIN: "Quản trị viên",
  FLEET_MANAGER: "Quản lý đội xe",
  DISPATCHER: "Điều phối viên",
  SAFETY_OFFICER: "An toàn vận hành",
  RESCUE_TEAM: "Đội cứu hộ",
  DRIVER: "Tài xế",
};

const ROLE_TONE: Record<UserRole, Tone> = {
  ADMIN: "primary",
  FLEET_MANAGER: "info",
  DISPATCHER: "info",
  SAFETY_OFFICER: "accent",
  RESCUE_TEAM: "danger",
  DRIVER: "neutral",
};

const ROLE_ORDER: UserRole[] = ["ADMIN", "FLEET_MANAGER", "DISPATCHER", "SAFETY_OFFICER", "RESCUE_TEAM", "DRIVER"];

const EMPTY_ACCOUNT_FORM = {
  actor: "MANAGER" as "MANAGER" | "DRIVER",
  username: "",
  email: "",
  password: "",
  fullName: "",
  phone: "",
  address: "",
  licenseNumber: "",
  licenseClass: "B2",
  licenseExpiredAt: "",
};

/** Đủ bốn trạng thái tài khoản của backend — bản thiết kế chỉ vẽ ba, thiếu PENDING */
const STATUS_LABELS: Record<Account["status"], string> = {
  ACTIVE: "Hoạt động",
  LOCKED: "Bị khóa",
  DISABLED: "Vô hiệu hóa",
  PENDING: "Chờ kích hoạt",
};

/** Trạng thái tài khoản → khóa tone dùng chung */
const STATUS_KEY: Record<Account["status"], string> = {
  ACTIVE: "active",
  LOCKED: "locked",
  DISABLED: "inactive",
  PENDING: "pending",
};

export default function AccountsPage() {
  const { showToast } = useToast();
  const [searchQuery, setSearchQuery] = useState("");
  const [roleFilter, setRoleFilter] = useState<"all" | UserRole>("all");
  const [statusFilter, setStatusFilter] = useState<"all" | Account["status"]>("all");
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selected, setSelected] = useState<Account | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [accountForm, setAccountForm] = useState(EMPTY_ACCOUNT_FORM);
  const [resetTarget, setResetTarget] = useState<Account | null>(null);
  const [resetPassword, setResetPassword] = useState("");

  useEffect(() => {
    if (new URLSearchParams(window.location.search).get("create") === "driver") {
      setAccountForm({ ...EMPTY_ACCOUNT_FORM, actor: "DRIVER" });
      setCreateOpen(true);
      window.history.replaceState(null, "", "/accounts");
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.accounts();
        if (!cancelled) setAccounts(data);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được tài khoản.";
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
      total: accounts.length,
      active: accounts.filter((a) => a.status === "ACTIVE").length,
      locked: accounts.filter((a) => a.status === "LOCKED").length,
      disabled: accounts.filter((a) => a.status === "DISABLED").length,
      manager: accounts.filter((a) => a.role !== "DRIVER").length,
      driver: accounts.filter((a) => a.role === "DRIVER").length,
    }),
    [accounts]
  );

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return accounts.filter((a) => {
      if (roleFilter !== "all" && a.role !== roleFilter) return false;
      if (statusFilter !== "all" && a.status !== statusFilter) return false;
      if (!q) return true;
      return (
        a.username.toLowerCase().includes(q) ||
        a.fullName.toLowerCase().includes(q) ||
        a.email.toLowerCase().includes(q)
      );
    });
  }, [accounts, searchQuery, roleFilter, statusFilter]);

  /* Chip lọc theo vai trò — dựng đủ sáu UserRole của backend (bản thiết kế chỉ
     vẽ hai), chỉ hiện vai trò thật sự có tài khoản. */
  const roleChips = useMemo(() => {
    /* Hai nhóm chip đứng cạnh nhau nên chip "tất cả" phải gọi rõ theo nhóm,
       tránh hai chip trùng nhãn khiến người dùng không biết đang lọc gì. */
    const chips: FilterChip[] = [{ key: "all", label: "Mọi vai trò", count: accounts.length }];
    ROLE_ORDER.forEach((role) => {
      const count = accounts.filter((a) => a.role === role).length;
      if (count > 0) chips.push({ key: role, label: ROLE_LABELS[role], count });
    });
    return chips;
  }, [accounts]);

  /* Chip lọc theo trạng thái — dựng đủ bốn AccountStatus, gồm cả PENDING mà
     bản thiết kế bỏ sót. */
  const statusChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "all", label: "Mọi trạng thái", count: accounts.length }];
    (Object.keys(STATUS_LABELS) as Account["status"][]).forEach((status) => {
      const count = accounts.filter((a) => a.status === status).length;
      if (count > 0) chips.push({ key: status, label: STATUS_LABELS[status], count });
    });
    return chips;
  }, [accounts]);

  const updateAccount = (next: Account) => {
    setAccounts((prev) => prev.map((a) => (a.id === next.id ? next : a)));
    setSelected((prev) => (prev && prev.id === next.id ? next : prev));
  };

  const handleToggleLock = async (id: number, currentStatus: Account["status"]) => {
    const nextStatus = currentStatus === "ACTIVE" ? "LOCKED" : "ACTIVE";
    try {
      updateAccount(await safeFleetApi.updateAccountStatus(id, nextStatus));
      showToast(nextStatus === "LOCKED" ? "Đã khóa tài khoản." : "Đã mở khóa tài khoản.", "info");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể cập nhật tài khoản.", "error");
    }
  };

  const handleDisable = async (id: number) => {
    try {
      updateAccount(await safeFleetApi.updateAccountStatus(id, "DISABLED"));
      showToast("Đã vô hiệu hóa tài khoản.", "success");
    } catch (error) {
      showToast(
        error instanceof Error ? error.message : "Không thể vô hiệu hóa tài khoản.",
        "error"
      );
    }
  };

  const handleCreate = async () => {
    setSaving(true);
    try {
      const common = {
        username: accountForm.username.trim(),
        email: accountForm.email.trim(),
        password: accountForm.password,
        fullName: accountForm.fullName.trim(),
        phone: accountForm.phone.trim(),
      };
      const created = accountForm.actor === "DRIVER"
        ? await safeFleetApi.createDriverAccount({
            ...common,
            phone: common.phone,
            address: accountForm.address.trim() || undefined,
            licenseNumber: accountForm.licenseNumber.trim(),
            licenseClass: accountForm.licenseClass.trim(),
            licenseExpiredAt: accountForm.licenseExpiredAt,
          })
        : await safeFleetApi.createManagerAccount(common);
      setAccounts((prev) => [created, ...prev]);
      setAccountForm(EMPTY_ACCOUNT_FORM);
      setCreateOpen(false);
      showToast("Đã tạo tài khoản và kích hoạt quyền truy cập.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể tạo tài khoản.", "error");
    } finally {
      setSaving(false);
    }
  };

  const handleResetPassword = async () => {
    if (!resetTarget) return;
    setSaving(true);
    try {
      await safeFleetApi.resetAccountPassword(resetTarget.id, resetPassword);
      showToast("Đã đặt lại mật khẩu và thu hồi các phiên cũ.", "success");
      setResetTarget(null);
      setResetPassword("");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể đặt lại mật khẩu.", "error");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Tổng tài khoản"
          value={stats.total}
          icon={Users}
          delta={`${stats.manager} quản lý · ${stats.driver} tài xế`}
          delay={0}
        />
        <StatCard
          label="Đang hoạt động"
          value={stats.active}
          icon={ShieldCheck}
          tone="success"
          delta={stats.total ? `${Math.round((stats.active / stats.total) * 100)}%` : ""}
          onClick={() => setStatusFilter(statusFilter === "ACTIVE" ? "all" : "ACTIVE")}
          active={statusFilter === "ACTIVE"}
          delay={70}
        />
        <StatCard
          label="Bị khóa"
          value={stats.locked}
          icon={Lock}
          tone="warning"
          deltaTone="warning"
          delta="chờ xử lý"
          onClick={() => setStatusFilter(statusFilter === "LOCKED" ? "all" : "LOCKED")}
          active={statusFilter === "LOCKED"}
          delay={140}
        />
        <StatCard
          label="Vô hiệu hóa"
          value={stats.disabled}
          icon={Ban}
          tone="neutral"
          delta="lưu trữ"
          onClick={() => setStatusFilter(statusFilter === "DISABLED" ? "all" : "DISABLED")}
          active={statusFilter === "DISABLED"}
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
              placeholder: "Tên đăng nhập, họ tên, email…",
            }}
            filters={
              <FilterChips items={roleChips} value={roleFilter} onChange={(k) => setRoleFilter(k as typeof roleFilter)} />
            }
            extra={
              <>
                <span aria-hidden className="hidden h-6 w-px shrink-0 bg-[var(--sf-border-card)] sm:block" />
                <FilterChips items={statusChips} value={statusFilter} onChange={(k) => setStatusFilter(k as typeof statusFilter)} />
              </>
            }
            action={
              <button type="button" className="sf-pill-primary" onClick={() => setCreateOpen(true)}>
                <Plus className="h-[17px] w-[17px]" />
                Tạo tài khoản
              </button>
            }
          />
        }
      >
        <DataTable
          grid="1.3fr 1.4fr .9fr 1fr 1fr"
          columns={["Tài khoản", "Họ tên & email", "Vai trò", "Trạng thái", "Hoạt động cuối"]}
          loading={isLoading}
          empty={{
            icon: Users,
            title: "Không tìm thấy tài khoản",
            description: "Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng.",
          }}
          rows={filtered.map((account) => ({
            key: String(account.id),
            onClick: () => setSelected(account),
            cells: [
              <span key="account" className="flex min-w-0 items-center gap-3">
                <span
                  className="grid h-9 w-9 flex-shrink-0 place-items-center rounded-[12px] text-[13px] font-extrabold"
                  style={{ background: "var(--sf-primary-soft)", color: "var(--sf-primary)" }}
                >
                  {account.fullName.charAt(0).toUpperCase()}
                </span>
                <span className="min-w-0">
                  <span className="sf-mono block truncate text-[13.5px] font-semibold text-sf-text">{account.username}</span>
                  <span className="mt-[3px] block truncate text-[11.5px] text-sf-text-muted">
                    ACC-{String(account.id).padStart(4, "0")}
                  </span>
                </span>
              </span>,
              <div key="person" className="min-w-0">
                <div className="truncate text-[13.5px] font-medium text-sf-text">{account.fullName}</div>
                <div className="mt-[3px] truncate text-[11.5px] text-sf-text-muted">{account.email}</div>
              </div>,
              <Badge key="role" tone={ROLE_TONE[account.role] ?? "neutral"} dot size="sm">
                {(ROLE_LABELS[account.role] || account.role).toUpperCase()}
              </Badge>,
              <Badge key="status" tone={toneOf(STATUS_KEY[account.status])} dot size="sm">
                {STATUS_LABELS[account.status].toUpperCase()}
              </Badge>,
              <span key="lastActive" className="sf-mono block truncate text-[13px] text-sf-text-secondary">
                {account.lastLogin || account.createdAt || "—"}
              </span>,
            ],
          }))}
        />
      </TableCard>

      {/* ===== Panel chi tiết ===== */}
      <Drawer
        open={Boolean(selected)}
        onClose={() => setSelected(null)}
        title={selected?.fullName ?? ""}
        subtitle={selected ? `@${selected.username} · ${ROLE_LABELS[selected.role] || selected.role}` : undefined}
        footer={
          <>
            <Button
              variant="outline"
              size="sm"
              icon={KeyRound}
              onClick={() => selected && setResetTarget(selected)}
            >
              Đặt lại mật khẩu
            </Button>
            <Button
              variant="outline"
              size="sm"
              icon={selected?.status === "ACTIVE" ? Lock : Unlock}
              onClick={() => selected && void handleToggleLock(selected.id, selected.status)}
            >
              {selected?.status === "ACTIVE" ? "Khóa" : "Mở khóa"}
            </Button>
            {selected?.status !== "DISABLED" && (
              <Button variant="danger" size="sm" icon={Ban} onClick={() => selected && void handleDisable(selected.id)}>
                Vô hiệu hóa
              </Button>
            )}
            <Button variant="outline" size="sm" onClick={() => setSelected(null)}>Đóng</Button>
          </>
        }
      >
        {selected && (
          <div className="space-y-4">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={ROLE_TONE[selected.role] ?? "neutral"}>
                {ROLE_LABELS[selected.role] || selected.role}
              </Badge>
              <Badge tone={toneOf(STATUS_KEY[selected.status])}>
                {STATUS_LABELS[selected.status]}
              </Badge>
            </div>

            <div>
              <InfoRow label="Tên đăng nhập" value={<span className="sf-mono">{selected.username}</span>} />
              <InfoRow label="Email" value={selected.email} />
              <InfoRow label="Ngày tạo" value={selected.createdAt || "—"} />
              <InfoRow label="Đăng nhập cuối" value={selected.lastLogin || "Chưa đăng nhập"} />
            </div>
          </div>
        )}
      </Drawer>

      <Modal
        open={createOpen}
        onClose={() => !saving && setCreateOpen(false)}
        title="Tạo tài khoản"
        subtitle="Chọn đúng actor để hệ thống tạo quyền và hồ sơ tương ứng."
        size="lg"
        footer={
          <>
            <Button variant="outline" onClick={() => setCreateOpen(false)} disabled={saving}>Hủy</Button>
            <Button onClick={() => void handleCreate()} loading={saving}>Tạo tài khoản</Button>
          </>
        }
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <label className="space-y-1.5 text-sm font-semibold text-sf-text-secondary">
            Actor
            <select
              className="sf-input sf-select"
              value={accountForm.actor}
              onChange={(event) => setAccountForm((prev) => ({ ...prev, actor: event.target.value as "MANAGER" | "DRIVER" }))}
            >
              <option value="MANAGER">Quản lý</option>
              <option value="DRIVER">Tài xế</option>
            </select>
          </label>
          <FormField label="Họ và tên" required value={accountForm.fullName} onChange={(value) => setAccountForm((prev) => ({ ...prev, fullName: value }))} />
          <FormField label="Tên đăng nhập" required value={accountForm.username} onChange={(value) => setAccountForm((prev) => ({ ...prev, username: value }))} />
          <FormField label="Email" type="email" required value={accountForm.email} onChange={(value) => setAccountForm((prev) => ({ ...prev, email: value }))} />
          <FormField label="Mật khẩu ban đầu" type="password" required value={accountForm.password} onChange={(value) => setAccountForm((prev) => ({ ...prev, password: value }))} />
          <FormField label="Số điện thoại" required={accountForm.actor === "DRIVER"} value={accountForm.phone} onChange={(value) => setAccountForm((prev) => ({ ...prev, phone: value }))} />
          {accountForm.actor === "DRIVER" && (
            <>
              <FormField label="Địa chỉ" value={accountForm.address} onChange={(value) => setAccountForm((prev) => ({ ...prev, address: value }))} />
              <FormField label="Số giấy phép lái xe" required value={accountForm.licenseNumber} onChange={(value) => setAccountForm((prev) => ({ ...prev, licenseNumber: value }))} />
              <FormField label="Hạng giấy phép" required value={accountForm.licenseClass} onChange={(value) => setAccountForm((prev) => ({ ...prev, licenseClass: value }))} />
              <FormField label="Ngày hết hạn giấy phép" type="date" required value={accountForm.licenseExpiredAt} onChange={(value) => setAccountForm((prev) => ({ ...prev, licenseExpiredAt: value }))} />
            </>
          )}
        </div>
      </Modal>

      <Modal
        open={Boolean(resetTarget)}
        onClose={() => !saving && setResetTarget(null)}
        title="Đặt lại mật khẩu"
        subtitle={resetTarget ? `Tài khoản ${resetTarget.username} sẽ bị đăng xuất khỏi các phiên cũ.` : undefined}
        size="sm"
        footer={
          <>
            <Button variant="outline" onClick={() => setResetTarget(null)} disabled={saving}>Hủy</Button>
            <Button onClick={() => void handleResetPassword()} loading={saving} disabled={resetPassword.length < 8}>Đặt lại</Button>
          </>
        }
      >
        <FormField label="Mật khẩu mới" type="password" required value={resetPassword} onChange={setResetPassword} />
        <p className="mt-2 text-xs text-sf-text-muted">Tối thiểu 8 ký tự.</p>
      </Modal>
    </div>
  );
}

function FormField({ label, value, onChange, type = "text", required = false }: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  required?: boolean;
}) {
  return (
    <label className="space-y-1.5 text-sm font-semibold text-sf-text-secondary">
      {label}{required && <span className="text-[var(--sf-danger)]"> *</span>}
      <input className="sf-input" type={type} value={value} required={required} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}
