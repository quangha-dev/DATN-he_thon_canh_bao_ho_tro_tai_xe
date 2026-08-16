"use client";

import { useEffect, useState, useMemo } from "react";
import { Alert, AlertSeverity, AlertType } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { cn, formatDateTime, formatTimeAgo } from "@/lib/utils";
import { useToast } from "@/context/ToastContext";
import {
  Badge,
  Button,
  Callout,
  Card,
  CardHeader,
  EmptyState,
  IconButton,
  InfoRow,
  Select,
  Skeleton,
  StatusDot,
  TONE,
  toneOf,
} from "@/components/ui";
import {
  ShieldAlert,
  Phone,
  MessageSquare,
  AlertTriangle,
  MapPin,
  Gauge,
  User,
  Truck,
  Video,
  CheckCircle2,
  Inbox,
} from "lucide-react";

const ALERT_TYPE_VI: Record<AlertType, string> = {
  drowsy: "Ngủ gật",
  phone_usage: "Dùng điện thoại",
  distraction: "Mất tập trung",
  overtime: "Quá giờ lái",
  speeding: "Vượt tốc độ",
  route_deviation: "Lệch tuyến",
  abnormal_stop: "Dừng bất thường",
  connection_lost: "Mất kết nối",
  near_flood: "Gần điểm ngập",
};

const SEVERITY_VI: Record<AlertSeverity, string> = {
  low: "Thấp",
  medium: "Trung bình",
  high: "Cao",
  critical: "Nghiêm trọng",
};

export default function AlertsPage() {
  const { showToast } = useToast();
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedAlertId, setSelectedAlertId] = useState("");
  const [severityFilter, setSeverityFilter] = useState("all");
  const [typeFilter, setTypeFilter] = useState("all");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.safetyEvents();
        if (cancelled) return;
        setAlerts(data);
        setSelectedAlertId((current) => current || data[0]?.id || "");
      } catch (error) {
        const message = error instanceof Error ? error.message : "Không tải được cảnh báo.";
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

  const filteredAlerts = useMemo(
    () =>
      alerts.filter((a) => {
        if (severityFilter !== "all" && a.severity !== severityFilter) return false;
        if (typeFilter !== "all" && a.type !== typeFilter) return false;
        return true;
      }),
    [alerts, severityFilter, typeFilter]
  );

  const selectedAlert = useMemo(
    () => alerts.find((a) => a.id === selectedAlertId),
    [alerts, selectedAlertId]
  );

  const counts = useMemo(
    () => ({
      new: alerts.filter((a) => a.status === "new").length,
      critical: alerts.filter((a) => a.severity === "critical" && a.status !== "resolved").length,
    }),
    [alerts]
  );

  const updateAlert = (next: Alert) => {
    setAlerts((prev) => prev.map((a) => (a.id === next.id ? next : a)));
    setSelectedAlertId(next.id);
  };

  const handleAcknowledge = async (id: string) => {
    setBusy(true);
    try {
      updateAlert(await safeFleetApi.acknowledgeSafetyEvent(id));
      showToast("Đã tiếp nhận cảnh báo.", "info");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể tiếp nhận cảnh báo.", "error");
    } finally {
      setBusy(false);
    }
  };

  const handleResolve = async (id: string) => {
    setBusy(true);
    try {
      updateAlert(await safeFleetApi.resolveSafetyEvent(id));
      showToast("Đã đánh dấu cảnh báo đã xử lý.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể xử lý cảnh báo.", "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex h-[calc(100vh-116px)] flex-col gap-4">
      {/* ===== Thanh lọc ===== */}
      <Card padding="sm" className="flex-shrink-0">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-2">
            <Select
              ariaLabel="Lọc theo mức độ"
              value={severityFilter}
              onChange={setSeverityFilter}
              options={[
                { value: "all", label: "Tất cả mức độ" },
                ...Object.entries(SEVERITY_VI).map(([value, label]) => ({ value, label })),
              ]}
            />
            <Select
              ariaLabel="Lọc theo loại cảnh báo"
              value={typeFilter}
              onChange={setTypeFilter}
              options={[
                { value: "all", label: "Tất cả loại cảnh báo" },
                ...Object.entries(ALERT_TYPE_VI).map(([value, label]) => ({ value, label })),
              ]}
              className="min-w-[12rem]"
            />
          </div>

          <div className="flex items-center gap-2">
            <Badge tone="danger" icon={AlertTriangle}>
              {counts.critical} nghiêm trọng
            </Badge>
            <Badge tone="accent">{counts.new} chưa xử lý</Badge>
            <span className="text-[12.5px] font-semibold text-sf-text-muted">
              {filteredAlerts.length} kết quả
            </span>
          </div>
        </div>
      </Card>

      {/* ===== Nội dung ===== */}
      <div className="grid min-h-0 flex-1 grid-cols-1 gap-5 overflow-y-auto pb-2 lg:grid-cols-3 lg:overflow-hidden">
        {/* --- Danh sách --- */}
        <Card padding="none" className="flex min-h-0 flex-col lg:col-span-1">
          <div className="flex flex-shrink-0 items-center justify-between border-b border-[var(--sf-border)] px-4 py-3.5">
            <CardHeader
              title="Dòng cảnh báo"
              subtitle="Cập nhật theo thời gian thực"
              icon={ShieldAlert}
            />
            <StatusDot tone={isLoading ? "warning" : "success"} pulse />
          </div>

          <div className="min-h-0 flex-1 space-y-1 overflow-y-auto p-2">
            {isLoading && alerts.length === 0 ? (
              Array.from({ length: 6 }).map((_, i) => (
                <div key={i} className="flex gap-3 p-3">
                  <Skeleton className="h-8 w-8 rounded-[var(--sf-r-xs)]" />
                  <div className="flex-1 space-y-2">
                    <Skeleton className="h-3 w-28" />
                    <Skeleton className="h-2.5 w-40" />
                  </div>
                </div>
              ))
            ) : filteredAlerts.length === 0 ? (
              <EmptyState
                icon={Inbox}
                title="Không có cảnh báo"
                description="Chưa ghi nhận cảnh báo nào khớp bộ lọc hiện tại."
              />
            ) : (
              filteredAlerts.map((alert) => {
                const active = alert.id === selectedAlertId;
                const tone = toneOf(alert.severity);
                return (
                  <button
                    key={alert.id}
                    onClick={() => setSelectedAlertId(alert.id)}
                    className={cn(
                      "relative flex w-full items-start gap-3 rounded-[var(--sf-r-sm)] border p-3 pl-4 text-left transition-colors duration-[var(--sf-dur-fast)] cursor-pointer",
                      active
                        ? "border-[color-mix(in_srgb,var(--sf-primary)_36%,transparent)] bg-[var(--sf-primary-soft)]"
                        : "border-transparent hover:bg-[var(--sf-bg-inset)]"
                    )}
                  >
                    <span
                      className="absolute bottom-3 left-0 top-3 w-[3px] rounded-r-full"
                      style={{ background: TONE[tone].dot }}
                    />
                    <span
                      className="grid h-8 w-8 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)]"
                      style={{ background: TONE[tone].bg, color: TONE[tone].fg }}
                    >
                      <AlertTriangle className="h-4 w-4" />
                    </span>

                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2">
                        <span className="truncate text-[12.5px] font-extrabold text-sf-text">
                          {ALERT_TYPE_VI[alert.type] || alert.type}
                        </span>
                        <span className="flex-shrink-0 text-[12px] font-semibold text-sf-text-muted">
                          {formatTimeAgo(alert.timestamp)}
                        </span>
                      </span>
                      <span className="mt-0.5 block truncate text-[12.5px] text-sf-text-secondary">
                        {alert.vehiclePlate} · {alert.driverName}
                      </span>
                      <span className="mt-1.5 flex flex-wrap items-center gap-1.5">
                        <Badge tone={tone} size="sm">
                          {SEVERITY_VI[alert.severity]}
                        </Badge>
                        {alert.status !== "new" && (
                          <Badge tone={toneOf(alert.status)} size="sm">
                            {alert.status === "resolved" ? "Đã xử lý" : "Đã tiếp nhận"}
                          </Badge>
                        )}
                        {alert.repeatCount && alert.repeatCount > 1 ? (
                          <Badge tone="danger" size="sm">
                            Lặp {alert.repeatCount}×
                          </Badge>
                        ) : null}
                      </span>
                    </span>
                  </button>
                );
              })
            )}
          </div>
        </Card>

        {/* --- Chi tiết --- */}
        <Card padding="none" className="flex min-h-0 flex-col lg:col-span-2">
          {selectedAlert ? (
            <>
              <div className="flex flex-shrink-0 flex-wrap items-start justify-between gap-3 border-b border-[var(--sf-border)] px-5 py-4">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <h3 className="text-base font-extrabold tracking-tight text-sf-text">
                      {ALERT_TYPE_VI[selectedAlert.type] || selectedAlert.type}
                    </h3>
                    <Badge tone={toneOf(selectedAlert.severity)} solid>
                      {SEVERITY_VI[selectedAlert.severity]}
                    </Badge>
                    <Badge tone={toneOf(selectedAlert.status)}>
                      {selectedAlert.status === "resolved"
                        ? "Đã xử lý"
                        : selectedAlert.status === "new"
                          ? "Chưa xử lý"
                          : "Đã tiếp nhận"}
                    </Badge>
                  </div>
                  <p className="mt-1 text-[12.5px] text-sf-text-muted">
                    ID {selectedAlert.id} · Phát hiện {formatDateTime(selectedAlert.timestamp)}
                  </p>
                </div>

                <div className="flex items-center gap-1.5">
                  <IconButton icon={Phone} label="Gọi tài xế" tone="primary" />
                  <IconButton icon={MessageSquare} label="Nhắn tin" tone="primary" />
                </div>
              </div>

              <div className="min-h-0 flex-1 space-y-5 overflow-y-auto p-5">
                <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
                  {/* Bằng chứng */}
                  <div className="space-y-2.5">
                    <p className="sf-eyebrow">Hình ảnh / video bằng chứng</p>
                    <div className="relative flex aspect-video items-center justify-center overflow-hidden rounded-[var(--sf-r-md)] border border-[var(--sf-border)] bg-[var(--sf-ink-950)]">
                      <span
                        aria-hidden
                        className="absolute inset-0 opacity-[0.07]"
                        style={{
                          backgroundImage:
                            "repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(255,255,255,0.6) 2px, rgba(255,255,255,0.6) 3px)",
                        }}
                      />
                      <div className="relative text-center">
                        <Video className="mx-auto mb-2 h-9 w-9 text-[var(--sf-ink-600)]" />
                        <span className="font-mono text-[12px] text-[var(--sf-ink-500)]">
                          CABIN_CAM_{selectedAlert.vehicleId}.stream
                        </span>
                      </div>
                      <span
                        className="absolute left-2.5 top-2.5 flex items-center gap-1.5 rounded-[var(--sf-r-xs)] px-2 py-1 font-mono text-[9.5px] font-bold uppercase tracking-wider text-white"
                        style={{ background: "var(--sf-danger)" }}
                      >
                        <span className="h-1.5 w-1.5 animate-sf-pulse-dot rounded-full bg-white" />
                        Rec live
                      </span>
                    </div>
                    <p className="text-center text-[12px] leading-relaxed text-sf-text-muted">
                      Dữ liệu hình ảnh truyền trực tiếp từ camera AI trong cabin phương tiện.
                    </p>
                  </div>

                  {/* Thông số */}
                  <div className="space-y-2.5">
                    <p className="sf-eyebrow">Thông tin kỹ thuật</p>
                    <div className="sf-inset px-4 py-1">
                      <InfoRow
                        label="Tài xế"
                        value={
                          <span className="inline-flex items-center gap-1.5">
                            <User className="h-3.5 w-3.5 text-sf-text-muted" />
                            {selectedAlert.driverName}
                          </span>
                        }
                      />
                      <InfoRow
                        label="Phương tiện"
                        value={
                          <span className="inline-flex items-center gap-1.5">
                            <Truck className="h-3.5 w-3.5 text-sf-text-muted" />
                            {selectedAlert.vehiclePlate}
                          </span>
                        }
                      />
                      <InfoRow
                        label="Tốc độ ghi nhận"
                        value={
                          <span className="sf-tnum inline-flex items-center gap-1.5">
                            <Gauge className="h-3.5 w-3.5 text-sf-text-muted" />
                            {selectedAlert.speed ? `${selectedAlert.speed} km/h` : "—"}
                          </span>
                        }
                      />
                      <InfoRow
                        label="Tọa độ GPS"
                        value={
                          <span className="sf-tnum inline-flex items-center gap-1.5 font-mono text-[12px]">
                            <MapPin className="h-3.5 w-3.5 text-sf-text-muted" />
                            {selectedAlert.lat.toFixed(5)}, {selectedAlert.lng.toFixed(5)}
                          </span>
                        }
                      />
                      {selectedAlert.handledBy && (
                        <InfoRow label="Người xử lý" value={selectedAlert.handledBy} />
                      )}
                    </div>

                    <Callout
                      tone={toneOf(selectedAlert.severity)}
                      icon={AlertTriangle}
                      title="Chi tiết phát hiện"
                    >
                      {selectedAlert.message}
                    </Callout>
                  </div>
                </div>

                {/* Hành động */}
                <div className="flex flex-wrap items-center gap-2 border-t border-[var(--sf-border)] pt-4">
                  <Button
                    variant="outline"
                    size="sm"
                    loading={busy}
                    disabled={selectedAlert.status !== "new"}
                    onClick={() => handleAcknowledge(selectedAlert.id)}
                  >
                    Tiếp nhận xử lý
                  </Button>
                  <Button
                    size="sm"
                    icon={CheckCircle2}
                    loading={busy}
                    disabled={selectedAlert.status === "resolved"}
                    onClick={() => handleResolve(selectedAlert.id)}
                  >
                    Đánh dấu đã giải quyết
                  </Button>
                </div>
              </div>
            </>
          ) : (
            <EmptyState
              icon={ShieldAlert}
              title="Chưa chọn cảnh báo"
              description="Chọn một cảnh báo ở danh sách bên trái để xem chi tiết và xử lý."
              className="flex-1"
            />
          )}
        </Card>
      </div>
    </div>
  );
}
