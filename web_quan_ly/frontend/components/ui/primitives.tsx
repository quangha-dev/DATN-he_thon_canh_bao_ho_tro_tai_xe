"use client";

/**
 * SafeFleet · Neo-Command UI primitives
 * ---------------------------------------------------------------------------
 * Quy tắc màu: mỗi trang chỉ dùng PRIMARY (teal) + ACCENT (amber) + NEUTRAL.
 * Các tone semantic (success/warning/danger/info) chỉ dành cho tín hiệu trạng
 * thái nhỏ: chấm, badge, viền trái, icon — không dùng làm nền lớn.
 */

import * as React from "react";
import { cn } from "@/lib/utils";
import { ChevronDown, Loader2, Search, X, type LucideIcon } from "lucide-react";

/* ==========================================================================
   TONE SYSTEM
   ========================================================================== */

export type Tone =
  | "primary"
  | "accent"
  | "neutral"
  | "success"
  | "warning"
  | "danger"
  | "info";

interface ToneStyle {
  fg: string;
  bg: string;
  border: string;
  solidBg: string;
  solidFg: string;
  dot: string;
}

export const TONE: Record<Tone, ToneStyle> = {
  primary: {
    fg: "var(--sf-primary)",
    bg: "var(--sf-primary-soft)",
    border: "color-mix(in srgb, var(--sf-primary) 30%, transparent)",
    solidBg: "var(--sf-primary)",
    solidFg: "var(--sf-primary-contrast)",
    dot: "var(--sf-primary)",
  },
  accent: {
    fg: "var(--sf-accent-hover)",
    bg: "var(--sf-accent-soft)",
    border: "color-mix(in srgb, var(--sf-accent) 34%, transparent)",
    solidBg: "var(--sf-accent)",
    solidFg: "var(--sf-accent-contrast)",
    dot: "var(--sf-accent)",
  },
  neutral: {
    fg: "var(--sf-text-secondary)",
    bg: "var(--sf-bg-inset)",
    border: "var(--sf-border)",
    solidBg: "var(--sf-bg-inset)",
    solidFg: "var(--sf-text)",
    dot: "var(--sf-neutral)",
  },
  success: {
    fg: "var(--sf-success)",
    bg: "var(--sf-success-soft)",
    border: "color-mix(in srgb, var(--sf-success) 30%, transparent)",
    solidBg: "var(--sf-success)",
    solidFg: "#04241a",
    dot: "var(--sf-success)",
  },
  warning: {
    fg: "var(--sf-warning)",
    bg: "var(--sf-warning-soft)",
    border: "color-mix(in srgb, var(--sf-warning) 32%, transparent)",
    solidBg: "var(--sf-warning)",
    solidFg: "#2b1a02",
    dot: "var(--sf-warning)",
  },
  danger: {
    fg: "var(--sf-danger)",
    bg: "var(--sf-danger-soft)",
    border: "color-mix(in srgb, var(--sf-danger) 30%, transparent)",
    solidBg: "var(--sf-danger)",
    solidFg: "#ffffff",
    dot: "var(--sf-danger)",
  },
  info: {
    fg: "var(--sf-info)",
    bg: "var(--sf-info-soft)",
    border: "color-mix(in srgb, var(--sf-info) 30%, transparent)",
    solidBg: "var(--sf-info)",
    solidFg: "#ffffff",
    dot: "var(--sf-info)",
  },
};

/** Ánh xạ trạng thái nghiệp vụ → tone. Nguồn chân lý duy nhất cho màu trạng thái. */
export const STATUS_TONE: Record<string, Tone> = {
  // Vehicle
  running: "primary",
  idle: "success",
  maintenance: "warning",
  offline: "neutral",
  // Driver
  driving: "primary",
  available: "success",
  resting: "warning",
  off_duty: "neutral",
  suspended: "danger",
  high_risk: "danger",
  inactive: "neutral",
  // Trip
  pending: "neutral",
  assigned: "info",
  accepted: "info",
  in_progress: "primary",
  paused: "warning",
  completed: "success",
  cancelled: "neutral",
  incident: "danger",
  // Severity
  low: "success",
  medium: "warning",
  high: "warning",
  critical: "danger",
  // Alert status
  new: "danger",
  acknowledged: "warning",
  resolved: "success",
  dismissed: "neutral",
  // Alert status còn thiếu "escalated" trong bản thiết kế gốc — bổ sung để
  // toneOf() phủ hết bốn trạng thái thật của AlertStatus (types/index.ts)
  escalated: "danger",
  // Incident
  open: "danger",
  overdue: "danger",
  // Flood
  light: "info",
  moderate: "warning",
  heavy: "warning",
  impassable: "danger",
  // Device
  active: "success",
  error: "danger",
  // Account
  locked: "danger",
};

export function toneOf(status?: string | null): Tone {
  if (!status) return "neutral";
  return STATUS_TONE[status] ?? "neutral";
}

/* ==========================================================================
   SURFACE / CARD
   ========================================================================== */

type CardProps = React.HTMLAttributes<HTMLDivElement> & {
  /** Bật hiệu ứng nâng khi rê chuột */
  interactive?: boolean;
  /** Tô đặc màu thương hiệu — chỉ dùng cho một thẻ nhấn trên mỗi màn hình */
  filled?: boolean;
  /** @deprecated giữ để không vỡ lời gọi cũ, không còn tác dụng */
  glint?: boolean;
  padding?: "none" | "sm" | "md" | "lg";
  as?: "div" | "section" | "article";
};

export const Card = React.forwardRef<HTMLDivElement, CardProps>(function Card(
  { className, interactive, filled, padding = "md", as: Tag = "div", glint: _glint, ...rest },
  ref
) {
  void _glint;
  const pad =
    padding === "none" ? "" : padding === "sm" ? "p-4" : padding === "lg" ? "p-7" : "p-5";
  return (
    <Tag
      ref={ref as never}
      className={cn(
        filled ? "sf-surface-filled" : "sf-surface",
        "overflow-hidden",
        interactive && "sf-interactive",
        pad,
        className
      )}
      {...rest}
    />
  );
});

export function CardHeader({
  title,
  subtitle,
  icon: Icon,
  action,
  className,
}: {
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  icon?: LucideIcon;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex items-start justify-between gap-3", className)}>
      <div className="flex min-w-0 items-center gap-3">
        {Icon && (
          <span className="sf-icon-chip">
            <Icon className="h-[19px] w-[19px]" />
          </span>
        )}
        <div className="min-w-0">
          <h3 className="truncate text-[15.5px] font-bold tracking-tight text-sf-text">{title}</h3>
          {subtitle && (
            <p className="mt-0.5 truncate text-[12.5px] text-sf-text-muted">{subtitle}</p>
          )}
        </div>
      </div>
      {action && <div className="flex flex-shrink-0 items-center gap-2">{action}</div>}
    </div>
  );
}

/* ==========================================================================
   SECTION TITLE
   ========================================================================== */

export function SectionTitle({
  eyebrow,
  title,
  description,
  action,
  className,
}: {
  eyebrow?: string;
  title: React.ReactNode;
  description?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex flex-wrap items-end justify-between gap-3", className)}>
      <div className="min-w-0">
        {eyebrow && (
          <p className="sf-eyebrow mb-1.5 flex items-center gap-2">
            <span
              className="inline-block h-[3px] w-6 rounded-full"
              style={{ background: "var(--sf-primary)" }}
            />
            {eyebrow}
          </p>
        )}
        <h2 className="text-base font-bold tracking-tight text-sf-text sm:text-lg">{title}</h2>
        {description && <p className="mt-1 text-xs text-sf-text-muted">{description}</p>}
      </div>
      {action && <div className="flex items-center gap-2">{action}</div>}
    </div>
  );
}

/* ==========================================================================
   BUTTON
   ========================================================================== */

type ButtonVariant = "primary" | "accent" | "outline" | "ghost" | "danger" | "subtle";
type ButtonSize = "xs" | "sm" | "md" | "lg";

const BTN_SIZE: Record<ButtonSize, string> = {
  xs: "h-8 px-3 text-[12px] gap-1.5 rounded-[var(--sf-r-xs)]",
  sm: "h-10 px-4 text-[13px] gap-2 rounded-[var(--sf-r-sm)]",
  md: "h-11 px-5 text-[14px] gap-2 rounded-[var(--sf-r-sm)]",
  lg: "h-13 px-7 text-[15px] gap-2.5 rounded-[var(--sf-r-md)]",
};

export type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
  icon?: LucideIcon;
  iconRight?: LucideIcon;
  loading?: boolean;
  block?: boolean;
};

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    className,
    variant = "primary",
    size = "md",
    icon: Icon,
    iconRight: IconRight,
    loading,
    block,
    disabled,
    children,
    style,
    ...rest
  },
  ref
) {
  const base =
    "relative inline-flex items-center justify-center font-bold tracking-tight " +
    "transition-[transform,box-shadow,background-color,border-color,color,filter] duration-[var(--sf-dur-fast)] " +
    "ease-[var(--sf-ease-out)] active:scale-[0.98] disabled:pointer-events-none disabled:opacity-45 " +
    "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sf-primary cursor-pointer whitespace-nowrap";

  const variants: Record<ButtonVariant, string> = {
    primary:
      "text-[var(--sf-primary-contrast)] bg-[var(--sf-primary)] hover:brightness-110 " +
      "shadow-[0_8px_20px_-8px_rgba(var(--sf-primary-rgb),0.6)]",
    accent:
      "text-[var(--sf-accent-contrast)] bg-[var(--sf-accent)] hover:brightness-105 " +
      "shadow-[0_8px_20px_-8px_rgba(var(--sf-accent-rgb),0.55)]",
    outline:
      "text-sf-text bg-[var(--sf-bg-card)] border border-[var(--sf-border)] " +
      "hover:border-[var(--sf-primary)] hover:text-[var(--sf-primary)]",
    subtle:
      "text-sf-text-secondary bg-[var(--sf-bg-inset)] hover:text-sf-text " +
      "hover:bg-[var(--sf-primary-soft)]",
    ghost: "text-sf-text-secondary hover:text-sf-text hover:bg-[var(--sf-bg-inset)]",
    danger:
      "text-white bg-[var(--sf-danger)] hover:brightness-110 " +
      "shadow-[0_8px_20px_-8px_rgba(229,72,77,0.55)]",
  };

  return (
    <button
      ref={ref}
      disabled={disabled || loading}
      className={cn(base, BTN_SIZE[size], variants[variant], block && "w-full", className)}
      style={style}
      {...rest}
    >
      {loading ? (
        <Loader2 className="h-[15px] w-[15px] animate-sf-spin" />
      ) : (
        Icon && <Icon className={size === "xs" ? "h-3.5 w-3.5" : "h-4 w-4"} />
      )}
      {children}
      {IconRight && !loading && (
        <IconRight className={size === "xs" ? "h-3.5 w-3.5" : "h-4 w-4"} />
      )}
    </button>
  );
});

/** Nút chỉ có icon */
export function IconButton({
  icon: Icon,
  label,
  tone = "neutral",
  size = "md",
  className,
  ...rest
}: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  icon: LucideIcon;
  label: string;
  tone?: Tone;
  size?: "sm" | "md";
}) {
  const dims = size === "sm" ? "h-8 w-8" : "h-9 w-9";
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      className={cn(
        dims,
        "grid place-items-center rounded-[var(--sf-r-sm)] text-sf-text-muted",
        "transition-[background-color,color,transform] duration-[var(--sf-dur-fast)]",
        "hover:bg-[var(--sf-bg-inset)] active:scale-90 cursor-pointer",
        className
      )}
      style={{ ["--hover-fg" as string]: TONE[tone].fg }}
      onMouseEnter={(e) => (e.currentTarget.style.color = TONE[tone].fg)}
      onMouseLeave={(e) => (e.currentTarget.style.color = "")}
      {...rest}
    >
      <Icon className={size === "sm" ? "h-4 w-4" : "h-[18px] w-[18px]"} />
    </button>
  );
}

/* ==========================================================================
   BADGE / STATUS DOT
   ========================================================================== */

export function Badge({
  tone = "neutral",
  children,
  icon: Icon,
  solid,
  dot,
  className,
  size = "md",
}: {
  tone?: Tone;
  children: React.ReactNode;
  icon?: LucideIcon;
  solid?: boolean;
  /** Chấm màu đứng trước chữ — kiểu huy hiệu mặc định của bản thiết kế */
  dot?: boolean;
  className?: string;
  size?: "sm" | "md";
}) {
  const t = TONE[tone];
  return (
    <span
      className={cn(
        "inline-flex max-w-full min-w-0 items-center gap-[7px] overflow-hidden rounded-[var(--sf-r-pill)] font-bold tracking-[0.02em] whitespace-nowrap",
        size === "sm" ? "px-2.5 py-1 text-[11px]" : "px-3 py-1.5 text-[11.5px]",
        className
      )}
      style={{
        color: solid ? t.solidFg : t.fg,
        background: solid ? t.solidBg : t.bg,
      }}
    >
      {dot && (
        <span
          aria-hidden
          className="h-1.5 w-1.5 flex-shrink-0 rounded-full"
          style={{ background: solid ? t.solidFg : t.fg }}
        />
      )}
      {Icon && <Icon className="h-3 w-3" />}
      <span className="min-w-0 truncate">{children}</span>
    </span>
  );
}

export function StatusDot({
  tone = "neutral",
  pulse,
  className,
}: {
  tone?: Tone;
  pulse?: boolean;
  className?: string;
}) {
  return (
    <span className={cn("relative inline-flex h-2 w-2 flex-shrink-0", className)}>
      {pulse && (
        <span
          className="absolute inline-flex h-full w-full rounded-full opacity-70 animate-sf-pulse-dot"
          style={{ background: TONE[tone].dot }}
        />
      )}
      <span
        className="relative inline-flex h-2 w-2 rounded-full"
        style={{ background: TONE[tone].dot }}
      />
    </span>
  );
}

/** Nhãn trạng thái = chấm + chữ. Dùng thay cho badge khi cần đọc nhanh trong bảng. */
export function StatusLabel({
  status,
  label,
  pulse,
  className,
}: {
  status?: string;
  label: React.ReactNode;
  pulse?: boolean;
  className?: string;
}) {
  const tone = toneOf(status);
  return (
    <span className={cn("inline-flex items-center gap-2 text-xs font-semibold", className)}>
      <StatusDot tone={tone} pulse={pulse} />
      <span className="text-sf-text-secondary">{label}</span>
    </span>
  );
}

/* ==========================================================================
   COUNT UP — số liệu chạy dần khi vào màn hình
   ========================================================================== */

export function CountUp({
  value,
  duration = 900,
  decimals = 0,
  suffix = "",
  className,
}: {
  value: number;
  duration?: number;
  decimals?: number;
  suffix?: string;
  className?: string;
}) {
  const [display, setDisplay] = React.useState(0);
  const fromRef = React.useRef(0);

  React.useEffect(() => {
    if (typeof window === "undefined") return;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const from = fromRef.current;
    const target = Number.isFinite(value) ? value : 0;
    if (reduce || from === target) {
      fromRef.current = target;
      setDisplay(target);
      return;
    }
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const p = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - p, 3);
      setDisplay(from + (target - from) * eased);
      if (p < 1) raf = requestAnimationFrame(tick);
      else fromRef.current = target;
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [value, duration]);

  return (
    <span className={cn("sf-tnum", className)}>
      {display.toLocaleString("vi-VN", {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals,
      })}
      {suffix}
    </span>
  );
}

/* ==========================================================================
   STAT CARD
   ========================================================================== */

/**
 * StatCard — bố cục theo phong cách bảng điều khiển mềm:
 *   [ô icon]                    [bộ chọn kỳ]
 *   nhãn
 *   số liệu lớn   +delta
 *   gợi ý
 *
 * `filled` tô đặc màu thương hiệu, dùng cho đúng một thẻ nhấn mỗi màn hình.
 */
export function StatCard({
  label,
  value,
  icon: Icon,
  tone = "neutral",
  hint,
  suffix,
  decimals,
  delta,
  deltaDown,
  deltaTone,
  trailing,
  filled,
  pulse,
  onClick,
  active,
  delay = 0,
  className,
}: {
  label: string;
  value: number | string;
  icon?: LucideIcon;
  tone?: Tone;
  hint?: React.ReactNode;
  suffix?: string;
  decimals?: number;
  /** Chú thích cạnh số liệu, ví dụ "+2 tháng này" hoặc "73% đội" */
  delta?: string;
  deltaDown?: boolean;
  /** Ép màu chú thích theo tone thay vì mặc định xanh/đỏ */
  deltaTone?: Tone;
  /** Nội dung góc phải trên, thường là bộ chọn kỳ */
  trailing?: React.ReactNode;
  filled?: boolean;
  pulse?: boolean;
  onClick?: () => void;
  active?: boolean;
  /** Độ trễ hoạt ảnh xuất hiện (ms) */
  delay?: number;
  className?: string;
}) {
  const t = TONE[tone];
  const Comp = onClick ? "button" : "div";

  const chipStyle: React.CSSProperties = filled
    ? { background: "rgba(255,255,255,0.14)", color: "#a7ecdc" }
    : { background: t.bg, color: t.fg };

  const deltaColor = filled
    ? "#7fe3cd"
    : deltaTone
      ? TONE[deltaTone].fg
      : delta && deltaDown
        ? "var(--sf-danger)"
        : delta
          ? "var(--sf-text-muted)"
          : undefined;

  return (
    <Comp
      onClick={onClick}
      type={onClick ? "button" : undefined}
      className={cn(
        filled ? "sf-surface-filled" : "sf-surface",
        "group relative overflow-hidden px-5 py-5 text-left animate-sf-pop",
        onClick && "cursor-pointer",
        className
      )}
      style={{
        animationDelay: `${delay}ms`,
        ...(active && !filled
          ? { boxShadow: `inset 0 0 0 1.5px ${t.fg}, var(--sf-shadow-md)` }
          : {}),
      }}
    >
      {/* Hàng trên: nhãn bên trái, ô icon bên phải */}
      <div className="flex items-center justify-between gap-3">
        <span
          className="truncate text-[12px] tracking-[0.02em]"
          style={{ color: filled ? "rgba(190,238,229,.75)" : "var(--sf-text-muted)" }}
        >
          {label}
        </span>
        {trailing ??
          (Icon && (
            <span
              className="grid h-8 w-8 flex-shrink-0 place-items-center rounded-[12px] transition-transform duration-[var(--sf-dur-base)] ease-[var(--sf-ease-spring)] group-hover:scale-105"
              style={chipStyle}
            >
              <Icon className="h-[18px] w-[18px]" />
            </span>
          ))}
      </div>

      {/* Số liệu + chú thích */}
      <div className="mt-3.5 flex flex-wrap items-baseline gap-2">
        <span
          className="sf-metric text-[29px]"
          style={filled ? { color: "#ffffff" } : undefined}
        >
          {typeof value === "number" ? (
            <CountUp value={value} suffix={suffix} decimals={decimals} />
          ) : (
            value
          )}
        </span>
        {delta && (
          <span className="text-[12px]" style={{ color: deltaColor }}>
            {delta}
          </span>
        )}
      </div>

      {hint && (
        <p
          className="mt-1.5 truncate text-[12px]"
          style={{ color: filled ? "rgba(206,232,229,.72)" : "var(--sf-text-muted)" }}
        >
          {hint}
        </p>
      )}

      {pulse && typeof value === "number" && value > 0 && !filled && (
        <span
          aria-hidden
          className="absolute bottom-0 left-0 h-[3px] w-full animate-sf-breathe"
          style={{ background: t.dot }}
        />
      )}
    </Comp>
  );
}

/* ==========================================================================
   TOOLBAR / SEARCH / SELECT / SEGMENTED
   ========================================================================== */

export function Toolbar({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "sf-surface flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between",
        className
      )}
    >
      {children}
    </div>
  );
}

/** Bộ chọn kỳ nhỏ ở góc thẻ thống kê — kiểu "Tuần này ⌄" */
export function PeriodSelect({
  value,
  onChange,
  options = [
    { value: "week", label: "Tuần này" },
    { value: "month", label: "Tháng này" },
    { value: "quarter", label: "Quý này" },
  ],
  onFilled,
}: {
  value: string;
  onChange: (v: string) => void;
  options?: { value: string; label: string }[];
  /** Đặt true khi nằm trong thẻ tô đặc để đảo màu chữ */
  onFilled?: boolean;
}) {
  return (
    <div className="relative">
      <select
        aria-label="Chọn khoảng thời gian"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="cursor-pointer appearance-none rounded-[var(--sf-r-xs)] bg-transparent py-1 pl-2 pr-6 text-[12.5px] font-semibold focus:outline-none"
        style={{ color: onFilled ? "rgba(255,255,255,0.86)" : "var(--sf-text-muted)" }}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <ChevronDown
        aria-hidden
        className="pointer-events-none absolute right-1 top-1/2 h-3.5 w-3.5 -translate-y-1/2"
        style={{ color: onFilled ? "rgba(255,255,255,0.8)" : "var(--sf-text-muted)" }}
      />
    </div>
  );
}

export function SearchInput({
  value,
  onChange,
  placeholder = "Tìm kiếm...",
  className,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  className?: string;
}) {
  return (
    <div className={cn("relative min-w-0 flex-1", className)}>
      <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-sf-text-muted" />
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="sf-input pl-9 pr-9"
      />
      {value && (
        <button
          type="button"
          onClick={() => onChange("")}
          aria-label="Xóa tìm kiếm"
          className="absolute right-2.5 top-1/2 grid h-5 w-5 -translate-y-1/2 place-items-center rounded-full text-sf-text-muted transition-colors hover:bg-[var(--sf-border)] hover:text-sf-text cursor-pointer"
        >
          <X className="h-3 w-3" />
        </button>
      )}
    </div>
  );
}

export function Select({
  value,
  onChange,
  options,
  className,
  ariaLabel,
}: {
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
  className?: string;
  ariaLabel?: string;
}) {
  return (
    <select
      aria-label={ariaLabel}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className={cn("sf-input sf-select h-10 !w-auto min-w-[9rem] flex-none font-semibold cursor-pointer", className)}
    >
      {options.map((o) => (
        <option key={o.value} value={o.value}>
          {o.label}
        </option>
      ))}
    </select>
  );
}

/** Bộ lọc dạng phân đoạn với con trượt nền chạy theo lựa chọn */
export function Segmented<T extends string>({
  value,
  onChange,
  options,
  className,
  size = "md",
}: {
  value: T;
  onChange: (v: T) => void;
  options: { value: T; label: string; count?: number }[];
  className?: string;
  size?: "sm" | "md";
}) {
  const containerRef = React.useRef<HTMLDivElement>(null);
  const [indicator, setIndicator] = React.useState<{ left: number; width: number } | null>(null);

  const sync = React.useCallback(() => {
    const el = containerRef.current?.querySelector<HTMLElement>(`[data-seg="${value}"]`);
    if (el) setIndicator({ left: el.offsetLeft, width: el.offsetWidth });
  }, [value]);

  React.useEffect(() => {
    sync();
    const ro = new ResizeObserver(sync);
    if (containerRef.current) ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, [sync]);

  return (
    <div
      ref={containerRef}
      className={cn(
        "relative inline-flex flex-shrink-0 items-center gap-0.5 rounded-[var(--sf-r-sm)] border border-[var(--sf-border-light)] bg-[var(--sf-bg-inset)] p-1",
        className
      )}
    >
      {indicator && (
        <span
          aria-hidden
          className="absolute top-1 bottom-1 rounded-[var(--sf-r-xs)] bg-[var(--sf-bg-card)] shadow-[var(--sf-shadow-xs)] transition-all duration-[var(--sf-dur-base)] ease-[var(--sf-ease-spring)]"
          style={{ left: indicator.left, width: indicator.width }}
        />
      )}
      {options.map((o) => {
        const active = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            data-seg={o.value}
            onClick={() => onChange(o.value)}
            className={cn(
              "relative z-10 flex items-center gap-1.5 whitespace-nowrap rounded-[var(--sf-r-xs)] font-bold transition-colors duration-[var(--sf-dur-fast)] cursor-pointer",
              size === "sm" ? "px-2.5 py-1 text-[12px]" : "px-3 py-1.5 text-[12.5px]",
              active ? "text-sf-text" : "text-sf-text-muted hover:text-sf-text-secondary"
            )}
          >
            {o.label}
            {typeof o.count === "number" && (
              <span
                className={cn(
                  "sf-tnum rounded-full px-1.5 py-px text-[12.5px] font-extrabold",
                  active ? "text-[var(--sf-primary)]" : "text-sf-text-muted"
                )}
                style={{ background: active ? "var(--sf-primary-soft)" : "transparent" }}
              >
                {o.count}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

/** Ô nhập có nhãn */
export function Field({
  label,
  hint,
  children,
  className,
}: {
  label: string;
  hint?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <label className={cn("block", className)}>
      <span className="mb-1.5 block text-[12.5px] font-bold text-sf-text-secondary">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-[12px] text-sf-text-muted">{hint}</span>}
    </label>
  );
}

export const TextInput = React.forwardRef<
  HTMLInputElement,
  React.InputHTMLAttributes<HTMLInputElement> & { mono?: boolean }
>(function TextInput({ className, mono, ...rest }, ref) {
  return <input ref={ref} className={cn("sf-input", mono && "font-mono", className)} {...rest} />;
});

/** Công tắc bật/tắt */
export function Switch({
  checked,
  onChange,
  label,
  description,
  className,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: string;
  description?: string;
  className?: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={cn(
        "sf-inset flex w-full items-center justify-between gap-4 p-3 text-left transition-colors duration-[var(--sf-dur-fast)] hover:border-[var(--sf-border-strong)] cursor-pointer",
        className
      )}
    >
      <span className="min-w-0">
        <span className="block text-[12.5px] font-bold text-sf-text">{label}</span>
        {description && (
          <span className="mt-0.5 block text-[12px] leading-snug text-sf-text-muted">
            {description}
          </span>
        )}
      </span>
      <span
        className="relative inline-flex h-[22px] w-[38px] flex-shrink-0 items-center rounded-full transition-colors duration-[var(--sf-dur-base)]"
        style={{ background: checked ? "var(--sf-primary)" : "var(--sf-border-strong)" }}
      >
        <span
          className="absolute h-[18px] w-[18px] rounded-full bg-white shadow-sm transition-transform duration-[var(--sf-dur-base)] ease-[var(--sf-ease-spring)]"
          style={{ transform: checked ? "translateX(18px)" : "translateX(2px)" }}
        />
      </span>
    </button>
  );
}

/* ==========================================================================
   TABLE
   ========================================================================== */

export function TableShell({
  children,
  loading,
  className,
}: {
  children: React.ReactNode;
  loading?: boolean;
  className?: string;
}) {
  return (
    <div className={cn("sf-surface overflow-hidden", className)}>
      {loading && <div className="sf-scanline h-0.5 w-full bg-[var(--sf-border-light)]" />}
      <div className="overflow-x-auto">{children}</div>
    </div>
  );
}

export function Table({
  head,
  children,
  className,
}: {
  head: React.ReactNode[];
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <table className={cn("w-full border-collapse text-left", className)}>
      <thead>
        <tr className="border-b border-[var(--sf-border-light)]">
          {head.map((h, i) => (
            <th
              key={i}
              className="whitespace-nowrap px-4 py-3.5 text-left text-[12.5px] font-semibold text-sf-text-muted first:pl-6 last:pr-6"
            >
              {h}
            </th>
          ))}
        </tr>
      </thead>
      <tbody className="divide-y divide-[var(--sf-border-light)]">{children}</tbody>
    </table>
  );
}

export function Tr({
  children,
  onClick,
  className,
}: {
  children: React.ReactNode;
  onClick?: () => void;
  className?: string;
}) {
  return (
    <tr
      onClick={onClick}
      className={cn(
        "group transition-colors duration-[var(--sf-dur-fast)] hover:bg-[var(--sf-bg-inset)]",
        onClick && "cursor-pointer",
        className
      )}
    >
      {children}
    </tr>
  );
}

export function Td({
  children,
  className,
  align,
  colSpan,
}: {
  children?: React.ReactNode;
  className?: string;
  align?: "left" | "center" | "right";
  colSpan?: number;
}) {
  return (
    <td
      colSpan={colSpan}
      className={cn(
        "px-4 py-3.5 text-[13px] text-sf-text-secondary first:pl-6 last:pr-6",
        align === "center" && "text-center",
        align === "right" && "text-right",
        className
      )}
    >
      {children}
    </td>
  );
}

/* ==========================================================================
   EMPTY / LOADING STATES
   ========================================================================== */

/** Trạng thái rỗng: vòng tròn lớn màu nhạt, tiêu đề rõ, mô tả và nút hành động. */
export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
  className,
  compact,
}: {
  icon?: LucideIcon;
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
  compact?: boolean;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center px-6 text-center",
        compact ? "gap-2.5 py-9" : "gap-3.5 py-14",
        className
      )}
    >
      {Icon && (
        <span
          className={cn(
            "grid place-items-center rounded-full",
            compact ? "h-16 w-16" : "h-28 w-28"
          )}
          style={{ background: "var(--sf-primary-soft)", color: "var(--sf-primary)" }}
        >
          <Icon className={compact ? "h-7 w-7" : "h-11 w-11"} strokeWidth={1.6} />
        </span>
      )}
      <p className={cn("font-extrabold text-sf-text", compact ? "text-[15px]" : "text-[19px]")}>
        {title}
      </p>
      {description && (
        <p className="max-w-xs text-[13.5px] leading-relaxed text-sf-text-muted">{description}</p>
      )}
      {action && <div className="mt-1.5">{action}</div>}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("sf-skeleton", className)} />;
}

export function SkeletonRows({ rows = 5, cols = 5 }: { rows?: number; cols?: number }) {
  return (
    <>
      {Array.from({ length: rows }).map((_, r) => (
        <tr key={r} className="border-b border-[var(--sf-border-light)]">
          {Array.from({ length: cols }).map((__, c) => (
            <td key={c} className="px-4 py-3.5 first:pl-5 last:pr-5">
              <Skeleton className={cn("h-3.5", c === 0 ? "w-24" : "w-16")} />
            </td>
          ))}
        </tr>
      ))}
    </>
  );
}

export function StatSkeletonGrid({ count = 4 }: { count?: number }) {
  return (
    <>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="sf-surface p-4">
          <Skeleton className="h-2.5 w-20" />
          <Skeleton className="mt-3 h-7 w-14" />
          <Skeleton className="mt-2.5 h-2.5 w-24" />
        </div>
      ))}
    </>
  );
}

/* ==========================================================================
   MODAL / DRAWER
   ========================================================================== */

export function Modal({
  open,
  onClose,
  title,
  subtitle,
  children,
  footer,
  size = "md",
}: {
  open: boolean;
  onClose: () => void;
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
  size?: "sm" | "md" | "lg" | "xl";
}) {
  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [open, onClose]);

  if (!open) return null;

  const width = {
    sm: "max-w-md",
    md: "max-w-xl",
    lg: "max-w-3xl",
    xl: "max-w-5xl",
  }[size];

  return (
    <div className="fixed inset-0 z-[100] flex items-end justify-center p-0 sm:items-center sm:p-6">
      <button
        type="button"
        aria-label="Đóng"
        onClick={onClose}
        className="absolute inset-0 animate-sf-fade bg-[var(--sf-bg-overlay)] backdrop-blur-[3px]"
      />
      <div
        role="dialog"
        aria-modal="true"
        className={cn(
          "sf-glass-panel relative flex max-h-[92vh] w-full flex-col animate-sf-scale",
          "rounded-b-none sm:rounded-b-[var(--sf-r-lg)]",
          width
        )}
      >
        <div className="flex items-start justify-between gap-4 border-b border-[var(--sf-border)] px-5 py-4">
          <div className="min-w-0">
            <h2 className="text-base font-bold tracking-tight text-sf-text">{title}</h2>
            {subtitle && <p className="mt-0.5 text-xs text-sf-text-muted">{subtitle}</p>}
          </div>
          <IconButton icon={X} label="Đóng" onClick={onClose} size="sm" />
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>
        {footer && (
          <div className="flex items-center justify-end gap-2 border-t border-[var(--sf-border)] px-5 py-3.5">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}

/** Drawer trượt từ phải — dùng cho panel chi tiết */
export function Drawer({
  open,
  onClose,
  title,
  subtitle,
  children,
  footer,
  width = "md",
}: {
  open: boolean;
  onClose: () => void;
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
  width?: "sm" | "md" | "lg";
}) {
  React.useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  const w = { sm: "max-w-sm", md: "max-w-lg", lg: "max-w-2xl" }[width];

  return (
    <div className="fixed inset-0 z-[100] flex justify-end">
      <button
        type="button"
        aria-label="Đóng"
        onClick={onClose}
        className="absolute inset-0 animate-sf-fade bg-[var(--sf-bg-overlay)] backdrop-blur-[3px]"
      />
      <aside
        className={cn(
          "relative flex h-full w-full flex-col animate-sf-slide-right border-l border-[var(--sf-border)] bg-[var(--sf-bg-card)] shadow-[var(--sf-shadow-xl)]",
          w
        )}
      >
        <div className="flex items-start justify-between gap-4 border-b border-[var(--sf-border)] px-5 py-4">
          <div className="min-w-0">
            <h2 className="truncate text-base font-bold tracking-tight text-sf-text">{title}</h2>
            {subtitle && <p className="mt-0.5 truncate text-xs text-sf-text-muted">{subtitle}</p>}
          </div>
          <IconButton icon={X} label="Đóng" onClick={onClose} size="sm" />
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">{children}</div>
        {footer && (
          <div className="flex items-center justify-end gap-2 border-t border-[var(--sf-border)] px-5 py-3.5">
            {footer}
          </div>
        )}
      </aside>
    </div>
  );
}

/* ==========================================================================
   TABS
   ========================================================================== */

export function Tabs<T extends string>({
  value,
  onChange,
  tabs,
  className,
}: {
  value: T;
  onChange: (v: T) => void;
  tabs: { value: T; label: string; icon?: LucideIcon; count?: number }[];
  className?: string;
}) {
  return (
    <div
      className={cn(
        "relative flex items-center gap-1 overflow-x-auto border-b border-[var(--sf-border)]",
        className
      )}
    >
      {tabs.map((t) => {
        const active = t.value === value;
        const Icon = t.icon;
        return (
          <button
            key={t.value}
            type="button"
            onClick={() => onChange(t.value)}
            className={cn(
              "relative flex items-center gap-2 whitespace-nowrap px-3.5 py-2.5 text-[13px] font-bold transition-colors duration-[var(--sf-dur-fast)] cursor-pointer",
              active ? "text-[var(--sf-primary)]" : "text-sf-text-muted hover:text-sf-text"
            )}
          >
            {Icon && <Icon className="h-4 w-4" />}
            {t.label}
            {typeof t.count === "number" && t.count > 0 && (
              <span
                className="sf-tnum rounded-full px-1.5 py-px text-[12px] font-extrabold"
                style={{
                  background: active ? "var(--sf-primary-soft)" : "var(--sf-bg-inset)",
                  color: active ? "var(--sf-primary)" : "var(--sf-text-muted)",
                }}
              >
                {t.count}
              </span>
            )}
            {active && (
              <span
                className="absolute inset-x-2 -bottom-px h-[2px] rounded-full"
                style={{ background: "var(--sf-primary)" }}
              />
            )}
          </button>
        );
      })}
    </div>
  );
}

/* ==========================================================================
   MISC
   ========================================================================== */

/** Thanh tiến trình mảnh, chỉ dùng primary/accent */
export function ProgressBar({
  value,
  tone = "primary",
  className,
  showLabel,
}: {
  value: number;
  tone?: Tone;
  className?: string;
  showLabel?: boolean;
}) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div className={cn("flex items-center gap-2", className)}>
      <div className="h-1.5 min-w-0 flex-1 overflow-hidden rounded-full bg-[var(--sf-bg-inset)]">
        <div
          className="h-full rounded-full transition-[width] duration-[var(--sf-dur-slow)] ease-[var(--sf-ease-out)]"
          style={{ width: `${pct}%`, background: TONE[tone].dot }}
        />
      </div>
      {showLabel && (
        <span className="sf-tnum text-[12.5px] font-bold text-sf-text-secondary">
          {Math.round(pct)}%
        </span>
      )}
    </div>
  );
}

/** Vòng tròn điểm số — dùng cho điểm an toàn tài xế */
export function ScoreRing({
  score,
  size = 44,
  tone,
  label,
}: {
  score: number;
  size?: number;
  tone?: Tone;
  label?: string;
}) {
  const t = TONE[tone ?? (score >= 85 ? "success" : score >= 70 ? "primary" : score >= 55 ? "warning" : "danger")];
  const r = (size - 6) / 2;
  const c = 2 * Math.PI * r;
  const offset = c - (Math.max(0, Math.min(100, score)) / 100) * c;
  return (
    <div className="relative inline-grid place-items-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          strokeWidth={3.5}
          stroke="var(--sf-bg-inset)"
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          strokeWidth={3.5}
          strokeLinecap="round"
          stroke={t.dot}
          strokeDasharray={c}
          strokeDashoffset={offset}
          style={{ transition: "stroke-dashoffset var(--sf-dur-slow) var(--sf-ease-out)" }}
        />
      </svg>
      <span
        className="sf-tnum absolute text-[12.5px] font-extrabold"
        style={{ color: t.fg }}
        title={label}
      >
        {Math.round(score)}
      </span>
    </div>
  );
}

/** Dòng thông tin nhãn — giá trị, dùng trong drawer/modal chi tiết */
export function InfoRow({
  label,
  value,
  className,
}: {
  label: string;
  value: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex items-baseline justify-between gap-4 border-b border-[var(--sf-border-light)] py-2.5 last:border-0",
        className
      )}
    >
      <span className="flex-shrink-0 text-[12.5px] font-semibold uppercase tracking-wide text-sf-text-muted">
        {label}
      </span>
      <span className="min-w-0 text-right text-[13px] font-semibold text-sf-text">{value}</span>
    </div>
  );
}

/** Khối cảnh báo nhẹ — chỉ dùng viền trái màu semantic */
export function Callout({
  tone = "primary",
  title,
  children,
  icon: Icon,
  className,
}: {
  tone?: Tone;
  title?: React.ReactNode;
  children?: React.ReactNode;
  icon?: LucideIcon;
  className?: string;
}) {
  const t = TONE[tone];
  return (
    <div
      className={cn("flex gap-3 rounded-[var(--sf-r-md)] border-l-[3px] p-3.5", className)}
      style={{ background: t.bg, borderLeftColor: t.dot }}
    >
      {Icon && <Icon className="mt-0.5 h-4 w-4 flex-shrink-0" style={{ color: t.fg }} />}
      <div className="min-w-0 text-xs">
        {title && (
          <p className="font-bold" style={{ color: t.fg }}>
            {title}
          </p>
        )}
        {children && <div className="mt-0.5 text-sf-text-secondary">{children}</div>}
      </div>
    </div>
  );
}

/** Nút xổ nhỏ dùng trong toolbar */
export function DropdownButton({
  label,
  children,
  align = "right",
}: {
  label: React.ReactNode;
  children: React.ReactNode;
  align?: "left" | "right";
}) {
  const [open, setOpen] = React.useState(false);
  const ref = React.useRef<HTMLDivElement>(null);

  React.useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, [open]);

  return (
    <div ref={ref} className="relative">
      <Button variant="outline" size="sm" iconRight={ChevronDown} onClick={() => setOpen(!open)}>
        {label}
      </Button>
      {open && (
        <div
          className={cn(
            "sf-glass-panel absolute top-full z-50 mt-2 min-w-[12rem] animate-sf-drop p-1.5",
            align === "right" ? "right-0" : "left-0"
          )}
          onClick={() => setOpen(false)}
        >
          {children}
        </div>
      )}
    </div>
  );
}

export function MenuItem({
  icon: Icon,
  children,
  onClick,
  tone = "neutral",
  href,
}: {
  icon?: LucideIcon;
  children: React.ReactNode;
  onClick?: () => void;
  tone?: Tone;
  href?: string;
}) {
  const cls =
    "flex w-full items-center gap-2.5 rounded-[var(--sf-r-xs)] px-2.5 py-2 text-[13px] font-semibold transition-colors hover:bg-[var(--sf-bg-inset)] cursor-pointer";
  const style = { color: tone === "neutral" ? "var(--sf-text-secondary)" : TONE[tone].fg };
  if (href) {
    return (
      <a href={href} className={cls} style={style}>
        {Icon && <Icon className="h-4 w-4" />}
        {children}
      </a>
    );
  }
  return (
    <button type="button" onClick={onClick} className={cls} style={style}>
      {Icon && <Icon className="h-4 w-4" />}
      {children}
    </button>
  );
}
