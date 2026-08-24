"use client";

/* ==========================================================================
   SafeFleet — Khối dữ liệu dùng chung (đợt dựng lại giao diện 2026)
   --------------------------------------------------------------------------
   Bản thiết kế mới lặp lại đúng bốn khối trên hầu hết màn hình:

     1. Dải nhấn tối (HeroPanel)      — mỗi màn hình dùng nhiều nhất một
     2. Lưới 4 thẻ số liệu            — StatCard trong <Stagger>
     3. Thanh công cụ: ô tìm + chip lọc + một nút hành động chính
     4. Bảng dạng thẻ: hàng bo góc, tách nhau, không kẻ ô

   Bảng ở đây không dùng <table> mà dùng CSS grid, đúng như bản thiết kế:
   mỗi hàng là một thẻ bo 20px, hover đổi nền, xuất hiện lần lượt từ phải sang.
   Vì vậy mỗi trang tự khai báo `grid` (grid-template-columns) và số cột phải
   khớp với số ô trong mỗi hàng.
   ========================================================================== */

import React from "react";
import type { LucideIcon } from "lucide-react";
import { Search, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { Badge, EmptyState, Skeleton, type Tone } from "./primitives";

/* ==========================================================================
   DẢI NHẤN TỐI
   ========================================================================== */

export function HeroPanel({
  children,
  className,
  padding = "lg",
}: {
  children: React.ReactNode;
  className?: string;
  padding?: "md" | "lg";
}) {
  return (
    <div className={cn("sf-hero-panel", padding === "lg" ? "p-7" : "p-6", className)}>
      <span
        aria-hidden
        className="sf-hero-glow"
        style={{ width: 340, height: 340, right: -110, top: -130 }}
      />
      <div className="relative flex h-full flex-col">{children}</div>
    </div>
  );
}

/** Ô số liệu nhỏ đặt trong dải nhấn tối */
export function HeroTile({
  value,
  label,
  tone,
  delay = 0,
}: {
  value: React.ReactNode;
  label: string;
  tone?: "warning" | "danger" | "default";
  delay?: number;
}) {
  const color =
    tone === "warning" ? "#ffc74d" : tone === "danger" ? "#ff9ea1" : "#ffffff";
  return (
    <div className="sf-hero-tile animate-sf-pop" style={{ animationDelay: `${delay}ms` }}>
      <div className="sf-mono text-[27px] font-medium leading-none" style={{ color }}>
        {value}
      </div>
      <div className="mt-1.5 text-[11.5px]" style={{ color: "rgba(206,232,229,.78)" }}>
        {label}
      </div>
    </div>
  );
}

/* ==========================================================================
   CHIP LỌC
   ========================================================================== */

export interface FilterChip {
  /** Khoá dùng cho React key và so sánh trạng thái chọn */
  key: string;
  label: string;
  /** Số lượng hiển thị sau nhãn; bỏ qua nếu không truyền */
  count?: number;
}

export function FilterChips({
  items,
  value,
  onChange,
  className,
}: {
  items: FilterChip[];
  value: string;
  onChange: (key: string) => void;
  className?: string;
}) {
  return (
    <div className={cn("flex flex-wrap gap-1.5", className)}>
      {items.map((item) => (
        <button
          key={item.key}
          type="button"
          onClick={() => onChange(item.key)}
          className={cn("sf-chip", value === item.key && "sf-chip-active")}
        >
          {item.label}
          {item.count != null && <span className="sf-mono ml-1.5 opacity-70">{item.count}</span>}
        </button>
      ))}
    </div>
  );
}

/* ==========================================================================
   THANH CÔNG CỤ CỦA THẺ BẢNG
   ========================================================================== */

export function TableToolbar({
  search,
  filters,
  action,
  extra,
}: {
  search?: { value: string; onChange: (v: string) => void; placeholder?: string };
  filters?: React.ReactNode;
  /** Nút hành động chính — mỗi màn hình chỉ nên có một */
  action?: React.ReactNode;
  extra?: React.ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-center gap-3 gap-y-3 border-b border-[var(--sf-border-card)] px-5 py-5 sm:px-6">
      {search && (
        <label className="sf-search-box min-w-[220px] flex-1 sm:max-w-[280px] sm:flex-none">
          <Search className="h-[18px] w-[18px] flex-shrink-0 text-sf-text-muted" />
          <input
            value={search.value}
            onChange={(e) => search.onChange(e.target.value)}
            placeholder={search.placeholder}
          />
          {search.value && (
            <button
              type="button"
              aria-label="Xóa từ khóa"
              onClick={() => search.onChange("")}
              className="grid h-5 w-5 flex-shrink-0 cursor-pointer place-items-center rounded-full text-sf-text-muted hover:text-sf-text"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </label>
      )}
      {filters}
      {extra && <div className="flex flex-none items-center gap-2">{extra}</div>}
      <div className="flex-1" />
      {action}
    </div>
  );
}

/* ==========================================================================
   BẢNG DẠNG THẺ
   ========================================================================== */

export interface DataRow {
  key: string;
  cells: React.ReactNode[];
  onClick?: () => void;
  /** Làm nổi hàng đang chọn */
  active?: boolean;
}

export function DataTable({
  grid,
  columns,
  rows,
  loading,
  empty,
  className,
}: {
  /** grid-template-columns, ví dụ "1.5fr 1fr 1fr .9fr 1.1fr" */
  grid: string;
  columns: React.ReactNode[];
  rows: DataRow[];
  loading?: boolean;
  empty?: { icon?: LucideIcon; title: string; description?: string; action?: React.ReactNode };
  className?: string;
}) {
  const cols = { gridTemplateColumns: grid } as React.CSSProperties;

  return (
    <div className={cn("overflow-x-auto px-3 pb-3.5 pt-1.5", className)}>
      <div className="min-w-[860px]">
        <div className="sf-row-head" style={cols}>
          {columns.map((c, i) => (
            <span key={i} className="truncate">
              {c}
            </span>
          ))}
        </div>

        {loading && rows.length === 0 ? (
          Array.from({ length: 6 }).map((_, r) => (
            <div key={r} className="sf-row" style={cols}>
              {columns.map((_c, i) => (
                <Skeleton key={i} className="h-4 w-full" />
              ))}
            </div>
          ))
        ) : rows.length === 0 ? (
          <div className="px-3 py-2">
            <EmptyState
              icon={empty?.icon}
              title={empty?.title ?? "Chưa có dữ liệu"}
              description={empty?.description}
              action={empty?.action}
            />
          </div>
        ) : (
          rows.map((row, i) => (
            <div
              key={row.key}
              role={row.onClick ? "button" : undefined}
              tabIndex={row.onClick ? 0 : undefined}
              onClick={row.onClick}
              onKeyDown={
                row.onClick
                  ? (e) => {
                      if (e.key === "Enter" || e.key === " ") {
                        e.preventDefault();
                        row.onClick?.();
                      }
                    }
                  : undefined
              }
              className={cn(
                "sf-row animate-sf-slide-left",
                row.onClick && "sf-row-clickable",
                row.active && "bg-[var(--sf-primary-soft)]"
              )}
              style={{ ...cols, animationDelay: `${Math.min(i, 12) * 45 + 60}ms` }}
            >
              {row.cells.map((cell, j) => (
                <div key={j} className="min-w-0">
                  {cell}
                </div>
              ))}
            </div>
          ))
        )}
      </div>
    </div>
  );
}

/* ==========================================================================
   Ô TRONG BẢNG
   ========================================================================== */

/** Ô chữ hai dòng: dòng chính + dòng phụ. Đây là ô mặc định của bản thiết kế. */
export function CellText({
  text,
  sub,
  mono,
  subMono,
  strong,
  color,
  icon: Icon,
  iconTone = "primary",
}: {
  text: React.ReactNode;
  sub?: React.ReactNode;
  mono?: boolean;
  subMono?: boolean;
  strong?: boolean;
  /** Màu chữ dòng chính — dùng cho giá trị vượt ngưỡng */
  color?: string;
  icon?: LucideIcon;
  iconTone?: Tone;
}) {
  const body = (
    <div className="min-w-0">
      <div
        className={cn(
          "truncate text-[13.5px]",
          strong ? "font-semibold" : "font-medium",
          mono && "sf-mono"
        )}
        style={{ color: color ?? "var(--sf-text)" }}
      >
        {text}
      </div>
      {sub != null && sub !== "" && (
        <div className={cn("mt-[3px] truncate text-[11.5px] text-sf-text-muted", subMono && "sf-mono")}>
          {sub}
        </div>
      )}
    </div>
  );

  if (!Icon) return body;

  return (
    <div className="flex min-w-0 items-center gap-3">
      <span
        className="grid h-9 w-9 flex-shrink-0 place-items-center rounded-[12px]"
        style={{
          background: `var(--sf-${iconTone === "neutral" ? "bg-inset" : iconTone + "-soft"})`,
          color: iconTone === "neutral" ? "var(--sf-text-muted)" : `var(--sf-${iconTone})`,
        }}
      >
        <Icon className="h-[18px] w-[18px]" />
      </span>
      {body}
    </div>
  );
}

/** Ô huy hiệu trạng thái — luôn kèm chấm màu để đọc nhanh */
export function CellBadge({
  tone = "neutral",
  children,
}: {
  tone?: Tone;
  children: React.ReactNode;
}) {
  return (
    <Badge tone={tone} dot>
      {children}
    </Badge>
  );
}

/** Ô tiến độ: nhãn trái, phần trăm phải, thanh mảnh bên dưới */
export function CellProgress({
  label,
  percent,
  tone = "primary",
}: {
  label: React.ReactNode;
  percent: number;
  tone?: "primary" | "warning" | "danger" | "info";
}) {
  const pct = Math.max(0, Math.min(100, Math.round(percent)));
  return (
    <div className="min-w-0">
      <div className="mb-1.5 flex justify-between gap-2 text-[11.5px] text-sf-text-muted">
        <span className="truncate">{label}</span>
        <span className="sf-mono flex-shrink-0">{pct}%</span>
      </div>
      <div
        className={cn(
          "sf-track !h-1.5",
          tone === "warning" && "sf-track-warn",
          tone === "danger" && "sf-track-danger",
          tone === "info" && "sf-track-info"
        )}
      >
        <span style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

/* ==========================================================================
   THẺ BAO QUANH BẢNG
   ========================================================================== */

/** Thẻ trắng bo 28px chứa thanh công cụ + bảng. Dùng cho 9 màn hình danh sách. */
export function TableCard({
  toolbar,
  children,
  className,
}: {
  toolbar?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("sf-surface overflow-hidden", className)}>
      {toolbar}
      {children}
    </div>
  );
}

/* ==========================================================================
   KHỐI THÔNG TIN NHỎ
   ========================================================================== */

/** Ô số liệu lõm trong thẻ — dùng ở bảng điều khiển bên phải bản đồ, hồ sơ… */
export function MiniStat({
  label,
  value,
  color,
  tone,
}: {
  label: React.ReactNode;
  value: React.ReactNode;
  color?: string;
  tone?: "warning" | "danger" | "info";
}) {
  const bg =
    tone === "warning"
      ? "var(--sf-accent-soft)"
      : tone === "danger"
        ? "var(--sf-danger-soft)"
        : tone === "info"
          ? "var(--sf-info-soft)"
          : "var(--sf-bg-inset)";
  const labelColor =
    tone === "warning"
      ? "var(--sf-accent-hover)"
      : tone === "danger"
        ? "var(--sf-danger)"
        : tone === "info"
          ? "var(--sf-info)"
          : "var(--sf-text-muted)";
  return (
    <div className="rounded-[var(--sf-r-md)] p-3.5" style={{ background: bg }}>
      <div className="text-[11.5px]" style={{ color: labelColor }}>
        {label}
      </div>
      <div className="sf-mono mt-1.5 text-[19px]" style={{ color: color ?? "var(--sf-text)" }}>
        {value}
      </div>
    </div>
  );
}

/** Dòng nhãn – giá trị, canh hai bên. Dùng trong bảng chi tiết. */
export function DetailRow({
  label,
  value,
  mono,
  color,
}: {
  label: React.ReactNode;
  value: React.ReactNode;
  mono?: boolean;
  color?: string;
}) {
  return (
    <div className="flex items-baseline justify-between gap-3 text-[12.5px]">
      <span className="flex-shrink-0 text-sf-text-muted">{label}</span>
      <span
        className={cn("truncate text-right font-medium", mono && "sf-mono")}
        style={{ color: color ?? "var(--sf-text)" }}
      >
        {value}
      </span>
    </div>
  );
}
