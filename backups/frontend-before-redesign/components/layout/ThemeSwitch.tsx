"use client";

import * as React from "react";
import { Sun, Moon, MonitorSmartphone } from "lucide-react";
import { useTheme, type ThemeMode } from "@/context/ThemeContext";
import { cn } from "@/lib/utils";

const MODES: { value: ThemeMode; label: string; icon: typeof Sun }[] = [
  { value: "light", label: "Sáng", icon: Sun },
  { value: "dark", label: "Tối", icon: Moon },
  { value: "system", label: "Theo hệ thống", icon: MonitorSmartphone },
];

/**
 * Bộ chuyển sáng / tối / theo hệ thống với con trượt nền chạy mượt.
 * `compact` dùng khi sidebar thu gọn — chỉ hiện nút xoay vòng.
 */
export default function ThemeSwitch({
  compact,
  className,
}: {
  compact?: boolean;
  className?: string;
}) {
  const { mode, resolvedTheme, setMode } = useTheme();
  const ref = React.useRef<HTMLDivElement>(null);
  const [indicator, setIndicator] = React.useState<{ left: number; width: number } | null>(null);
  const [mounted, setMounted] = React.useState(false);

  React.useEffect(() => setMounted(true), []);

  const sync = React.useCallback(() => {
    const el = ref.current?.querySelector<HTMLElement>(`[data-mode="${mode}"]`);
    if (el) setIndicator({ left: el.offsetLeft, width: el.offsetWidth });
  }, [mode]);

  React.useEffect(() => {
    if (compact) return;
    sync();
    const ro = new ResizeObserver(sync);
    if (ref.current) ro.observe(ref.current);
    return () => ro.disconnect();
  }, [sync, compact]);

  if (compact) {
    const next: ThemeMode =
      mode === "light" ? "dark" : mode === "dark" ? "system" : "light";
    const Icon = mode === "system" ? MonitorSmartphone : resolvedTheme === "dark" ? Moon : Sun;
    return (
      <button
        type="button"
        onClick={() => setMode(next)}
        title={`Giao diện: ${MODES.find((m) => m.value === mode)?.label}`}
        aria-label="Đổi chế độ giao diện"
        className={cn(
          "mx-auto grid h-9 w-9 place-items-center rounded-[var(--sf-r-sm)] text-sf-text-muted",
          "transition-[background-color,color,transform] duration-[var(--sf-dur-fast)]",
          "hover:bg-[var(--sf-bg-inset)] hover:text-[var(--sf-primary)] active:scale-90 cursor-pointer",
          className
        )}
      >
        <Icon
          key={mode + resolvedTheme}
          className="h-[18px] w-[18px] animate-sf-scale"
        />
      </button>
    );
  }

  return (
    <div
      ref={ref}
      role="radiogroup"
      aria-label="Chế độ giao diện"
      className={cn(
        "relative flex items-center gap-0.5 rounded-[var(--sf-r-sm)] border border-[var(--sf-border-light)] bg-[var(--sf-bg-inset)] p-1",
        className
      )}
    >
      {mounted && indicator && (
        <span
          aria-hidden
          className="absolute top-1 bottom-1 rounded-[var(--sf-r-xs)] bg-[var(--sf-bg-card)] shadow-[var(--sf-shadow-xs)] transition-all duration-[var(--sf-dur-base)] ease-[var(--sf-ease-spring)]"
          style={{ left: indicator.left, width: indicator.width }}
        />
      )}
      {MODES.map((m) => {
        const Icon = m.icon;
        const active = mounted && mode === m.value;
        return (
          <button
            key={m.value}
            type="button"
            role="radio"
            aria-checked={active}
            data-mode={m.value}
            onClick={() => setMode(m.value)}
            title={m.label}
            className={cn(
              "relative z-10 flex flex-1 items-center justify-center gap-1.5 rounded-[var(--sf-r-xs)] py-1.5 text-[12.5px] font-bold transition-colors duration-[var(--sf-dur-fast)] cursor-pointer",
              active
                ? "text-[var(--sf-primary)]"
                : "text-sf-text-muted hover:text-sf-text-secondary"
            )}
          >
            <Icon className="h-3.5 w-3.5" />
            <span className="hidden sm:inline">{m.label}</span>
          </button>
        );
      })}
    </div>
  );
}
