"use client";

import type { ReactNode } from "react";
import { BadgeCheck, KeyRound, Mail, ShieldCheck, UserRound } from "lucide-react";
import { useAuth } from "@/context/AuthContext";

const roleLabels: Record<string, string> = {
  ADMIN: "Quản trị viên",
  FLEET_MANAGER: "Quản lý đội xe",
  DISPATCHER: "Điều phối viên",
  SAFETY_OFFICER: "An toàn vận hành",
  RESCUE_TEAM: "Đội cứu hộ",
  DRIVER: "Tài xế",
};

export default function ProfilePage() {
  const { user } = useAuth();

  if (!user) return null;

  const initial = user.fullName?.trim().charAt(0).toUpperCase() || "U";

  return (
    <div className="mx-auto max-w-5xl space-y-6 animate-fadeIn">
      <section className="overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900">
        <div className="h-28 bg-[linear-gradient(110deg,#0f766e_0%,#0f766e_46%,#dff7f3_46%,#f8fafc_100%)]" />
        <div className="px-6 pb-7 sm:px-8">
          <div className="-mt-12 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div className="flex items-end gap-4">
              <div className="flex h-24 w-24 items-center justify-center rounded-3xl border-4 border-white bg-slate-900 text-3xl font-black text-white shadow-lg dark:border-slate-900">
                {initial}
              </div>
              <div className="pb-1">
                <div className="flex items-center gap-2">
                  <h2 className="text-xl font-black text-slate-950 dark:text-white">
                    {user.fullName}
                  </h2>
                  <BadgeCheck className="h-5 w-5 text-teal-600" />
                </div>
                <p className="mt-1 text-sm font-medium text-slate-500">
                  {roleLabels[user.role] || user.role}
                </p>
              </div>
            </div>
            <span className="inline-flex w-fit items-center gap-2 rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-bold text-emerald-700 ring-1 ring-emerald-200">
              <span className="h-2 w-2 rounded-full bg-emerald-500" />
              Tài khoản đang hoạt động
            </span>
          </div>
        </div>
      </section>

      <div className="grid gap-6 lg:grid-cols-[1.35fr_0.65fr]">
        <section className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900">
          <div className="mb-6 flex items-center gap-3">
            <div className="rounded-2xl bg-teal-50 p-3 text-teal-700">
              <UserRound className="h-5 w-5" />
            </div>
            <div>
              <h3 className="font-bold text-slate-950 dark:text-white">Thông tin tài khoản</h3>
              <p className="text-xs text-slate-500">Dữ liệu được đồng bộ từ hệ thống xác thực</p>
            </div>
          </div>
          <dl className="grid gap-4 sm:grid-cols-2">
            <Info label="Họ và tên" value={user.fullName} />
            <Info label="Tên đăng nhập" value={user.username} />
            <Info label="Email" value={user.email} icon={<Mail className="h-4 w-4" />} />
            <Info label="Vai trò" value={roleLabels[user.role] || user.role} />
            <Info label="Mã tài khoản" value={`SF-${String(user.id).padStart(4, "0")}`} />
            <Info label="Trạng thái" value="Đang hoạt động" />
          </dl>
        </section>

        <section className="rounded-3xl border border-slate-200 bg-slate-950 p-6 text-white shadow-sm">
          <ShieldCheck className="h-8 w-8 text-teal-300" />
          <h3 className="mt-5 text-lg font-bold">Bảo mật tài khoản</h3>
          <p className="mt-2 text-sm leading-6 text-slate-400">
            Phiên đăng nhập được bảo vệ bằng JWT và tự động làm mới an toàn.
          </p>
          <div className="mt-6 flex items-center gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4">
            <KeyRound className="h-5 w-5 text-teal-300" />
            <div>
              <p className="text-xs font-bold">Mật khẩu</p>
              <p className="mt-0.5 text-xs text-slate-500">Được lưu dưới dạng mã hóa một chiều</p>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function Info({ label, value, icon }: { label: string; value: string; icon?: ReactNode }) {
  return (
    <div className="rounded-2xl border border-slate-100 bg-slate-50 px-4 py-3.5 dark:border-slate-800 dark:bg-slate-950">
      <dt className="text-[11px] font-bold uppercase tracking-wider text-slate-400">{label}</dt>
      <dd className="mt-1.5 flex items-center gap-2 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {icon}
        <span className="truncate">{value || "Chưa cập nhật"}</span>
      </dd>
    </div>
  );
}
