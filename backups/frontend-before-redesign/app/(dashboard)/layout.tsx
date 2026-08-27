"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import Sidebar from "@/components/layout/Sidebar";
import Header from "@/components/layout/Header";
import { PageTransition } from "@/components/ui";
import { cn } from "@/lib/utils";
import { canAccessPath } from "@/lib/accessControl";
import { useAuth } from "@/context/AuthContext";
import { ShieldAlert } from "lucide-react";

const PAGE_META: Record<string, { title: string; description?: string }> = {
  "/command-center": { title: "Trung tâm điều hành", description: "Tổng quan hoạt động đội xe theo thời gian thực" },
  "/realtime-map": { title: "Bản đồ realtime", description: "Theo dõi vị trí và trạng thái xe trên bản đồ" },
  "/dispatch": { title: "Điều phối chuyến", description: "Lập kế hoạch, gợi ý ghép xe và giao chuyến" },
  "/trips": { title: "Chuyến đi & chứng từ", description: "Danh sách, tiến độ và phiếu xuất kho" },
  "/document-reviews": { title: "Duyệt phiếu lệch biển", description: "Đối chiếu biển số OCR với xe cố định của tài xế" },
  "/vehicles": { title: "Quản lý phương tiện", description: "Danh sách xe, thiết bị và hạn đăng kiểm" },
  "/drivers": { title: "Quản lý tài xế", description: "Hồ sơ tài xế, điểm an toàn và giờ lái" },
  "/alerts": { title: "Cảnh báo AI", description: "Trung tâm an toàn — sự kiện phát hiện bởi mô hình AI" },
  "/incidents": { title: "SOS / Sự cố", description: "Phòng xử lý sự cố khẩn cấp" },
  "/flood-map": { title: "Điểm ngập & rủi ro", description: "Bản đồ ngập lụt và tuyến đường rủi ro" },
  "/devices": { title: "Quản lý thiết bị", description: "GPS, camera hành trình, cảm biến" },
  "/maintenance": { title: "Bảo trì", description: "Lệnh bảo trì, sửa chữa và nhắc hạn" },
  "/reports": { title: "Báo cáo", description: "Số liệu vận hành và an toàn từ backend" },
  "/accounts": { title: "Tài khoản", description: "Quản lý người dùng và trạng thái truy cập" },
  "/settings": { title: "Cấu hình hệ thống", description: "Tham số vận hành và ngưỡng cảnh báo" },
  "/profile": { title: "Hồ sơ cá nhân", description: "Thông tin tài khoản và bảo mật" },
};

const FULLSCREEN_PATHS = ["/realtime-map", "/flood-map"];
const SIDEBAR_KEY = "safefleet-sidebar-collapsed";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const pathname = usePathname();
  const { user } = useAuth();

  /* Ghi nhớ trạng thái thu gọn sidebar */
  useEffect(() => {
    setSidebarCollapsed(window.localStorage.getItem(SIDEBAR_KEY) === "1");
  }, []);

  const toggleSidebar = () => {
    setSidebarCollapsed((prev) => {
      window.localStorage.setItem(SIDEBAR_KEY, prev ? "0" : "1");
      return !prev;
    });
  };

  /* Khóa cuộn nền khi mở menu mobile */
  useEffect(() => {
    document.body.style.overflow = mobileMenuOpen ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [mobileMenuOpen]);

  const matchedPath = Object.keys(PAGE_META)
    .sort((a, b) => b.length - a.length)
    .find((path) => pathname.startsWith(path));
  const pageMeta = matchedPath ? PAGE_META[matchedPath] : { title: "SafeFleet Command Center" };

  const isFullScreen = FULLSCREEN_PATHS.includes(pathname);
  const canAccess = user ? canAccessPath(user.role, pathname) : true;

  return (
    <div className="sf-app-shell flex min-h-screen overflow-x-hidden">
      {mobileMenuOpen && (
        <button
          type="button"
          aria-label="Đóng menu điều hướng"
          onClick={() => setMobileMenuOpen(false)}
          className="fixed inset-0 z-40 animate-sf-fade bg-[var(--sf-bg-overlay)] backdrop-blur-[2px] lg:hidden"
        />
      )}

      <Sidebar
        collapsed={sidebarCollapsed}
        onToggle={toggleSidebar}
        mobileOpen={mobileMenuOpen}
        onMobileClose={() => setMobileMenuOpen(false)}
      />

      <div
        className={cn(
          "flex min-w-0 flex-1 flex-col transition-[margin] duration-[var(--sf-dur-base)] ease-[var(--sf-ease-out)]",
          sidebarCollapsed ? "lg:ml-[80px]" : "lg:ml-[268px]"
        )}
      >
        <Header
          title={pageMeta.title}
          description={pageMeta.description}
          onMenuClick={() => setMobileMenuOpen(true)}
        />

        <main className={cn("min-w-0 flex-1 overflow-x-hidden", isFullScreen ? "" : "p-4 sm:p-6")}>
          {canAccess ? (
            <PageTransition className={isFullScreen ? "h-full" : undefined}>
              {children}
            </PageTransition>
          ) : (
            <div className="flex min-h-[calc(100vh-200px)] items-center justify-center">
              <div
                className="sf-surface w-full max-w-md animate-sf-scale p-7 text-center"
                style={{ borderColor: "color-mix(in srgb, var(--sf-warning) 34%, transparent)" }}
              >
                <span
                  className="mx-auto mb-4 grid h-12 w-12 place-items-center rounded-[var(--sf-r-md)]"
                  style={{ background: "var(--sf-warning-soft)", color: "var(--sf-warning)" }}
                >
                  <ShieldAlert className="h-6 w-6" />
                </span>
                <h2 className="text-base font-extrabold text-sf-text">Không có quyền truy cập</h2>
                <p className="mt-2 text-[13px] text-sf-text-secondary">
                  Tài khoản hiện tại không được phép mở màn hình này. Liên hệ quản trị viên nếu bạn
                  cho rằng đây là nhầm lẫn.
                </p>
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
