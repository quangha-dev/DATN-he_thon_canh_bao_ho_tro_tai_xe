"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { usePathname } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/context/AuthContext";
import { useTheme } from "@/context/ThemeContext";
import { cn } from "@/lib/utils";
import { canAccessPath } from "@/lib/accessControl";
import { safeFleetApi } from "@/lib/safeFleetApi";
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
  HardDrive,
  Moon,
  Sun,
  User,
  Bot,
  type LucideIcon,
} from "lucide-react";

/* ==========================================================================
   MENU
   --------------------------------------------------------------------------
   Bảy nhóm, đúng thứ tự bản thiết kế. "Hồ sơ cá nhân" được đưa vào nhóm
   "Hệ thống" theo bản thiết kế — trước đây chỉ vào được qua menu ở đầu trang.
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
      { key: "agent", label: "Agent quản lý", icon: Bot, path: "/agent" },
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
      { key: "profile", label: "Hồ sơ cá nhân", icon: User, path: "/profile" },
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
  const { resolvedTheme, toggleTheme } = useTheme();
  const [badges, setBadges] = useState({ alerts: 0, incidents: 0, reviews: 0 });
  const navRef = useRef<HTMLElement>(null);
  const [pillTop, setPillTop] = useState<number | null>(null);

  /* --- Badge realtime: cảnh báo mới, sự cố chưa đóng, phiếu chờ duyệt --- */
  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      const [alerts, incidents, reviews] = await Promise.all([
        safeFleetApi.safetyEvents().catch(() => []),
        safeFleetApi.incidents().catch(() => []),
        safeFleetApi.documentPlateReviews("REVIEW_REQUIRED").catch(() => []),
      ]);
      if (cancelled) return;
      setBadges({
        alerts: alerts.filter((a) => a.status === "new").length,
        incidents: incidents.filter((i) => i.status !== "resolved").length,
        reviews: reviews.length,
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

  /* --- Vệt nền trượt tới mục đang mở --- */
  const syncPill = useCallback(() => {
    const el = navRef.current?.querySelector<HTMLElement>('[data-active="true"]');
    setPillTop(el ? el.offsetTop : null);
  }, []);

  /* Danh sách menu dài hơn chiều cao màn hình nên mục đang mở có thể nằm ngoài
     vùng nhìn thấy — cuộn nó vào giữa khi đổi trang. */
  useEffect(() => {
    const nav = navRef.current;
    const el = nav?.querySelector<HTMLElement>('[data-active="true"]');
    if (!nav || !el) return;
    const top = el.offsetTop;
    const bottom = top + el.offsetHeight;
    if (top < nav.scrollTop || bottom > nav.scrollTop + nav.clientHeight) {
      nav.scrollTo({ top: top - nav.clientHeight / 2 + el.offsetHeight / 2, behavior: "smooth" });
    }
  }, [pathname, collapsed]);

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
    key === "alerts"
      ? badges.alerts
      : key === "incidents"
        ? badges.incidents
        : key === "document-reviews"
          ? badges.reviews
          : 0;

  return (
    <aside
      className={cn(
        "fixed left-0 top-0 z-50 flex h-screen flex-col bg-[var(--sf-bg-sidebar)]",
        "border-r border-[var(--sf-border-card)] px-4 pb-4 pt-[22px]",
        "shadow-[var(--sf-shadow-lg)] lg:shadow-none",
        "transition-[width,transform] duration-[420ms] ease-[var(--sf-ease-out)]",
        mobileOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0",
        collapsed ? "w-[268px] lg:w-[84px]" : "w-[268px]"
      )}
    >
      {/* ===== Logo — bấm để thu gọn / mở rộng ===== */}
      <div className="flex flex-shrink-0 items-center gap-3 px-1.5 pb-[22px]">
        <button
          type="button"
          onClick={onToggle}
          title="Thu gọn / mở thanh điều hướng"
          aria-label="Thu gọn hoặc mở thanh điều hướng"
          className="grid h-10 w-10 flex-shrink-0 cursor-pointer place-items-center rounded-[14px] transition-transform duration-[var(--sf-dur-base)] ease-[var(--sf-ease-spring)] hover:scale-[1.06]"
          style={{
            background: "linear-gradient(150deg,#34d3b5,#087f73)",
            boxShadow: "0 10px 22px -10px rgba(8,127,115,.7)",
          }}
        >
          <Shield className="h-[21px] w-[21px]" style={{ color: "#04211f" }} />
        </button>

        {!collapsed && (
          <Link
            href="/command-center"
            onClick={onMobileClose}
            className="min-w-0 animate-sf-fade overflow-hidden whitespace-nowrap"
          >
            <span className="block text-[15px] font-bold tracking-tight text-sf-text">SafeFleet</span>
            <span className="sf-eyebrow block text-[11px]">Command</span>
          </Link>
        )}
      </div>

      {/* ===== Điều hướng ===== */}
      <nav ref={navRef} className="relative min-h-0 flex-1 overflow-y-auto overflow-x-hidden pr-0.5">
        {pillTop != null && (
          <>
            <span aria-hidden className="sf-nav-pill" style={{ top: pillTop }} />
            <span aria-hidden className="sf-nav-bar" style={{ top: pillTop + 12 }} />
          </>
        )}

        {/* Nhóm KHÔNG được đặt position:relative — nếu không offsetTop của mục
            sẽ tính theo nhóm thay vì theo <nav>, làm vệt chỉ mục lệch vị trí. */}
        {visibleMenu.map((group) => (
          <div key={group.title} className="mb-2.5">
            {!collapsed && (
              <div className="mb-2 flex h-[26px] items-center whitespace-nowrap px-2.5 text-[10.5px] uppercase tracking-[0.13em] text-sf-text-muted">
                {group.title}
              </div>
            )}
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
                  title={item.label}
                  className={cn(
                    "sf-nav-item mb-1",
                    active && "sf-nav-item-active",
                    collapsed && "justify-center px-0"
                  )}
                >
                  <span className="relative flex-shrink-0">
                    <Icon className="h-[21px] w-[21px]" />
                    {collapsed && count > 0 && (
                      <span
                        className="sf-tnum absolute -right-2 -top-1.5 grid h-[17px] min-w-[17px] place-items-center rounded-full px-1 text-[10px] font-bold text-white"
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
                          className="sf-tnum grid h-5 min-w-[20px] flex-shrink-0 place-items-center rounded-full px-1.5 text-[11px] font-semibold text-white"
                          style={{ background: badgeColor }}
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
        ))}
      </nav>

      {/* ===== Chân: đổi nền sáng/tối + đăng xuất ===== */}
      <div className="flex flex-shrink-0 flex-col gap-1.5 border-t border-[var(--sf-border-card)] pt-3.5">
        <button
          type="button"
          onClick={toggleTheme}
          title={resolvedTheme === "dark" ? "Chuyển nền sáng" : "Chuyển nền tối"}
          className={cn(
            "flex h-[42px] cursor-pointer items-center gap-3 rounded-[14px] px-3 text-[13px] text-sf-text-muted transition-colors hover:bg-[var(--sf-hover)] hover:text-sf-text",
            collapsed && "justify-center px-0"
          )}
        >
          {resolvedTheme === "dark" ? (
            <Sun className="h-5 w-5 flex-shrink-0" />
          ) : (
            <Moon className="h-5 w-5 flex-shrink-0" />
          )}
          {!collapsed && (
            <span className="whitespace-nowrap">
              {resolvedTheme === "dark" ? "Nền sáng" : "Nền tối"}
            </span>
          )}
        </button>

        <button
          type="button"
          onClick={logout}
          title="Đăng xuất"
          className={cn(
            "group flex h-[42px] cursor-pointer items-center gap-3 rounded-[14px] px-3 text-[13px] text-sf-text-muted transition-colors hover:bg-[var(--sf-danger-soft)] hover:text-[var(--sf-danger)]",
            collapsed && "justify-center px-0"
          )}
        >
          <LogOut className="h-5 w-5 flex-shrink-0" />
          {!collapsed && <span className="whitespace-nowrap">Đăng xuất</span>}
        </button>
      </div>
    </aside>
  );
}
