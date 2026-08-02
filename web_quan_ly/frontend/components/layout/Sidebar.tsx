"use client";

import { useState, useEffect } from "react";
import { usePathname } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/context/AuthContext";
import { cn } from "@/lib/utils";
import { canAccessPath } from "@/lib/accessControl";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { useTheme } from "@/context/ThemeContext";
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
  Sun,
  Moon,
  Shield,
  Wrench,
  type LucideIcon,
} from "lucide-react";

// =============================================================================
// MENU STRUCTURE
// =============================================================================
interface MenuItem {
  key: string;
  label: string;
  icon: LucideIcon;
  path: string;
  badge?: number;
  badgeColor?: string;
}

interface MenuGroup {
  title: string;
  items: MenuItem[];
}

const MENU: MenuGroup[] = [
  {
    title: "COMMAND",
    items: [
      { key: "command-center", label: "Trung tâm điều hành", icon: LayoutDashboard, path: "/command-center" },
      { key: "realtime-map", label: "Bản đồ realtime", icon: Map, path: "/realtime-map" },
    ],
  },
  {
    title: "OPERATIONS",
    items: [
      { key: "dispatch", label: "Điều phối chuyến", icon: Route, path: "/dispatch" },
      { key: "trips", label: "Chuyến đi & chứng từ", icon: Navigation, path: "/trips" },
    ],
  },
  {
    title: "SAFETY",
    items: [
      { key: "alerts", label: "Cảnh báo AI", icon: ShieldAlert, path: "/alerts", badgeColor: "bg-amber-500" },
      { key: "incidents", label: "SOS / Sự cố", icon: Siren, path: "/incidents", badgeColor: "bg-red-500" },
      { key: "flood-map", label: "Điểm ngập & rủi ro", icon: Droplets, path: "/flood-map" },
    ],
  },
  {
    title: "FLEET",
    items: [
      { key: "vehicles", label: "Phương tiện", icon: Car, path: "/vehicles" },
      { key: "drivers", label: "Tài xế", icon: Users, path: "/drivers" },
      { key: "maintenance", label: "Bảo trì", icon: Wrench, path: "/maintenance" },
    ],
  },
  {
    title: "INTELLIGENCE",
    items: [
      { key: "reports", label: "Báo cáo", icon: BarChart3, path: "/reports" },
    ],
  },
  {
    title: "SYSTEM",
    items: [
      { key: "accounts", label: "Tài khoản", icon: UserCog, path: "/accounts" },
      { key: "settings", label: "Cấu hình", icon: Settings, path: "/settings" },
    ],
  },
];

// =============================================================================
// SIDEBAR COMPONENT
// =============================================================================
interface SidebarProps {
  collapsed: boolean;
  onToggle: () => void;
}

export default function Sidebar({ collapsed, onToggle }: SidebarProps) {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const { resolvedTheme, toggleTheme } = useTheme();
  const [liveBadges, setLiveBadges] = useState({ alerts: 0, incidents: 0 });

  useEffect(() => {
    let cancelled = false;
    const loadBadges = async () => {
      const [alerts, incidents] = await Promise.all([
        safeFleetApi.safetyEvents().catch(() => []),
        safeFleetApi.incidents().catch(() => []),
      ]);
      if (!cancelled) {
        setLiveBadges({
          alerts: alerts.filter((alert) => alert.status === "new").length,
          incidents: incidents.filter((incident) => incident.status !== "resolved").length,
        });
      }
    };
    void loadBadges();
    const timer = window.setInterval(loadBadges, 30_000);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
    };
  }, []);
  const isActive = (path: string) => {
    if (path === "/command-center") return pathname === "/command-center";
    return pathname.startsWith(path);
  };

  const visibleMenu = MENU
    .map((group) => ({
      ...group,
      items: group.items
        .filter((item) => !user || canAccessPath(user.role, item.path))
        .map((item) => ({
          ...item,
          badge:
            item.key === "alerts"
              ? liveBadges.alerts
              : item.key === "incidents"
                ? liveBadges.incidents
                : item.badge,
        })),
    }))
    .filter((group) => group.items.length > 0);

  return (
    <aside
      className={cn(
        "fixed top-0 left-0 h-screen flex flex-col z-50 transition-all duration-300 ease-in-out",
        "bg-[var(--sf-bg-sidebar)] border-r border-slate-800",
        collapsed ? "w-[72px]" : "w-[260px]"
      )}
    >
      {/* ===== Header ===== */}
      <div className="flex items-center justify-between px-4 h-16 border-b border-slate-800 flex-shrink-0">
        {!collapsed && (
          <button
            type="button"
            onClick={onToggle}
            className="flex items-center gap-2.5 rounded-lg text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-400"
            title="Thu gọn thanh điều hướng"
            aria-label="Thu gọn thanh điều hướng"
          >
            <div className="w-9 h-9 rounded-lg bg-teal-600 flex items-center justify-center">
              <Shield className="w-5 h-5 text-white" />
            </div>
            <div className="overflow-hidden">
              <h1 className="text-sm font-bold text-white tracking-tight leading-none">
                SafeFleet
              </h1>
              <p className="text-[9px] text-blue-400 font-medium tracking-wider uppercase leading-none mt-0.5">
                Command Center
              </p>
            </div>
          </button>
        )}
        {collapsed && (
          <button
            type="button"
            onClick={onToggle}
            className="mx-auto rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-400"
            title="Mở rộng thanh điều hướng"
            aria-label="Mở rộng thanh điều hướng"
          >
            <div className="w-9 h-9 rounded-lg bg-teal-600 flex items-center justify-center">
              <Shield className="w-5 h-5 text-white" />
            </div>
          </button>
        )}
      </div>

      {/* ===== Navigation ===== */}
      <nav className="flex-1 overflow-y-auto py-3 px-2.5 space-y-5">
        {visibleMenu.map((group) => (
          <div key={group.title}>
            {/* Group title */}
            {!collapsed && (
              <p className="text-[10px] font-bold text-slate-500 uppercase tracking-[0.12em] px-2.5 mb-2">
                {group.title}
              </p>
            )}
            {collapsed && (
              <div className="w-6 h-px bg-slate-700 mx-auto mb-2" />
            )}

            {/* Items */}
            <div className="space-y-0.5">
              {group.items.map((item) => {
                const Icon = item.icon;
                const active = isActive(item.path);

                return (
                  <Link
                    key={item.key}
                    href={item.path}
                    title={collapsed ? item.label : undefined}
                    className={cn(
                      "flex items-center gap-3 px-2.5 py-2 rounded-lg font-medium text-sm transition-all duration-150 group relative",
                      active
                        ? "bg-teal-500/15 text-teal-300"
                        : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/60",
                      collapsed && "justify-center px-0"
                    )}
                  >
                    {/* Active indicator */}
                    {active && (
                      <div className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 bg-teal-400 rounded-r-full" />
                    )}

                    <Icon
                      className={cn(
                        "w-[18px] h-[18px] flex-shrink-0 transition-colors",
                        active ? "text-blue-400" : "text-slate-500 group-hover:text-slate-300"
                      )}
                    />

                    {!collapsed && (
                      <>
                        <span className="truncate">{item.label}</span>
                        {item.badge && (
                          <span
                            className={cn(
                              "ml-auto px-1.5 py-0.5 rounded-full text-[10px] font-bold text-white min-w-[18px] text-center",
                              item.badgeColor || "bg-blue-500"
                            )}
                          >
                            {item.badge}
                          </span>
                        )}
                      </>
                    )}

                    {/* Collapsed badge */}
                    {collapsed && item.badge && (
                      <span
                        className={cn(
                          "absolute -top-0.5 -right-0.5 w-4 h-4 rounded-full text-[9px] font-bold text-white flex items-center justify-center",
                          item.badgeColor || "bg-blue-500"
                        )}
                      >
                        {item.badge}
                      </span>
                    )}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      {/* ===== Footer ===== */}
      <div className="border-t border-slate-800 p-2.5 space-y-1.5 flex-shrink-0">
        {/* Theme toggle */}
        <button
          onClick={toggleTheme}
          className={cn(
            "flex items-center gap-3 w-full px-2.5 py-2 rounded-lg text-sm font-medium text-slate-400 hover:text-slate-200 hover:bg-slate-800/60 transition-all",
            collapsed && "justify-center px-0"
          )}
          title={resolvedTheme === "dark" ? "Chuyển sang chế độ sáng" : "Chuyển sang chế độ tối"}
          aria-label={resolvedTheme === "dark" ? "Chuyển sang chế độ sáng" : "Chuyển sang chế độ tối"}
        >
          {resolvedTheme === "dark" ? (
            <Sun className="w-[18px] h-[18px] text-amber-400" />
          ) : (
            <Moon className="w-[18px] h-[18px] text-slate-500" />
          )}
          {!collapsed && (
            <span>{resolvedTheme === "dark" ? "Chế độ sáng" : "Chế độ tối"}</span>
          )}
        </button>

        {/* Logout */}
        <button
          onClick={logout}
          className={cn(
            "flex items-center gap-3 w-full px-2.5 py-2 rounded-lg text-sm font-medium text-red-400 hover:text-red-300 hover:bg-red-500/10 transition-all",
            collapsed && "justify-center px-0"
          )}
          title="Đăng xuất"
        >
          <LogOut className="w-[18px] h-[18px]" />
          {!collapsed && <span>Đăng xuất</span>}
        </button>
      </div>
    </aside>
  );
}
