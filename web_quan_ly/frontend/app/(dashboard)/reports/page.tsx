"use client";

import { useState, useEffect, useMemo } from "react";
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Cell,
} from "recharts";
import { AlertTriangle, Download, Navigation, ShieldAlert, Sparkles, TrendingUp } from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { useTheme } from "@/context/ThemeContext";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { ALERT_TYPE_LABELS } from "@/lib/utils";
import { EmptyState, Skeleton, StatCard } from "@/components/ui";

/**
 * Cột biểu đồ để tông rất nhạt cho êm mắt; riêng cột cao nhất mới tô đậm màu
 * thương hiệu để mắt bắt ngay điểm cần chú ý.
 */
function barColors(dark: boolean, isTop: boolean) {
  if (isTop) return dark ? "#34d3b5" : "#087f73";
  return dark ? "rgba(52, 211, 181, 0.28)" : "#d1faee";
}

export default function ReportsPage() {
  const { showToast } = useToast();
  const { resolvedTheme } = useTheme();
  const dark = resolvedTheme === "dark";
  const [isClient, setIsClient] = useState(false);
  const [alertByTypeData, setAlertByTypeData] = useState<{ name: string; count: number }[]>([]);
  const [tripTrendData, setTripTrendData] = useState<{ date: string; totalTrips: number }[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => setIsClient(true), []);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const [alertsByType, tripsByDay] = await Promise.all([
          safeFleetApi.reportSafetyEventsByType(),
          safeFleetApi.reportTripsByDay(),
        ]);
        if (cancelled) return;
        setAlertByTypeData(
          Object.entries(alertsByType).map(([key, count]) => ({
            name: ALERT_TYPE_LABELS[key.toLowerCase()] || key.replaceAll("_", " "),
            count,
          }))
        );
        setTripTrendData(
          tripsByDay.map((item) => ({
            date: new Date(item.date).toLocaleDateString("vi-VN", {
              day: "2-digit",
              month: "2-digit",
            }),
            totalTrips: item.totalTrips,
          }))
        );
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được báo cáo.";
        if (!cancelled) showToast(message, "error");
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    };
    void load();
    return () => {
      cancelled = true;
    };
  }, [showToast]);

  const summary = useMemo(() => {
    const totalAlerts = alertByTypeData.reduce((sum, i) => sum + i.count, 0);
    const totalTrips = tripTrendData.reduce((sum, i) => sum + i.totalTrips, 0);
    const topAlert = [...alertByTypeData].sort((a, b) => b.count - a.count)[0];
    const avgTripsPerDay = tripTrendData.length
      ? Math.round((totalTrips / tripTrendData.length) * 10) / 10
      : 0;
    return { totalAlerts, totalTrips, topAlert, avgTripsPerDay };
  }, [alertByTypeData, tripTrendData]);

  const maxAlertCount = Math.max(0, ...alertByTypeData.map((i) => i.count));
  const maxTripCount = Math.max(0, ...tripTrendData.map((i) => i.totalTrips));

  const axisStyle = {
    stroke: dark ? "#8ba3b0" : "#5f7482",
    fontSize: 12,
    tickLine: false,
    axisLine: false,
  };

  const tooltipStyle = {
    background: dark ? "#14222c" : "#ffffff",
    border: "none",
    borderRadius: 16,
    color: dark ? "#eef5f7" : "#0c1720",
    fontSize: 13,
    fontWeight: 600,
    boxShadow: dark ? "0 20px 44px -14px rgba(0,0,0,0.7)" : "0 20px 44px -14px rgba(20,40,55,0.2)",
    padding: "10px 14px",
  };

  const handleExport = () => {
    const rows = [
      ["Nhóm dữ liệu", "Chỉ tiêu", "Giá trị"],
      ...alertByTypeData.map((i) => ["Cảnh báo", i.name, String(i.count)]),
      ...tripTrendData.map((i) => ["Chuyến đi", i.date, String(i.totalTrips)]),
    ];
    const csv = rows
      .map((row) => row.map((cell) => `"${cell.replaceAll('"', '""')}"`).join(","))
      .join("\r\n");
    const url = URL.createObjectURL(new Blob(["﻿", csv], { type: "text/csv;charset=utf-8" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `bao-cao-safefleet-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    showToast("Đã xuất báo cáo từ dữ liệu backend.", "success");
  };

  /* Bảng màu thanh ngang: hai loại nhiều nhất dùng teal, kế đó amber,
     riêng nhóm liên quan điểm ngập dùng xanh dương — giống bản thiết kế. */
  const barGradient = (index: number, name: string) => {
    if (/ngập|flood/i.test(name)) return "sf-track-info";
    return index < 2 ? "" : "sf-track-warn";
  };

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Tổng cảnh báo"
          value={summary.totalAlerts}
          icon={ShieldAlert}
          delta="trong kỳ dữ liệu hiện có"
          delay={0}
        />
        <StatCard
          label="Tổng chuyến"
          value={summary.totalTrips}
          icon={Navigation}
          tone="primary"
          delta={`${tripTrendData.length} ngày`}
          delay={70}
        />
        <StatCard
          label="Trung bình mỗi ngày"
          value={summary.avgTripsPerDay}
          decimals={1}
          icon={TrendingUp}
          tone="success"
          delta="chuyến/ngày"
          delay={140}
        />
        <StatCard
          label="Cảnh báo phổ biến"
          value={summary.topAlert ? summary.topAlert.name : "—"}
          icon={Sparkles}
          tone="warning"
          deltaTone="warning"
          delta={
            summary.topAlert && summary.totalAlerts
              ? `chiếm ${Math.round((summary.topAlert.count / summary.totalAlerts) * 100)}%`
              : "chưa có cảnh báo"
          }
          delay={210}
        />
      </div>

      {/* ===== Hai biểu đồ ===== */}
      <div className="grid gap-5 lg:grid-cols-2">
        {/* --- Cảnh báo theo loại: thanh ngang như bản thiết kế --- */}
        <div className="sf-surface p-6">
          <div className="mb-5 flex items-start justify-between gap-4">
            <div>
              <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
                Cảnh báo theo loại
              </div>
              <div className="mt-1 text-[12.5px] text-sf-text-muted">
                Nguồn: /reports/safety-events/by-type
              </div>
            </div>
            <button type="button" className="sf-pill-ghost" onClick={handleExport}>
              <Download className="h-[17px] w-[17px]" />
              Xuất CSV
            </button>
          </div>

          {isLoading ? (
            <div className="grid gap-4">
              {[0, 1, 2, 3, 4].map((i) => (
                <Skeleton key={i} className="h-8 w-full" />
              ))}
            </div>
          ) : alertByTypeData.length === 0 ? (
            <EmptyState
              icon={AlertTriangle}
              title="Chưa có dữ liệu cảnh báo"
              description="Backend chưa trả về sự kiện an toàn nào trong kỳ."
              compact
            />
          ) : (
            <div className="grid gap-4">
              {[...alertByTypeData]
                .sort((a, b) => b.count - a.count)
                .map((item, index) => (
                  <div key={item.name}>
                    <div className="mb-1.5 flex justify-between gap-3 text-[12.5px]">
                      <span className="truncate text-sf-text">{item.name}</span>
                      <span className="sf-mono flex-none text-sf-text-muted">{item.count}</span>
                    </div>
                    <div className={`sf-track !h-2.5 ${barGradient(index, item.name)}`}>
                      <span
                        style={{
                          width: `${maxAlertCount ? Math.round((item.count / maxAlertCount) * 100) : 0}%`,
                        }}
                      />
                    </div>
                  </div>
                ))}
            </div>
          )}
        </div>

        {/* --- Số chuyến theo ngày: giữ Recharts để còn trục và tooltip --- */}
        <div className="sf-surface p-6">
          <div className="mb-5">
            <div className="text-[15.5px] font-bold tracking-[-0.01em] text-sf-text">
              Số chuyến theo ngày
            </div>
            <div className="mt-1 text-[12.5px] text-sf-text-muted">
              Nguồn: /reports/trips/by-day
            </div>
          </div>

          <div className="h-[264px] w-full">
            {isLoading ? (
              <Skeleton className="h-full w-full" />
            ) : !isClient || tripTrendData.length === 0 ? (
              <EmptyState
                icon={TrendingUp}
                title="Chưa có dữ liệu chuyến"
                description="Backend chưa trả về chuyến đi nào trong kỳ."
                compact
              />
            ) : (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={tripTrendData} margin={{ top: 8, right: 8, left: -22, bottom: 0 }}>
                  <CartesianGrid
                    strokeDasharray="4 4"
                    vertical={false}
                    stroke={dark ? "rgba(160,195,210,0.10)" : "#eaeff1"}
                  />
                  <XAxis dataKey="date" {...axisStyle} />
                  <YAxis {...axisStyle} allowDecimals={false} />
                  <Tooltip
                    cursor={{ fill: dark ? "rgba(52,211,181,0.08)" : "rgba(8,127,115,0.06)" }}
                    contentStyle={tooltipStyle}
                  />
                  <Bar dataKey="totalTrips" name="Số chuyến" radius={[10, 10, 4, 4]} maxBarSize={26}>
                    {tripTrendData.map((entry, index) => (
                      <Cell
                        key={index}
                        fill={barColors(dark, entry.totalTrips === maxTripCount && entry.totalTrips > 0)}
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
