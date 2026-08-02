"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useAuth } from "@/context/AuthContext";
import { useRealtime } from "@/context/RealtimeContext";
import {
  Search,
  Bell,
  ChevronDown,
  LogOut,
  Settings,
  User,
  Wifi,
  WifiOff,
} from "lucide-react";
import CommandSearch from "./CommandSearch";

interface HeaderProps {
  title: string;
  description?: string;
}

export default function Header({ title, description }: HeaderProps) {
  const { user, logout } = useAuth();
  const { status: realtimeStatus } = useRealtime();
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);

  // Ctrl+K keyboard shortcut
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "k") {
        e.preventDefault();
        setIsSearchOpen((prev) => !prev);
      }
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, []);

  const today = new Date().toLocaleDateString("vi-VN", {
    weekday: "long",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });

  const roleLabels: Record<string, string> = {
    ADMIN: "Quản trị viên",
    FLEET_MANAGER: "Quản lý đội xe",
    DISPATCHER: "Điều phối viên",
    SAFETY_OFFICER: "An toàn vận hành",
    RESCUE_TEAM: "Đội cứu hộ",
    DRIVER: "Tài xế",
  };

  return (
    <header className="sticky top-0 z-30 bg-white/80 dark:bg-slate-900/80 backdrop-blur-xl border-b border-slate-200 dark:border-slate-800">
      <div className="flex items-center justify-between px-6 h-16">
        {/* Left: Title + Description */}
        <div className="flex-1 min-w-0">
          <h1 className="text-lg font-bold text-slate-900 dark:text-white truncate">
            {title}
          </h1>
          {description && (
            <p className="text-xs text-slate-500 dark:text-slate-400 truncate">
              {description}
            </p>
          )}
        </div>

        {/* Center: Command Search */}
        <div className="hidden md:flex flex-1 max-w-lg mx-8">
          <button
            onClick={() => setIsSearchOpen(true)}
            className="relative w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200/60 dark:hover:bg-slate-700/60 border border-transparent hover:border-slate-200 dark:hover:border-slate-700 text-left text-sm text-slate-400 dark:text-slate-500 transition-all cursor-pointer"
          >
            <Search className="w-4 h-4 text-slate-400" />
            <span>Tìm xe, tài xế, chuyến đi, cảnh báo...</span>
            <kbd className="absolute right-3 top-1/2 -translate-y-1/2 hidden sm:inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-slate-200 dark:bg-slate-700 text-[10px] font-mono text-slate-500 dark:text-slate-400 border border-slate-300 dark:border-slate-600">
              Ctrl+K
            </kbd>
          </button>
        </div>

        {/* Right: Date + Notifications + User */}
        <div className="flex items-center gap-3">
          <div
            className="hidden xl:flex items-center gap-1.5 rounded-full border border-slate-200 bg-white px-2.5 py-1 text-[11px] font-medium text-slate-600 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-300"
            title={
              realtimeStatus === "connected"
                ? "Đang nhận dữ liệu trực tiếp từ backend"
                : "REST polling vẫn hoạt động khi realtime mất kết nối"
            }
          >
            {realtimeStatus === "connected" ? (
              <Wifi className="h-3.5 w-3.5 text-teal-600" />
            ) : (
              <WifiOff className="h-3.5 w-3.5 text-slate-400" />
            )}
            {realtimeStatus === "connected" ? "Realtime" : "Đang kết nối"}
          </div>

          {/* Date (hidden on small) */}
          <span className="hidden lg:block text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap">
            {today}
          </span>

          {/* Notification Bell */}
          <button
            className="relative p-2.5 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            title="Thông báo"
          >
            <Bell className="w-[18px] h-[18px] text-slate-500 dark:text-slate-400" />
            {/* Badge */}
            <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-red-500 rounded-full animate-pulse-dot" />
          </button>

          {/* User Menu */}
          <div className="relative">
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              className="flex items-center gap-2.5 px-2.5 py-1.5 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            >
              {/* Avatar */}
              <div className="w-8 h-8 rounded-lg bg-teal-700 flex items-center justify-center text-white text-xs font-bold shadow-sm">
                {user?.fullName?.charAt(0) || "U"}
              </div>
              {/* Name (hidden on small) */}
              <div className="hidden sm:block text-left">
                <p className="text-sm font-semibold text-slate-900 dark:text-white leading-none">
                  {user?.fullName || "User"}
                </p>
                <p className="text-[10px] text-slate-500 dark:text-slate-400 mt-0.5">
                  {user?.role ? roleLabels[user.role] || user.role : ""}
                </p>
              </div>
              <ChevronDown className="w-3.5 h-3.5 text-slate-400 hidden sm:block" />
            </button>

            {/* Dropdown */}
            {showUserMenu && (
              <div className="absolute right-0 top-full mt-2 w-52 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 py-1.5 animate-fadeInDown z-50">
                <div className="px-3 py-2 border-b border-slate-100 dark:border-slate-700 mb-1">
                  <p className="text-sm font-semibold text-slate-900 dark:text-white">
                    {user?.fullName}
                  </p>
                  <p className="text-xs text-slate-500 dark:text-slate-400">
                    {user?.email}
                  </p>
                </div>
                <Link
                  href="/profile"
                  onClick={() => setShowUserMenu(false)}
                  className="w-full flex items-center gap-2.5 px-3 py-2 text-sm text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
                >
                  <User className="w-4 h-4" />
                  Hồ sơ cá nhân
                </Link>
                <Link
                  href="/settings"
                  onClick={() => setShowUserMenu(false)}
                  className="w-full flex items-center gap-2.5 px-3 py-2 text-sm text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
                >
                  <Settings className="w-4 h-4" />
                  Cài đặt
                </Link>
                <div className="border-t border-slate-100 dark:border-slate-700 mt-1 pt-1">
                  <button
                    onClick={() => {
                      setShowUserMenu(false);
                      logout();
                    }}
                    className="w-full flex items-center gap-2.5 px-3 py-2 text-sm text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                  >
                    <LogOut className="w-4 h-4" />
                    Đăng xuất
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Command Search Dialog */}
      <CommandSearch
        isOpen={isSearchOpen}
        onClose={() => setIsSearchOpen(false)}
      />
    </header>
  );
}
