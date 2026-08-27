"use client";

import { useState } from "react";
import { BadgeCheck, KeyRound, Mail, ShieldCheck, UserRound, Fingerprint } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { Badge, Button, Card, CardHeader, InfoRow, Reveal, StatusDot } from "@/components/ui";

const ROLE_LABELS: Record<string, string> = {
  ADMIN: "Quản trị viên",
  FLEET_MANAGER: "Quản lý đội xe",
  DISPATCHER: "Điều phối viên",
  SAFETY_OFFICER: "An toàn vận hành",
  RESCUE_TEAM: "Đội cứu hộ",
  DRIVER: "Tài xế",
};

export default function ProfilePage() {
  const { user } = useAuth();
  const { showToast } = useToast();
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [savingPassword, setSavingPassword] = useState(false);
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

  const initial = user.fullName?.trim().charAt(0).toUpperCase() || "U";

  return (
    <div className="mx-auto max-w-5xl space-y-5">
      {/* ===== Thẻ hồ sơ ===== */}
      <Card padding="none">
        <div
          className="relative h-28"
          style={{
            background:
              "linear-gradient(115deg, var(--sf-primary) 0%, var(--sf-primary-700) 42%, var(--sf-accent) 128%)",
          }}
        >
          <span
            aria-hidden
            className="absolute inset-0 opacity-25"
            style={{
              backgroundImage:
                "linear-gradient(to right, rgba(255,255,255,0.25) 1px, transparent 1px), linear-gradient(to bottom, rgba(255,255,255,0.25) 1px, transparent 1px)",
              backgroundSize: "36px 36px",
              maskImage: "radial-gradient(120% 100% at 20% 0%, #000, transparent 75%)",
              WebkitMaskImage: "radial-gradient(120% 100% at 20% 0%, #000, transparent 75%)",
            }}
          />
        </div>

        <div className="px-6 pb-6">
          <div className="-mt-12 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div className="flex items-end gap-4">
              <span
                className="grid h-24 w-24 place-items-center rounded-[var(--sf-r-lg)] border-4 text-3xl font-black shadow-[var(--sf-shadow-lg)]"
                style={{
                  borderColor: "var(--sf-bg-card)",
                  background: "var(--sf-ink-900)",
                  color: "var(--sf-primary-300)",
                }}
              >
                {initial}
              </span>
              <div className="pb-1">
                <div className="flex items-center gap-2">
                  <h2 className="text-xl font-black tracking-tight text-sf-text">
                    {user.fullName}
                  </h2>
                  <BadgeCheck className="h-5 w-5" style={{ color: "var(--sf-primary)" }} />
                </div>
                <p className="mt-1 text-[13px] font-semibold text-sf-text-muted">
                  {ROLE_LABELS[user.role] || user.role}
                </p>
              </div>
            </div>

            <Badge tone="success" className="w-fit">
              <StatusDot tone="success" pulse />
              Tài khoản đang hoạt động
            </Badge>
          </div>
        </div>
      </Card>

      <div className="grid gap-5 lg:grid-cols-[1.4fr_0.6fr]">
        {/* ===== Thông tin tài khoản ===== */}
        <Reveal>
          <Card padding="lg">
            <CardHeader
              title="Thông tin tài khoản"
              subtitle="Dữ liệu đồng bộ từ hệ thống xác thực"
              icon={UserRound}
            />
            <div className="mt-4">
              <InfoRow label="Họ và tên" value={user.fullName || "Chưa cập nhật"} />
              <InfoRow label="Tên đăng nhập" value={user.username} />
              <InfoRow
                label="Email"
                value={
                  <span className="inline-flex items-center gap-1.5">
                    <Mail className="h-3.5 w-3.5 text-sf-text-muted" />
                    {user.email || "Chưa cập nhật"}
                  </span>
                }
              />
              <InfoRow label="Vai trò" value={ROLE_LABELS[user.role] || user.role} />
              <InfoRow
                label="Mã tài khoản"
                value={
                  <span className="sf-tnum font-mono">
                    SF-{String(user.id).padStart(4, "0")}
                  </span>
                }
              />
              <InfoRow
                label="Trạng thái"
                value={<Badge tone="success" size="sm">Đang hoạt động</Badge>}
              />
            </div>
          </Card>
        </Reveal>

        {/* ===== Bảo mật ===== */}
        <Reveal delay={80}>
          <Card
            padding="lg"
            className="h-full border-0"
            style={{ background: "var(--sf-ink-900)" }}
          >
            <ShieldCheck className="h-8 w-8" style={{ color: "var(--sf-primary-300)" }} />
            <h3 className="mt-4 text-lg font-extrabold tracking-tight text-[var(--sf-ink-25)]">
              Bảo mật tài khoản
            </h3>
            <p className="mt-2 text-[13px] leading-6 text-[var(--sf-ink-400)]">
              Phiên đăng nhập được bảo vệ bằng JWT và tự động làm mới an toàn qua refresh token.
            </p>

            <div className="mt-5 space-y-2.5">
              <div
                className="flex items-center gap-3 rounded-[var(--sf-r-md)] p-3.5"
                style={{ background: "var(--sf-ink-950)" }}
              >
                <KeyRound className="h-4 w-4 flex-shrink-0" style={{ color: "var(--sf-primary-300)" }} />
                <div className="min-w-0">
                  <p className="text-[12px] font-bold text-[var(--sf-ink-100)]">Mật khẩu</p>
                  <p className="mt-0.5 text-[12px] text-[var(--sf-ink-500)]">
                    Lưu dưới dạng băm một chiều (BCrypt)
                  </p>
                </div>
              </div>
              <div
                className="flex items-center gap-3 rounded-[var(--sf-r-md)] p-3.5"
                style={{ background: "var(--sf-ink-950)" }}
              >
                <Fingerprint
                  className="h-4 w-4 flex-shrink-0"
                  style={{ color: "var(--sf-accent-300)" }}
                />
                <div className="min-w-0">
                  <p className="text-[12px] font-bold text-[var(--sf-ink-100)]">Phiên đăng nhập</p>
                  <p className="mt-0.5 text-[12px] text-[var(--sf-ink-500)]">
                    Tự động thu hồi khi đăng xuất
                  </p>
                </div>
              </div>
            </div>

            <div className="mt-5 space-y-3 border-t border-[var(--sf-ink-700)] pt-5">
              <p className="text-[13px] font-extrabold text-[var(--sf-ink-100)]">Đổi mật khẩu</p>
              <PasswordInput label="Mật khẩu hiện tại" value={currentPassword} onChange={setCurrentPassword} />
              <PasswordInput label="Mật khẩu mới" value={newPassword} onChange={setNewPassword} />
              <PasswordInput label="Nhập lại mật khẩu mới" value={confirmPassword} onChange={setConfirmPassword} />
              <Button
                size="sm"
                block
                loading={savingPassword}
                disabled={!currentPassword || !newPassword || !confirmPassword}
                onClick={() => void changePassword()}
              >
                Cập nhật mật khẩu
              </Button>
            </div>
          </Card>
        </Reveal>
      </div>
    </div>
  );
}

function PasswordInput({ label, value, onChange }: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="block space-y-1.5 text-[12px] font-semibold text-[var(--sf-ink-300)]">
      {label}
      <input
        className="sf-input border-[var(--sf-ink-700)] bg-[var(--sf-ink-950)] text-[var(--sf-ink-50)]"
        type="password"
        autoComplete="new-password"
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
    </label>
  );
}
