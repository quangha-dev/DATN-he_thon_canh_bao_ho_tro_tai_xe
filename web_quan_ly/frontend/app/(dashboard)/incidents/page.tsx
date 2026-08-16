"use client";

import { useEffect, useState, useMemo } from "react";
import { Incident, IncidentStatus, IncidentPriority } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { cn, formatTimeAgo } from "@/lib/utils";
import MapView from "@/components/map/MapView";
import { useToast } from "@/context/ToastContext";
import {
  Badge,
  Button,
  Callout,
  Card,
  CardHeader,
  EmptyState,
  IconButton,
  Segmented,
  Skeleton,
  StatusDot,
  TONE,
  toneOf,
} from "@/components/ui";
import {
  Siren,
  CheckCircle2,
  MessageSquare,
  Phone,
  MapPin,
  AlertOctagon,
  ShieldCheck,
} from "lucide-react";

const PRIORITY_VI: Record<IncidentPriority, string> = {
  critical: "Khẩn cấp",
  high: "Cao",
  medium: "Trung bình",
  low: "Thấp",
};

const STATUS_VI: Record<IncidentStatus, string> = {
  open: "Chưa tiếp nhận",
  in_progress: "Đang xử lý",
  resolved: "Đã xử lý",
  overdue: "Quá hạn",
};

const STATUS_TABS = ["all", "open", "in_progress", "resolved"] as const;
type StatusTab = (typeof STATUS_TABS)[number];

export default function IncidentsPage() {
  const { showToast } = useToast();
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedIncidentId, setSelectedIncidentId] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusTab>("open");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.incidents();
        if (cancelled) return;
        setIncidents(data);
        setSelectedIncidentId((current) => current || data[0]?.id || "");
      } catch (error) {
        const message =
          error instanceof Error ? error.message : "Không tải được danh sách sự cố.";
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

  useEffect(() => {
    if (!selectedIncidentId) return;
    let cancelled = false;
    const loadTimeline = async () => {
      try {
        const timeline = await safeFleetApi.incidentTimeline(selectedIncidentId);
        if (!cancelled && timeline.length > 0) {
          setIncidents((prev) =>
            prev.map((i) => (i.id === selectedIncidentId ? { ...i, timeline } : i))
          );
        }
      } catch {
        /* timeline là thông tin phụ, bỏ qua nếu backend từ chối */
      }
    };
    void loadTimeline();
    return () => {
      cancelled = true;
    };
  }, [selectedIncidentId]);

  const filteredIncidents = useMemo(
    () => incidents.filter((i) => statusFilter === "all" || i.status === statusFilter),
    [incidents, statusFilter]
  );

  const selectedIncident = useMemo(
    () => incidents.find((i) => i.id === selectedIncidentId),
    [incidents, selectedIncidentId]
  );

  const tabCounts = useMemo(
    () => ({
      all: incidents.length,
      open: incidents.filter((i) => i.status === "open").length,
      in_progress: incidents.filter((i) => i.status === "in_progress").length,
      resolved: incidents.filter((i) => i.status === "resolved").length,
    }),
    [incidents]
  );

  const updateIncident = (next: Incident) => {
    setIncidents((prev) => prev.map((i) => (i.id === next.id ? next : i)));
    setSelectedIncidentId(next.id);
  };

  const handleAcknowledge = async (id: string) => {
    setBusy(true);
    try {
      updateIncident(await safeFleetApi.acceptIncident(id));
      showToast("Đã tiếp nhận sự cố.", "info");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể tiếp nhận sự cố.", "error");
    } finally {
      setBusy(false);
    }
  };

  const handleResolve = async (id: string) => {
    setBusy(true);
    try {
      updateIncident(await safeFleetApi.closeIncident(id));
      showToast("Đã đóng sự cố.", "success");
    } catch (error) {
      showToast(error instanceof Error ? error.message : "Không thể đóng sự cố.", "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex h-[calc(100vh-116px)] flex-col gap-4">
      {/* ===== Thanh lọc ===== */}
      <Card padding="sm" className="flex-shrink-0">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <Segmented
            value={statusFilter}
            onChange={setStatusFilter}
            options={STATUS_TABS.map((t) => ({
              value: t,
              label: t === "all" ? "Tất cả" : STATUS_VI[t as IncidentStatus],
              count: tabCounts[t],
            }))}
          />
          <span className="flex items-center gap-2 text-[12.5px] font-bold">
            <StatusDot tone={tabCounts.open > 0 ? "danger" : "success"} pulse={tabCounts.open > 0} />
            <span
              style={{
                color: tabCounts.open > 0 ? "var(--sf-danger)" : "var(--sf-text-muted)",
              }}
            >
              {tabCounts.open} sự cố khẩn cấp đang mở
            </span>
          </span>
        </div>
      </Card>

      {/* ===== Nội dung ===== */}
      <div className="grid min-h-0 flex-1 grid-cols-1 gap-5 overflow-y-auto pb-2 lg:grid-cols-3 lg:overflow-hidden">
        {/* --- Danh sách --- */}
        <Card padding="none" className="flex min-h-0 flex-col lg:col-span-1">
          <div className="flex flex-shrink-0 items-center justify-between border-b border-[var(--sf-border)] px-4 py-3.5">
            <CardHeader
              title="Phòng xử lý sự cố"
              subtitle={`${filteredIncidents.length} sự cố hiển thị`}
              icon={Siren}
            />
            {tabCounts.open > 0 && <StatusDot tone="danger" pulse />}
          </div>

          <div className="min-h-0 flex-1 space-y-1 overflow-y-auto p-2">
            {isLoading && incidents.length === 0 ? (
              Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex gap-3 p-3">
                  <Skeleton className="h-8 w-8 rounded-[var(--sf-r-xs)]" />
                  <div className="flex-1 space-y-2">
                    <Skeleton className="h-3 w-32" />
                    <Skeleton className="h-2.5 w-44" />
                  </div>
                </div>
              ))
            ) : filteredIncidents.length === 0 ? (
              <EmptyState
                icon={ShieldCheck}
                title="Không có sự cố"
                description="Chưa ghi nhận sự cố nào ở trạng thái này."
              />
            ) : (
              filteredIncidents.map((incident) => {
                const active = incident.id === selectedIncidentId;
                const tone = toneOf(incident.status);
                const isSos = incident.type === "sos";
                return (
                  <button
                    key={incident.id}
                    onClick={() => setSelectedIncidentId(incident.id)}
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
                      <Siren
                        className={cn(
                          "h-4 w-4",
                          incident.status === "open" && "animate-sf-breathe"
                        )}
                      />
                    </span>

                    <span className="min-w-0 flex-1">
                      <span className="flex items-center justify-between gap-2">
                        <span
                          className="truncate text-[12.5px] font-extrabold uppercase tracking-wide"
                          style={{ color: TONE[tone].fg }}
                        >
                          {isSos ? "SOS khẩn cấp" : "Sự cố kỹ thuật"}
                        </span>
                        <span className="flex-shrink-0 text-[12px] font-semibold text-sf-text-muted">
                          {formatTimeAgo(incident.timestamp)}
                        </span>
                      </span>
                      <span className="mt-0.5 block truncate text-[12.5px] font-bold text-sf-text">
                        {incident.vehiclePlate} · {incident.driverName}
                      </span>
                      <span className="mt-0.5 block truncate text-[12.5px] text-sf-text-muted">
                        {incident.location}
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
          {selectedIncident ? (
            <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
              {/* Bản đồ */}
              <div className="sf-map-dark relative h-56 flex-shrink-0 border-b border-[var(--sf-border)]">
                <MapView incidents={[selectedIncident]} interactive={false} />
                <span className="sf-glass-panel absolute bottom-3 left-3 flex items-center gap-1.5 px-2.5 py-1.5 text-[12.5px] font-bold text-sf-text">
                  <MapPin className="h-3.5 w-3.5" style={{ color: "var(--sf-danger)" }} />
                  {selectedIncident.location}
                </span>
              </div>

              <div className="flex-1 space-y-5 p-5">
                {/* Tiêu đề */}
                <div className="flex flex-wrap items-start justify-between gap-3 border-b border-[var(--sf-border)] pb-4">
                  <div className="min-w-0">
                    <h3 className="text-base font-extrabold tracking-tight text-sf-text">
                      Sự cố xe {selectedIncident.vehiclePlate}
                    </h3>
                    <p className="mt-1 text-[12.5px] text-sf-text-muted">
                      Tài xế {selectedIncident.driverName} · GPS{" "}
                      <span className="sf-tnum font-mono">
                        {selectedIncident.lat.toFixed(5)}, {selectedIncident.lng.toFixed(5)}
                      </span>
                    </p>
                  </div>

                  <div className="flex flex-wrap items-center gap-2">
                    <Badge tone={toneOf(selectedIncident.priority)} solid icon={AlertOctagon}>
                      {PRIORITY_VI[selectedIncident.priority]}
                    </Badge>
                    <Badge tone={toneOf(selectedIncident.status)}>
                      {STATUS_VI[selectedIncident.status]}
                    </Badge>
                    <IconButton icon={Phone} label="Gọi tài xế" tone="danger" />
                    <IconButton icon={MessageSquare} label="Nhắn tin" tone="primary" />
                  </div>
                </div>

                {selectedIncident.description && (
                  <Callout tone="danger" icon={AlertOctagon} title="Mô tả sự cố">
                    {selectedIncident.description}
                  </Callout>
                )}

                {/* Nhật ký xử lý */}
                <div className="space-y-3">
                  <p className="sf-eyebrow">Nhật ký xử lý</p>

                  {selectedIncident.timeline.length === 0 ? (
                    <p className="text-[12px] text-sf-text-muted">Chưa có bản ghi xử lý nào.</p>
                  ) : (
                    <ol className="relative space-y-4 pl-6">
                      <span className="absolute bottom-2 left-[5px] top-2 w-px bg-[var(--sf-border)]" />
                      {selectedIncident.timeline.map((entry, idx) => {
                        const isLast = idx === selectedIncident.timeline.length - 1;
                        return (
                          <li key={idx} className="relative">
                            <span
                              className={cn(
                                "absolute -left-[22px] top-1 h-[11px] w-[11px] rounded-full border-2",
                                isLast && "animate-sf-pulse-ring"
                              )}
                              style={{
                                background: isLast ? "var(--sf-danger)" : "var(--sf-bg-card)",
                                borderColor: isLast ? "var(--sf-danger)" : "var(--sf-border-strong)",
                              }}
                            />
                            <div className="flex items-start justify-between gap-4">
                              <div className="min-w-0">
                                <p
                                  className={cn(
                                    "text-[12.5px] font-bold",
                                    isLast ? "text-sf-text" : "text-sf-text-secondary"
                                  )}
                                >
                                  {entry.action}
                                </p>
                                {entry.actor && (
                                  <p className="mt-0.5 text-[12px] text-sf-text-muted">
                                    Thực hiện bởi {entry.actor}
                                  </p>
                                )}
                              </div>
                              <span className="sf-tnum flex-shrink-0 font-mono text-[12px] text-sf-text-muted">
                                {entry.time}
                              </span>
                            </div>
                          </li>
                        );
                      })}
                    </ol>
                  )}
                </div>

                {/* Hành động */}
                <div className="flex flex-wrap items-center gap-2 border-t border-[var(--sf-border)] pt-4">
                  {selectedIncident.status === "open" && (
                    <Button
                      variant="danger"
                      size="sm"
                      icon={CheckCircle2}
                      loading={busy}
                      onClick={() => handleAcknowledge(selectedIncident.id)}
                    >
                      Tiếp nhận sự cố
                    </Button>
                  )}
                  {selectedIncident.status === "in_progress" && (
                    <Button
                      size="sm"
                      icon={CheckCircle2}
                      loading={busy}
                      onClick={() => handleResolve(selectedIncident.id)}
                    >
                      Đóng sự cố (đã xử lý)
                    </Button>
                  )}
                  {selectedIncident.status === "resolved" && (
                    <Badge tone="success" icon={ShieldCheck}>
                      Sự cố đã được đóng
                    </Badge>
                  )}
                </div>
              </div>
            </div>
          ) : (
            <EmptyState
              icon={Siren}
              title="Chưa chọn sự cố"
              description="Chọn một sự cố ở cột trái để bắt đầu điều phối cứu hộ."
              className="flex-1"
            />
          )}
        </Card>
      </div>
    </div>
  );
}
