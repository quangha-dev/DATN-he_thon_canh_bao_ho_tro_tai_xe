"use client";

import * as React from "react";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

/**
 * PageTransition — bọc nội dung mỗi trang. Khi pathname đổi, `key` đổi nên
 * React remount và animation chạy lại. Không dùng thư viện ngoài để giữ nhẹ.
 */
export function PageTransition({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  const pathname = usePathname();
  return (
    <div key={pathname} className={cn("animate-sf-rise-sm", className)}>
      {children}
    </div>
  );
}

/**
 * Stagger — các con xuất hiện lần lượt. Dùng cho lưới thẻ thống kê,
 * danh sách cảnh báo, danh sách chuyến.
 */
export function Stagger({
  children,
  className,
  as: Tag = "div",
}: {
  children: React.ReactNode;
  className?: string;
  as?: "div" | "ul" | "section";
}) {
  return <Tag className={cn("sf-stagger", className)}>{children}</Tag>;
}

/**
 * Reveal — hiện dần khi cuộn tới. Dùng cho các khối phía dưới trang dài.
 */
export function Reveal({
  children,
  delay = 0,
  className,
}: {
  children: React.ReactNode;
  delay?: number;
  className?: string;
}) {
  const ref = React.useRef<HTMLDivElement>(null);
  const [shown, setShown] = React.useState(false);

  React.useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (typeof IntersectionObserver === "undefined") {
      setShown(true);
      return;
    }
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setShown(true);
          io.disconnect();
        }
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.05 }
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  return (
    <div
      ref={ref}
      className={cn(
        "transition-[opacity,transform] duration-[var(--sf-dur-slow)] ease-[var(--sf-ease-out)]",
        shown ? "translate-y-0 opacity-100" : "translate-y-3 opacity-0",
        className
      )}
      style={{ transitionDelay: `${delay}ms` }}
    >
      {children}
    </div>
  );
}
