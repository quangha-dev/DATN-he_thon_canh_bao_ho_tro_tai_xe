"use client";

import { useEffect, useMemo, useState } from "react";
import { Activity, Camera, Radio, Smartphone, Wifi, WifiOff, Waves } from "lucide-react";
import { FleetDevice, safeFleetApi } from "@/lib/safeFleetApi";
import { useToast } from "@/context/ToastContext";
import { formatTimeAgo } from "@/lib/utils";
import {
  EmptyState,
  SearchInput,
  Segmented,
  SkeletonRows,
  Stagger,
  StatCard,
  StatSkeletonGrid,
  StatusLabel,
  Table,
  TableShell,
  Td,
  Toolbar,
  Tr,
} from "@/components/ui";

const TYPE_LABELS: Record<FleetDevice["type"], string> = {
  GPS_TRACKER: "Định vị GPS",
  CABIN_CAMERA: "Camera cabin",
  DASH_CAMERA: "Camera hành trình",
  DRIVER_PHONE: "Điện thoại tài xế",
  IOT_FLOOD_SENSOR: "Cảm biến ngập",
};

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

const STATUS_KEYS = ["ALL", ...(Object.keys(STATUS_LABELS) as FleetDevice["status"][])] as const;
type StatusKey = (typeof STATUS_KEYS)[number];

function deviceIcon(type: FleetDevice["type"]) {
  if (type === "CABIN_CAMERA" || type === "DASH_CAMERA") return Camera;
  if (type === "DRIVER_PHONE") return Smartphone;
  if (type === "IOT_FLOOD_SENSOR") return Waves;
  return Radio;
}

export default function DevicesPage() {
  const { showToast } = useToast();
  const [devices, setDevices] = useState<FleetDevice[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState<StatusKey>("ALL");

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
      assigned: devices.filter((d) => d.vehicleId != null).length,
    }),
    [devices]
  );

  const filtered = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    return devices.filter((item) => {
      if (status !== "ALL" && item.status !== status) return false;
      if (!keyword) return true;
      return [item.deviceCode, item.name, item.vehiclePlateNumber, item.serialNumber]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(keyword));
    });
  }, [devices, query, status]);

  return (
    <div className="space-y-5">
      <Stagger className="grid grid-cols-2 gap-3.5 lg:grid-cols-4">
        {loading && devices.length === 0 ? (
          <StatSkeletonGrid count={4} />
        ) : (
          <>
            <StatCard label="Tổng thiết bị" value={stats.total} icon={Activity} tone="primary" />
            <StatCard
              label="Trực tuyến"
              value={stats.online}
              icon={Wifi}
              tone="success"
              onClick={() => setStatus(status === "ONLINE" ? "ALL" : "ONLINE")}
              active={status === "ONLINE"}
            />
            <StatCard
              label="Mất kết nối"
              value={stats.offline}
              icon={WifiOff}
              tone="danger"
              onClick={() => setStatus(status === "OFFLINE" ? "ALL" : "OFFLINE")}
              active={status === "OFFLINE"}
            />
            <StatCard label="Đã gắn xe" value={stats.assigned} icon={Radio} tone="accent" />
          </>
        )}
      </Stagger>

      <Toolbar>
        <SearchInput
          value={query}
          onChange={setQuery}
          placeholder="Tìm mã, tên, serial hoặc biển số…"
          className="sm:max-w-sm"
        />
        <Segmented
          value={status}
          onChange={setStatus}
          options={STATUS_KEYS.map((s) => ({
            value: s,
            label: s === "ALL" ? "Tất cả" : STATUS_LABELS[s as FleetDevice["status"]],
          }))}
        />
      </Toolbar>

      <TableShell loading={loading}>
        <Table
          head={[
            "Thiết bị",
            "Loại",
            "Phương tiện",
            "Firmware / Serial",
            "Kết nối cuối",
            "Trạng thái",
          ]}
        >
          {loading && devices.length === 0 ? (
            <SkeletonRows rows={6} cols={6} />
          ) : filtered.length === 0 ? (
            <tr>
              <Td colSpan={6}>
                <EmptyState
                  icon={Radio}
                  title="Không có thiết bị phù hợp"
                  description="Thử đổi từ khóa tìm kiếm hoặc chọn trạng thái khác."
                />
              </Td>
            </tr>
          ) : (
            filtered.map((item) => {
              const Icon = deviceIcon(item.type);
              return (
                <Tr key={item.id}>
                  <Td>
                    <span className="flex items-center gap-3">
                      <span
                        className="grid h-8 w-8 flex-shrink-0 place-items-center rounded-[var(--sf-r-xs)]"
                        style={{ background: "var(--sf-primary-soft)", color: "var(--sf-primary)" }}
                      >
                        <Icon className="h-4 w-4" />
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate text-[13px] font-bold text-sf-text">
                          {item.name}
                        </span>
                        <span className="block font-mono text-[12px] text-sf-text-muted">
                          {item.deviceCode}
                        </span>
                      </span>
                    </span>
                  </Td>
                  <Td className="font-semibold">{TYPE_LABELS[item.type]}</Td>
                  <Td>
                    {item.vehiclePlateNumber ? (
                      <span className="font-bold text-sf-text-secondary">
                        {item.vehiclePlateNumber}
                      </span>
                    ) : (
                      <span className="italic text-sf-text-muted">Chưa gắn xe</span>
                    )}
                  </Td>
                  <Td>
                    <span className="block font-mono text-[12.5px]">
                      {item.firmwareVersion || "—"}
                    </span>
                    <span className="block font-mono text-[12px] text-sf-text-muted">
                      {item.serialNumber || "Không có serial"}
                    </span>
                  </Td>
                  <Td>{item.lastSeenAt ? formatTimeAgo(item.lastSeenAt) : "Chưa ghi nhận"}</Td>
                  <Td>
                    <StatusLabel
                      status={STATUS_KEY[item.status]}
                      label={STATUS_LABELS[item.status]}
                      pulse={item.status === "ONLINE"}
                    />
                  </Td>
                </Tr>
              );
            })
          )}
        </Table>
      </TableShell>
    </div>
  );
}
