"use client";

import { createContext, useContext, useState, useCallback, ReactNode } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { CheckCircle2, AlertTriangle, XCircle, Info, X } from "lucide-react";

type ToastType = "success" | "error" | "warning" | "info";

interface Toast {
  id: number;
  message: string;
  type: ToastType;
}

interface ToastContextType {
  showToast: (message: string, type?: ToastType) => void;
}

const ToastContext = createContext<ToastContextType | undefined>(undefined);

/** Toast dùng token semantic — chỉ tô màu icon và vạch tiến trình, nền vẫn là surface. */
const TOAST_CONFIG: Record<
  ToastType,
  { icon: typeof CheckCircle2; color: string; soft: string }
> = {
  success: { icon: CheckCircle2, color: "var(--sf-success)", soft: "var(--sf-success-soft)" },
  error: { icon: XCircle, color: "var(--sf-danger)", soft: "var(--sf-danger-soft)" },
  warning: { icon: AlertTriangle, color: "var(--sf-warning)", soft: "var(--sf-warning-soft)" },
  info: { icon: Info, color: "var(--sf-primary)", soft: "var(--sf-primary-soft)" },
};

const DURATION = 4200;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const showToast = useCallback((message: string, type: ToastType = "success") => {
    const id = Date.now() + Math.random();
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), DURATION);
  }, []);

  const removeToast = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}

      <div className="pointer-events-none fixed right-4 top-4 z-[200] flex w-full max-w-sm flex-col gap-2.5">
        <AnimatePresence initial={false}>
          {toasts.map((toast) => {
            const config = TOAST_CONFIG[toast.type];
            const Icon = config.icon;

            return (
              <motion.div
                key={toast.id}
                layout
                initial={{ opacity: 0, x: 60, scale: 0.96 }}
                animate={{ opacity: 1, x: 0, scale: 1 }}
                exit={{ opacity: 0, x: 60, scale: 0.96 }}
                transition={{ type: "spring", stiffness: 420, damping: 32 }}
                className="sf-glass-panel pointer-events-auto relative flex items-start gap-3 overflow-hidden px-4 py-3.5"
              >
                <span
                  aria-hidden
                  className="absolute inset-y-0 left-0 w-[3px]"
                  style={{ background: config.color }}
                />
                <span
                  className="mt-px grid h-7 w-7 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)]"
                  style={{ background: config.soft, color: config.color }}
                >
                  <Icon className="h-4 w-4" />
                </span>
                <p className="flex-1 pt-0.5 text-[13px] font-semibold leading-snug text-sf-text">
                  {toast.message}
                </p>
                <button
                  type="button"
                  onClick={() => removeToast(toast.id)}
                  aria-label="Đóng thông báo"
                  className="mt-px grid h-6 w-6 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)] text-sf-text-muted transition-colors hover:bg-[var(--sf-bg-inset)] hover:text-sf-text cursor-pointer"
                >
                  <X className="h-3.5 w-3.5" />
                </button>

                {/* Vạch đếm ngược */}
                <motion.span
                  aria-hidden
                  className="absolute bottom-0 left-0 h-[2px]"
                  style={{ background: config.color, opacity: 0.55 }}
                  initial={{ width: "100%" }}
                  animate={{ width: "0%" }}
                  transition={{ duration: DURATION / 1000, ease: "linear" }}
                />
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) throw new Error("useToast must be used within ToastProvider");
  return context;
}
