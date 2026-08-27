"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import Link from "next/link";
import { useAuth } from "@/context/AuthContext";
import { useRealtime } from "@/context/RealtimeContext";
import { safeFleetApi, type AppNotification } from "@/lib/safeFleetApi";
import { cn, formatTimeAgo } from "@/lib/utils";
import { StatusDot } from "@/components/ui";
import CommandSearch from "./CommandSearch";
import {
  Search,
  Bell,
  Menu,
  CheckCheck,
  ShieldAlert,
  Siren,
  Droplets,
  WifiOff,
  Clock,
  Wrench,
  Info,
  type LucideIcon,
} from "lucide-react";

const ROLE_LABELS: Record<string, string> = {
  ADMIN: "Quản trị viên",
  FLEET_MANAGER: "Quản lý đội xe",
  DISPATCHER: "Điều phối viên",
  SAFETY_OFFICER: "An toàn vận hành",
  RESCUE_TEAM: "Đội cứu hộ",
  DRIVER: "Tài xế",
};

const NOTIF_META: Record<
  string,
  { icon: LucideIcon; tone: "danger" | "accent" | "primary" | "neutral" }
> = {
  SOS: { icon: Siren, tone: "danger" },
  AI_ALERT: { icon: ShieldAlert, tone: "accent" },
  FLOOD: { icon: Droplets, tone: "primary" },
  GPS_LOST: { icon: WifiOff, tone: "neutral" },
  DRIVING_TIME: { icon: Clock, tone: "accent" },
  TRIP_DELAYED: { icon: Clock, tone: "accent" },
  MAINTENANCE: { icon: Wrench, tone: "neutral" },
  SYSTEM: { icon: Info, tone: "neutral" },
};

/** Viết tắt tên người dùng: lấy chữ cái đầu của hai từ cuối */
function initialsOf(fullName?: string): string {
  if (!fullName) return "SF";
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "SF";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
}

interface HeaderProps {
  /** Nhãn nhóm menu chứa trang hiện tại, ví dụ "Vận hành" */
  group?: string;
  title: string;
  onMenuClick?: () => void;
}

export default function Header({ group, title, onMenuClick }: HeaderProps) {
  const { user } = useAuth();
  const { status: realtimeStatus } = useRealtime();
  const [showNotifs, setShowNotifs] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const notifRef = useRef<HTMLDivElement>(null);

  /* --- Ctrl+K mở tìm nhanh --- */
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setIsSearchOpen((v) => !v);
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  /* --- Đóng bảng thông báo khi bấm ra ngoài --- */
  useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      const t = e.target as Node;
      if (notifRef.current && !notifRef.current.contains(t)) setShowNotifs(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, []);

  /* --- Thông báo lấy từ backend, tự làm mới mỗi 45 giây --- */
  const loadNotifications = useCallback(async () => {
    const data = await safeFleetApi.notifications().catch(() => []);
    setNotifications(data);
  }, []);

  useEffect(() => {
    void loadNotifications();
    const timer = window.setInterval(loadNotifications, 45_000);
    return () => window.clearInterval(timer);
  }, [loadNotifications]);

  const unread = notifications.filter((n) => !n.read).length;

  const markAll = async () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    await safeFleetApi.markAllNotificationsRead().catch(() => void 0);
  };

  const markOne = async (id: number) => {
    setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, read: true } : n)));
    await safeFleetApi.markNotificationRead(id).catch(() => void 0);
  };

  const connected = realtimeStatus === "connected";

  return (
    <header
      className="sticky top-0 z-30 border-b border-[var(--sf-border-card)] bg-[var(--sf-bg-header)] backdrop-blur-[14px]"
      style={{ height: "var(--header-height)" }}
    >
      <div className="flex h-full items-center gap-3 px-4 sm:gap-[18px] sm:px-[30px]">
        {/* ===== Nút menu (chỉ trên màn hẹp) ===== */}
        <button
          type="button"
          onClick={onMenuClick}
          aria-label="Mở menu điều hướng"
          className="grid h-[42px] w-[42px] flex-shrink-0 cursor-pointer place-items-center rounded-full border border-[var(--sf-border-card)] bg-[var(--sf-bg-card)] text-sf-text-secondary shadow-[var(--sf-shadow-xs)] transition-colors hover:text-sf-text lg:hidden"
        >
          <Menu className="h-5 w-5" />
        </button>

        {/* ===== Nhóm menu + tên trang ===== */}
        <div className="min-w-0 flex-auto">
          {group && <div className="sf-eyebrow truncate">{group}</div>}
          <h1 className="truncate text-[19px] font-bold tracking-[-0.015em] text-sf-text">
            {title}
          </h1>
        </div>

        {/* ===== Trạng thái realtime ===== */}
        <span
          className="hidden h-[42px] flex-none items-center gap-2 rounded-full border border-[var(--sf-border-card)] bg-[var(--sf-bg-card)] px-3.5 text-[12.5px] shadow-[var(--sf-shadow-xs)] xl:flex"
          title={
            connected
              ? "Đang nhận dữ liệu trực tiếp từ backend"
              : "Realtime mất kết nối — hệ thống vẫn cập nhật theo chu kỳ"
          }
        >
          <StatusDot tone={connected ? "success" : "neutral"} pulse={connected} />
          <span className="text-sf-text-muted">
            {connected ? "Realtime" : realtimeStatus === "connecting" ? "Đang kết nối" : "Mất kết nối"}
          </span>
        </span>

        {/* ===== Ô tìm nhanh ===== */}
        <button
          type="button"
          onClick={() => setIsSearchOpen(true)}
          title="Tìm nhanh xe, tài xế, chuyến (Ctrl K)"
          className="flex h-[42px] min-w-[42px] flex-none cursor-pointer items-center gap-2.5 overflow-hidden rounded-full border border-[var(--sf-border-card)] bg-[var(--sf-bg-card)] px-3.5 text-[13px] text-sf-text-muted shadow-[var(--sf-shadow-xs)] transition-shadow hover:shadow-[0_8px_20px_-10px_rgba(20,40,55,.22)]"
        >
          <Search className="h-[19px] w-[19px] flex-none" />
          <span className="hidden whitespace-nowrap xl:inline">
            Tìm nhanh xe, tài xế, chuyến…
          </span>
          <kbd className="sf-mono hidden flex-none rounded-lg bg-[var(--sf-bg-inset-strong,var(--sf-bg-inset))] px-[7px] py-[3px] text-[11px] xl:inline">
            Ctrl K
          </kbd>
        </button>

        {/* ===== Thông báo ===== */}
        <div ref={notifRef} className="relative flex-none">
          <button
            type="button"
            onClick={() => setShowNotifs((v) => !v)}
            aria-label="Thông báo"
            title="Thông báo"
            className="relative grid h-[42px] w-[42px] cursor-pointer place-items-center rounded-full border border-[var(--sf-border-card)] bg-[var(--sf-bg-card)] text-sf-text-secondary shadow-[var(--sf-shadow-xs)] transition-colors hover:text-[var(--sf-primary)]"
          >
            <Bell className="h-5 w-5" />
            {unread > 0 && (
              <span
                className="absolute right-[9px] top-2 h-2 w-2 rounded-full"
                style={{
                  background: "var(--sf-danger)",
                  boxShadow: "0 0 0 2px var(--sf-bg-card)",
                }}
              />
            )}
          </button>

          {showNotifs && (
            <div className="sf-glass-panel absolute right-0 top-full z-50 mt-2 w-[22rem] animate-sf-drop overflow-hidden">
              <div className="flex items-center justify-between border-b border-[var(--sf-border)] px-4 py-3">
                <div>
                  <p className="text-[13px] font-bold text-sf-text">Thông báo</p>
                  <p className="text-[12px] text-sf-text-muted">
                    {unread > 0 ? `${unread} thông báo chưa đọc` : "Đã đọc hết"}
                  </p>
                </div>
                {unread > 0 && (
                  <button
                    type="button"
                    onClick={markAll}
                    className="flex cursor-pointer items-center gap-1.5 rounded-[var(--sf-r-xs)] px-2 py-1 text-[12px] font-semibold text-[var(--sf-primary)] transition-colors hover:bg-[var(--sf-primary-soft)]"
                  >
                    <CheckCheck className="h-3.5 w-3.5" />
                    Đọc hết
                  </button>
                )}
              </div>

              <div className="max-h-[26rem] overflow-y-auto">
                {notifications.length === 0 ? (
                  <p className="px-4 py-10 text-center text-[12.5px] text-sf-text-muted">
                    Chưa có thông báo nào
                  </p>
                ) : (
                  notifications.slice(0, 20).map((n) => {
                    const meta = NOTIF_META[n.kind] ?? NOTIF_META.SYSTEM;
                    const Icon = meta.icon;
                    return (
                      <button
                        key={n.id}
                        type="button"
                        onClick={() => markOne(n.id)}
                        className={cn(
                          "flex w-full cursor-pointer items-start gap-3 border-b border-[var(--sf-border-light)] px-4 py-3 text-left transition-colors last:border-0 hover:bg-[var(--sf-bg-inset)]",
                          !n.read && "bg-[var(--sf-primary-soft)]"
                        )}
                      >
                        <span
                          className="mt-0.5 grid h-7 w-7 flex-shrink-0 place-items-center rounded-[10px]"
                          style={{
                            background:
                              meta.tone === "danger"
                                ? "var(--sf-danger-soft)"
                                : meta.tone === "accent"
                                  ? "var(--sf-accent-soft)"
                                  : meta.tone === "primary"
                                    ? "var(--sf-primary-soft)"
                                    : "var(--sf-bg-inset)",
                            color:
                              meta.tone === "danger"
                                ? "var(--sf-danger)"
                                : meta.tone === "accent"
                                  ? "var(--sf-accent-hover)"
                                  : meta.tone === "primary"
                                    ? "var(--sf-primary)"
                                    : "var(--sf-text-muted)",
                          }}
                        >
                          <Icon className="h-3.5 w-3.5" />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="flex items-center gap-2">
                            <span className="min-w-0 flex-1 truncate text-[12.5px] font-bold text-sf-text">
                              {n.title}
                            </span>
                            {!n.read && <StatusDot tone="danger" />}
                          </span>
                          <span className="mt-0.5 block line-clamp-2 text-[12.5px] leading-snug text-sf-text-secondary">
                            {n.content}
                          </span>
                          <span className="sf-mono mt-1 block text-[11.5px] text-sf-text-muted">
                            {formatTimeAgo(n.createdAt)}
                          </span>
                        </span>
                      </button>
                    );
                  })
                )}
              </div>
            </div>
          )}
        </div>

        {/* ===== Hồ sơ cá nhân ===== */}
        <Link
          href="/profile"
          title="Hồ sơ cá nhân"
          className="flex h-[42px] flex-none items-center gap-2.5 whitespace-nowrap rounded-full border border-[var(--sf-border-card)] bg-[var(--sf-bg-card)] py-1 pl-1 pr-3.5 shadow-[var(--sf-shadow-xs)] transition-shadow hover:shadow-[0_8px_20px_-10px_rgba(20,40,55,.22)]"
        >
          <span
            className="grid h-[34px] w-[34px] flex-none place-items-center rounded-full text-[12.5px] font-bold"
            style={{ background: "linear-gradient(150deg,#34d3b5,#087f73)", color: "#04211f" }}
          >
            {initialsOf(user?.fullName)}
          </span>
          <span className="hidden text-left sm:block">
            <span className="block text-[12.5px] font-semibold leading-tight text-sf-text">
              {user?.fullName || "Người dùng"}
            </span>
            <span className="block text-[11px] leading-tight text-sf-text-muted">
              {user?.role ? ROLE_LABELS[user.role] || user.role : ""}
            </span>
          </span>
        </Link>
      </div>

      <CommandSearch isOpen={isSearchOpen} onClose={() => setIsSearchOpen(false)} />
    </header>
  );
}
