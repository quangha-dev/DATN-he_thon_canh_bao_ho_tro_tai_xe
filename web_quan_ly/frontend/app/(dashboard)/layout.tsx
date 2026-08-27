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

/* Nhãn nhóm + tên trang hiển thị ở đầu trang — khớp đúng nhóm menu bên trái */
const PAGE_META: Record<string, { group: string; title: string }> = {
  "/command-center": { group: "Điều hành", title: "Trung tâm điều hành" },
  "/agent": { group: "Điều hành", title: "Agent quản lý" },
  "/realtime-map": { group: "Điều hành", title: "Bản đồ realtime" },
  "/drivers": { group: "Quản lý", title: "Quản lý tài xế" },
  "/accounts": { group: "Quản lý", title: "Quản lý tài khoản" },
  "/vehicles": { group: "Quản lý", title: "Quản lý phương tiện" },
  "/dispatch": { group: "Vận hành", title: "Điều phối chuyến" },
  "/trips": { group: "Vận hành", title: "Chuyến đi & chứng từ" },
  "/document-reviews": { group: "Vận hành", title: "Duyệt phiếu lệch biển số" },
  "/alerts": { group: "An toàn", title: "Cảnh báo AI" },
  "/incidents": { group: "An toàn", title: "SOS / Sự cố" },
  "/flood-map": { group: "An toàn", title: "Điểm ngập & rủi ro" },
  "/devices": { group: "Đội xe", title: "Thiết bị" },
  "/maintenance": { group: "Đội xe", title: "Bảo trì" },
  "/reports": { group: "Phân tích", title: "Báo cáo" },
  "/settings": { group: "Hệ thống", title: "Cấu hình" },
  "/profile": { group: "Hệ thống", title: "Hồ sơ cá nhân" },
};

const FULLSCREEN_PATHS = ["/realtime-map"];
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
    .find((path) => pathname === path || pathname.startsWith(`${path}/`));
  const pageMeta = matchedPath
    ? PAGE_META[matchedPath]
    : { group: "", title: "SafeFleet Command Center" };

  const isFullScreen = FULLSCREEN_PATHS.some((p) => pathname.startsWith(p));
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
          sidebarCollapsed ? "lg:ml-[84px]" : "lg:ml-[268px]"
        )}
      >
        <Header
          group={pageMeta.group}
          title={pageMeta.title}
          onMenuClick={() => setMobileMenuOpen(true)}
        />

        <main
          className={cn(
            "min-w-0 flex-1 overflow-x-hidden",
            isFullScreen ? "p-4 sm:px-[30px] sm:py-5" : "p-4 sm:px-[30px] sm:pb-10 sm:pt-[26px]"
          )}
        >
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
