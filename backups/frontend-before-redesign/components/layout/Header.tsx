"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import Link from "next/link";
import { useAuth } from "@/context/AuthContext";
import { useRealtime } from "@/context/RealtimeContext";
import { safeFleetApi, type AppNotification } from "@/lib/safeFleetApi";
import { cn, formatTimeAgo } from "@/lib/utils";
import { Badge, IconButton, StatusDot } from "@/components/ui";
import CommandSearch from "./CommandSearch";
import {
  Search,
  Bell,
  ChevronDown,
  LogOut,
  Settings,
  User,
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

const NOTIF_META: Record<string, { icon: LucideIcon; tone: "danger" | "accent" | "primary" | "neutral" }> = {
  SOS: { icon: Siren, tone: "danger" },
  AI_ALERT: { icon: ShieldAlert, tone: "accent" },
  FLOOD: { icon: Droplets, tone: "primary" },
  GPS_LOST: { icon: WifiOff, tone: "neutral" },
  DRIVING_TIME: { icon: Clock, tone: "accent" },
  TRIP_DELAYED: { icon: Clock, tone: "accent" },
  MAINTENANCE: { icon: Wrench, tone: "neutral" },
  SYSTEM: { icon: Info, tone: "neutral" },
};

interface HeaderProps {
  title: string;
  description?: string;
  onMenuClick?: () => void;
}

export default function Header({ title, description, onMenuClick }: HeaderProps) {
  const { user, logout } = useAuth();
  const { status: realtimeStatus } = useRealtime();
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [showNotifs, setShowNotifs] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [notifications, setNotifications] = useState<AppNotification[]>([]);
  const userMenuRef = useRef<HTMLDivElement>(null);
  const notifRef = useRef<HTMLDivElement>(null);

  /* --- Ctrl+K --- */
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

  /* --- Đóng popover khi click ra ngoài --- */
  useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      const t = e.target as Node;
      if (userMenuRef.current && !userMenuRef.current.contains(t)) setShowUserMenu(false);
      if (notifRef.current && !notifRef.current.contains(t)) setShowNotifs(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, []);

  /* --- Thông báo từ backend --- */
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

  const today = new Date().toLocaleDateString("vi-VN", {
    weekday: "short",
    day: "2-digit",
    month: "2-digit",
  });

  const connected = realtimeStatus === "connected";

  return (
    <header className="sticky top-0 z-30 bg-[var(--sf-bg-header)] backdrop-blur-xl">
      <div className="flex h-[76px] items-center gap-3 px-4 sm:px-6">
        {/* ===== Trái: menu mobile + tiêu đề ===== */}
        <button
          type="button"
          onClick={onMenuClick}
          aria-label="Mở menu điều hướng"
          className="grid h-10 w-10 flex-shrink-0 place-items-center rounded-[var(--sf-r-sm)] bg-[var(--sf-bg-card)] text-sf-text-secondary shadow-[var(--sf-shadow-xs)] transition-colors hover:text-sf-text lg:hidden cursor-pointer"
        >
          <Menu className="h-5 w-5" />
        </button>

        <div className="min-w-0 flex-1">
          <h1 className="truncate text-[22px] font-extrabold tracking-tight text-sf-text">
            {title}
          </h1>
          {description && (
            <p className="mt-0.5 truncate text-[13px] text-sf-text-muted">{description}</p>
          )}
        </div>

        {/* ===== Giữa: ô tìm kiếm ===== */}
        <button
          onClick={() => setIsSearchOpen(true)}
          className="group relative mx-2 hidden h-11 w-full max-w-xs items-center gap-2.5 rounded-[var(--sf-r-sm)] bg-[var(--sf-bg-card)] px-3.5 text-left text-[13.5px] text-sf-text-muted shadow-[var(--sf-shadow-xs)] transition-shadow hover:shadow-[var(--sf-shadow-sm)] xl:flex cursor-pointer"
        >
          <Search className="h-4 w-4 flex-shrink-0 transition-colors group-hover:text-[var(--sf-primary)]" />
          <span className="truncate">Tìm kiếm…</span>
          <kbd className="sf-tnum ml-auto flex-shrink-0 rounded-[6px] bg-[var(--sf-bg-inset)] px-1.5 py-0.5 font-mono text-[12px] font-bold">
            Ctrl K
          </kbd>
        </button>

        {/* ===== Phải ===== */}
        <div className="flex flex-shrink-0 items-center gap-2">
          <IconButton
            icon={Search}
            label="Tìm kiếm"
            onClick={() => setIsSearchOpen(true)}
            className="xl:hidden"
          />

          {/* Trạng thái realtime */}
          <span
            className="hidden items-center gap-2 rounded-[var(--sf-r-pill)] bg-[var(--sf-bg-card)] px-3 py-2 text-[12.5px] font-semibold shadow-[var(--sf-shadow-xs)] lg:flex"
            title={
              connected
                ? "Đang nhận dữ liệu trực tiếp từ backend"
                : "REST polling vẫn hoạt động khi realtime mất kết nối"
            }
          >
            <StatusDot tone={connected ? "success" : "neutral"} pulse={connected} />
            <span className="text-sf-text-secondary">
              {connected ? "Realtime" : "Đang kết nối"}
            </span>
            <span className="hidden text-sf-text-muted xl:inline">· {today}</span>
          </span>

          {/* ===== Thông báo ===== */}
          <div ref={notifRef} className="relative">
            <button
              type="button"
              onClick={() => setShowNotifs((v) => !v)}
              aria-label="Thông báo"
              title="Thông báo"
              className="relative grid h-11 w-11 place-items-center rounded-[var(--sf-r-sm)] bg-[var(--sf-bg-card)] text-sf-text-secondary shadow-[var(--sf-shadow-xs)] transition-colors hover:text-[var(--sf-primary)] cursor-pointer"
            >
              <Bell className="h-5 w-5" />
              {unread > 0 && (
                <span
                  className="sf-tnum absolute -right-1 -top-1 grid h-[19px] min-w-[19px] place-items-center rounded-full px-1 text-[12px] font-extrabold text-white"
                  style={{ background: "var(--sf-danger)" }}
                >
                  {unread > 99 ? "99+" : unread}
                </span>
              )}
            </button>

            {showNotifs && (
              <div className="sf-glass-panel absolute right-0 top-full z-50 mt-2 w-[22rem] animate-sf-drop overflow-hidden">
                <div className="flex items-center justify-between border-b border-[var(--sf-border)] px-4 py-3">
                  <div>
                    <p className="text-[13px] font-extrabold text-sf-text">Thông báo</p>
                    <p className="text-[12.5px] text-sf-text-muted">
                      {unread > 0 ? `${unread} thông báo chưa đọc` : "Đã đọc hết"}
                    </p>
                  </div>
                  {unread > 0 && (
                    <button
                      type="button"
                      onClick={markAll}
                      className="flex items-center gap-1.5 rounded-[var(--sf-r-xs)] px-2 py-1 text-[12.5px] font-bold text-[var(--sf-primary)] transition-colors hover:bg-[var(--sf-primary-soft)] cursor-pointer"
                    >
                      <CheckCheck className="h-3.5 w-3.5" />
                      Đọc hết
                    </button>
                  )}
                </div>

                <div className="max-h-[26rem] overflow-y-auto">
                  {notifications.length === 0 ? (
                    <p className="px-4 py-10 text-center text-xs text-sf-text-muted">
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
                            "flex w-full items-start gap-3 border-b border-[var(--sf-border-light)] px-4 py-3 text-left transition-colors last:border-0 hover:bg-[var(--sf-bg-inset)] cursor-pointer",
                            !n.read && "bg-[var(--sf-primary-soft)]/40"
                          )}
                        >
                          <span
                            className="mt-0.5 grid h-7 w-7 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)]"
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
                            <span className="mt-1 block text-[12px] font-semibold text-sf-text-muted">
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

          {/* ===== Người dùng ===== */}
          <div ref={userMenuRef} className="relative">
            <button
              type="button"
              onClick={() => setShowUserMenu((v) => !v)}
              className="flex items-center gap-2.5 rounded-[var(--sf-r-sm)] bg-[var(--sf-bg-card)] py-1.5 pl-1.5 pr-3 shadow-[var(--sf-shadow-xs)] transition-shadow hover:shadow-[var(--sf-shadow-sm)] cursor-pointer"
            >
              <span
                className="grid h-9 w-9 flex-shrink-0 place-items-center rounded-full text-[13px] font-extrabold"
                style={{ background: "var(--sf-primary)", color: "var(--sf-primary-contrast)" }}
              >
                {user?.fullName?.charAt(0)?.toUpperCase() || "U"}
              </span>
              <span className="hidden text-left sm:block">
                <span className="block text-[13.5px] font-bold leading-tight text-sf-text">
                  {user?.fullName || "Người dùng"}
                </span>
                <span className="block text-[12.5px] leading-tight text-sf-text-muted">
                  {user?.role ? ROLE_LABELS[user.role] || user.role : ""}
                </span>
              </span>
              <ChevronDown
                className={cn(
                  "hidden h-4 w-4 text-sf-text-muted transition-transform duration-[var(--sf-dur-fast)] sm:block",
                  showUserMenu && "rotate-180"
                )}
              />
            </button>

            {showUserMenu && (
              <div className="sf-glass-panel absolute right-0 top-full z-50 mt-2 w-60 animate-sf-drop overflow-hidden">
                <div className="border-b border-[var(--sf-border)] px-4 py-3">
                  <p className="truncate text-[13px] font-extrabold text-sf-text">
                    {user?.fullName}
                  </p>
                  <p className="mt-0.5 truncate text-[12.5px] text-sf-text-muted">{user?.email}</p>
                  {user?.role && (
                    <Badge tone="primary" size="sm" className="mt-2">
                      {ROLE_LABELS[user.role] || user.role}
                    </Badge>
                  )}
                </div>
                <div className="p-1.5">
                  <Link
                    href="/profile"
                    onClick={() => setShowUserMenu(false)}
                    className="flex items-center gap-2.5 rounded-[var(--sf-r-xs)] px-2.5 py-2 text-[13px] font-semibold text-sf-text-secondary transition-colors hover:bg-[var(--sf-bg-inset)] hover:text-sf-text"
                  >
                    <User className="h-4 w-4" /> Hồ sơ cá nhân
                  </Link>
                  <Link
                    href="/settings"
                    onClick={() => setShowUserMenu(false)}
                    className="flex items-center gap-2.5 rounded-[var(--sf-r-xs)] px-2.5 py-2 text-[13px] font-semibold text-sf-text-secondary transition-colors hover:bg-[var(--sf-bg-inset)] hover:text-sf-text"
                  >
                    <Settings className="h-4 w-4" /> Cài đặt hệ thống
                  </Link>
                </div>
                <div className="border-t border-[var(--sf-border)] p-1.5">
                  <button
                    type="button"
                    onClick={() => {
                      setShowUserMenu(false);
                      logout();
                    }}
                    className="flex w-full items-center gap-2.5 rounded-[var(--sf-r-xs)] px-2.5 py-2 text-[13px] font-semibold transition-colors hover:bg-[var(--sf-danger-soft)] cursor-pointer"
                    style={{ color: "var(--sf-danger)" }}
                  >
                    <LogOut className="h-4 w-4" /> Đăng xuất
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      <CommandSearch isOpen={isSearchOpen} onClose={() => setIsSearchOpen(false)} />
    </header>
  );
}
