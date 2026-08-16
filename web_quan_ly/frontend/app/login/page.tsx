"use client";

import { useRef, useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import {
  Shield,
  Eye,
  EyeOff,
  ArrowRight,
  ArrowDown,
  User,
  Lock,
  ScanFace,
  Siren,
  Droplets,
  MapPinned,
  Route,
  BarChart3,
  Check,
  type LucideIcon,
} from "lucide-react";
import FleetCanvas from "@/components/auth/FleetCanvas";
import ThemeSwitch from "@/components/layout/ThemeSwitch";

const SHOW_DEMO_CREDENTIALS = process.env.NEXT_PUBLIC_SHOW_DEMO_CREDENTIALS === "true";

/* ==========================================================================
   MÀN 1 — ĐĂNG NHẬP (tối giản, tương phản cao)
   ========================================================================== */

export default function LoginPage() {
  const { login, isLoading } = useAuth();
  const { showToast } = useToast();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [remember, setRemember] = useState(false);

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
    <div className="sf-auth-page min-h-screen">
      {/* ===== Thanh trên ===== */}
      <header className="sticky top-0 z-30 border-b border-[var(--sf-border)] bg-[var(--sf-bg-elevated)]/95 backdrop-blur-lg">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-5 py-3.5 sm:px-8">
          <div className="flex items-center gap-3">
            <span
              className="grid h-10 w-10 flex-shrink-0 place-items-center rounded-[var(--sf-r-sm)]"
              style={{ background: "var(--sf-primary)" }}
            >
              <Shield className="h-5 w-5" style={{ color: "var(--sf-primary-contrast)" }} />
            </span>
            <span>
              <span className="block text-[16px] font-extrabold leading-tight tracking-tight text-sf-text">
                SafeFleet
              </span>
              <span
                className="block text-[12.5px] font-bold leading-tight"
                style={{ color: "var(--sf-primary)" }}
              >
                Command Center
              </span>
            </span>
          </div>

          <ThemeSwitch />
        </div>
      </header>

      {/* ===== MÀN 1 ===== */}
      <section className="sf-auth-hero flex min-h-[calc(100vh-4.5rem)] flex-col items-center justify-center px-5 py-12">
        <div className="w-full max-w-[26rem]">
          <div className="mb-7 text-center">
            <h1 className="text-[30px] font-black leading-tight tracking-tight text-sf-text">
              Đăng nhập
            </h1>
            <p className="mt-2.5 text-[15px] leading-relaxed text-sf-text-secondary">
              Truy cập trung tâm điều hành đội xe SafeFleet.
            </p>
          </div>

          {/* Thẻ đăng nhập — nền đặc, viền rõ, không có hoạ tiết phía dưới */}
          <div
            className="rounded-[var(--sf-r-lg)] border p-6 sm:p-7"
            style={{
              background: "var(--sf-bg-card)",
              borderColor: "var(--sf-border-strong)",
              boxShadow: "var(--sf-shadow-md)",
            }}
          >
            <form onSubmit={handleSubmit} className="space-y-4">
              <TextField
                id="login-username"
                label="Username hoặc email"
                icon={User}
                value={username}
                onChange={setUsername}
                autoComplete="username"
                placeholder="admin"
              />

              <TextField
                id="login-password"
                label="Mật khẩu"
                icon={Lock}
                value={password}
                onChange={setPassword}
                type={showPassword ? "text" : "password"}
                autoComplete="current-password"
                placeholder="Nhập mật khẩu"
                trailing={
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                    className="grid h-9 w-9 place-items-center rounded-[var(--sf-r-xs)] text-sf-text-secondary transition-colors hover:bg-[var(--sf-bg-inset)] hover:text-sf-text cursor-pointer"
                  >
                    {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                  </button>
                }
              />

              <div className="flex flex-wrap items-center justify-between gap-3 pt-0.5">
                <button
                  type="button"
                  onClick={() => setRemember(!remember)}
                  aria-pressed={remember}
                  className="group flex items-center gap-2.5 cursor-pointer"
                >
                  <span
                    className="grid h-5 w-5 flex-shrink-0 place-items-center rounded-[5px] border-2 transition-colors duration-[var(--sf-dur-fast)]"
                    style={{
                      borderColor: remember ? "var(--sf-primary)" : "var(--sf-border-strong)",
                      background: remember ? "var(--sf-primary)" : "transparent",
                    }}
                  >
                    {remember && (
                      <Check
                        className="h-3.5 w-3.5"
                        strokeWidth={3.5}
                        style={{ color: "var(--sf-primary-contrast)" }}
                      />
                    )}
                  </span>
                  <span className="text-[14px] font-semibold text-sf-text-secondary group-hover:text-sf-text">
                    Ghi nhớ đăng nhập
                  </span>
                </button>

                <button
                  type="button"
                  className="text-[14px] font-bold underline-offset-4 hover:underline cursor-pointer"
                  style={{ color: "var(--sf-primary)" }}
                >
                  Quên mật khẩu?
                </button>
              </div>

              <button
                type="submit"
                disabled={isLoading}
                className="mt-1 flex w-full items-center justify-center gap-2.5 rounded-[var(--sf-r-md)] text-[15px] font-extrabold tracking-tight transition-[filter,transform] duration-[var(--sf-dur-fast)] hover:brightness-110 active:scale-[0.99] disabled:pointer-events-none disabled:opacity-60 cursor-pointer"
                style={{
                  height: "3.25rem",
                  background: "var(--sf-primary)",
                  color: "var(--sf-primary-contrast)",
                }}
              >
                {isLoading ? (
                  <>
                    <span
                      aria-hidden
                      className="h-4 w-4 animate-sf-spin rounded-full border-2 border-current border-t-transparent"
                    />
                    Đang xác thực…
                  </>
                ) : (
                  <>
                    Đăng nhập
                    <ArrowRight className="h-[18px] w-[18px]" />
                  </>
                )}
              </button>
            </form>

            {SHOW_DEMO_CREDENTIALS && (
              <div
                className="mt-5 rounded-[var(--sf-r-md)] border p-4"
                style={{
                  background: "var(--sf-bg-inset)",
                  borderColor: "var(--sf-border)",
                }}
              >
                <p className="mb-2 text-[13px] font-bold text-sf-text">Tài khoản seed backend</p>
                <div className="space-y-1.5 text-[13px] text-sf-text-secondary">
                  <p>
                    <Code>admin</Code> / <Code>123456</Code> — Quản trị viên
                  </p>
                  <p>
                    <Code>dispatcher</Code> / <Code>123456</Code> — Điều phối viên
                  </p>
                </div>
              </div>
            )}
          </div>

          {/* Gợi ý cuộn xuống */}
          <div className="mt-9 flex justify-center">
            <a
              href="#tinh-nang"
              className="flex items-center gap-2 rounded-[var(--sf-r-pill)] border px-4 py-2.5 text-[14px] font-bold transition-colors hover:bg-[var(--sf-bg-inset)]"
              style={{ borderColor: "var(--sf-border-strong)", color: "var(--sf-text-secondary)" }}
            >
              Hệ thống làm được gì
              <ArrowDown className="h-4 w-4" />
            </a>
          </div>
        </div>
      </section>

      {/* ===== MÀN 2 — TÍNH NĂNG ===== */}
      <FeaturesSection />

      {/* ===== MÀN 3 — QUY TRÌNH ===== */}
      <FlowSection />

      <footer className="border-t border-[var(--sf-border)] px-5 py-6 sm:px-8">
        <p className="mx-auto max-w-6xl text-center text-[13px] text-sf-text-muted">
          © 2026 SafeFleet Agentic AI — Hệ thống cảnh báo và hỗ trợ tài xế
        </p>
      </footer>
    </div>
  );
}

/* ==========================================================================
   MÀN 2 — TÍNH NĂNG
   ========================================================================== */

const FEATURES: { icon: LucideIcon; title: string; body: string }[] = [
  {
    icon: ScanFace,
    title: "AI giám sát cabin",
    body: "Camera trong cabin phát hiện ngủ gật, mất tập trung và dùng điện thoại, gửi cảnh báo về trung tâm ngay khi xảy ra.",
  },
  {
    icon: MapPinned,
    title: "Theo dõi realtime",
    body: "Vị trí, tốc độ và trạng thái kết nối của từng xe cập nhật liên tục trên bản đồ điều hành.",
  },
  {
    icon: Siren,
    title: "Điều phối SOS",
    body: "Tài xế bấm SOS là sự cố hiện lên phòng xử lý kèm vị trí, nhật ký thao tác và luồng giao cứu hộ.",
  },
  {
    icon: Droplets,
    title: "Cảnh báo điểm ngập",
    body: "Tổng hợp báo cáo ngập từ tài xế và cảm biến, chấm điểm rủi ro tuyến trước khi xe xuất phát.",
  },
  {
    icon: Route,
    title: "Điều phối chuyến",
    body: "Gợi ý ghép xe và tài xế theo điểm an toàn, kèm phiếu xuất kho điện tử chuyển thẳng sang app tài xế.",
  },
  {
    icon: BarChart3,
    title: "Báo cáo vận hành",
    body: "Thống kê cảnh báo theo loại, số chuyến theo ngày và danh sách tài xế rủi ro cao, xuất được ra CSV.",
  },
];

function FeaturesSection() {
  return (
    <section
      id="tinh-nang"
      className="border-t border-[var(--sf-border)] px-5 py-16 sm:px-8 sm:py-20"
      style={{ background: "var(--sf-bg-card)" }}
    >
      <div className="mx-auto max-w-6xl">
        <div className="mb-10 max-w-2xl">
          <p
            className="mb-3 text-[13px] font-extrabold uppercase tracking-[0.14em]"
            style={{ color: "var(--sf-primary)" }}
          >
            Tính năng
          </p>
          <h2 className="text-[30px] font-black leading-tight tracking-tight text-sf-text sm:text-[36px]">
            Sáu nhóm chức năng chính
          </h2>
          <p className="mt-3.5 text-[16px] leading-relaxed text-sf-text-secondary">
            Toàn bộ dữ liệu đến từ backend Spring Boot qua REST và WebSocket, không dùng số liệu
            minh hoạ.
          </p>
        </div>

        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => {
            const Icon = f.icon;
            return (
              <article
                key={f.title}
                className="rounded-[var(--sf-r-lg)] border p-6 transition-[border-color,transform] duration-[var(--sf-dur-base)] hover:-translate-y-1"
                style={{
                  background: "var(--sf-bg-elevated)",
                  borderColor: "var(--sf-border)",
                }}
              >
                <span
                  className="mb-4 grid h-12 w-12 place-items-center rounded-[var(--sf-r-md)]"
                  style={{ background: "var(--sf-primary-soft)", color: "var(--sf-primary)" }}
                >
                  <Icon className="h-6 w-6" />
                </span>
                <h3 className="text-[18px] font-extrabold tracking-tight text-sf-text">
                  {f.title}
                </h3>
                <p className="mt-2 text-[15px] leading-relaxed text-sf-text-secondary">{f.body}</p>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   MÀN 3 — QUY TRÌNH + HÌNH MINH HOẠ
   ========================================================================== */

const STEPS = [
  {
    step: "01",
    title: "Thu thập",
    body: "Thiết bị GPS, camera cabin và app tài xế gửi telemetry về backend liên tục.",
  },
  {
    step: "02",
    title: "Phân tích",
    body: "Mô hình AI chấm điểm hành vi lái, đối chiếu giờ lái liên tục và dữ liệu điểm ngập.",
  },
  {
    step: "03",
    title: "Xử lý",
    body: "Điều phối viên nhận cảnh báo trên trung tâm điều hành và giao việc cho đội cứu hộ.",
  },
];

function FlowSection() {
  return (
    <section className="border-t border-[var(--sf-border)] px-5 py-16 sm:px-8 sm:py-20">
      <div className="mx-auto max-w-6xl">
        <div className="mb-10 max-w-2xl">
          <p
            className="mb-3 text-[13px] font-extrabold uppercase tracking-[0.14em]"
            style={{ color: "var(--sf-primary)" }}
          >
            Quy trình
          </p>
          <h2 className="text-[30px] font-black leading-tight tracking-tight text-sf-text sm:text-[36px]">
            Từ tín hiệu ngoài đường tới thao tác xử lý
          </h2>
        </div>

        <div className="grid gap-5 lg:grid-cols-3">
          {STEPS.map((s) => (
            <article
              key={s.step}
              className="rounded-[var(--sf-r-lg)] border p-6"
              style={{ background: "var(--sf-bg-card)", borderColor: "var(--sf-border)" }}
            >
              <span
                className="text-[13px] font-black tracking-wider"
                style={{ color: "var(--sf-primary)" }}
              >
                {s.step}
              </span>
              <h3 className="mt-2 text-[18px] font-extrabold tracking-tight text-sf-text">
                {s.title}
              </h3>
              <p className="mt-2 text-[15px] leading-relaxed text-sf-text-secondary">{s.body}</p>
            </article>
          ))}
        </div>

        {/* Hình minh hoạ động — nằm trong khung riêng, không có chữ đè lên */}
        <figure className="mt-10">
          <div className="sf-visual-frame h-[16rem] sm:h-[20rem]">
            <FleetCanvas className="h-full w-full" />
          </div>
          <figcaption className="mt-3 text-[14px] text-sf-text-muted">
            Mô phỏng mạng lưới tuyến đường: chấm teal là xe đang chạy, nét đứt vàng là luồng
            telemetry, vòng đỏ là điểm phát tín hiệu SOS.
          </figcaption>
        </figure>

        <div className="mt-10 flex justify-center">
          <a
            href="#top"
            onClick={(e) => {
              e.preventDefault();
              window.scrollTo({ top: 0, behavior: "smooth" });
            }}
            className="flex items-center gap-2 rounded-[var(--sf-r-md)] px-6 py-3.5 text-[15px] font-extrabold transition-[filter] hover:brightness-110"
            style={{ background: "var(--sf-primary)", color: "var(--sf-primary-contrast)" }}
          >
            Quay lại đăng nhập
            <ArrowRight className="h-[18px] w-[18px]" />
          </a>
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   THÀNH PHẦN PHỤ
   ========================================================================== */

function TextField({
  id,
  label,
  icon: Icon,
  value,
  onChange,
  type = "text",
  autoComplete,
  placeholder,
  trailing,
}: {
  id: string;
  label: string;
  icon: LucideIcon;
  value: string;
  onChange: (v: string) => void;
  type?: string;
  autoComplete?: string;
  placeholder?: string;
  trailing?: React.ReactNode;
}) {
  const [focused, setFocused] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  return (
    <div>
      <label htmlFor={id} className="mb-2 block text-[14px] font-bold text-sf-text">
        {label}
      </label>
      <div
        className="relative rounded-[var(--sf-r-md)] border-2 transition-[border-color] duration-[var(--sf-dur-fast)]"
        style={{
          background: "var(--sf-bg-inset)",
          borderColor: focused ? "var(--sf-primary)" : "var(--sf-border-strong)",
        }}
        onClick={() => inputRef.current?.focus()}
      >
        <Icon
          className="pointer-events-none absolute left-3.5 top-1/2 h-5 w-5 -translate-y-1/2"
          style={{ color: focused ? "var(--sf-primary)" : "var(--sf-text-muted)" }}
        />
        <input
          ref={inputRef}
          id={id}
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          autoComplete={autoComplete}
          placeholder={placeholder}
          className="w-full border-none bg-transparent pl-12 pr-12 text-[16px] font-semibold text-sf-text placeholder:font-normal placeholder:text-sf-text-muted focus:outline-none"
          style={{ height: "3.25rem" }}
        />
        {trailing && <span className="absolute right-2 top-1/2 -translate-y-1/2">{trailing}</span>}
      </div>
    </div>
  );
}

function Code({ children }: { children: React.ReactNode }) {
  return (
    <span
      className="rounded px-1.5 py-0.5 font-mono text-[13px] font-bold"
      style={{ background: "var(--sf-bg-card)", color: "var(--sf-primary)" }}
    >
      {children}
    </span>
  );
}
