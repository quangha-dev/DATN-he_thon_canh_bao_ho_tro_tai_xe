// ===================================================================
// SafeFleet Command Center — TypeScript Type Definitions
// ===================================================================

// ===== AUTH =====
export interface LoginPayload {
  usernameOrEmail: string;
  password: string;
}

export interface AuthUser {
  id: number;
  username: string;
  fullName: string;
  email: string;
  role: UserRole;
  status: AccountStatus;
  avatarUrl?: string;
}

export type UserRole = 'ADMIN' | 'FLEET_MANAGER' | 'DISPATCHER' | 'SAFETY_OFFICER' | 'RESCUE_TEAM' | 'DRIVER';
export type AccountStatus = 'ACTIVE' | 'LOCKED' | 'DISABLED' | 'PENDING';

// ===== API RESPONSE =====
export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message: string;
  timestamp?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  totalElements: number;
  totalPages: number;
  page: number;
  size: number;
}

// ===== VEHICLE =====
export interface Vehicle {
  id: string;
  code?: string;
  plate: string;
  type: VehicleType;
  brand: string;
  model: string;
  year: number;
  capacity: number;
  status: VehicleStatus;
  gpsStatus: GpsStatus;
  currentDriverId?: string;
  currentDriverName?: string;
  currentSpeed: number;
  lat: number | null;
  lng: number | null;
  lastUpdated: string | null;
  registrationExpiry: string;
  insuranceExpiry: string;
  totalTrips: number;
  totalKm: number;
  totalAlerts: number;
  nextMaintenanceKm: number;
  imageUrl?: string;
  backendType?: string;
  backendStatus?: string;
  fuelType?: string;
  seatCount?: number;
  gpsDeviceId?: string;
  cameraDeviceId?: string;
}

export type VehicleType = 'Xe tải' | 'Xe khách' | 'Xe container' | 'Xe van' | 'Xe bồn' | 'Xe con' | 'Xe bán tải' | 'Xe máy';
export type VehicleStatus = 'running' | 'idle' | 'maintenance' | 'offline';
export type GpsStatus = 'online' | 'offline' | 'weak';

// ===== DRIVER =====
export interface Driver {
  id: string;
  userId?: string;
  code?: string;
  fullName: string;
  phone: string;
  email: string;
  address?: string;
  licenseNumber?: string;
  licenseClass: string;
  licenseExpiry: string;
  status: DriverStatus;
  backendStatus?: string;
  currentVehicleId?: string;
  currentVehiclePlate?: string;
  safetyScore: number;
  drivingTimeToday: number; // minutes
  totalTrips: number;
  totalKm: number;
  totalDrivingHours: number;
  sleepAlerts: number;
  phoneAlerts: number;
  speedAlerts: number;
  overtimeAlerts: number;
  incidents: number;
  avatarUrl?: string;
  joinDate: string;
}

export type DriverStatus = 'driving' | 'available' | 'resting' | 'off_duty' | 'suspended' | 'high_risk' | 'inactive';

// ===== TRIP =====
export interface Trip {
  id: string;
  code: string;
  type: TripType;
  vehicleId: string;
  vehiclePlate: string;
  driverId: string;
  driverName: string;
  origin: string;
  destination: string;
  waypoints: string[];
  scheduledStart: string;
  scheduledEnd: string;
  actualStart?: string;
  actualEnd?: string;
  eta?: string;
  progress: number; // 0-100
  status: TripStatus;
  riskLevel: RiskLevel;
  totalKm: number;
  notes?: string;
}

export type TripType = 'delivery' | 'passenger' | 'transfer' | 'return';
export type TripStatus = 'pending' | 'in_progress' | 'completed' | 'cancelled' | 'incident';
export type RiskLevel = 'low' | 'medium' | 'high' | 'critical';

// ===== DOCUMENT PLATE REVIEW =====
export type DocumentPlateReviewStatus =
  | 'REVIEW_REQUIRED'
  | 'APPROVED'
  | 'REJECTED'
  | 'MATCHED';

export interface DocumentPlateReview {
  id: string;
  driverId?: string;
  driverName: string;
  tripId?: string;
  tripCode?: string;
  expectedVehiclePlate?: string;
  recognizedVehiclePlate?: string;
  reviewStatus: DocumentPlateReviewStatus;
  reviewReason?: string;
  reviewNote?: string;
  reviewedByName?: string;
  reviewedAt?: string;
  voucherNumber?: string;
  voucherDate?: string;
  projectAddress?: string;
  originalFilename?: string;
  imageUrl?: string;
  createdAt: string;
  completedAt?: string;
}

// ===== ALERT =====
export interface Alert {
  id: string;
  type: AlertType;
  severity: AlertSeverity;
  vehicleId: string;
  vehiclePlate: string;
  driverId: string;
  driverName: string;
  message: string;
  timestamp: string;
  lat: number;
  lng: number;
  speed?: number;
  drivingTime?: number;
  repeatCount?: number;
  status: AlertStatus;
  handledBy?: string;
  handledAt?: string;
  evidenceUrl?: string;
}

export type AlertType =
  | 'drowsy'
  | 'phone_usage'
  | 'distraction'
  | 'overtime'
  | 'speeding'
  | 'route_deviation'
  | 'abnormal_stop'
  | 'connection_lost'
  | 'near_flood';

export type AlertSeverity = 'low' | 'medium' | 'high' | 'critical';
export type AlertStatus = 'new' | 'acknowledged' | 'resolved' | 'escalated';

// ===== INCIDENT (SOS) =====
export interface Incident {
  id: string;
  type: IncidentType;
  vehicleId: string;
  vehiclePlate: string;
  driverId: string;
  driverName: string;
  location: string;
  lat: number;
  lng: number;
  timestamp: string;
  status: IncidentStatus;
  priority: IncidentPriority;
  description?: string;
  timeline: IncidentTimelineEntry[];
  assignedTo?: string;
}

export type IncidentType = 'sos' | 'accident' | 'breakdown' | 'medical' | 'other';
export type IncidentStatus = 'open' | 'in_progress' | 'resolved' | 'overdue';
export type IncidentPriority = 'critical' | 'high' | 'medium' | 'low';

export interface IncidentTimelineEntry {
  time: string;
  action: string;
  actor?: string;
}

// ===== FLOOD POINT =====
export interface FloodPoint {
  id: string;
  location: string;
  lat: number;
  lng: number;
  severity: FloodSeverity;
  verified: boolean;
  reportCount: number;
  confidence: number; // 0-100
  lastUpdated: string;
  affectedVehicles: number;
  affectedRoutes: string[];
  imageUrl?: string;
  source: string;
}

export type FloodSeverity = 'light' | 'moderate' | 'heavy' | 'impassable';

// ===== DEVICE =====
export interface Device {
  id: string;
  type: DeviceType;
  name: string;
  serial: string;
  vehicleId?: string;
  vehiclePlate?: string;
  status: DeviceStatus;
  lastPing: string;
  firmwareVersion?: string;
}

export type DeviceType = 'gps_tracker' | 'cabin_camera' | 'dashcam' | 'driver_phone' | 'flood_sensor' | 'obd';
export type DeviceStatus = 'active' | 'inactive' | 'error';

// ===== MAINTENANCE =====
export interface Maintenance {
  id: string;
  vehicleId: string;
  vehiclePlate: string;
  type: MaintenanceType;
  description: string;
  scheduledDate: string;
  completedDate?: string;
  status: MaintenanceStatus;
  cost: number;
  notes?: string;
}

export type MaintenanceType = 'regular' | 'repair' | 'inspection' | 'registration';
export type MaintenanceStatus = 'scheduled' | 'in_progress' | 'completed' | 'overdue';

// ===== ACCOUNT =====
export interface Account {
  id: number;
  username: string;
  fullName: string;
  email: string;
  role: UserRole;
  status: AccountStatus;
  createdAt: string;
  lastLogin?: string;
}

// ===== OVERVIEW STATS =====
export interface CommandCenterStats {
  totalOperating: number;
  alertsToday: number;
  openSos: number;
  driversNearOvertime: number;
  vehiclesOffline: number;
  activeFloodPoints: number;
}

// ===== SIDEBAR MENU =====
export interface SidebarItem {
  key: string;
  label: string;
  icon: string;
  path: string;
  badge?: number;
  badgeColor?: string;
}

export interface SidebarGroup {
  title: string;
  items: SidebarItem[];
}
