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
  AreaChart,
  Area,
  Cell,
} from "recharts";
import { TrendingUp, AlertTriangle, Sparkles, Download, Navigation, ShieldAlert } from "lucide-react";
import { useToast } from "@/context/ToastContext";
import { useTheme } from "@/context/ThemeContext";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { ALERT_TYPE_LABELS } from "@/lib/utils";
import {
  Button,
  Card,
  CardHeader,
  EmptyState,
  Reveal,
  SectionTitle,
  Skeleton,
  Stagger,
  StatCard,
} from "@/components/ui";

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

  return (
    <div className="space-y-5">
      {/* ===== Tiêu đề ===== */}
      <Card padding="sm">
        <SectionTitle
          eyebrow="Phân tích"
          title="Báo cáo vận hành & an toàn"
          description="Số liệu tổng hợp trực tiếp từ backend, không dùng dữ liệu minh họa."
          action={
            <Button icon={Download} size="sm" onClick={handleExport}>
              Xuất CSV
            </Button>
          }
        />
      </Card>

      {/* ===== Chỉ số tổng quan ===== */}
      <Stagger className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          label="Tổng cảnh báo"
          value={summary.totalAlerts}
          icon={ShieldAlert}
          tone="accent"
          hint="Trong kỳ dữ liệu hiện có"
        />
        <StatCard
          label="Tổng chuyến"
          value={summary.totalTrips}
          icon={Navigation}
          tone="primary"
          hint="Theo chuỗi thời gian"
        />
        <StatCard
          label="Trung bình / ngày"
          value={summary.avgTripsPerDay}
          decimals={1}
          icon={TrendingUp}
          tone="primary"
          hint="Số chuyến mỗi ngày"
        />
        <Card padding="sm" className="flex flex-col justify-center">
          <p className="sf-eyebrow flex items-center gap-1.5">
            <Sparkles className="h-3.5 w-3.5" style={{ color: "var(--sf-accent)" }} />
            Cần ưu tiên
          </p>
          <p className="mt-2 truncate text-[17px] font-extrabold tracking-tight text-sf-text">
            {summary.topAlert ? summary.topAlert.name : "—"}
          </p>
          <p className="mt-1 text-[12.5px] font-semibold text-sf-text-muted">
            {summary.topAlert ? `${summary.topAlert.count} lần ghi nhận` : "Chưa có cảnh báo"}
          </p>
        </Card>
      </Stagger>

      {/* ===== Biểu đồ ===== */}
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
        <Reveal>
          <Card padding="lg" className="h-full">
            <CardHeader
              title="Tần suất cảnh báo theo loại"
              subtitle="Nguồn: /reports/safety-events/by-type"
              icon={AlertTriangle}
            />
            <div className="mt-4 h-72 w-full">
              {isLoading ? (
                <Skeleton className="h-full w-full" />
              ) : !isClient || alertByTypeData.length === 0 ? (
                <EmptyState
                  icon={AlertTriangle}
                  title="Chưa có dữ liệu cảnh báo"
                  description="Backend chưa trả về sự kiện an toàn nào trong kỳ."
                />
              ) : (
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart
                    data={alertByTypeData}
                    margin={{ top: 8, right: 8, left: -22, bottom: 0 }}
                  >
                    <CartesianGrid
                      strokeDasharray="4 4"
                      vertical={false}
                      stroke={dark ? "rgba(160,195,210,0.10)" : "#eaeff1"}
                    />
                    <XAxis dataKey="name" {...axisStyle} interval={0} angle={-12} dy={6} />
                    <YAxis {...axisStyle} allowDecimals={false} />
                    <Tooltip
                      cursor={{ fill: dark ? "rgba(52,211,181,0.08)" : "rgba(8,127,115,0.06)" }}
                      contentStyle={tooltipStyle}
                    />
                    <Bar dataKey="count" name="Số lần" radius={[10, 10, 10, 10]} maxBarSize={30}>
                      {alertByTypeData.map((entry, index) => (
                        <Cell
                          key={index}
                          fill={barColors(dark, entry.count === maxAlertCount && entry.count > 0)}
                        />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
          </Card>
        </Reveal>

        <Reveal delay={80}>
          <Card padding="lg" className="h-full">
            <CardHeader
              title="Số chuyến theo ngày"
              subtitle="Nguồn: /reports/trips/by-day"
              icon={TrendingUp}
            />
            <div className="mt-4 h-72 w-full">
              {isLoading ? (
                <Skeleton className="h-full w-full" />
              ) : !isClient || tripTrendData.length === 0 ? (
                <EmptyState
                  icon={TrendingUp}
                  title="Chưa có dữ liệu chuyến"
                  description="Backend chưa trả về chuyến đi nào trong kỳ."
                />
              ) : (
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart
                    data={tripTrendData}
                    margin={{ top: 8, right: 8, left: -22, bottom: 0 }}
                  >
                    <defs>
                      <linearGradient id="sfTripGradient" x1="0" y1="0" x2="0" y2="1">
                        <stop
                          offset="0%"
                          stopColor={dark ? "#34d3b5" : "#087f73"}
                          stopOpacity={0.32}
                        />
                        <stop
                          offset="100%"
                          stopColor={dark ? "#34d3b5" : "#087f73"}
                          stopOpacity={0}
                        />
                      </linearGradient>
                    </defs>
                    <CartesianGrid
                      strokeDasharray="4 4"
                      vertical={false}
                      stroke={dark ? "rgba(160,195,210,0.10)" : "#eaeff1"}
                    />
                    <XAxis dataKey="date" {...axisStyle} />
                    <YAxis {...axisStyle} allowDecimals={false} />
                    <Tooltip
                      cursor={{ stroke: dark ? "#34d3b5" : "#087f73", strokeWidth: 1 }}
                      contentStyle={tooltipStyle}
                    />
                    <Area
                      type="monotone"
                      dataKey="totalTrips"
                      name="Số chuyến"
                      stroke={dark ? "#34d3b5" : "#087f73"}
                      strokeWidth={2.5}
                      fill="url(#sfTripGradient)"
                      activeDot={{ r: 5, strokeWidth: 2 }}
                      dot={{ r: 3, strokeWidth: 2 }}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </div>
          </Card>
        </Reveal>
      </div>
    </div>
  );
}
