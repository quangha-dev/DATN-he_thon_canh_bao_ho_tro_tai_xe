"use client";

import { useEffect, useState, useMemo } from "react";
import { Account } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { Plus, Ban, Lock, Unlock, UserCog, ShieldCheck, Users, Siren, KeyRound } from "lucide-react";
import {
  Badge,
  Button,
  EmptyState,
  IconButton,
  Modal,
  SearchInput,
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
} from "@/components/ui";

const ROLE_LABELS: Record<string, string> = {
  ADMIN: "Quản lý",
  FLEET_MANAGER: "Quản lý",
  DISPATCHER: "Quản lý",
  SAFETY_OFFICER: "Quản lý",
  RESCUE_TEAM: "Quản lý",
  DRIVER: "Tài xế",
};

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
  const [roleFilter, setRoleFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [isLoading, setIsLoading] = useState(true);
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
      manager: accounts.filter((a) => a.role !== "DRIVER").length,
      driver: accounts.filter((a) => a.role === "DRIVER").length,
      locked: accounts.filter((a) => a.status === "LOCKED").length,
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

  const updateAccount = (next: Account) =>
    setAccounts((prev) => prev.map((a) => (a.id === next.id ? next : a)));

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
    <div className="space-y-5">
      {/* ===== Thống kê ===== */}
      <Stagger className="grid grid-cols-2 gap-3.5 lg:grid-cols-5">
        {isLoading && accounts.length === 0 ? (
          <StatSkeletonGrid count={5} />
        ) : (
          <>
            <StatCard label="Tổng tài khoản" value={stats.total} icon={Users} tone="primary" />
            <StatCard
              label="Đang hoạt động"
              value={stats.active}
              icon={ShieldCheck}
              tone="success"
              onClick={() => setStatusFilter(statusFilter === "ACTIVE" ? "all" : "ACTIVE")}
              active={statusFilter === "ACTIVE"}
            />
            <StatCard label="Quản lý" value={stats.manager} icon={UserCog} tone="primary" />
            <StatCard
              label="Tài xế"
              value={stats.driver}
              icon={Users}
              tone="primary"
              onClick={() => setRoleFilter(roleFilter === "DRIVER" ? "all" : "DRIVER")}
              active={roleFilter === "DRIVER"}
            />
            <StatCard
              label="Bị khóa"
              value={stats.locked}
              icon={Siren}
              tone="danger"
              onClick={() => setStatusFilter(statusFilter === "LOCKED" ? "all" : "LOCKED")}
              active={statusFilter === "LOCKED"}
            />
          </>
        )}
      </Stagger>

      {/* ===== Thanh công cụ ===== */}
      <Toolbar>
        <SearchInput
          value={searchQuery}
          onChange={setSearchQuery}
          placeholder="Tìm tên đăng nhập, họ tên, email…"
          className="sm:max-w-sm"
        />
        <div className="flex flex-wrap items-center gap-2">
          <Select
            ariaLabel="Lọc theo vai trò"
            value={roleFilter}
            onChange={setRoleFilter}
            options={[
              { value: "all", label: "Tất cả vai trò" },
              { value: "DRIVER", label: "Tài xế" },
            ]}
            className="min-w-[11rem]"
          />
          <Select
            ariaLabel="Lọc theo trạng thái"
            value={statusFilter}
            onChange={setStatusFilter}
            options={[
              { value: "all", label: "Tất cả trạng thái" },
              ...Object.entries(STATUS_LABELS).map(([value, label]) => ({ value, label })),
            ]}
          />
          <Button icon={Plus} size="sm" onClick={() => setCreateOpen(true)}>
            Tạo tài khoản
          </Button>
        </div>
      </Toolbar>

      {/* ===== Bảng ===== */}
      <TableShell loading={isLoading}>
        <Table
          head={["Tên đăng nhập", "Họ và tên", "Email", "Vai trò", "Trạng thái", "Ngày tạo", ""]}
        >
          {isLoading && accounts.length === 0 ? (
            <SkeletonRows rows={6} cols={7} />
          ) : filtered.length === 0 ? (
            <tr>
              <Td colSpan={7}>
                <EmptyState
                  icon={UserCog}
                  title="Không tìm thấy tài khoản"
                  description="Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng."
                />
              </Td>
            </tr>
          ) : (
            filtered.map((account) => (
              <Tr key={account.id}>
                <Td>
                  <span className="flex items-center gap-2.5">
                    <span
                      className="grid h-7 w-7 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)] text-[12.5px] font-extrabold"
                      style={{ background: "var(--sf-primary-soft)", color: "var(--sf-primary)" }}
                    >
                      {account.fullName.charAt(0).toUpperCase()}
                    </span>
                    <span className="font-mono text-[12.5px] font-bold text-sf-text">
                      {account.username}
                    </span>
                  </span>
                </Td>
                <Td className="font-semibold text-sf-text-secondary">{account.fullName}</Td>
                <Td>{account.email}</Td>
                <Td>
                  <Badge tone={account.role === "ADMIN" ? "primary" : "neutral"} size="sm">
                    {ROLE_LABELS[account.role] || account.role}
                  </Badge>
                </Td>
                <Td>
                  <StatusLabel
                    status={STATUS_KEY[account.status]}
                    label={STATUS_LABELS[account.status]}
                    pulse={account.status === "ACTIVE"}
                  />
                </Td>
                <Td className="sf-tnum">{account.createdAt}</Td>
                <Td align="center">
                  <span className="flex items-center justify-center gap-1">
                    <IconButton
                      icon={KeyRound}
                      label="Đặt lại mật khẩu"
                      size="sm"
                      tone="neutral"
                      onClick={() => setResetTarget(account)}
                    />
                    <IconButton
                      icon={account.status === "ACTIVE" ? Lock : Unlock}
                      label={account.status === "ACTIVE" ? "Khóa tài khoản" : "Mở khóa tài khoản"}
                      size="sm"
                      tone="primary"
                      onClick={() => handleToggleLock(account.id, account.status)}
                    />
                    <IconButton
                      icon={Ban}
                      label="Vô hiệu hóa tài khoản"
                      size="sm"
                      tone="danger"
                      onClick={() => handleDisable(account.id)}
                    />
                  </span>
                </Td>
              </Tr>
            ))
          )}
        </Table>
      </TableShell>

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
