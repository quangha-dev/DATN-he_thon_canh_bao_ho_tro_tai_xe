"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { useTheme } from "@/context/ThemeContext";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { Eye, EyeOff, Lock, Moon, Shield, Sun, User, Zap, ShieldCheck } from "lucide-react";

const SHOW_DEMO_CREDENTIALS = process.env.NEXT_PUBLIC_SHOW_DEMO_CREDENTIALS === "true";

/* ==========================================================================
   ĐĂNG NHẬP — hai cột: dải nhấn tối bên trái, biểu mẫu bên phải
   --------------------------------------------------------------------------
   Bản thiết kế đặt số xe trực tuyến ngay trên dải nhấn. Con số đó lấy từ API
   thật (dashboardStats) chứ không cố định như trong bản thiết kế; khi chưa
   đăng nhập mà API từ chối thì ẩn hẳn dòng đó đi.
   ========================================================================== */

export default function LoginPage() {
  const { login, isLoading } = useAuth();
  const { showToast } = useToast();
  const { resolvedTheme, toggleTheme } = useTheme();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [onlineVehicles, setOnlineVehicles] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    safeFleetApi
      .dashboardStats()
      .then((stats) => {
        if (cancelled) return;
        if (typeof stats.totalOperating === "number") setOnlineVehicles(stats.totalOperating);
      })
      .catch(() => void 0);
    return () => {
      cancelled = true;
    };
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      showToast("Vui lòng nhập đầy đủ thông tin", "warning");
      return;
    }
    try {
      await login(username, password);
      showToast("Đăng nhập thành công!", "success");
    } catch (err: unknown) {
      showToast(err instanceof Error ? err.message : "Đăng nhập thất bại", "error");
    }
  };

  return (
    <div
      className="grid min-h-screen animate-sf-fade lg:grid-cols-[1.05fr_0.95fr]"
      style={{ background: "var(--sf-bg)" }}
    >
      {/* ===================== Cột trái: dải nhấn tối ===================== */}
      <div
        className="relative hidden flex-col justify-between overflow-hidden px-[72px] py-16 lg:flex"
        style={{
          background:
            "radial-gradient(120% 90% at 12% 8%, #0f5f58 0%, #08313a 48%, #061a22 100%)",
          borderRadius: "0 44px 44px 0",
        }}
      >
        <span
          aria-hidden
          className="sf-hero-glow"
          style={{ width: 520, height: 520, right: -160, top: -120 }}
        />
        <span
          aria-hidden
          className="sf-hero-glow"
          style={{
            width: 360,
            height: 360,
            left: -120,
            bottom: -90,
            background: "radial-gradient(circle, rgba(245,158,11,.18), transparent 70%)",
            animationDelay: "0.8s",
          }}
        />

        <div className="relative flex items-center gap-3.5">
          <span
            className="grid h-[46px] w-[46px] place-items-center rounded-2xl"
            style={{
              background: "linear-gradient(150deg,#34d3b5,#087f73)",
              boxShadow: "0 14px 30px -12px rgba(52,211,181,.75)",
            }}
          >
            <Shield className="h-6 w-6" style={{ color: "#04211f" }} />
          </span>
          <div>
            <div className="text-[17px] font-bold tracking-tight" style={{ color: "#eef7f6" }}>
              SafeFleet
            </div>
            <div
              className="text-[11px] uppercase tracking-[0.09em]"
              style={{ color: "rgba(206,232,229,.62)" }}
            >
              Command Suite
            </div>
          </div>
        </div>

        <div className="relative max-w-[460px]">
          <div
            className="mb-[18px] text-[13px] uppercase tracking-[0.1em]"
            style={{ color: "#7fe3cd" }}
          >
            Trung tâm điều hành
          </div>
          <h1
            className="text-[46px] font-bold leading-[1.1] tracking-[-0.02em]"
            style={{ color: "#f4fbfa", textWrap: "pretty" }}
          >
            Nhìn thấy cả đội xe trong một hơi thở.
          </h1>
          <p
            className="mt-5 text-[15px] leading-[1.7]"
            style={{ color: "rgba(206,232,229,.72)", textWrap: "pretty" }}
          >
            Cảnh báo buồn ngủ, điểm ngập, SOS và tiến độ chuyến — tất cả hội tụ trên một mặt bàn
            điều hành duy nhất.
          </p>

          <div className="mt-9 flex flex-wrap gap-3">
            {onlineVehicles != null && (
              <span className="sf-hero-chip backdrop-blur-[8px]">
                <span
                  className="h-[7px] w-[7px] rounded-full animate-sf-pulse-dot"
                  style={{ background: "#34d3b5" }}
                />
                <span className="text-[13px] font-normal" style={{ color: "#d9efec" }}>
                  {onlineVehicles} xe trực tuyến
                </span>
              </span>
            )}
            <span className="sf-hero-chip backdrop-blur-[8px]">
              <Zap className="h-4 w-4" style={{ color: "#ffc74d" }} />
              <span className="text-[13px] font-normal" style={{ color: "#d9efec" }}>
                AI giám sát liên tục
              </span>
            </span>
          </div>
        </div>

        <div
          className="relative flex gap-[26px] text-[12px]"
          style={{ color: "rgba(206,232,229,.5)" }}
        >
          <span>© {new Date().getFullYear()} SafeFleet</span>
          <span>Hỗ trợ 24/7 · 1900 6068</span>
        </div>
      </div>

      {/* ===================== Cột phải: biểu mẫu ===================== */}
      <div className="flex items-center justify-center px-6 py-14 sm:px-16">
        <div className="w-full max-w-[412px] animate-sf-pop">
          <div className="mb-[34px] flex items-center justify-between gap-3">
            <span className="sf-eyebrow">Đăng nhập</span>
            <button
              type="button"
              onClick={toggleTheme}
              title={resolvedTheme === "dark" ? "Chuyển nền sáng" : "Chuyển nền tối"}
              className="grid h-9 w-9 cursor-pointer place-items-center rounded-full border border-[var(--sf-border-card)] bg-[var(--sf-bg-card)] text-sf-text-muted transition-colors hover:text-sf-text"
            >
              {resolvedTheme === "dark" ? (
                <Sun className="h-[18px] w-[18px]" />
              ) : (
                <Moon className="h-[18px] w-[18px]" />
              )}
            </button>
          </div>

          {/* Logo rút gọn cho màn hẹp, khi cột trái bị ẩn */}
          <div className="mb-6 flex items-center gap-3 lg:hidden">
            <span
              className="grid h-10 w-10 place-items-center rounded-[14px]"
              style={{ background: "linear-gradient(150deg,#34d3b5,#087f73)" }}
            >
              <Shield className="h-5 w-5" style={{ color: "#04211f" }} />
            </span>
            <span className="text-[17px] font-bold tracking-tight text-sf-text">SafeFleet</span>
          </div>

          <h2 className="mb-2 text-[30px] font-bold tracking-[-0.02em] text-sf-text">
            Chào mừng trở lại
          </h2>
          <p className="mb-8 text-[14px] text-sf-text-muted">
            Dành cho quản trị viên, quản lý đội xe, điều phối viên và cán bộ an toàn.
          </p>

          <form onSubmit={handleSubmit} className="flex flex-col gap-[18px]">
            <div>
              <label
                htmlFor="login-username"
                className="mb-2 block text-[12.5px] font-semibold text-sf-text-secondary"
              >
                Tài khoản hoặc email
              </label>
              <div className="flex items-center gap-2.5 rounded-2xl border border-[var(--sf-border)] bg-[var(--sf-bg-card)] px-4 py-3.5 shadow-[var(--sf-shadow-xs)] transition-colors focus-within:border-[var(--sf-primary)]">
                <User className="h-[19px] w-[19px] flex-none text-sf-text-muted" />
                <input
                  id="login-username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  autoComplete="username"
                  placeholder="Nhập tài khoản hoặc email"
                  className="min-w-0 flex-1 border-0 bg-transparent text-[14.5px] text-sf-text outline-none placeholder:text-sf-text-muted"
                />
              </div>
            </div>

            <div>
              <label
                htmlFor="login-password"
                className="mb-2 block text-[12.5px] font-semibold text-sf-text-secondary"
              >
                Mật khẩu
              </label>
              <div className="flex items-center gap-2.5 rounded-2xl border border-[var(--sf-border)] bg-[var(--sf-bg-card)] px-4 py-3.5 shadow-[var(--sf-shadow-xs)] transition-colors focus-within:border-[var(--sf-primary)]">
                <Lock className="h-[19px] w-[19px] flex-none text-sf-text-muted" />
                <input
                  id="login-password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  placeholder="Nhập mật khẩu"
                  className="min-w-0 flex-1 border-0 bg-transparent text-[14.5px] text-sf-text outline-none placeholder:text-sf-text-muted"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                  className="grid flex-none cursor-pointer place-items-center text-sf-text-muted transition-colors hover:text-sf-text"
                >
                  {showPassword ? (
                    <EyeOff className="h-[19px] w-[19px]" />
                  ) : (
                    <Eye className="h-[19px] w-[19px]" />
                  )}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="mt-1.5 w-full cursor-pointer rounded-[18px] border-0 py-4 text-[15px] font-semibold tracking-[0.01em] text-white transition-transform duration-[var(--sf-dur-base)] ease-[var(--sf-ease-spring)] hover:-translate-y-0.5 disabled:pointer-events-none disabled:opacity-60"
              style={{
                background: "linear-gradient(140deg,#0b8c7f,#076a61)",
                boxShadow: "0 16px 32px -14px rgba(8,127,115,.7)",
              }}
            >
              {isLoading ? "Đang đăng nhập…" : "Đăng nhập"}
            </button>

            <div className="flex items-center gap-2.5 text-[12px] text-sf-text-muted">
              <ShieldCheck className="h-4 w-4 flex-none" style={{ color: "var(--sf-primary)" }} />
              <span>Phiên đăng nhập được bảo vệ bằng JWT, tự hết hạn sau 8 giờ.</span>
            </div>

            {SHOW_DEMO_CREDENTIALS && (
              <div className="rounded-[18px] bg-[var(--sf-bg-inset)] px-4 py-3.5 text-[12px] leading-relaxed text-sf-text-secondary">
                <p className="mb-1 font-semibold text-sf-text">Tài khoản dùng thử</p>
                <p className="sf-mono">admin / admin123 · dispatcher / dispatcher123</p>
              </div>
            )}
          </form>
        </div>
      </div>
    </div>
  );
}
