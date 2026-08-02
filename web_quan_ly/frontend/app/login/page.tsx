"use client";

import { useState } from "react";
import { useAuth } from "@/context/AuthContext";
import { useToast } from "@/context/ToastContext";
import { motion } from "framer-motion";
import {
  Shield,
  Eye,
  EyeOff,
  Loader2,
  Truck,
  MapPin,
  AlertTriangle,
} from "lucide-react";

const SHOW_DEMO_CREDENTIALS =
  process.env.NEXT_PUBLIC_SHOW_DEMO_CREDENTIALS === "true";

export default function LoginPage() {
  const { login, isLoading } = useAuth();
  const { showToast } = useToast();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [remember, setRemember] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      showToast("Vui lòng nhập đầy đủ thông tin", "warning");
      return;
    }
    try {
      await login(username, password);
      showToast("Đăng nhập thành công!", "success");
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Đăng nhập thất bại";
      showToast(message, "error");
    }
  };

  return (
    <div className="min-h-screen flex">
      {/* Left Panel — Branding */}
      <div className="hidden lg:flex lg:w-[55%] relative overflow-hidden bg-[#10243d]">
        {/* Background pattern */}
        <div className="absolute inset-0 opacity-10">
          <div
            className="absolute inset-0"
            style={{
              backgroundImage:
                "radial-gradient(circle at 2px 2px, rgba(255,255,255,0.15) 1px, transparent 0)",
              backgroundSize: "40px 40px",
            }}
          />
        </div>

        {/* Floating elements */}
        <motion.div
          animate={{ y: [0, -15, 0] }}
          transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-[15%] left-[10%] w-20 h-20 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center"
        >
          <Truck className="w-8 h-8 text-teal-300" />
        </motion.div>

        <motion.div
          animate={{ y: [0, 12, 0] }}
          transition={{
            duration: 5,
            repeat: Infinity,
            ease: "easeInOut",
            delay: 1,
          }}
          className="absolute top-[35%] right-[15%] w-16 h-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center"
        >
          <MapPin className="w-7 h-7 text-teal-300" />
        </motion.div>

        <motion.div
          animate={{ y: [0, -10, 0] }}
          transition={{
            duration: 4,
            repeat: Infinity,
            ease: "easeInOut",
            delay: 2,
          }}
          className="absolute bottom-[25%] left-[20%] w-14 h-14 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center"
        >
          <AlertTriangle className="w-6 h-6 text-amber-400" />
        </motion.div>

        {/* Main content */}
        <div className="relative z-10 flex flex-col justify-center px-16 xl:px-24">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
          >
            {/* Logo */}
            <div className="flex items-center gap-3 mb-8">
              <div className="w-12 h-12 rounded-xl bg-teal-600 flex items-center justify-center">
                <Shield className="w-7 h-7 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-white tracking-tight">
                  SafeFleet
                </h1>
                <p className="text-xs text-teal-200 font-medium tracking-wider uppercase">
                  Command Center
                </p>
              </div>
            </div>

            {/* Title */}
            <h2 className="text-4xl xl:text-5xl font-bold text-white leading-tight mb-6">
              Trung tâm điều hành
              <br />
              <span className="text-teal-300">
                đội xe thông minh
              </span>
            </h2>

            <p className="text-lg text-slate-400 max-w-md leading-relaxed mb-10">
              Giám sát realtime, cảnh báo AI, hỗ trợ an toàn tài xế và cứu hộ
              tự động — tất cả trong một nền tảng duy nhất.
            </p>

            {/* Features */}
            <div className="space-y-4">
              {[
                "Theo dõi đội xe realtime trên bản đồ",
                "AI nhận diện hành vi ngủ gật, mất tập trung",
                "Cảnh báo SOS & cứu hộ tự động",
                "Báo cáo điểm ngập thông minh",
              ].map((feature, i) => (
                <motion.div
                  key={i}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.4 + i * 0.15 }}
                  className="flex items-center gap-3"
                >
                  <div className="w-2 h-2 rounded-full bg-teal-400" />
                  <span className="text-slate-300 text-sm">{feature}</span>
                </motion.div>
              ))}
            </div>
          </motion.div>
        </div>

        {/* Bottom gradient fade */}
        <div className="absolute bottom-0 left-0 right-0 h-32 bg-[#10243d]/80" />
      </div>

      {/* Right Panel — Login Form */}
      <div className="flex-1 flex items-center justify-center px-6 py-12 bg-slate-50 dark:bg-slate-900">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="w-full max-w-md"
        >
          {/* Mobile logo */}
          <div className="lg:hidden flex items-center gap-3 mb-8 justify-center">
            <div className="w-11 h-11 rounded-xl bg-teal-600 flex items-center justify-center">
              <Shield className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-slate-900 dark:text-white">
                SafeFleet
              </h1>
              <p className="text-[10px] text-teal-700 dark:text-teal-400 font-medium tracking-wider uppercase">
                Command Center
              </p>
            </div>
          </div>

          {/* Header */}
          <div className="mb-8">
            <h2 className="text-2xl font-bold text-slate-900 dark:text-white">
              Đăng nhập
            </h2>
            <p className="text-slate-500 dark:text-slate-400 mt-1">
              Truy cập vào hệ thống điều hành đội xe
            </p>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Username */}
            <div>
              <label
                htmlFor="login-username"
                className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
              >
                Username hoặc email
              </label>
              <input
                id="login-username"
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="Nhập username hoặc email..."
                autoComplete="username"
                className="w-full px-4 py-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-teal-500/30 focus:border-teal-600 transition-all"
              />
            </div>

            {/* Password */}
            <div>
              <label
                htmlFor="login-password"
                className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
              >
                Mật khẩu
              </label>
              <div className="relative">
                <input
                  id="login-password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Nhập mật khẩu..."
                  autoComplete="current-password"
                  className="w-full px-4 py-3 pr-12 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-teal-500/30 focus:border-teal-600 transition-all"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition"
                >
                  {showPassword ? (
                    <EyeOff className="w-5 h-5" />
                  ) : (
                    <Eye className="w-5 h-5" />
                  )}
                </button>
              </div>
            </div>

            {/* Remember + Forgot */}
            <div className="flex items-center justify-between">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={remember}
                  onChange={(e) => setRemember(e.target.checked)}
                  className="w-4 h-4 rounded border-slate-300 dark:border-slate-600 text-teal-600 focus:ring-teal-500/30"
                />
                <span className="text-sm text-slate-600 dark:text-slate-400">
                  Ghi nhớ đăng nhập
                </span>
              </label>
              <button
                type="button"
                className="text-sm text-teal-700 dark:text-teal-400 hover:text-teal-800 font-medium transition"
              >
                Quên mật khẩu?
              </button>
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-3 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-semibold shadow-sm disabled:opacity-60 disabled:cursor-not-allowed transition-all duration-200 flex items-center justify-center gap-2"
            >
              {isLoading ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin" />
                  Đang đăng nhập...
                </>
              ) : (
                "Đăng nhập"
              )}
            </button>
          </form>

          {SHOW_DEMO_CREDENTIALS && (
            <div className="mt-8 p-4 rounded-xl bg-teal-50 dark:bg-teal-950/30 border border-teal-100 dark:border-teal-900/50">
              <p className="text-xs text-teal-800 dark:text-teal-400 font-medium mb-2">
                Tài khoản seed backend:
              </p>
              <div className="space-y-1 text-xs text-teal-700 dark:text-teal-400/80">
                <p>
                  <span className="font-mono bg-teal-100 dark:bg-teal-900/50 px-1.5 py-0.5 rounded">
                    admin
                  </span>{" "}
                  /{" "}
                  <span className="font-mono bg-teal-100 dark:bg-teal-900/50 px-1.5 py-0.5 rounded">
                    123456
                  </span>{" "}
                  — Quản trị viên
                </p>
                <p>
                  <span className="font-mono bg-teal-100 dark:bg-teal-900/50 px-1.5 py-0.5 rounded">
                    dispatcher
                  </span>{" "}
                  /{" "}
                  <span className="font-mono bg-teal-100 dark:bg-teal-900/50 px-1.5 py-0.5 rounded">
                    123456
                  </span>{" "}
                  — Điều phối viên
                </p>
              </div>
            </div>
          )}

          {/* Footer */}
          <p className="text-center text-xs text-slate-400 dark:text-slate-500 mt-6">
            © 2026 SafeFleet Agentic AI — Đồ án tốt nghiệp
          </p>
        </motion.div>
      </div>
    </div>
  );
}
