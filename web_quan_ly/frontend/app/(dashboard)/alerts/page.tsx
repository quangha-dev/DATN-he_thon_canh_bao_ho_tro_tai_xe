"use client";

import { useEffect, useState, useMemo } from "react";
import { Alert, AlertSeverity, AlertStatus, AlertType } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { formatDateTime, formatTimeAgo } from "@/lib/utils";
import { useToast } from "@/context/ToastContext";
import {
  Badge,
  Button,
  Callout,
  CellText,
  DataTable,
  Drawer,
  FilterChips,
  IconButton,
  InfoRow,
  StatCard,
  TableCard,
  TableToolbar,
  toneOf,
  type FilterChip,
} from "@/components/ui";
import {
  AlertTriangle,
  CheckCheck,
  CheckCircle2,
  Gauge,
  Headphones,
  Inbox,
  MapPin,
  MessageSquare,
  Phone,
  ShieldAlert,
  Truck,
  User,
  Video,
} from "lucide-react";

/** Chín loại cảnh báo AI thật của backend (AlertType) — bản thiết kế chỉ vẽ 4-5 loại */
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

/** Bốn trạng thái thật của AlertStatus — bản thiết kế bỏ sót "escalated" */
const ALERT_STATUS_VI: Record<AlertStatus, string> = {
  new: "Mới",
  acknowledged: "Đang xử lý",
  resolved: "Đã giải quyết",
  escalated: "Đã chuyển cấp trên",
};

const isToday = (dateStr?: string) => {
  if (!dateStr) return false;
  const d = new Date(dateStr);
  const now = new Date();
  return (
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
  );
};

export default function AlertsPage() {
  const { showToast } = useToast();
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [typeFilter, setTypeFilter] = useState<"all" | AlertType>("all");
  /** Bật/tắt qua thẻ số liệu "Nghiêm trọng" — không phải chip lọc riêng */
  const [criticalOnly, setCriticalOnly] = useState(false);
  const [selectedAlertId, setSelectedAlertId] = useState("");
  const [busy, setBusy] = useState(false);
  const [bulkBusy, setBulkBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.safetyEvents();
        if (!cancelled) setAlerts(data);
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

  const selectedAlert = useMemo(
    () => alerts.find((a) => a.id === selectedAlertId),
    [alerts, selectedAlertId]
  );

  const updateAlert = (next: Alert) => {
    setAlerts((prev) => prev.map((a) => (a.id === next.id ? next : a)));
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

  /** Nút chính của thanh công cụ — tiếp nhận toàn bộ cảnh báo còn "Mới" cùng lúc,
      gọi lại đúng API acknowledgeSafetyEvent cho từng bản ghi, không đổi hành vi. */
  const handleAcknowledgeAll = async () => {
    const targets = alerts.filter((a) => a.status === "new");
    if (targets.length === 0) return;
    setBulkBusy(true);
    try {
      const updated = await Promise.all(
        targets.map((a) => safeFleetApi.acknowledgeSafetyEvent(a.id))
      );
      setAlerts((prev) => prev.map((a) => updated.find((u) => u.id === a.id) ?? a));
      showToast(`Đã tiếp nhận ${updated.length} cảnh báo.`, "success");
    } catch (error) {
      showToast(
        error instanceof Error ? error.message : "Không thể tiếp nhận tất cả cảnh báo.",
        "error"
      );
    } finally {
      setBulkBusy(false);
    }
  };

  const stats = useMemo(
    () => ({
      new: alerts.filter((a) => a.status === "new").length,
      critical: alerts.filter((a) => a.severity === "critical" && a.status !== "resolved").length,
      acknowledged: alerts.filter((a) => a.status === "acknowledged").length,
      resolvedToday: alerts.filter((a) => a.status === "resolved" && isToday(a.handledAt || a.timestamp)).length,
    }),
    [alerts]
  );

  /* Chip lọc dựng theo đúng chín loại cảnh báo của backend (bản thiết kế chỉ
     vẽ 4-5 loại) — chỉ hiện loại thực sự có dữ liệu, luôn có "Tất cả" đứng đầu. */
  const typeChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "all", label: "Tất cả", count: alerts.length }];
    (Object.keys(ALERT_TYPE_VI) as AlertType[]).forEach((key) => {
      const count = alerts.filter((a) => a.type === key).length;
      if (count > 0) chips.push({ key, label: ALERT_TYPE_VI[key], count });
    });
    return chips;
  }, [alerts]);

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return alerts.filter((a) => {
      if (typeFilter !== "all" && a.type !== typeFilter) return false;
      if (criticalOnly && a.severity !== "critical") return false;
      if (!q) return true;
      return (
        a.driverName.toLowerCase().includes(q) ||
        a.vehiclePlate.toLowerCase().includes(q) ||
        a.message.toLowerCase().includes(q)
      );
    });
  }, [alerts, searchQuery, typeFilter, criticalOnly]);

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Cảnh báo mới"
          value={stats.new}
          icon={ShieldAlert}
          delta="trong 1 giờ qua"
          delay={0}
        />
        <StatCard
          label="Nghiêm trọng"
          value={stats.critical}
          icon={AlertTriangle}
          tone="danger"
          deltaTone="danger"
          delta="cần xử lý ngay"
          onClick={() => setCriticalOnly((v) => !v)}
          active={criticalOnly}
          delay={70}
        />
        <StatCard
          label="Đang tiếp nhận"
          value={stats.acknowledged}
          icon={Headphones}
          tone="warning"
          delta="đã có người xử lý"
          delay={140}
        />
        <StatCard
          label="Đã giải quyết hôm nay"
          value={stats.resolvedToday}
          icon={CheckCircle2}
          tone="success"
          delay={210}
        />
      </div>

      {/* ===== Thẻ bảng: thanh công cụ + bảng dạng thẻ ===== */}
      <TableCard
        toolbar={
          <TableToolbar
            search={{
              value: searchQuery,
              onChange: setSearchQuery,
              placeholder: "Tài xế, biển số, loại cảnh báo…",
            }}
            filters={
              <FilterChips items={typeChips} value={typeFilter} onChange={(k) => setTypeFilter(k as "all" | AlertType)} />
            }
            action={
              <button
                type="button"
                className="sf-pill-primary"
                disabled={bulkBusy || stats.new === 0}
                onClick={() => void handleAcknowledgeAll()}
              >
                <CheckCheck className="h-[17px] w-[17px]" />
                Tiếp nhận tất cả
              </button>
            }
          />
        }
      >
        <DataTable
          grid="1.2fr 1.3fr 1.5fr 1fr 1fr"
          columns={["Loại & mức độ", "Tài xế & xe", "Chi tiết phát hiện", "Kỹ thuật", "Trạng thái"]}
          loading={isLoading}
          empty={{
            icon: Inbox,
            title: "Không có cảnh báo",
            description: "Thử đổi từ khóa hoặc bỏ bớt bộ lọc đang áp dụng.",
          }}
          rows={filtered.map((alert) => ({
            key: alert.id,
            onClick: () => setSelectedAlertId(alert.id),
            cells: [
              <Badge key="type" tone={toneOf(alert.severity)} dot>
                {`${ALERT_TYPE_VI[alert.type] || alert.type} · ${SEVERITY_VI[alert.severity]}`.toUpperCase()}
              </Badge>,
              <CellText key="driver" strong text={alert.driverName} sub={alert.vehiclePlate} subMono />,
              <CellText
                key="detail"
                text={alert.message}
                sub={
                  alert.repeatCount && alert.repeatCount > 1
                    ? `Lặp lại ${alert.repeatCount} lần liên tiếp`
                    : "Ghi nhận tự động bởi hệ thống AI"
                }
              />,
              <CellText
                key="tech"
                mono
                text={alert.speed != null ? `${alert.speed} km/h` : "—"}
                sub={formatTimeAgo(alert.timestamp)}
              />,
              <Badge key="status" tone={toneOf(alert.status)}>
                {ALERT_STATUS_VI[alert.status].toUpperCase()}
              </Badge>,
            ],
          }))}
        />
      </TableCard>

      {/* ===== Panel chi tiết ===== */}
      <Drawer
        open={Boolean(selectedAlert)}
        onClose={() => setSelectedAlertId("")}
        title={selectedAlert ? ALERT_TYPE_VI[selectedAlert.type] || selectedAlert.type : ""}
        subtitle={selectedAlert ? `ID ${selectedAlert.id} · Phát hiện ${formatDateTime(selectedAlert.timestamp)}` : undefined}
        width="lg"
        footer={
          selectedAlert && (
            <>
              <IconButton icon={Phone} label="Gọi tài xế" tone="primary" />
              <IconButton icon={MessageSquare} label="Nhắn tin" tone="primary" />
              <div className="flex-1" />
              <Button
                variant="outline"
                size="sm"
                loading={busy}
                disabled={selectedAlert.status !== "new"}
                onClick={() => void handleAcknowledge(selectedAlert.id)}
              >
                Tiếp nhận xử lý
              </Button>
              <Button
                size="sm"
                icon={CheckCircle2}
                loading={busy}
                disabled={selectedAlert.status === "resolved"}
                onClick={() => void handleResolve(selectedAlert.id)}
              >
                Đánh dấu đã giải quyết
              </Button>
            </>
          )
        }
      >
        {selectedAlert && (
          <div className="space-y-5">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={toneOf(selectedAlert.severity)} solid>
                {SEVERITY_VI[selectedAlert.severity]}
              </Badge>
              <Badge tone={toneOf(selectedAlert.status)}>
                {ALERT_STATUS_VI[selectedAlert.status]}
              </Badge>
              {selectedAlert.repeatCount && selectedAlert.repeatCount > 1 ? (
                <Badge tone="danger">Lặp {selectedAlert.repeatCount}×</Badge>
              ) : null}
            </div>

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

              <Callout tone={toneOf(selectedAlert.severity)} icon={AlertTriangle} title="Chi tiết phát hiện">
                {selectedAlert.message}
              </Callout>
            </div>
          </div>
        )}
      </Drawer>
    </div>
  );
}
