"use client";

import { useMemo, useState } from "react";
import { Eye, EyeOff, Info, ShieldCheck } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { safeFleetApi } from "@/lib/safeFleetApi";
import type { AccountStatus, UserRole } from "@/types";
import { Badge, DetailRow, toneOf } from "@/components/ui";

/* Đủ sáu vai trò của hệ thống — bản thiết kế chỉ vẽ "Điều phối viên". */
const ROLE_LABELS: Record<UserRole, string> = {
  ADMIN: "Quản trị viên",
  FLEET_MANAGER: "Quản lý đội xe",
  DISPATCHER: "Điều phối viên",
  SAFETY_OFFICER: "An toàn vận hành",
  RESCUE_TEAM: "Đội cứu hộ",
  DRIVER: "Tài xế",
};

/* Đủ bốn trạng thái tài khoản — bản thiết kế chỉ vẽ "Đang hoạt động". */
const STATUS_LABELS: Record<AccountStatus, string> = {
  ACTIVE: "Đang hoạt động",
  LOCKED: "Bị khóa",
  DISABLED: "Vô hiệu hóa",
  PENDING: "Chờ kích hoạt",
};

const STATUS_TONE_KEY: Record<AccountStatus, string> = {
  ACTIVE: "active",
  LOCKED: "locked",
  DISABLED: "inactive",
  PENDING: "pending",
};

/** Viết tắt tên: chữ cái đầu của hai từ cuối, giống thẻ người dùng ở đầu trang */
function initialsOf(fullName?: string): string {
  if (!fullName) return "SF";
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "SF";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
}

/** Bốn mức độ mạnh: dài ≥ 8, có số, có chữ hoa, có ký tự đặc biệt */
function passwordStrength(pw: string) {
  if (!pw) return { score: 0, label: "chưa nhập" };
  let score = 0;
  if (pw.length >= 8) score += 1;
  if (/\d/.test(pw)) score += 1;
  if (/[A-Z]/.test(pw)) score += 1;
  if (/[^A-Za-z0-9]/.test(pw)) score += 1;
  const labels = ["rất yếu", "yếu", "trung bình", "tốt", "rất tốt"];
  return { score, label: labels[score] };
}

export default function ProfilePage() {
  const { user } = useAuth();
  const { showToast } = useToast();
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);

  const strength = useMemo(() => passwordStrength(newPassword), [newPassword]);

  if (!user) return null;

  const changePassword = async () => {
    if (newPassword.length < 8) {
      showToast("Mật khẩu mới phải có ít nhất 8 ký tự.", "error");
      return;
    }
    if (newPassword !== confirmPassword) {
      showToast("Xác nhận mật khẩu chưa khớp.", "error");
      return;
    }
    setSavingPassword(true);
    try {
      await safeFleetApi.changePassword(currentPassword, newPassword);
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
      showToast("Đã đổi mật khẩu. Các phiên đăng nhập cũ đã được thu hồi.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể đổi mật khẩu.", "error");
    } finally {
      setSavingPassword(false);
    }
  };

  const status = (user.status ?? "ACTIVE") as AccountStatus;

  return (
    <div className="grid items-start gap-5 lg:grid-cols-2">
      {/* ===================== Thẻ hồ sơ ===================== */}
      <div className="sf-surface overflow-hidden">
        <div className="relative h-[130px] overflow-hidden" style={{ background: "var(--sf-hero)" }}>
          <span
            aria-hidden
            className="sf-hero-glow"
            style={{ width: 260, height: 260, right: -80, top: -120 }}
          />
        </div>

        <div className="relative -mt-[38px] px-7 pb-7">
          <div
            className="grid h-[76px] w-[76px] place-items-center rounded-[26px] text-2xl font-bold"
            style={{
              background: "linear-gradient(150deg,#34d3b5,#087f73)",
              color: "#04211f",
              boxShadow:
                "0 16px 32px -14px rgba(8,64,62,.6), 0 0 0 5px var(--sf-bg-card)",
            }}
          >
            {initialsOf(user.fullName)}
          </div>

          <h2 className="mt-4 text-[21px] font-bold tracking-[-0.015em] text-sf-text">
            {user.fullName}
          </h2>
          <p className="mt-1 text-[13px] text-sf-text-muted">{user.email || "Chưa cập nhật email"}</p>

          <div className="mt-3.5 flex flex-wrap gap-2">
            <Badge tone="primary" size="sm">
              {(ROLE_LABELS[user.role] || user.role).toUpperCase()}
            </Badge>
            <Badge tone={toneOf(STATUS_TONE_KEY[status])} dot size="sm">
              {(STATUS_LABELS[status] || status).toUpperCase()}
            </Badge>
          </div>

          <div className="mt-6 grid gap-3">
            <DetailRow label="Tên đăng nhập" value={user.username} mono />
            <DetailRow label="Mã tài khoản" value={`ACC-${String(user.id).padStart(4, "0")}`} mono />
            <DetailRow label="Vai trò hệ thống" value={ROLE_LABELS[user.role] || user.role} />
          </div>

          <div
            className="mt-5 flex gap-3 rounded-[var(--sf-r-md)] p-4"
            style={{ background: "var(--sf-bg-inset)" }}
          >
            <ShieldCheck
              className="h-[18px] w-[18px] flex-none"
              style={{ color: "var(--sf-primary)" }}
            />
            <span className="text-[12px] leading-[1.55] text-sf-text-secondary">
              Phiên làm việc được bảo vệ bằng JWT và tự đăng xuất sau 8 giờ không hoạt động để bảo
              vệ tài khoản.
            </span>
          </div>
        </div>
      </div>

      {/* ===================== Đổi mật khẩu ===================== */}
      <div className="sf-surface p-7">
        <h3 className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">Đổi mật khẩu</h3>
        <p className="mt-1.5 text-[12.5px] text-sf-text-muted">
          Xác thực mật khẩu hiện tại trước khi đổi
        </p>

        <div className="mt-6 grid gap-4">
          <PasswordField
            label="Mật khẩu hiện tại"
            value={currentPassword}
            onChange={setCurrentPassword}
            visible={showPw}
            onToggle={() => setShowPw((v) => !v)}
            autoComplete="current-password"
          />

          <div>
            <PasswordField
              label="Mật khẩu mới"
              value={newPassword}
              onChange={setNewPassword}
              visible={showPw}
              onToggle={() => setShowPw((v) => !v)}
              autoComplete="new-password"
            />
            <div className="mt-2.5 flex gap-1.5">
              {[0, 1, 2, 3].map((i) => (
                <span
                  key={i}
                  className="h-[5px] flex-1 rounded-full transition-colors duration-[var(--sf-dur-base)]"
                  style={{
                    background:
                      i < strength.score
                        ? strength.score <= 1
                          ? "var(--sf-danger)"
                          : strength.score === 2
                            ? "var(--sf-accent)"
                            : "var(--sf-primary)"
                        : "var(--sf-bg-inset-strong, var(--sf-bg-inset))",
                  }}
                />
              ))}
            </div>
            <p className="mt-1.5 text-[11.5px] text-sf-text-muted">
              Độ mạnh: {strength.label} · tối thiểu 8 ký tự, nên có số và chữ hoa
            </p>
          </div>

          <PasswordField
            label="Xác nhận mật khẩu mới"
            value={confirmPassword}
            onChange={setConfirmPassword}
            visible={showPw}
            onToggle={() => setShowPw((v) => !v)}
            autoComplete="new-password"
          />

          <button
            type="button"
            disabled={savingPassword || !currentPassword || !newPassword || !confirmPassword}
            onClick={() => void changePassword()}
            className="mt-1.5 cursor-pointer rounded-[var(--sf-r-md)] border-0 py-3.5 text-[13.5px] font-semibold text-white transition-transform duration-[var(--sf-dur-base)] ease-[var(--sf-ease-spring)] hover:-translate-y-0.5 disabled:pointer-events-none disabled:opacity-50"
            style={{
              background: "linear-gradient(140deg,#0b8c7f,#076a61)",
              boxShadow: "0 16px 30px -14px rgba(8,127,115,.7)",
            }}
          >
            {savingPassword ? "Đang cập nhật…" : "Cập nhật mật khẩu"}
          </button>

          <div
            className="flex gap-3 rounded-[var(--sf-r-md)] p-4"
            style={{ background: "var(--sf-accent-soft)" }}
          >
            <Info
              className="h-[18px] w-[18px] flex-none"
              style={{ color: "var(--sf-accent-hover)" }}
            />
            <span
              className="text-[12px] leading-[1.55]"
              style={{ color: "var(--sf-accent-hover)" }}
            >
              Đổi mật khẩu sẽ thu hồi toàn bộ phiên đăng nhập cũ trên các thiết bị khác.
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

function PasswordField({
  label,
  value,
  onChange,
  visible,
  onToggle,
  autoComplete,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  visible: boolean;
  onToggle: () => void;
  autoComplete: string;
}) {
  return (
    <div>
      <label className="mb-2 block text-[12.5px] font-semibold text-sf-text-secondary">
        {label}
      </label>
      <div className="flex items-center gap-2.5 rounded-[15px] border border-[var(--sf-border)] bg-[var(--sf-bg-card)] px-4 py-3.5 transition-colors focus-within:border-[var(--sf-primary)]">
        <input
          type={visible ? "text" : "password"}
          value={value}
          autoComplete={autoComplete}
          onChange={(e) => onChange(e.target.value)}
          className="min-w-0 flex-1 border-0 bg-transparent text-[13.5px] text-sf-text outline-none"
        />
        <button
          type="button"
          onClick={onToggle}
          aria-label={visible ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
          className="grid flex-none cursor-pointer place-items-center text-sf-text-muted transition-colors hover:text-sf-text"
        >
          {visible ? <EyeOff className="h-[18px] w-[18px]" /> : <Eye className="h-[18px] w-[18px]" />}
        </button>
      </div>
    </div>
  );
}
