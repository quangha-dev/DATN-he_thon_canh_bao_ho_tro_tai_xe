"use client";

import { useEffect, useState, useMemo } from "react";
import { cn } from "@/lib/utils";
import { Account } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import {
  Search,
  Plus,
  Trash2,
  Lock,
  Unlock,
} from "lucide-react";
import { useToast } from "@/context/ToastContext";

export default function AccountsPage() {
  const { showToast } = useToast();
  const [searchQuery, setSearchQuery] = useState("");
  const [roleFilter, setRoleFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    const loadAccounts = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.accounts();
        if (!cancelled) setAccounts(data);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được tài khoản.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };

    loadAccounts();

    return () => {
      cancelled = true;
    };
  }, [showToast]);

  // Summary stats
  const stats = useMemo(() => {
    return {
      total: accounts.length,
      active: accounts.filter((a) => a.status === "ACTIVE").length,
      admin: accounts.filter((a) => a.role === "ADMIN").length,
      dispatcher: accounts.filter((a) => a.role === "DISPATCHER").length,
      driver: accounts.filter((a) => a.role === "DRIVER").length,
      locked: accounts.filter((a) => a.status === "LOCKED").length,
    };
  }, [accounts]);

  // Filtered accounts
  const filteredAccounts = useMemo(() => {
    return accounts.filter((a) => {
      if (roleFilter !== "all" && a.role !== roleFilter) return false;
      if (statusFilter !== "all" && a.status !== statusFilter) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        return (
          a.username.toLowerCase().includes(q) ||
          a.fullName.toLowerCase().includes(q) ||
          a.email.toLowerCase().includes(q)
        );
      }
      return true;
    });
  }, [accounts, searchQuery, roleFilter, statusFilter]);

  const updateAccount = (next: Account) => {
    setAccounts((prev) => prev.map((account) => (account.id === next.id ? next : account)));
  };

  const handleToggleLock = async (id: number, currentStatus: Account["status"]) => {
    const nextStatus = currentStatus === "ACTIVE" ? "LOCKED" : "ACTIVE";
    try {
      updateAccount(await safeFleetApi.updateAccountStatus(id, nextStatus));
      showToast(nextStatus === "LOCKED" ? "Đã khóa tài khoản." : "Đã mở khóa tài khoản.", "info");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể cập nhật tài khoản.", "error");
    }
  };

  const handleDisable = async (id: number) => {
    try {
      updateAccount(await safeFleetApi.updateAccountStatus(id, "DISABLED"));
      showToast("Đã vô hiệu hóa tài khoản.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể vô hiệu hóa tài khoản.", "error");
    }
  };

  return (
    <div className="space-y-6 animate-fadeIn">
      {/* ===== Stat Cards ===== */}
      <div className="grid grid-cols-2 lg:grid-cols-6 gap-4">
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Tổng tài khoản</span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">{stats.total}</span>
        </div>
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-emerald-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Đang hoạt động</span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">{stats.active}</span>
        </div>
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-blue-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Admin</span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">{stats.admin}</span>
        </div>
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-purple-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Điều phối viên</span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">{stats.dispatcher}</span>
        </div>
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-cyan-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Tài xế</span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">{stats.driver}</span>
        </div>
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-red-500">
          <span className="text-[10px] text-slate-500 font-semibold uppercase tracking-wider block">Bị khóa</span>
          <span className="text-2xl font-bold text-slate-900 dark:text-white mt-1 block">{stats.locked}</span>
        </div>
      </div>

      {/* ===== Toolbar & Filters ===== */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Tìm tên đăng nhập, họ tên, email..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 dark:bg-slate-800 border border-transparent rounded-lg text-sm text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:bg-white dark:focus:bg-slate-800 focus:border-slate-200 dark:focus:border-slate-700 transition"
          />
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs font-semibold text-slate-700 dark:text-slate-200 focus:outline-none"
          >
            <option value="all">Tất cả vai trò</option>
            <option value="ADMIN">Quản trị viên (ADMIN)</option>
            <option value="FLEET_MANAGER">Quản lý đội xe (FLEET_MANAGER)</option>
            <option value="DISPATCHER">Điều phối viên (DISPATCHER)</option>
            <option value="SAFETY_OFFICER">An toàn vận hành (SAFETY_OFFICER)</option>
            <option value="RESCUE_TEAM">Đội cứu hộ (RESCUE_TEAM)</option>
            <option value="DRIVER">Tài xế (DRIVER)</option>
          </select>

          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg text-xs font-semibold text-slate-700 dark:text-slate-200 focus:outline-none"
          >
            <option value="all">Tất cả trạng thái</option>
            <option value="ACTIVE">Đang hoạt động</option>
            <option value="LOCKED">Bị khóa</option>
            <option value="DISABLED">Vô hiệu hóa</option>
            <option value="PENDING">Chờ kích hoạt</option>
          </select>

          <button className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-lg shadow transition cursor-pointer">
            <Plus className="w-3.5 h-3.5" /> Tạo tài khoản
          </button>
        </div>
      </div>

      {/* ===== Table ===== */}
      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden">
        {isLoading && (
          <div className="px-4 py-2 text-xs text-blue-600 dark:text-blue-400 border-b border-slate-100 dark:border-slate-800">
            Đang tải tài khoản từ backend...
          </div>
        )}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-50/50 dark:bg-slate-800/30 border-b border-slate-100 dark:border-slate-800 text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                <th className="py-3.5 px-4">Tên đăng nhập</th>
                <th className="py-3.5 px-4">Họ và tên</th>
                <th className="py-3.5 px-4">Email</th>
                <th className="py-3.5 px-4">Vai trò</th>
                <th className="py-3.5 px-4">Trạng thái</th>
                <th className="py-3.5 px-4">Ngày tạo</th>
                <th className="py-3.5 px-4 text-center">Hành động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-800/60">
              {filteredAccounts.map((account) => {
                return (
                  <tr key={account.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-800/20 transition-colors">
                    <td className="py-3 px-4 font-bold text-slate-900 dark:text-white text-xs">
                      {account.username}
                    </td>
                    <td className="py-3 px-4 text-xs text-slate-700 dark:text-slate-300">
                      {account.fullName}
                    </td>
                    <td className="py-3 px-4 text-xs text-slate-600 dark:text-slate-400">
                      {account.email}
                    </td>
                    <td className="py-3 px-4 text-xs">
                      <span className={cn(
                        "px-2 py-0.5 rounded text-[10px] font-bold uppercase",
                        account.role === "ADMIN" && "bg-blue-100 text-blue-800 dark:bg-blue-950/40 dark:text-blue-400",
                        account.role === "DISPATCHER" && "bg-purple-100 text-purple-800 dark:bg-purple-950/40 dark:text-purple-400",
                        account.role === "DRIVER" && "bg-cyan-100 text-cyan-800 dark:bg-cyan-950/40 dark:text-cyan-400",
                        account.role === "FLEET_MANAGER" && "bg-slate-100 text-slate-800 dark:bg-slate-950/40 dark:text-slate-300",
                        account.role === "SAFETY_OFFICER" && "bg-amber-100 text-amber-800 dark:bg-amber-950/40 dark:text-amber-400",
                        account.role === "RESCUE_TEAM" && "bg-red-100 text-red-800 dark:bg-red-950/40 dark:text-red-400"
                      )}>
                        {account.role}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-xs">
                      <span className={cn(
                        "px-2 py-0.5 rounded-full text-[10px] font-bold uppercase",
                        account.status === "ACTIVE" && "bg-emerald-50 dark:bg-emerald-950/30 text-emerald-600 dark:text-emerald-400",
                        account.status === "LOCKED" && "bg-red-50 dark:bg-red-950/30 text-red-600 dark:text-red-400",
                        account.status === "DISABLED" && "bg-slate-50 dark:bg-slate-800/50 text-slate-500 dark:text-slate-400",
                        account.status === "PENDING" && "bg-amber-50 dark:bg-amber-950/30 text-amber-600 dark:text-amber-400"
                      )}>
                        {account.status === "ACTIVE"
                          ? "Hoạt động"
                          : account.status === "LOCKED"
                            ? "Bị khóa"
                            : account.status === "PENDING"
                              ? "Chờ kích hoạt"
                              : "Vô hiệu hóa"}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-xs text-slate-600 dark:text-slate-400">
                      {account.createdAt}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <div className="flex items-center justify-center gap-1.5">
                        <button
                          onClick={() => handleToggleLock(account.id, account.status)}
                          className="p-1 rounded text-slate-500 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition cursor-pointer"
                          title={account.status === "ACTIVE" ? "Khóa tài khoản" : "Mở khóa tài khoản"}
                        >
                          {account.status === "ACTIVE" ? <Lock className="w-4 h-4" /> : <Unlock className="w-4 h-4" />}
                        </button>
                        <button
                          onClick={() => handleDisable(account.id)}
                          className="p-1 rounded text-slate-500 hover:text-red-600 dark:hover:text-red-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition cursor-pointer"
                          title="Vô hiệu hóa tài khoản"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
