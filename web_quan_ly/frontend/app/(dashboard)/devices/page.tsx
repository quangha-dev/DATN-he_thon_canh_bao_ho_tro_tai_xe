"use client";

import { useEffect, useMemo, useState } from "react";
import { Cpu, Link as LinkIcon, Unlink, Wifi, WifiOff } from "lucide-react";
import { FleetDevice, safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { formatTimeAgo } from "@/lib/utils";
import {
  Badge,
  CellText,
  DataTable,
  FilterChips,
  StatCard,
  TableCard,
  TableToolbar,
  toneOf,
  type FilterChip,
} from "@/components/ui";

/** Nhãn loại thiết bị — đúng 5 loại backend trả về (`FleetDevice.type`). */
const TYPE_LABELS: Record<FleetDevice["type"], string> = {
  GPS_TRACKER: "Định vị GPS",
  CABIN_CAMERA: "Camera cabin",
  DASH_CAMERA: "Camera hành trình",
  DRIVER_PHONE: "Điện thoại tài xế",
  IOT_FLOOD_SENSOR: "Cảm biến ngập",
};

/** Nhãn trạng thái thiết bị — đúng 4 trạng thái backend (`FleetDevice.status`).
    Bản thiết kế chỉ vẽ "Trực tuyến / Mất kết nối / Chưa gắn" nên bổ sung thêm
    MAINTENANCE và INACTIVE để chip lọc không bỏ sót thiết bị nào. */
const STATUS_LABELS: Record<FleetDevice["status"], string> = {
  ONLINE: "Trực tuyến",
  OFFLINE: "Mất kết nối",
  MAINTENANCE: "Bảo trì",
  INACTIVE: "Ngừng dùng",
};

/** Ánh xạ trạng thái thiết bị sang khóa tone dùng chung */
const STATUS_KEY: Record<FleetDevice["status"], string> = {
  ONLINE: "active",
  OFFLINE: "error",
  MAINTENANCE: "maintenance",
  INACTIVE: "inactive",
};

type StatusFilter = "ALL" | FleetDevice["status"];

export default function DevicesPage() {
  const { showToast } = useToast();
  const [devices, setDevices] = useState<FleetDevice[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("ALL");
  /* "Chưa gắn xe" không phải một trạng thái thiết bị mà là điều kiện
     vehicleId == null, nên tách thành bộ lọc riêng, độc lập với statusFilter. */
  const [unassignedOnly, setUnassignedOnly] = useState(false);

  useEffect(() => {
    let cancelled = false;
    safeFleetApi
      .devices()
      .then((items) => !cancelled && setDevices(items))
      .catch((error) => {
        if (!cancelled)
          showToast(error instanceof Error ? error.message : "Không tải được thiết bị.", "error");
      })
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [showToast]);

  const stats = useMemo(
    () => ({
      total: devices.length,
      online: devices.filter((d) => d.status === "ONLINE").length,
      offline: devices.filter((d) => d.status === "OFFLINE").length,
      unassigned: devices.filter((d) => d.vehicleId == null).length,
    }),
    [devices]
  );

  const filtered = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    return devices.filter((item) => {
      if (statusFilter !== "ALL" && item.status !== statusFilter) return false;
      if (unassignedOnly && item.vehicleId != null) return false;
      if (!keyword) return true;
      return [item.deviceCode, item.name, item.vehiclePlateNumber, item.serialNumber]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(keyword));
    });
  }, [devices, query, statusFilter, unassignedOnly]);

  /* Chip lọc dựng theo đúng bốn trạng thái thiết bị của backend, chỉ hiện
     giá trị thực sự có dữ liệu — bản thiết kế chỉ vẽ hai trạng thái. */
  const statusChips = useMemo(() => {
    const chips: FilterChip[] = [{ key: "ALL", label: "Tất cả", count: devices.length }];
    (Object.keys(STATUS_LABELS) as FleetDevice["status"][]).forEach((key) => {
      const count = devices.filter((d) => d.status === key).length;
      if (count > 0) chips.push({ key, label: STATUS_LABELS[key], count });
    });
    return chips;
  }, [devices]);

  return (
    <div className="grid gap-5">
      {/* ===== Bốn thẻ số liệu, thẻ đầu tô đặc màu thương hiệu ===== */}
      <div className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        <StatCard
          filled
          label="Tổng thiết bị"
          value={stats.total}
          icon={Cpu}
          delta={`${stats.total - stats.unassigned} đã gắn xe`}
          delay={0}
        />
        <StatCard
          label="Trực tuyến"
          value={stats.online}
          icon={Wifi}
          tone="success"
          delta={stats.total ? `${Math.round((stats.online / stats.total) * 100)}%` : ""}
          onClick={() => setStatusFilter(statusFilter === "ONLINE" ? "ALL" : "ONLINE")}
          active={statusFilter === "ONLINE"}
          delay={70}
        />
        <StatCard
          label="Mất kết nối"
          value={stats.offline}
          icon={WifiOff}
          tone="danger"
          deltaTone="danger"
          delta={stats.total ? `${Math.round((stats.offline / stats.total) * 100)}%` : ""}
          onClick={() => setStatusFilter(statusFilter === "OFFLINE" ? "ALL" : "OFFLINE")}
          active={statusFilter === "OFFLINE"}
          delay={140}
        />
        <StatCard
          label="Chưa gắn xe"
          value={stats.unassigned}
          icon={Unlink}
          tone="warning"
          deltaTone="warning"
          delta="trong kho"
          onClick={() => setUnassignedOnly((v) => !v)}
          active={unassignedOnly}
          delay={210}
        />
      </div>

      {/* ===== Thẻ bảng: thanh công cụ + bảng dạng thẻ ===== */}
      <TableCard
        toolbar={
          <TableToolbar
            search={{
              value: query,
              onChange: setQuery,
              placeholder: "Mã, tên, serial, biển số…",
            }}
            filters={
              <FilterChips
                items={statusChips}
                value={statusFilter}
                onChange={(k) => setStatusFilter(k as StatusFilter)}
              />
            }
            action={
              <button
                type="button"
                className="sf-pill-primary"
                onClick={() =>
                  showToast("Gắn thiết bị vào xe được thực hiện tại mục Quản lý phương tiện.", "info")
                }
              >
                <LinkIcon className="h-[17px] w-[17px]" />
                Gắn thiết bị
              </button>
            }
          />
        }
      >
        <DataTable
          grid="1.1fr 1.3fr 1.1fr 1.2fr 1fr"
          columns={["Mã thiết bị", "Tên & serial", "Xe đã gắn", "Kết nối cuối", "Trạng thái"]}
          loading={loading}
          empty={{
            icon: Cpu,
            title: "Không có thiết bị phù hợp",
            description: "Thử đổi từ khóa tìm kiếm hoặc bỏ bớt bộ lọc đang áp dụng.",
          }}
          rows={filtered.map((item) => ({
            key: String(item.id),
            cells: [
              <CellText key="code" mono strong text={item.deviceCode} sub={TYPE_LABELS[item.type]} />,
              <CellText
                key="name"
                text={item.name}
                sub={item.serialNumber ? `SN ${item.serialNumber}` : "Không có serial"}
              />,
              <CellText
                key="vehicle"
                mono
                text={item.vehiclePlateNumber || "—"}
                sub={item.vehiclePlateNumber ? undefined : "chưa gắn xe"}
              />,
              <CellText
                key="seen"
                mono
                text={item.lastSeenAt ? formatTimeAgo(item.lastSeenAt) : "Chưa ghi nhận"}
                sub={item.phone ? `SĐT ${item.phone}` : undefined}
              />,
              <Badge key="status" tone={toneOf(STATUS_KEY[item.status])} dot size="sm">
                {STATUS_LABELS[item.status].toUpperCase()}
              </Badge>,
            ],
          }))}
        />
      </TableCard>
    </div>
  );
}
