"use client";

import { useState } from "react";
import { usePathname } from "next/navigation";
import Sidebar from "@/components/layout/Sidebar";
import Header from "@/components/layout/Header";
import { cn } from "@/lib/utils";
import { canAccessPath } from "@/lib/accessControl";
import { useAuth } from "@/context/AuthContext";
import { ShieldAlert } from "lucide-react";

// Page title mapping
const PAGE_META: Record<string, { title: string; description?: string }> = {
  "/command-center": { title: "Trung tâm điều hành", description: "Tổng quan hoạt động đội xe realtime" },
  "/realtime-map": { title: "Bản đồ Realtime", description: "Theo dõi vị trí xe trên bản đồ" },
  "/dispatch": { title: "Điều phối chuyến", description: "Lập kế hoạch và giao chuyến" },
  "/trips": { title: "Quản lý chuyến đi", description: "Danh sách và theo dõi chuyến" },
  "/vehicles": { title: "Quản lý phương tiện", description: "Danh sách và thông tin xe" },
  "/drivers": { title: "Quản lý tài xế", description: "Danh sách tài xế và điểm an toàn" },
  "/alerts": { title: "Cảnh báo AI", description: "Trung tâm an toàn — Cảnh báo từ hệ thống AI" },
  "/incidents": { title: "SOS / Sự cố", description: "Phòng xử lý sự cố khẩn cấp" },
  "/flood-map": { title: "Điểm ngập", description: "Bản đồ thông tin ngập lụt" },
  "/devices": { title: "Quản lý thiết bị", description: "GPS, camera, cảm biến" },
  "/maintenance": { title: "Bảo trì", description: "Lịch bảo trì và sửa chữa" },
  "/reports": { title: "Báo cáo", description: "Số liệu vận hành và an toàn từ backend" },
  "/accounts": { title: "Tài khoản", description: "Quản lý người dùng hệ thống" },
  "/permissions": { title: "Phân quyền", description: "Vai trò và ma trận quyền" },
  "/settings": { title: "Cấu hình", description: "Cài đặt hệ thống" },
  "/profile": { title: "Hồ sơ cá nhân", description: "Thông tin tài khoản và bảo mật" },
};

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const pathname = usePathname();
  const { user } = useAuth();

  // Find matching page meta
  const matchedPath = Object.keys(PAGE_META).find((path) =>
    pathname.startsWith(path)
  );
  const pageMeta = matchedPath
    ? PAGE_META[matchedPath]
    : { title: "SafeFleet Command Center" };

  // Full-screen pages (map pages don't need padding)
  const isFullScreen = ["/realtime-map", "/flood-map"].includes(pathname);
  const canAccess = user ? canAccessPath(user.role, pathname) : true;

  return (
    <div className="sf-app-shell flex min-h-screen overflow-x-hidden">
      {mobileMenuOpen && (
        <button type="button" aria-label="Đóng menu điều hướng" onClick={() => setMobileMenuOpen(false)} className="fixed inset-0 z-40 bg-slate-950/45 backdrop-blur-[2px] lg:hidden" />
      )}
      {/* Sidebar */}
      <Sidebar
        collapsed={sidebarCollapsed}
        onToggle={() => setSidebarCollapsed(!sidebarCollapsed)}
        mobileOpen={mobileMenuOpen}
        onMobileClose={() => setMobileMenuOpen(false)}
      />

      {/* Main content area */}
      <div
        className={cn(
          "min-w-0 flex-1 flex flex-col transition-all duration-300",
          sidebarCollapsed ? "lg:ml-[72px]" : "lg:ml-[260px]"
        )}
      >
        {/* Header */}
        <Header title={pageMeta.title} description={pageMeta.description} onMenuClick={() => setMobileMenuOpen(true)} />

        {/* Page content */}
        <main
          className={cn(
            "min-w-0 flex-1 overflow-x-hidden overflow-y-auto",
            isFullScreen ? "" : "p-4 sm:p-6"
          )}
        >
          {canAccess ? (
            children
          ) : (
            <div className="min-h-[calc(100vh-160px)] flex items-center justify-center">
              <div className="max-w-md w-full rounded-2xl border border-amber-200 dark:border-amber-900 bg-amber-50 dark:bg-amber-950/20 p-6 text-center">
                <ShieldAlert className="w-10 h-10 text-amber-500 mx-auto mb-3" />
                <h2 className="text-base font-bold text-slate-900 dark:text-white">
                  Không có quyền truy cập
                </h2>
                <p className="text-sm text-slate-600 dark:text-slate-300 mt-2">
                  Tài khoản hiện tại không được phép mở màn hình này.
                </p>
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
