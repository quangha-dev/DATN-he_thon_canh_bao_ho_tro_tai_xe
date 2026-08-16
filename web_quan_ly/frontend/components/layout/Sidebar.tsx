"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { usePathname } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/context/AuthContext";
import { cn } from "@/lib/utils";
import { canAccessPath } from "@/lib/accessControl";
import { safeFleetApi } from "@/lib/safeFleetApi";
import ThemeSwitch from "./ThemeSwitch";
import {
  LayoutDashboard,
  Map,
  Route,
  Navigation,
  Car,
  Users,
  ShieldAlert,
  Siren,
  Droplets,
  BarChart3,
  UserCog,
  Settings,
  LogOut,
  Shield,
  FileWarning,
  Wrench,
  PanelLeftClose,
  PanelLeftOpen,
  HardDrive,
  LifeBuoy,
  Sparkles,
  ChevronRight,
  type LucideIcon,
} from "lucide-react";

/* ==========================================================================
   MENU
   ========================================================================== */
interface MenuItem {
  key: string;
  label: string;
  icon: LucideIcon;
  path: string;
  badgeTone?: "danger" | "accent";
}

interface MenuGroup {
  title: string;
  items: MenuItem[];
}

const MENU: MenuGroup[] = [
  {
    title: "Điều hành",
    items: [
      { key: "command-center", label: "Trung tâm điều hành", icon: LayoutDashboard, path: "/command-center" },
      { key: "realtime-map", label: "Bản đồ realtime", icon: Map, path: "/realtime-map" },
    ],
  },
  {
    title: "Quản lý",
    items: [
      { key: "drivers", label: "Quản lý tài xế", icon: Users, path: "/drivers" },
      { key: "accounts", label: "Quản lý tài khoản", icon: UserCog, path: "/accounts" },
      { key: "vehicles", label: "Quản lý phương tiện", icon: Car, path: "/vehicles" },
    ],
  },
  {
    title: "Vận hành",
    items: [
      { key: "dispatch", label: "Điều phối chuyến", icon: Route, path: "/dispatch" },
      { key: "trips", label: "Chuyến đi & chứng từ", icon: Navigation, path: "/trips" },
      { key: "document-reviews", label: "Duyệt phiếu lệch biển", icon: FileWarning, path: "/document-reviews", badgeTone: "accent" },
    ],
  },
  {
    title: "An toàn",
    items: [
      { key: "alerts", label: "Cảnh báo AI", icon: ShieldAlert, path: "/alerts", badgeTone: "accent" },
      { key: "incidents", label: "SOS / Sự cố", icon: Siren, path: "/incidents", badgeTone: "danger" },
      { key: "flood-map", label: "Điểm ngập & rủi ro", icon: Droplets, path: "/flood-map" },
    ],
  },
  {
    title: "Đội xe",
    items: [
      { key: "devices", label: "Thiết bị", icon: HardDrive, path: "/devices" },
      { key: "maintenance", label: "Bảo trì", icon: Wrench, path: "/maintenance" },
    ],
  },
  {
    title: "Phân tích",
    items: [{ key: "reports", label: "Báo cáo", icon: BarChart3, path: "/reports" }],
  },
  {
    title: "Hệ thống",
    items: [
      { key: "settings", label: "Cấu hình", icon: Settings, path: "/settings" },
    ],
  },
];

/* ==========================================================================
   SIDEBAR
   ========================================================================== */
interface SidebarProps {
  collapsed: boolean;
  onToggle: () => void;
  mobileOpen: boolean;
  onMobileClose: () => void;
}

export default function Sidebar({ collapsed, onToggle, mobileOpen, onMobileClose }: SidebarProps) {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const [badges, setBadges] = useState({ alerts: 0, incidents: 0 });
  const navRef = useRef<HTMLElement>(null);
  const [pill, setPill] = useState<{ top: number; height: number } | null>(null);

  /* --- Badge realtime --- */
  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      const [alerts, incidents] = await Promise.all([
        safeFleetApi.safetyEvents().catch(() => []),
        safeFleetApi.incidents().catch(() => []),
      ]);
      if (cancelled) return;
      setBadges({
        alerts: alerts.filter((a) => a.status === "new").length,
        incidents: incidents.filter((i) => i.status !== "resolved").length,
      });
    };
    void load();
    const timer = window.setInterval(load, 30_000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, []);

  const isActive = useCallback(
    (path: string) => (path === "/command-center" ? pathname === path : pathname.startsWith(path)),
    [pathname]
  );

  /* --- Con trượt chỉ mục trang đang mở --- */
  const syncPill = useCallback(() => {
    const el = navRef.current?.querySelector<HTMLElement>('[data-active="true"]');
    if (el) setPill({ top: el.offsetTop, height: el.offsetHeight });
    else setPill(null);
  }, []);

  useEffect(() => {
    const raf = requestAnimationFrame(syncPill);
    return () => cancelAnimationFrame(raf);
  }, [pathname, collapsed, badges, syncPill]);

  useEffect(() => {
    const nav = navRef.current;
    if (!nav) return;
    const ro = new ResizeObserver(syncPill);
    ro.observe(nav);
    nav.addEventListener("scroll", syncPill, { passive: true });
    return () => {
      ro.disconnect();
      nav.removeEventListener("scroll", syncPill);
    };
  }, [syncPill]);

  const visibleMenu = MENU.map((group) => ({
    ...group,
    items: group.items.filter((item) => !user || canAccessPath(user.role, item.path)),
  })).filter((group) => group.items.length > 0);

  const badgeFor = (key: string) =>
    key === "alerts" ? badges.alerts : key === "incidents" ? badges.incidents : 0;

  return (
    <aside
      className={cn(
        "fixed left-0 top-0 z-50 flex h-screen flex-col bg-[var(--sf-bg-sidebar)]",
        "border-r border-[var(--sf-border-card)]",
        "shadow-[var(--sf-shadow-lg)] lg:shadow-none",
        "transition-[width,transform] duration-[var(--sf-dur-base)] ease-[var(--sf-ease-out)]",
        mobileOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0",
        collapsed ? "w-[268px] lg:w-[80px]" : "w-[268px]"
      )}
    >
      {/* ===== Logo ===== */}
      <div
        className={cn(
          "flex h-[76px] flex-shrink-0 items-center",
          collapsed ? "justify-center px-3" : "justify-between px-5"
        )}
      >
        <Link
          href="/command-center"
          onClick={onMobileClose}
          className="flex min-w-0 items-center gap-2.5"
          title="SafeFleet Command Center"
        >
          <span
            className="grid h-9 w-9 flex-shrink-0 place-items-center rounded-[var(--sf-r-sm)]"
            style={{ background: "var(--sf-primary)" }}
          >
            <Shield className="h-[19px] w-[19px] text-[var(--sf-primary-contrast)]" />
          </span>
          {!collapsed && (
            <span className="min-w-0 animate-sf-fade text-[19px] font-extrabold tracking-tight text-sf-text">
              SafeFleet
            </span>
          )}
        </Link>

        {!collapsed && (
          <button
            type="button"
            onClick={onToggle}
            aria-label="Thu gọn thanh điều hướng"
            title="Thu gọn thanh điều hướng"
            className="hidden h-8 w-8 place-items-center rounded-[var(--sf-r-xs)] text-sf-text-muted transition-colors hover:bg-[var(--sf-bg-inset)] hover:text-sf-text lg:grid cursor-pointer"
          >
            <PanelLeftClose className="h-4 w-4" />
          </button>
        )}
      </div>

      {/* ===== Nav ===== */}
      <nav
        ref={navRef}
        className={cn(
          "relative min-h-0 flex-1 overflow-y-auto overflow-x-hidden pb-3",
          collapsed ? "px-3" : "px-4"
        )}
      >
        {/* Viên thuốc nền trượt theo mục đang mở */}
        {pill && (
          <span
            aria-hidden
            className="pointer-events-none absolute inset-x-0 z-0 rounded-[var(--sf-r-sm)] transition-all duration-[var(--sf-dur-base)] ease-[var(--sf-ease-spring)]"
            style={{
              top: pill.top,
              height: pill.height,
              background: "var(--sf-primary)",
              boxShadow: "0 8px 20px -8px rgba(var(--sf-primary-rgb), 0.6)",
            }}
          />
        )}

        <div className={collapsed ? "space-y-4" : "space-y-5"}>
          {visibleMenu.map((group) => (
            <div key={group.title}>
              {!collapsed ? (
                <p className="mb-1.5 px-3 text-[12.5px] font-bold uppercase tracking-wider text-sf-text-muted">
                  {group.title}
                </p>
              ) : (
                <div className="mx-auto mb-2 h-px w-7 bg-[var(--sf-border-light)]" />
              )}

              <div className="space-y-1">
                {group.items.map((item) => {
                  const Icon = item.icon;
                  const active = isActive(item.path);
                  const count = badgeFor(item.key);
                  const badgeColor =
                    item.badgeTone === "danger" ? "var(--sf-danger)" : "var(--sf-accent)";

                  return (
                    <Link
                      key={item.key}
                      href={item.path}
                      data-active={active}
                      onClick={onMobileClose}
                      title={collapsed ? item.label : undefined}
                      className={cn(
                        "group relative z-10 flex items-center rounded-[var(--sf-r-sm)] text-[14px] font-semibold",
                        "transition-colors duration-[var(--sf-dur-fast)]",
                        collapsed ? "justify-center px-0 py-3" : "gap-3 px-3 py-3",
                        active
                          ? "text-[var(--sf-primary-contrast)]"
                          : "text-sf-text-secondary hover:bg-[var(--sf-bg-inset)] hover:text-sf-text"
                      )}
                    >
                      <span className="relative flex-shrink-0">
                        <Icon
                          className={cn(
                            "h-[19px] w-[19px]",
                            active ? "text-[var(--sf-primary-contrast)]" : "text-sf-text-muted"
                          )}
                        />
                        {collapsed && count > 0 && (
                          <span
                            className="sf-tnum absolute -right-2 -top-2 grid h-[17px] min-w-[17px] place-items-center rounded-full px-1 text-[12px] font-extrabold text-white"
                            style={{ background: badgeColor }}
                          >
                            {count > 99 ? "99+" : count}
                          </span>
                        )}
                      </span>

                      {!collapsed && (
                        <>
                          <span className="min-w-0 flex-1 truncate">{item.label}</span>
                          {count > 0 && (
                            <span
                              className="sf-tnum grid h-[20px] min-w-[20px] flex-shrink-0 place-items-center rounded-full px-1.5 text-[12.5px] font-extrabold text-white"
                              style={{ background: active ? "rgba(255,255,255,0.28)" : badgeColor }}
                            >
                              {count > 99 ? "99+" : count}
                            </span>
                          )}
                        </>
                      )}
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </nav>

      {/* ===== Footer ===== */}
      <div
        className={cn("flex-shrink-0 space-y-2.5 pb-4", collapsed ? "px-3" : "px-4")}
      >
        {collapsed ? (
          <>
            <button
              type="button"
              onClick={onToggle}
              aria-label="Mở rộng thanh điều hướng"
              title="Mở rộng thanh điều hướng"
              className="mx-auto grid h-10 w-10 place-items-center rounded-[var(--sf-r-sm)] text-sf-text-muted transition-colors hover:bg-[var(--sf-bg-inset)] hover:text-sf-text cursor-pointer"
            >
              <PanelLeftOpen className="h-4 w-4" />
            </button>
            <ThemeSwitch compact />
            <button
              type="button"
              onClick={logout}
              aria-label="Đăng xuất"
              title="Đăng xuất"
              className="mx-auto grid h-10 w-10 place-items-center rounded-[var(--sf-r-sm)] transition-colors hover:bg-[var(--sf-danger-soft)] cursor-pointer"
              style={{ color: "var(--sf-danger)" }}
            >
              <LogOut className="h-4 w-4" />
            </button>
          </>
        ) : (
          <>
            {/* Hỗ trợ */}
            <Link
              href="/settings"
              onClick={onMobileClose}
              className="flex items-center gap-3 rounded-[var(--sf-r-sm)] px-3 py-3 text-[14px] font-semibold text-sf-text-secondary transition-colors hover:bg-[var(--sf-bg-inset)] hover:text-sf-text"
            >
              <LifeBuoy className="h-[19px] w-[19px] text-sf-text-muted" />
              Trung tâm hỗ trợ
            </Link>

            {/* Thẻ trạng thái hệ thống */}
            <div
              className="rounded-[var(--sf-r-md)] p-3.5"
              style={{ background: "var(--sf-accent-soft)" }}
            >
              <div className="flex items-center gap-2">
                <Sparkles className="h-4 w-4" style={{ color: "var(--sf-accent-hover)" }} />
                <p
                  className="text-[13px] font-extrabold"
                  style={{ color: "var(--sf-accent-hover)" }}
                >
                  Trợ lý AI đang bật
                </p>
              </div>
              <p className="mt-1 text-[12px] leading-snug text-sf-text-secondary">
                Đang giám sát {badges.alerts + badges.incidents > 0 ? "và có việc cần xử lý" : "toàn bộ đội xe"}.
              </p>
              <Link
                href="/alerts"
                onClick={onMobileClose}
                className="mt-2.5 inline-flex items-center gap-1 text-[12.5px] font-bold"
                style={{ color: "var(--sf-accent-hover)" }}
              >
                Xem cảnh báo
                <ChevronRight className="h-3.5 w-3.5" />
              </Link>
            </div>

            <ThemeSwitch />

            {/* Người dùng + đăng xuất */}
            <div className="flex items-center gap-2.5 rounded-[var(--sf-r-sm)] px-1 pt-1">
              <span
                className="grid h-9 w-9 flex-shrink-0 place-items-center rounded-full text-[13px] font-extrabold"
                style={{ background: "var(--sf-primary-soft)", color: "var(--sf-primary)" }}
              >
                {user?.fullName?.charAt(0)?.toUpperCase() || "U"}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13px] font-bold leading-tight text-sf-text">
                  {user?.fullName || "Người dùng"}
                </span>
                <span className="block truncate text-[12.5px] leading-tight text-sf-text-muted">
                  {user?.email || ""}
                </span>
              </span>
            </div>

            <button
              type="button"
              onClick={logout}
              className="flex w-full items-center gap-3 rounded-[var(--sf-r-sm)] px-3 py-2.5 text-[14px] font-bold transition-colors hover:bg-[var(--sf-danger-soft)] cursor-pointer"
              style={{ color: "var(--sf-danger)" }}
            >
              <LogOut className="h-[18px] w-[18px]" />
              Đăng xuất
            </button>
          </>
        )}
      </div>
    </aside>
  );
}
