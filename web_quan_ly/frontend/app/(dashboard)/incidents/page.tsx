"use client";

import { useEffect, useState, useMemo } from "react";
import { Incident, IncidentPriority, IncidentStatus, IncidentType } from "@/types";
import { safeFleetApi } from "@/lib/safeFleetApi";
import { cn, formatDrivingTime, formatTimeAgo } from "@/lib/utils";
import MapView from "@/components/map/MapView";
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
  StatCard,
  TableCard,
  TableToolbar,
  toneOf,
  type FilterChip,
} from "@/components/ui";
import {
  AlertOctagon,
  CheckCircle2,
  Clock,
  Headphones,
  MapPin,
  MessageSquare,
  Phone,
  ShieldCheck,
  Siren,
  Timer,
} from "lucide-react";

/** Năm loại sự cố thật của backend (IncidentType) — bản thiết kế chỉ vẽ SOS/va
    chạm/hỏng xe/ngập đường, bỏ sót "medical" và "other". */
const INCIDENT_TYPE_VI: Record<IncidentType, string> = {
  sos: "SOS khẩn cấp",
  accident: "Va chạm",
  breakdown: "Hỏng xe",
  medical: "Y tế khẩn cấp",
  other: "Khác",
};

const PRIORITY_VI: Record<IncidentPriority, string> = {
  critical: "Nghiêm trọng",
  high: "Cao",
  medium: "Trung bình",
  low: "Thấp",
};

/** Bốn trạng thái thật của IncidentStatus — bản thiết kế bỏ sót "overdue"
    (sự cố quá hạn phản hồi), phải có chip riêng tone danger. */
const STATUS_VI: Record<IncidentStatus, string> = {
  open: "Đang mở",
  in_progress: "Đang xử lý",
  resolved: "Đã đóng",
  overdue: "Quá hạn",
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

export default function IncidentsPage() {
  const { showToast } = useToast();
  const [incidents, setIncidents] = useState<Incident[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | IncidentStatus>("all");
  const [selectedIncidentId, setSelectedIncidentId] = useState("");
  const [busy, setBusy] = useState(false);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);

  useEffect(() => {
    const updateClock = () => setCurrentTime(Date.now());
    updateClock();
    const timer = window.setInterval(updateClock, 60_000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const data = await safeFleetApi.incidents();
        if (!cancelled) setIncidents(data);
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

  const selectedIncident = useMemo(
    () => incidents.find((i) => i.id === selectedIncidentId),
    [incidents, selectedIncidentId]
  );

  const updateIncident = (next: Incident) => {
    setIncidents((prev) => prev.map((i) => (i.id === next.id ? next : i)));
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

  /** Nút chính của thanh công cụ — tiếp nhận toàn bộ sự cố đang "Đang mở"/"Quá
      hạn" cùng lúc, gọi lại đúng API acceptIncident cho từng bản ghi. */
  const handleAcknowledgeAll = async () => {
    const targets = incidents.filter((i) => i.status === "open" || i.status === "overdue");
    if (targets.length === 0) return;
    setBulkBusy(true);
    try {
      const updated = await Promise.all(targets.map((i) => safeFleetApi.acceptIncident(i.id)));
      setIncidents((prev) => prev.map((i) => updated.find((u) => u.id === i.id) ?? i));
      showToast(`Đã tiếp nhận ${updated.length} sự cố.`, "success");
    } catch (error) {
      showToast(
        error instanceof Error ? error.message : "Không thể tiếp nhận tất cả sự cố.",
        "error"
      );
    } finally {
      setBulkBusy(false);
    }
  };

  const stats = useMemo(() => {
    const open = incidents.filter((i) => i.status === "open" || i.status === "overdue");
    /* Backend có acceptedAt/resolvedAt nhưng chưa được ánh xạ sang Incident ở
       tầng frontend (chỉ có `timestamp` = thời điểm tạo). Vì không được đổi
       logic dữ liệu, "Thời gian phản hồi" tính bằng tuổi trung bình của các
       sự cố đang mở/quá hạn — phản ánh đúng thời gian đang chờ được xử lý,
       thay vì thời lượng xử lý đã hoàn tất (không có dữ liệu để tính chính xác). */
    const avgWaitMinutes =
      open.length > 0 && currentTime > 0
        ? Math.round(
            open.reduce((sum, i) => sum + (currentTime - new Date(i.timestamp).getTime()) / 60000, 0) /
              open.length
          )
        : null;
    return {
      open: open.length,
      inProgress: incidents.filter((i) => i.status === "in_progress").length,
      resolvedToday: incidents.filter((i) => i.status === "resolved" && isToday(i.timestamp)).length,
      avgWaitMinutes,
    };
  }, [incidents, currentTime]);

  /* Chip lọc theo đúng bốn trạng thái thật của backend (bản thiết kế bỏ sót
     "overdue") — chỉ hiện trạng thái thực sự có dữ liệu, "Tất cả" đứng đầu. */
  const statusChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "all", label: "Tất cả", count: incidents.length }];
    (Object.keys(STATUS_VI) as IncidentStatus[]).forEach((key) => {
      const count = incidents.filter((i) => i.status === key).length;
      if (count > 0) chips.push({ key, label: STATUS_VI[key], count });
    });
    return chips;
  }, [incidents]);

  const filtered = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return incidents.filter((i) => {
      if (statusFilter !== "all" && i.status !== statusFilter) return false;
      if (!q) return true;
      return (
        i.driverName.toLowerCase().includes(q) ||
        i.vehiclePlate.toLowerCase().includes(q) ||
        i.location.toLowerCase().includes(q)
      );
    });
  }, [incidents, searchQuery, statusFilter]);

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Sự cố đang mở"
          value={stats.open}
          icon={Siren}
          delta="cần tiếp nhận"
          delay={0}
        />
        <StatCard
          label="Đang xử lý"
          value={stats.inProgress}
          icon={Headphones}
          tone="warning"
          delta="đã có điều phối viên"
          delay={70}
        />
        <StatCard
          label="Đã đóng hôm nay"
          value={stats.resolvedToday}
          icon={ShieldCheck}
          tone="success"
          delay={140}
        />
        <StatCard
          label="Thời gian phản hồi"
          value={stats.avgWaitMinutes != null ? formatDrivingTime(stats.avgWaitMinutes) : "—"}
          icon={Timer}
          tone="info"
          hint="tuổi trung bình sự cố đang chờ"
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
              placeholder: "Tài xế, biển số, vị trí…",
            }}
            filters={
              <FilterChips
                items={statusChips}
                value={statusFilter}
                onChange={(k) => setStatusFilter(k as "all" | IncidentStatus)}
              />
            }
            action={
              <button
                type="button"
                className="sf-pill-primary"
                disabled={bulkBusy || stats.open === 0}
                onClick={() => void handleAcknowledgeAll()}
              >
                <Headphones className="h-[17px] w-[17px]" />
                Tiếp nhận sự cố
              </button>
            }
          />
        }
      >
        <DataTable
          grid="1.1fr 1.2fr 1.5fr 1.1fr 1fr"
          columns={["Loại & ưu tiên", "Tài xế & xe", "Mô tả & vị trí", "Nhật ký xử lý", "Trạng thái"]}
          loading={isLoading}
          empty={{
            icon: ShieldCheck,
            title: "Không có sự cố",
            description: "Chưa ghi nhận sự cố nào khớp bộ lọc hiện tại.",
          }}
          rows={filtered.map((incident) => {
            const lastEntry = incident.timeline[incident.timeline.length - 1];
            return {
              key: incident.id,
              onClick: () => setSelectedIncidentId(incident.id),
              cells: [
                <Badge key="type" tone={toneOf(incident.priority)} dot>
                  {`${INCIDENT_TYPE_VI[incident.type] || incident.type} · ${PRIORITY_VI[incident.priority]}`.toUpperCase()}
                </Badge>,
                <CellText key="driver" strong text={incident.driverName} sub={incident.vehiclePlate} subMono />,
                <CellText
                  key="desc"
                  text={incident.description || INCIDENT_TYPE_VI[incident.type]}
                  sub={incident.location}
                />,
                <CellText
                  key="log"
                  text={`${incident.timeline.length} bước`}
                  sub={
                    incident.assignedTo
                      ? `ĐPV ${incident.assignedTo}`
                      : lastEntry?.actor
                        ? lastEntry.actor
                        : "chưa có người nhận"
                  }
                />,
                <Badge key="status" tone={toneOf(incident.status)}>
                  {STATUS_VI[incident.status].toUpperCase()}
                </Badge>,
              ],
            };
          })}
        />
      </TableCard>

      {/* ===== Panel chi tiết ===== */}
      <Drawer
        open={Boolean(selectedIncident)}
        onClose={() => setSelectedIncidentId("")}
        title={selectedIncident ? `Sự cố xe ${selectedIncident.vehiclePlate}` : ""}
        subtitle={selectedIncident ? `${formatTimeAgo(selectedIncident.timestamp)} · ${selectedIncident.location}` : undefined}
        width="lg"
        footer={
          selectedIncident && (
            <>
              <IconButton icon={Phone} label="Gọi tài xế" tone="danger" />
              <IconButton icon={MessageSquare} label="Nhắn tin" tone="primary" />
              <div className="flex-1" />
              {selectedIncident.status === "open" || selectedIncident.status === "overdue" ? (
                <Button
                  variant="danger"
                  size="sm"
                  icon={CheckCircle2}
                  loading={busy}
                  onClick={() => void handleAcknowledge(selectedIncident.id)}
                >
                  Tiếp nhận sự cố
                </Button>
              ) : selectedIncident.status === "in_progress" ? (
                <Button
                  size="sm"
                  icon={CheckCircle2}
                  loading={busy}
                  onClick={() => void handleResolve(selectedIncident.id)}
                >
                  Đóng sự cố (đã xử lý)
                </Button>
              ) : (
                <Badge tone="success" icon={ShieldCheck}>
                  Sự cố đã được đóng
                </Badge>
              )}
            </>
          )
        }
      >
        {selectedIncident && (
          <div className="space-y-5">
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={toneOf(selectedIncident.priority)} solid icon={AlertOctagon}>
                {PRIORITY_VI[selectedIncident.priority]}
              </Badge>
              <Badge tone={toneOf(selectedIncident.status)}>{STATUS_VI[selectedIncident.status]}</Badge>
            </div>

            {/* Bản đồ */}
            <div className="sf-map-dark relative h-56 overflow-hidden rounded-[var(--sf-r-md)] border border-[var(--sf-border)]">
              <MapView incidents={[selectedIncident]} interactive={false} />
              <span className="sf-glass-panel absolute bottom-3 left-3 flex items-center gap-1.5 px-2.5 py-1.5 text-[12.5px] font-bold text-sf-text">
                <MapPin className="h-3.5 w-3.5" style={{ color: "var(--sf-danger)" }} />
                {selectedIncident.location}
              </span>
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
                            <Clock className="mr-1 inline-block h-3 w-3 -translate-y-px" />
                            {entry.time}
                          </span>
                        </div>
                      </li>
                    );
                  })}
                </ol>
              )}
            </div>
          </div>
        )}
      </Drawer>
    </div>
  );
}
