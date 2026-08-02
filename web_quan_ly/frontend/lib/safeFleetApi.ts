"use client";

import apiClient from "@/lib/apiClient";
import {
  Account,
  Alert,
  AlertSeverity,
  AlertStatus,
  AlertType,
  AuthUser,
  CommandCenterStats,
  Driver,
  DriverStatus,
  FloodPoint,
  FloodSeverity,
  Incident,
  IncidentPriority,
  IncidentStatus,
  IncidentTimelineEntry,
  IncidentType,
  RiskLevel,
  Trip,
  TripStatus,
  Vehicle,
  VehicleStatus,
  VehicleType,
} from "@/types";

type BackendApiResponse<T> = {
  success: boolean;
  message: string;
  data: T;
  timestamp?: string;
};

type BackendPage<T> = {
  items: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
};

export type BackendRole =
  | "ADMIN"
  | "FLEET_MANAGER"
  | "DISPATCHER"
  | "SAFETY_OFFICER"
  | "RESCUE_TEAM"
  | "DRIVER";

export type BackendAuthResponse = {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresInSeconds: number;
  userId: number;
  driverId?: number | null;
  username: string;
  email: string;
  fullName: string;
  role: BackendRole;
};

export type BackendCurrentUserResponse = {
  userId: number;
  driverId?: number | null;
  username: string;
  email: string;
  fullName: string;
  status: AuthUser["status"];
  role: BackendRole;
};

type BackendVehicle = {
  id: number;
  plateNumber: string;
  vehicleType: string;
  brand: string;
  model: string;
  year: number;
  loadCapacity?: number | string | null;
  seatCount?: number | null;
  fuelType?: string | null;
  status: string;
  currentDriverId?: number | null;
  currentDriverName?: string | null;
  gpsDeviceId?: number | null;
  gpsDeviceCode?: string | null;
  cameraDeviceId?: number | null;
  cameraDeviceCode?: string | null;
  inspectionExpiredAt?: string | null;
  insuranceExpiredAt?: string | null;
  lastLat?: number | null;
  lastLng?: number | null;
  lastSpeed?: number | null;
  lastUpdatedAt?: string | null;
};

type BackendDriver = {
  id: number;
  userId?: number | null;
  fullName: string;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
  licenseNumber?: string | null;
  licenseClass?: string | null;
  licenseExpiredAt?: string | null;
  status: string;
  currentVehicleId?: number | null;
  currentVehiclePlateNumber?: string | null;
  safetyScore?: number | null;
  drivingTimeTodayMinutes?: number | null;
  continuousDrivingMinutes?: number | null;
  totalTrips?: number | null;
  totalAlerts?: number | null;
};

type BackendTrip = {
  id: number;
  tripCode: string;
  vehicleId?: number | null;
  vehiclePlateNumber?: string | null;
  driverId?: number | null;
  driverName?: string | null;
  startLocation: string;
  startLat?: number | null;
  startLng?: number | null;
  endLocation: string;
  endLat?: number | null;
  endLng?: number | null;
  waypoints?: string | null;
  plannedRoute?: string | null;
  actualRoute?: string | null;
  plannedStartTime?: string | null;
  actualStartTime?: string | null;
  estimatedEndTime?: string | null;
  actualEndTime?: string | null;
  status: string;
  progress?: number | null;
  riskLevel?: string | null;
};

type BackendSafetyEvent = {
  id: number;
  eventType: string;
  severity: string;
  vehicleId?: number | null;
  vehiclePlateNumber?: string | null;
  driverId?: number | null;
  driverName?: string | null;
  tripId?: number | null;
  lat?: number | null;
  lng?: number | null;
  speed?: number | null;
  confidence?: number | null;
  evidenceUrl?: string | null;
  status: string;
  handledBy?: number | null;
  handledByName?: string | null;
  handledAt?: string | null;
  note?: string | null;
  createdAt: string;
};

type BackendIncident = {
  id: number;
  incidentCode: string;
  type: string;
  severity: string;
  vehicleId?: number | null;
  vehiclePlateNumber?: string | null;
  driverId?: number | null;
  driverName?: string | null;
  tripId?: number | null;
  lat?: number | null;
  lng?: number | null;
  description?: string | null;
  status: string;
  assignedTo?: number | null;
  assignedToName?: string | null;
  createdAt: string;
  acceptedAt?: string | null;
  resolvedAt?: string | null;
};

type BackendIncidentTimeline = {
  id: number;
  incidentId: number;
  action: string;
  actorId?: number | null;
  actorName?: string | null;
  note?: string | null;
  createdAt: string;
};

type BackendFloodReport = {
  id: number;
  lat: number;
  lng: number;
  address?: string | null;
  severity: string;
  source: string;
  reportedByDriverId?: number | null;
  reportedByDriverName?: string | null;
  imageUrl?: string | null;
  confidence?: number | null;
  status: string;
  verifiedBy?: number | null;
  verifiedAt?: string | null;
  expiredAt?: string | null;
  createdAt: string;
};

type BackendAccount = {
  id: number;
  username: string;
  email: string;
  fullName: string;
  phone?: string | null;
  status: Account["status"];
  role: BackendRole;
  createdAt: string;
};

type BackendSetting = {
  id: number;
  key: string;
  group: string;
  value: string;
  valueType: "STRING" | "INTEGER" | "DECIMAL" | "BOOLEAN" | "JSON";
  description?: string | null;
  updatedBy?: number | null;
  updatedAt?: string | null;
};

type BackendDashboardSummary = {
  totalVehicles: number;
  vehiclesByStatus: Record<string, number>;
  totalDrivers: number;
  driversByStatus: Record<string, number>;
  totalTrips: number;
  tripsByStatus: Record<string, number>;
  openSafetyEvents: number;
  openIncidents: number;
};

export type DispatchSuggestion = {
  vehicleId: string;
  plateNumber: string;
  driverId: string;
  driverName: string;
  score: number;
  distanceKm?: number | null;
  reasons: string[];
};

export type LocationSuggestion = {
  id: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
  source: "PHOTON" | "LOCAL" | string;
};

export type RouteSummary = {
  distanceKm: number;
  durationMinutes: number;
  coordinates: [number, number][];
  provider: "OSRM" | "HAVERSINE" | string;
  fallback: boolean;
  message: string;
};

export type SystemSetting = {
  id: number;
  key: string;
  group: string;
  value: string;
  valueType: BackendSetting["valueType"];
  description?: string | null;
  updatedAt?: string | null;
};

export type FleetDevice = {
  id: number;
  deviceCode: string;
  name: string;
  type: "GPS_TRACKER" | "CABIN_CAMERA" | "DASH_CAMERA" | "DRIVER_PHONE" | "IOT_FLOOD_SENSOR";
  status: "ONLINE" | "OFFLINE" | "MAINTENANCE" | "INACTIVE";
  vehicleId?: number | null;
  vehiclePlateNumber?: string | null;
  phone?: string | null;
  serialNumber?: string | null;
  firmwareVersion?: string | null;
  lastSeenAt?: string | null;
};

export type MaintenanceOrder = {
  id: number;
  maintenanceCode: string;
  vehicleId: number;
  vehiclePlateNumber: string;
  type: "PERIODIC" | "REPAIR" | "INSPECTION" | "INSURANCE" | "EMERGENCY";
  title: string;
  description?: string | null;
  scheduledDate?: string | null;
  completedDate?: string | null;
  cost?: number | null;
  status: "OPEN" | "SCHEDULED" | "IN_PROGRESS" | "COMPLETED" | "CANCELLED";
  priority: "LOW" | "MEDIUM" | "HIGH" | "URGENT";
  assignedTo?: number | null;
  assignedToName?: string | null;
  note?: string | null;
};

export type WarehouseIssueStatus =
  | "DRAFT"
  | "ISSUED"
  | "DRIVER_RECEIVED"
  | "DELIVERED"
  | "COMPLETED"
  | "CANCELLED";

export type WarehouseIssueItemInput = {
  itemCode?: string;
  description: string;
  specification?: string;
  unit: string;
  requestedQuantity?: number;
  issuedQuantity: number;
  returnedQuantity?: number;
  deliveredQuantity?: number;
  conditionNote?: string;
  confirmationNote?: string;
};

export type WarehouseIssueInput = {
  tripId: number;
  issueNumber?: string;
  issueDate: string;
  companyName?: string;
  companyAddress?: string;
  issueReason?: string;
  warehouseName: string;
  warehouseLocation?: string;
  projectName: string;
  workItem?: string;
  recipientName: string;
  recipientPhone?: string;
  deliveryAddress?: string;
  deliveryPersonName?: string;
  quantityInWords?: string;
  notes?: string;
  items: WarehouseIssueItemInput[];
};

export type WarehouseIssue = WarehouseIssueInput & {
  id: number;
  tripCode?: string | null;
  status: WarehouseIssueStatus;
  documentVersion: number;
  preparedByName?: string | null;
  driverId?: number | null;
  driverName?: string | null;
  vehicleId?: number | null;
  vehiclePlateNumber?: string | null;
  issuedAt?: string | null;
  completedAt?: string | null;
  createdAt: string;
  updatedAt?: string | null;
};

const HANOI = { lat: 21.0285, lng: 105.8542 };

function dataOf<T>(response: BackendApiResponse<T>): T {
  return response.data;
}

async function getData<T>(url: string, params?: Record<string, unknown>): Promise<T> {
  const response = await apiClient.get<BackendApiResponse<T>>(url, { params });
  return dataOf(response.data);
}

async function postData<T>(url: string, body?: unknown): Promise<T> {
  const response = await apiClient.post<BackendApiResponse<T>>(url, body ?? {});
  return dataOf(response.data);
}

async function putData<T>(url: string, body: unknown): Promise<T> {
  const response = await apiClient.put<BackendApiResponse<T>>(url, body);
  return dataOf(response.data);
}

async function patchData<T>(url: string, body: unknown): Promise<T> {
  const response = await apiClient.patch<BackendApiResponse<T>>(url, body);
  return dataOf(response.data);
}

function pageParams(size = 100): Record<string, unknown> {
  return { page: 0, size, sort: "id,desc" };
}

function toNumber(value: number | string | null | undefined, fallback = 0): number {
  if (value === null || value === undefined || value === "") return fallback;
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

function toId(value: number | string | null | undefined, prefix = ""): string {
  if (value === null || value === undefined) return "";
  return `${prefix}${value}`;
}

function recentGpsStatus(lastUpdatedAt?: string | null, backendStatus?: string): Vehicle["gpsStatus"] {
  if (backendStatus === "OFFLINE" || backendStatus === "INACTIVE") return "offline";
  if (!lastUpdatedAt) return "offline";
  const diffMins = (Date.now() - new Date(lastUpdatedAt).getTime()) / 60000;
  if (!Number.isFinite(diffMins)) return "offline";
  if (diffMins <= 10) return "online";
  if (diffMins <= 30) return "weak";
  return "offline";
}

function mapVehicleType(value: string): VehicleType {
  const map: Record<string, VehicleType> = {
    TRUCK: "Xe tải",
    BUS: "Xe khách",
    VAN: "Xe van",
    CAR: "Xe con",
    PICKUP: "Xe bán tải",
    MOTORBIKE: "Xe máy",
  };
  return map[value] ?? "Xe tải";
}

function mapVehicleStatus(value: string): VehicleStatus {
  const map: Record<string, VehicleStatus> = {
    AVAILABLE: "idle",
    RUNNING: "running",
    RESTING: "idle",
    MAINTENANCE: "maintenance",
    OFFLINE: "offline",
    INACTIVE: "offline",
  };
  return map[value] ?? "offline";
}

function mapDriverStatus(value: string): DriverStatus {
  const map: Record<string, DriverStatus> = {
    AVAILABLE: "available",
    DRIVING: "driving",
    RESTING: "resting",
    SUSPENDED: "suspended",
    HIGH_RISK: "high_risk",
    INACTIVE: "inactive",
  };
  return map[value] ?? "off_duty";
}

function mapTripStatus(value: string): TripStatus {
  const map: Record<string, TripStatus> = {
    DRAFT: "pending",
    ASSIGNED: "pending",
    ACCEPTED: "pending",
    IN_PROGRESS: "in_progress",
    RESTING: "in_progress",
    COMPLETED: "completed",
    DELAYED: "pending",
    INCIDENT: "incident",
    CANCELLED: "cancelled",
  };
  return map[value] ?? "pending";
}

function mapRiskLevel(value?: string | null): RiskLevel {
  const lower = (value ?? "LOW").toLowerCase();
  return ["low", "medium", "high", "critical"].includes(lower) ? (lower as RiskLevel) : "low";
}

function mapAlertType(value: string): AlertType {
  const map: Record<string, AlertType> = {
    DROWSINESS: "drowsy",
    PHONE_USAGE: "phone_usage",
    DISTRACTION: "distraction",
    SPEEDING: "speeding",
    OVER_DRIVING_TIME: "overtime",
    ROUTE_DEVIATION: "route_deviation",
    ABNORMAL_STOP: "abnormal_stop",
    GPS_LOST: "connection_lost",
    FLOOD_RISK: "near_flood",
  };
  return map[value] ?? "distraction";
}

function mapAlertStatus(value: string): AlertStatus {
  const map: Record<string, AlertStatus> = {
    NEW: "new",
    ACKNOWLEDGED: "acknowledged",
    PROCESSING: "acknowledged",
    RESOLVED: "resolved",
    DISMISSED: "resolved",
  };
  return map[value] ?? "new";
}

function mapSeverity(value: string): AlertSeverity {
  const lower = value.toLowerCase();
  return ["low", "medium", "high", "critical"].includes(lower) ? (lower as AlertSeverity) : "low";
}

function mapIncidentType(value: string): IncidentType {
  const map: Record<string, IncidentType> = {
    SOS: "sos",
    ACCIDENT: "accident",
    VEHICLE_BREAKDOWN: "breakdown",
    DRIVER_UNRESPONSIVE: "medical",
    FLOOD_STUCK: "other",
    GPS_LOST: "other",
    MANUAL: "other",
  };
  return map[value] ?? "other";
}

function mapIncidentStatus(value: string): IncidentStatus {
  const map: Record<string, IncidentStatus> = {
    OPEN: "open",
    ACCEPTED: "in_progress",
    PROCESSING: "in_progress",
    ESCALATED: "overdue",
    RESOLVED: "resolved",
    CLOSED: "resolved",
    CANCELLED: "resolved",
  };
  return map[value] ?? "open";
}

function mapIncidentPriority(value: string): IncidentPriority {
  const map: Record<string, IncidentPriority> = {
    CRITICAL: "critical",
    HIGH: "high",
    MEDIUM: "medium",
    LOW: "low",
  };
  return map[value] ?? "medium";
}

function mapFloodSeverity(value: string): FloodSeverity {
  const map: Record<string, FloodSeverity> = {
    NONE: "light",
    LOW: "light",
    MEDIUM: "moderate",
    HIGH: "heavy",
    BLOCKED: "impassable",
  };
  return map[value] ?? "light";
}

function alertMessage(event: BackendSafetyEvent): string {
  const type = mapAlertType(event.eventType);
  const labels: Record<AlertType, string> = {
    drowsy: "Phát hiện dấu hiệu ngủ gật",
    phone_usage: "Sử dụng điện thoại khi lái xe",
    distraction: "Mất tập trung khi lái xe",
    overtime: "Vượt ngưỡng thời gian lái",
    speeding: "Vượt tốc độ an toàn",
    route_deviation: "Lệch khỏi tuyến đường",
    abnormal_stop: "Dừng bất thường",
    connection_lost: "Mất tín hiệu GPS",
    near_flood: "Rủi ro điểm ngập trên tuyến",
  };
  return event.note || labels[type];
}

function vehicleFromBackend(vehicle: BackendVehicle): Vehicle {
  const status = mapVehicleStatus(vehicle.status);
  return {
    id: toId(vehicle.id),
    code: String(vehicle.id).padStart(3, "0"),
    plate: vehicle.plateNumber,
    type: mapVehicleType(vehicle.vehicleType),
    brand: vehicle.brand,
    model: vehicle.model,
    year: vehicle.year,
    capacity: toNumber(vehicle.loadCapacity),
    status,
    gpsStatus: recentGpsStatus(vehicle.lastUpdatedAt, vehicle.status),
    currentDriverId: toId(vehicle.currentDriverId) || undefined,
    currentDriverName: vehicle.currentDriverName || undefined,
    currentSpeed: toNumber(vehicle.lastSpeed),
    lat: vehicle.lastLat ?? HANOI.lat,
    lng: vehicle.lastLng ?? HANOI.lng,
    lastUpdated: vehicle.lastUpdatedAt || new Date().toISOString(),
    registrationExpiry: vehicle.inspectionExpiredAt || "",
    insuranceExpiry: vehicle.insuranceExpiredAt || "",
    totalTrips: 0,
    totalKm: 0,
    totalAlerts: 0,
    nextMaintenanceKm: status === "maintenance" ? 0 : 2000,
  };
}

function driverFromBackend(driver: BackendDriver): Driver {
  return {
    id: toId(driver.id),
    code: driver.licenseNumber || String(driver.id).padStart(3, "0"),
    fullName: driver.fullName,
    phone: driver.phone || "Chưa cập nhật",
    email: driver.email || "Chưa cập nhật",
    licenseClass: driver.licenseClass || "-",
    licenseExpiry: driver.licenseExpiredAt || "",
    status: mapDriverStatus(driver.status),
    currentVehicleId: toId(driver.currentVehicleId) || undefined,
    currentVehiclePlate: driver.currentVehiclePlateNumber || undefined,
    safetyScore: driver.safetyScore ?? 100,
    drivingTimeToday: driver.drivingTimeTodayMinutes ?? 0,
    totalTrips: driver.totalTrips ?? 0,
    totalKm: 0,
    totalDrivingHours: Math.round((driver.continuousDrivingMinutes ?? 0) / 60),
    sleepAlerts: 0,
    phoneAlerts: 0,
    speedAlerts: 0,
    overtimeAlerts: 0,
    incidents: 0,
    joinDate: "",
  };
}

function parseWaypoints(value?: string | null): string[] {
  if (!value) return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.map(String) : [value];
  } catch {
    return value.split(",").map((item) => item.trim()).filter(Boolean);
  }
}

function tripFromBackend(trip: BackendTrip): Trip {
  return {
    id: toId(trip.id),
    code: trip.tripCode,
    type: "delivery",
    vehicleId: toId(trip.vehicleId),
    vehiclePlate: trip.vehiclePlateNumber || "Chưa giao xe",
    driverId: toId(trip.driverId),
    driverName: trip.driverName || "Chưa giao tài xế",
    origin: trip.startLocation,
    destination: trip.endLocation,
    waypoints: parseWaypoints(trip.waypoints),
    scheduledStart: trip.plannedStartTime || "",
    scheduledEnd: trip.estimatedEndTime || "",
    actualStart: trip.actualStartTime || undefined,
    actualEnd: trip.actualEndTime || undefined,
    eta: trip.estimatedEndTime || undefined,
    progress: trip.progress ?? 0,
    status: mapTripStatus(trip.status),
    riskLevel: mapRiskLevel(trip.riskLevel),
    totalKm: 0,
    notes: trip.plannedRoute || undefined,
  };
}

function alertFromBackend(event: BackendSafetyEvent): Alert {
  return {
    id: toId(event.id),
    type: mapAlertType(event.eventType),
    severity: mapSeverity(event.severity),
    vehicleId: toId(event.vehicleId),
    vehiclePlate: event.vehiclePlateNumber || "Không rõ xe",
    driverId: toId(event.driverId),
    driverName: event.driverName || "Không rõ tài xế",
    message: alertMessage(event),
    timestamp: event.createdAt,
    lat: event.lat ?? HANOI.lat,
    lng: event.lng ?? HANOI.lng,
    speed: event.speed ?? undefined,
    status: mapAlertStatus(event.status),
    handledBy: event.handledByName || undefined,
    handledAt: event.handledAt || undefined,
    evidenceUrl: event.evidenceUrl || undefined,
  };
}

function incidentTimelineFromBackend(item: BackendIncidentTimeline): IncidentTimelineEntry {
  return {
    time: item.createdAt,
    action: item.note ? `${item.action}: ${item.note}` : item.action,
    actor: item.actorName || undefined,
  };
}

function incidentFromBackend(incident: BackendIncident, timeline?: IncidentTimelineEntry[]): Incident {
  const fallbackTimeline: IncidentTimelineEntry[] = [
    {
      time: incident.createdAt,
      action: incident.type === "SOS" ? "Tạo sự cố SOS" : "Tạo sự cố",
      actor: "Hệ thống",
    },
  ];

  return {
    id: toId(incident.id),
    type: mapIncidentType(incident.type),
    vehicleId: toId(incident.vehicleId),
    vehiclePlate: incident.vehiclePlateNumber || "Không rõ xe",
    driverId: toId(incident.driverId),
    driverName: incident.driverName || "Không rõ tài xế",
    location:
      incident.lat && incident.lng
        ? `${incident.lat.toFixed(5)}, ${incident.lng.toFixed(5)}`
        : "Chưa có tọa độ",
    lat: incident.lat ?? HANOI.lat,
    lng: incident.lng ?? HANOI.lng,
    timestamp: incident.createdAt,
    status: mapIncidentStatus(incident.status),
    priority: mapIncidentPriority(incident.severity),
    description: incident.description || undefined,
    timeline: timeline && timeline.length > 0 ? timeline : fallbackTimeline,
    assignedTo: incident.assignedToName || undefined,
  };
}

function floodFromBackend(report: BackendFloodReport): FloodPoint {
  return {
    id: toId(report.id),
    location: report.address || `${report.lat.toFixed(5)}, ${report.lng.toFixed(5)}`,
    lat: report.lat,
    lng: report.lng,
    severity: mapFloodSeverity(report.severity),
    verified: report.status === "VERIFIED" || report.status === "RESOLVED",
    reportCount: report.reportedByDriverId ? 1 : 0,
    confidence: Math.round(report.confidence ?? 0),
    lastUpdated: report.verifiedAt || report.createdAt,
    affectedVehicles: 0,
    affectedRoutes: [],
    imageUrl: report.imageUrl || undefined,
    source: report.source.replaceAll("_", " "),
  };
}

function accountFromBackend(account: BackendAccount): Account {
  return {
    id: account.id,
    username: account.username,
    fullName: account.fullName,
    email: account.email,
    role: account.role,
    status: account.status,
    createdAt: account.createdAt,
  };
}

function statsFromBackend(summary: BackendDashboardSummary, floodPoints: FloodPoint[] = []): CommandCenterStats {
  return {
    totalOperating: summary.vehiclesByStatus.RUNNING ?? 0,
    alertsToday: summary.openSafetyEvents,
    openSos: summary.openIncidents,
    driversNearOvertime: summary.driversByStatus.HIGH_RISK ?? 0,
    vehiclesOffline: summary.vehiclesByStatus.OFFLINE ?? 0,
    activeFloodPoints: floodPoints.filter((point) => point.verified).length,
  };
}

export function userFromAuth(data: BackendAuthResponse): AuthUser {
  return {
    id: data.userId,
    username: data.username,
    fullName: data.fullName,
    email: data.email,
    role: data.role,
    status: "ACTIVE",
  };
}

export function userFromCurrent(data: BackendCurrentUserResponse): AuthUser {
  return {
    id: data.userId,
    username: data.username,
    fullName: data.fullName,
    email: data.email,
    role: data.role,
    status: data.status,
  };
}

export const safeFleetApi = {
  async login(usernameOrEmail: string, password: string): Promise<BackendAuthResponse> {
    return postData<BackendAuthResponse>("/auth/login", { usernameOrEmail, password });
  },

  async logout(refreshToken: string): Promise<void> {
    await postData<void>("/auth/logout", { refreshToken });
  },

  async me(): Promise<BackendCurrentUserResponse> {
    return getData<BackendCurrentUserResponse>("/auth/me");
  },

  async vehicles(): Promise<Vehicle[]> {
    const page = await getData<BackendPage<BackendVehicle>>("/vehicles", pageParams(200));
    return page.items.map(vehicleFromBackend);
  },

  async devices(): Promise<FleetDevice[]> {
    const page = await getData<BackendPage<FleetDevice>>("/devices", pageParams(200));
    return page.items;
  },

  async maintenanceOrders(): Promise<MaintenanceOrder[]> {
    const page = await getData<BackendPage<MaintenanceOrder>>(
      "/maintenance-orders",
      pageParams(200)
    );
    return page.items;
  },

  async drivers(): Promise<Driver[]> {
    const page = await getData<BackendPage<BackendDriver>>("/drivers", pageParams(200));
    return page.items.map(driverFromBackend);
  },

  async trips(): Promise<Trip[]> {
    const page = await getData<BackendPage<BackendTrip>>("/trips", pageParams(200));
    return page.items.map(tripFromBackend);
  },

  async safetyEvents(): Promise<Alert[]> {
    const page = await getData<BackendPage<BackendSafetyEvent>>("/safety-events", pageParams(200));
    return page.items.map(alertFromBackend);
  },

  async acknowledgeSafetyEvent(id: string): Promise<Alert> {
    const event = await postData<BackendSafetyEvent>(`/safety-events/${id}/acknowledge`, {
      note: "Tiếp nhận từ giao diện web",
    });
    return alertFromBackend(event);
  },

  async resolveSafetyEvent(id: string): Promise<Alert> {
    const event = await postData<BackendSafetyEvent>(`/safety-events/${id}/resolve`, {
      note: "Đã xử lý từ giao diện web",
    });
    return alertFromBackend(event);
  },

  async incidents(): Promise<Incident[]> {
    const page = await getData<BackendPage<BackendIncident>>("/incidents", pageParams(200));
    return page.items.map((incident) => incidentFromBackend(incident));
  },

  async incidentTimeline(id: string): Promise<IncidentTimelineEntry[]> {
    const items = await getData<BackendIncidentTimeline[]>(`/incidents/${id}/timeline`);
    return items.map(incidentTimelineFromBackend);
  },

  async acceptIncident(id: string): Promise<Incident> {
    const incident = await postData<BackendIncident>(`/incidents/${id}/accept`);
    const timeline = await this.incidentTimeline(id).catch(() => []);
    return incidentFromBackend(incident, timeline);
  },

  async closeIncident(id: string): Promise<Incident> {
    const incident = await postData<BackendIncident>(`/incidents/${id}/close`, {
      action: "CLOSE",
      note: "Đóng sự cố từ giao diện web",
    });
    const timeline = await this.incidentTimeline(id).catch(() => []);
    return incidentFromBackend(incident, timeline);
  },

  async floodPoints(): Promise<FloodPoint[]> {
    const reports = await getData<BackendFloodReport[]>("/flood-reports/map");
    return reports.map(floodFromBackend);
  },

  async verifyFloodPoint(id: string): Promise<FloodPoint> {
    const report = await postData<BackendFloodReport>(`/flood-reports/${id}/verify`, {
      note: "Xác minh từ giao diện web",
    });
    return floodFromBackend(report);
  },

  async resolveFloodPoint(id: string): Promise<FloodPoint> {
    const report = await postData<BackendFloodReport>(`/flood-reports/${id}/resolve`, {
      note: "Đã hết ngập",
    });
    return floodFromBackend(report);
  },

  async accounts(): Promise<Account[]> {
    const page = await getData<BackendPage<BackendAccount>>("/accounts", pageParams(200));
    return page.items.map(accountFromBackend);
  },

  async updateAccountStatus(id: number, status: Account["status"]): Promise<Account> {
    const account = await patchData<BackendAccount>(`/accounts/${id}/status`, { status });
    return accountFromBackend(account);
  },

  async dashboardStats(): Promise<CommandCenterStats> {
    const [summary, floodPoints] = await Promise.all([
      getData<BackendDashboardSummary>("/dashboard/summary"),
      this.floodPoints().catch(() => []),
    ]);
    return statsFromBackend(summary, floodPoints);
  },

  async dispatchSuggestions(): Promise<DispatchSuggestion[]> {
    const suggestions = await getData<
      {
        vehicleId: number;
        plateNumber: string;
        driverId: number;
        driverName: string;
        score: number;
        distanceKm?: number | null;
        reasons: string[];
      }[]
    >("/dispatch/suggestions", { limit: 5 });

    return suggestions.map((item) => ({
      vehicleId: toId(item.vehicleId),
      plateNumber: item.plateNumber,
      driverId: toId(item.driverId),
      driverName: item.driverName,
      score: item.score,
      distanceKm: item.distanceKm,
      reasons: item.reasons,
    }));
  },

  async locationAutocomplete(query: string, limit = 6): Promise<LocationSuggestion[]> {
    if (query.trim().length < 2) return [];
    return getData<LocationSuggestion[]>("/locations/autocomplete", { query: query.trim(), limit });
  },

  async routeSummary(input: {
    startLat: number;
    startLng: number;
    endLat: number;
    endLng: number;
  }): Promise<RouteSummary> {
    return postData<RouteSummary>("/locations/route", input);
  },

  async createTrip(input: {
    vehicleId?: string;
    driverId?: string;
    startLocation: string;
    startLat?: number;
    startLng?: number;
    endLocation: string;
    endLat?: number;
    endLng?: number;
    plannedStartTime: string;
    estimatedEndTime: string;
    riskLevel?: RiskLevel;
    waypoints?: string[];
    plannedRoute?: string;
  }): Promise<Trip> {
    const trip = await postData<BackendTrip>("/trips", {
      vehicleId: input.vehicleId ? Number(input.vehicleId) : null,
      driverId: input.driverId ? Number(input.driverId) : null,
      startLocation: input.startLocation,
      startLat: input.startLat,
      startLng: input.startLng,
      endLocation: input.endLocation,
      endLat: input.endLat,
      endLng: input.endLng,
      plannedStartTime: input.plannedStartTime,
      estimatedEndTime: input.estimatedEndTime,
      riskLevel: (input.riskLevel ?? "low").toUpperCase(),
      waypoints: input.waypoints?.join(", "),
      plannedRoute: input.plannedRoute,
    });
    return tripFromBackend(trip);
  },

  async createWarehouseIssue(input: WarehouseIssueInput): Promise<WarehouseIssue> {
    return postData<WarehouseIssue>("/warehouse-issues", input);
  },

  async updateWarehouseIssue(id: number, input: WarehouseIssueInput): Promise<WarehouseIssue> {
    return putData<WarehouseIssue>(`/warehouse-issues/${id}`, input);
  },

  async issueWarehouseIssue(id: number): Promise<WarehouseIssue> {
    return postData<WarehouseIssue>(`/warehouse-issues/${id}/issue`);
  },

  async warehouseIssueByTrip(tripId: string | number): Promise<WarehouseIssue> {
    return getData<WarehouseIssue>(`/warehouse-issues/by-trip/${tripId}`);
  },

  async reportSafetyEventsByType(): Promise<Record<string, number>> {
    return getData<Record<string, number>>("/reports/safety-events/by-type");
  },

  async reportTripsByDay(): Promise<{ date: string; totalTrips: number }[]> {
    return getData<{ date: string; totalTrips: number }[]>("/reports/trips/by-day");
  },

  async settings(): Promise<SystemSetting[]> {
    const settings = await getData<BackendSetting[]>("/settings");
    return settings.map((setting) => ({
      id: setting.id,
      key: setting.key,
      group: setting.group,
      value: setting.value,
      valueType: setting.valueType,
      description: setting.description,
      updatedAt: setting.updatedAt,
    }));
  },

  async updateSetting(setting: SystemSetting): Promise<SystemSetting> {
    const updated = await putData<BackendSetting>(`/settings/${setting.key}`, {
      group: setting.group,
      value: setting.value,
      valueType: setting.valueType,
      description: setting.description,
    });
    return {
      id: updated.id,
      key: updated.key,
      group: updated.group,
      value: updated.value,
      valueType: updated.valueType,
      description: updated.description,
      updatedAt: updated.updatedAt,
    };
  },
};
