// Environment configuration
const USE_MOCK = process.env.NEXT_PUBLIC_USE_MOCK === 'true';

export { USE_MOCK };

// Status label mappings (Vietnamese)
export const VEHICLE_STATUS_LABELS: Record<string, string> = {
  running: 'Đang chạy',
  idle: 'Sẵn sàng',
  maintenance: 'Bảo trì',
  offline: 'Mất kết nối',
};

export const DRIVER_STATUS_LABELS: Record<string, string> = {
  driving: 'Đang lái',
  available: 'Sẵn sàng',
  resting: 'Đang nghỉ',
  off_duty: 'Nghỉ phép',
  suspended: 'Tạm khóa',
  high_risk: 'Rủi ro cao',
  inactive: 'Ngừng hoạt động',
};

export const TRIP_STATUS_LABELS: Record<string, string> = {
  pending: 'Chưa bắt đầu',
  in_progress: 'Đang thực hiện',
  completed: 'Hoàn thành',
  cancelled: 'Đã hủy',
  incident: 'Gặp sự cố',
};

export const ALERT_TYPE_LABELS: Record<string, string> = {
  drowsy: 'Ngủ gật',
  drowsiness: 'Ngủ gật',
  phone_usage: 'Dùng điện thoại',
  distraction: 'Mất tập trung',
  overtime: 'Quá giờ lái',
  speeding: 'Vượt tốc độ',
  route_deviation: 'Lệch tuyến',
  abnormal_stop: 'Dừng bất thường',
  connection_lost: 'Mất kết nối',
  gps_lost: 'Mất GPS',
  near_flood: 'Gần điểm ngập',
  flood_risk: 'Rủi ro ngập',
};

export const ALERT_SEVERITY_LABELS: Record<string, string> = {
  low: 'Thấp',
  medium: 'Trung bình',
  high: 'Cao',
  critical: 'Nghiêm trọng',
};

export const FLOOD_SEVERITY_LABELS: Record<string, string> = {
  light: 'Ngập nhẹ',
  moderate: 'Ngập vừa',
  heavy: 'Ngập nặng',
  impassable: 'Không thể đi qua',
};

export const INCIDENT_STATUS_LABELS: Record<string, string> = {
  open: 'Chưa tiếp nhận',
  in_progress: 'Đang xử lý',
  resolved: 'Đã xử lý',
  overdue: 'Quá hạn',
};

// Status color mappings
export const STATUS_COLORS: Record<string, string> = {
  // Vehicle
  running: '#3b82f6',
  idle: '#22c55e',
  maintenance: '#f59e0b',
  offline: '#6b7280',
  
  // Driver
  driving: '#3b82f6',
  available: '#22c55e',
  resting: '#f59e0b',
  off_duty: '#6b7280',
  suspended: '#ef4444',
  high_risk: '#ef4444',
  inactive: '#6b7280',
  
  // Trip
  pending: '#6b7280',
  in_progress: '#3b82f6',
  completed: '#22c55e',
  cancelled: '#6b7280',
  incident: '#ef4444',
  
  // Alert severity
  low: '#22c55e',
  medium: '#f59e0b',
  high: '#f97316',
  critical: '#ef4444',

  // Incident
  open: '#ef4444',
  overdue: '#7c3aed',
  resolved: '#22c55e',

  // Flood
  light: '#06b6d4',
  moderate: '#f59e0b',
  heavy: '#f97316',
  impassable: '#ef4444',
};

// Map configuration
export const MAP_CONFIG = {
  center: [105.8542, 21.0285] as [number, number], // Hà Nội
  zoom: 12,
  tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  attribution: '© OpenStreetMap contributors',
};

// Safety score thresholds
export const SAFETY_SCORE = {
  EXCELLENT: { min: 90, label: 'Rất tốt', color: '#22c55e' },
  GOOD: { min: 75, label: 'Tốt', color: '#3b82f6' },
  MONITOR: { min: 60, label: 'Cần theo dõi', color: '#f59e0b' },
  HIGH_RISK: { min: 0, label: 'Rủi ro cao', color: '#ef4444' },
};

// Driving time limits (minutes)
export const DRIVING_LIMITS = {
  MAX_CONTINUOUS: 240, // 4 hours
  WARNING_1: 180,      // 3 hours
  WARNING_2: 210,      // 3.5 hours
  CRITICAL: 230,       // 3h50m
};

export function getSafetyScoreInfo(score: number) {
  if (score >= SAFETY_SCORE.EXCELLENT.min) return SAFETY_SCORE.EXCELLENT;
  if (score >= SAFETY_SCORE.GOOD.min) return SAFETY_SCORE.GOOD;
  if (score >= SAFETY_SCORE.MONITOR.min) return SAFETY_SCORE.MONITOR;
  return SAFETY_SCORE.HIGH_RISK;
}

export function formatDrivingTime(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return hours > 0 ? `${hours}h${mins > 0 ? mins + 'm' : ''}` : `${mins}m`;
}

export function formatDateTime(dateStr: string): string {
  return new Date(dateStr).toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatTimeAgo(dateStr: string): string {
  const now = new Date();
  const date = new Date(dateStr);
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);

  if (diffMins < 1) return 'Vừa xong';
  if (diffMins < 60) return `${diffMins} phút trước`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours} giờ trước`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays} ngày trước`;
}

export function cn(...classes: (string | boolean | undefined | null)[]): string {
  return classes.filter(Boolean).join(' ');
}
