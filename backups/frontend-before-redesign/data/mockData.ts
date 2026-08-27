import { Vehicle, Driver, Trip, Alert, Incident, FloodPoint, CommandCenterStats } from '@/types';

// ===================================================================
// MOCK VEHICLES — 20 xe, bối cảnh Hà Nội
// ===================================================================
const now = new Date();
const minutesAgo = (m: number) => new Date(now.getTime() - m * 60000).toISOString();

export const mockVehicles: Vehicle[] = [
  { id: 'V001', plate: '30A-12345', type: 'Xe tải', brand: 'Hyundai', model: 'HD120', year: 2022, capacity: 5, status: 'running', gpsStatus: 'online', currentDriverId: 'D001', currentDriverName: 'Nguyễn Văn An', currentSpeed: 42, lat: 21.0285, lng: 105.8542, lastUpdated: minutesAgo(1), registrationExpiry: '2027-03-15', insuranceExpiry: '2027-06-20', totalTrips: 342, totalKm: 45200, totalAlerts: 8, nextMaintenanceKm: 420 },
  { id: 'V002', plate: '30B-67890', type: 'Xe khách', brand: 'Thaco', model: 'TB82S', year: 2021, capacity: 29, status: 'running', gpsStatus: 'online', currentDriverId: 'D002', currentDriverName: 'Trần Văn Bình', currentSpeed: 55, lat: 21.0070, lng: 105.8200, lastUpdated: minutesAgo(2), registrationExpiry: '2026-12-10', insuranceExpiry: '2027-01-15', totalTrips: 520, totalKm: 82100, totalAlerts: 15, nextMaintenanceKm: 800 },
  { id: 'V003', plate: '29C-88888', type: 'Xe tải', brand: 'Isuzu', model: 'NQR75', year: 2023, capacity: 3.5, status: 'idle', gpsStatus: 'online', currentDriverId: undefined, currentDriverName: undefined, currentSpeed: 0, lat: 21.0367, lng: 105.7750, lastUpdated: minutesAgo(5), registrationExpiry: '2028-01-20', insuranceExpiry: '2027-12-05', totalTrips: 128, totalKm: 15600, totalAlerts: 3, nextMaintenanceKm: 2200 },
  { id: 'V004', plate: '30D-11111', type: 'Xe van', brand: 'Ford', model: 'Transit', year: 2022, capacity: 1.5, status: 'running', gpsStatus: 'online', currentDriverId: 'D003', currentDriverName: 'Lê Văn Cường', currentSpeed: 35, lat: 21.0505, lng: 105.7330, lastUpdated: minutesAgo(1), registrationExpiry: '2027-05-22', insuranceExpiry: '2027-08-10', totalTrips: 415, totalKm: 38700, totalAlerts: 5, nextMaintenanceKm: 1500 },
  { id: 'V005', plate: '30E-22222', type: 'Xe container', brand: 'Hino', model: 'FL8J', year: 2020, capacity: 15, status: 'running', gpsStatus: 'online', currentDriverId: 'D004', currentDriverName: 'Phạm Văn Đức', currentSpeed: 60, lat: 21.0540, lng: 105.7160, lastUpdated: minutesAgo(3), registrationExpiry: '2026-09-18', insuranceExpiry: '2026-11-30', totalTrips: 210, totalKm: 98500, totalAlerts: 22, nextMaintenanceKm: 350 },
  { id: 'V006', plate: '30F-33333', type: 'Xe tải', brand: 'Hyundai', model: 'HD65', year: 2023, capacity: 2.5, status: 'idle', gpsStatus: 'online', currentDriverId: undefined, currentDriverName: undefined, currentSpeed: 0, lat: 21.0180, lng: 105.8030, lastUpdated: minutesAgo(10), registrationExpiry: '2028-07-01', insuranceExpiry: '2028-03-15', totalTrips: 89, totalKm: 9800, totalAlerts: 1, nextMaintenanceKm: 4500 },
  { id: 'V007', plate: '30G-44444', type: 'Xe khách', brand: 'Thaco', model: 'TB120S', year: 2021, capacity: 45, status: 'maintenance', gpsStatus: 'offline', currentDriverId: undefined, currentDriverName: undefined, currentSpeed: 0, lat: 21.0285, lng: 105.7855, lastUpdated: minutesAgo(180), registrationExpiry: '2027-02-28', insuranceExpiry: '2027-04-10', totalTrips: 678, totalKm: 125000, totalAlerts: 30, nextMaintenanceKm: 0 },
  { id: 'V008', plate: '29H-55555', type: 'Xe bồn', brand: 'Dongfeng', model: 'DFL1250', year: 2019, capacity: 12, status: 'running', gpsStatus: 'online', currentDriverId: 'D005', currentDriverName: 'Hoàng Văn Em', currentSpeed: 48, lat: 21.0420, lng: 105.8680, lastUpdated: minutesAgo(1), registrationExpiry: '2026-08-12', insuranceExpiry: '2026-10-20', totalTrips: 445, totalKm: 115000, totalAlerts: 18, nextMaintenanceKm: 600 },
  { id: 'V009', plate: '30K-66666', type: 'Xe tải', brand: 'Mitsubishi', model: 'Canter', year: 2022, capacity: 3, status: 'offline', gpsStatus: 'offline', currentDriverId: 'D006', currentDriverName: 'Vũ Văn Giang', currentSpeed: 0, lat: 21.0100, lng: 105.8400, lastUpdated: minutesAgo(45), registrationExpiry: '2027-11-05', insuranceExpiry: '2027-09-15', totalTrips: 267, totalKm: 32000, totalAlerts: 7, nextMaintenanceKm: 1800 },
  { id: 'V010', plate: '30L-77777', type: 'Xe van', brand: 'Mercedes', model: 'Sprinter', year: 2023, capacity: 2, status: 'running', gpsStatus: 'online', currentDriverId: 'D007', currentDriverName: 'Ngô Văn Hải', currentSpeed: 38, lat: 21.0600, lng: 105.8100, lastUpdated: minutesAgo(2), registrationExpiry: '2028-04-20', insuranceExpiry: '2028-02-10', totalTrips: 156, totalKm: 18500, totalAlerts: 4, nextMaintenanceKm: 3200 },
  { id: 'V011', plate: '30M-99999', type: 'Xe tải', brand: 'Hino', model: 'XZU', year: 2021, capacity: 4, status: 'running', gpsStatus: 'online', currentDriverId: 'D008', currentDriverName: 'Đỗ Văn Ích', currentSpeed: 52, lat: 21.0330, lng: 105.8900, lastUpdated: minutesAgo(1), registrationExpiry: '2027-06-15', insuranceExpiry: '2027-05-20', totalTrips: 389, totalKm: 52000, totalAlerts: 11, nextMaintenanceKm: 900 },
  { id: 'V012', plate: '30N-10101', type: 'Xe khách', brand: 'Thaco', model: 'TB85S', year: 2022, capacity: 34, status: 'idle', gpsStatus: 'online', currentDriverId: undefined, currentDriverName: undefined, currentSpeed: 0, lat: 21.0150, lng: 105.7600, lastUpdated: minutesAgo(15), registrationExpiry: '2027-10-30', insuranceExpiry: '2027-12-25', totalTrips: 445, totalKm: 67800, totalAlerts: 9, nextMaintenanceKm: 1600 },
  { id: 'V013', plate: '29P-20202', type: 'Xe container', brand: 'Isuzu', model: 'FVM34W', year: 2020, capacity: 18, status: 'running', gpsStatus: 'online', currentDriverId: 'D009', currentDriverName: 'Bùi Văn Khôi', currentSpeed: 58, lat: 21.0680, lng: 105.7500, lastUpdated: minutesAgo(2), registrationExpiry: '2026-07-20', insuranceExpiry: '2026-09-10', totalTrips: 189, totalKm: 102000, totalAlerts: 25, nextMaintenanceKm: 200 },
  { id: 'V014', plate: '30Q-30303', type: 'Xe tải', brand: 'Hyundai', model: 'EX8', year: 2023, capacity: 7.5, status: 'running', gpsStatus: 'weak', currentDriverId: 'D010', currentDriverName: 'Lý Văn Long', currentSpeed: 45, lat: 21.0450, lng: 105.8350, lastUpdated: minutesAgo(5), registrationExpiry: '2028-02-14', insuranceExpiry: '2028-01-10', totalTrips: 98, totalKm: 12400, totalAlerts: 2, nextMaintenanceKm: 5000 },
  { id: 'V015', plate: '30R-40404', type: 'Xe van', brand: 'Toyota', model: 'HiAce', year: 2022, capacity: 1, status: 'idle', gpsStatus: 'online', currentDriverId: undefined, currentDriverName: undefined, currentSpeed: 0, lat: 21.0220, lng: 105.8600, lastUpdated: minutesAgo(8), registrationExpiry: '2027-08-08', insuranceExpiry: '2027-07-15', totalTrips: 312, totalKm: 28500, totalAlerts: 6, nextMaintenanceKm: 2800 },
  { id: 'V016', plate: '30S-50505', type: 'Xe tải', brand: 'Isuzu', model: 'NMR85H', year: 2021, capacity: 1.9, status: 'running', gpsStatus: 'online', currentDriverId: 'D011', currentDriverName: 'Trịnh Văn Minh', currentSpeed: 40, lat: 21.0380, lng: 105.7950, lastUpdated: minutesAgo(1), registrationExpiry: '2027-04-25', insuranceExpiry: '2027-03-30', totalTrips: 478, totalKm: 55000, totalAlerts: 14, nextMaintenanceKm: 700 },
  { id: 'V017', plate: '29T-60606', type: 'Xe bồn', brand: 'Dongfeng', model: 'DFL1160', year: 2020, capacity: 8, status: 'offline', gpsStatus: 'offline', currentDriverId: undefined, currentDriverName: undefined, currentSpeed: 0, lat: 21.0050, lng: 105.8500, lastUpdated: minutesAgo(120), registrationExpiry: '2026-11-15', insuranceExpiry: '2027-01-20', totalTrips: 356, totalKm: 88000, totalAlerts: 20, nextMaintenanceKm: 450 },
  { id: 'V018', plate: '30U-70707', type: 'Xe tải', brand: 'Hino', model: 'FC9J', year: 2022, capacity: 6, status: 'running', gpsStatus: 'online', currentDriverId: 'D012', currentDriverName: 'Phan Văn Nam', currentSpeed: 50, lat: 21.0560, lng: 105.8250, lastUpdated: minutesAgo(1), registrationExpiry: '2027-09-10', insuranceExpiry: '2027-08-05', totalTrips: 234, totalKm: 36700, totalAlerts: 9, nextMaintenanceKm: 1400 },
  { id: 'V019', plate: '30V-80808', type: 'Xe khách', brand: 'Thaco', model: 'MEADOW', year: 2023, capacity: 16, status: 'running', gpsStatus: 'online', currentDriverId: 'D013', currentDriverName: 'Cao Văn Oanh', currentSpeed: 47, lat: 21.0300, lng: 105.8100, lastUpdated: minutesAgo(2), registrationExpiry: '2028-05-20', insuranceExpiry: '2028-04-10', totalTrips: 167, totalKm: 22300, totalAlerts: 5, nextMaintenanceKm: 3500 },
  { id: 'V020', plate: '30X-90909', type: 'Xe tải', brand: 'Mitsubishi', model: 'FE71', year: 2021, capacity: 2.5, status: 'idle', gpsStatus: 'online', currentDriverId: undefined, currentDriverName: undefined, currentSpeed: 0, lat: 21.0190, lng: 105.7900, lastUpdated: minutesAgo(12), registrationExpiry: '2027-07-30', insuranceExpiry: '2027-06-15', totalTrips: 290, totalKm: 34500, totalAlerts: 7, nextMaintenanceKm: 2100 },
];

// ===================================================================
// MOCK DRIVERS — 15 tài xế
// ===================================================================
export const mockDrivers: Driver[] = [
  { id: 'D001', fullName: 'Nguyễn Văn An', phone: '0901234567', email: 'an.nguyen@safefleet.vn', licenseClass: 'C', licenseExpiry: '2028-05-15', status: 'driving', currentVehicleId: 'V001', currentVehiclePlate: '30A-12345', safetyScore: 92, drivingTimeToday: 160, totalTrips: 342, totalKm: 45200, totalDrivingHours: 1520, sleepAlerts: 1, phoneAlerts: 2, speedAlerts: 3, overtimeAlerts: 0, incidents: 0, joinDate: '2022-03-15' },
  { id: 'D002', fullName: 'Trần Văn Bình', phone: '0912345678', email: 'binh.tran@safefleet.vn', licenseClass: 'D', licenseExpiry: '2027-11-20', status: 'driving', currentVehicleId: 'V002', currentVehiclePlate: '30B-67890', safetyScore: 78, drivingTimeToday: 230, totalTrips: 520, totalKm: 82100, totalDrivingHours: 2800, sleepAlerts: 5, phoneAlerts: 8, speedAlerts: 12, overtimeAlerts: 3, incidents: 1, joinDate: '2021-06-10' },
  { id: 'D003', fullName: 'Lê Văn Cường', phone: '0923456789', email: 'cuong.le@safefleet.vn', licenseClass: 'C', licenseExpiry: '2028-02-28', status: 'driving', currentVehicleId: 'V004', currentVehiclePlate: '30D-11111', safetyScore: 85, drivingTimeToday: 95, totalTrips: 415, totalKm: 38700, totalDrivingHours: 1650, sleepAlerts: 2, phoneAlerts: 3, speedAlerts: 5, overtimeAlerts: 1, incidents: 0, joinDate: '2022-01-05' },
  { id: 'D004', fullName: 'Phạm Văn Đức', phone: '0934567890', email: 'duc.pham@safefleet.vn', licenseClass: 'FC', licenseExpiry: '2027-08-10', status: 'driving', currentVehicleId: 'V005', currentVehiclePlate: '30E-22222', safetyScore: 55, drivingTimeToday: 230, totalTrips: 210, totalKm: 98500, totalDrivingHours: 3200, sleepAlerts: 12, phoneAlerts: 15, speedAlerts: 20, overtimeAlerts: 8, incidents: 3, joinDate: '2020-09-20' },
  { id: 'D005', fullName: 'Hoàng Văn Em', phone: '0945678901', email: 'em.hoang@safefleet.vn', licenseClass: 'C', licenseExpiry: '2028-01-15', status: 'driving', currentVehicleId: 'V008', currentVehiclePlate: '29H-55555', safetyScore: 88, drivingTimeToday: 120, totalTrips: 445, totalKm: 115000, totalDrivingHours: 4100, sleepAlerts: 3, phoneAlerts: 4, speedAlerts: 6, overtimeAlerts: 2, incidents: 0, joinDate: '2019-11-01' },
  { id: 'D006', fullName: 'Vũ Văn Giang', phone: '0956789012', email: 'giang.vu@safefleet.vn', licenseClass: 'B2', licenseExpiry: '2027-04-20', status: 'available', currentVehicleId: undefined, currentVehiclePlate: undefined, safetyScore: 70, drivingTimeToday: 0, totalTrips: 267, totalKm: 32000, totalDrivingHours: 1100, sleepAlerts: 4, phoneAlerts: 6, speedAlerts: 8, overtimeAlerts: 2, incidents: 1, joinDate: '2021-08-15' },
  { id: 'D007', fullName: 'Ngô Văn Hải', phone: '0967890123', email: 'hai.ngo@safefleet.vn', licenseClass: 'C', licenseExpiry: '2028-06-30', status: 'driving', currentVehicleId: 'V010', currentVehiclePlate: '30L-77777', safetyScore: 95, drivingTimeToday: 80, totalTrips: 156, totalKm: 18500, totalDrivingHours: 720, sleepAlerts: 0, phoneAlerts: 1, speedAlerts: 1, overtimeAlerts: 0, incidents: 0, joinDate: '2023-02-01' },
  { id: 'D008', fullName: 'Đỗ Văn Ích', phone: '0978901234', email: 'ich.do@safefleet.vn', licenseClass: 'C', licenseExpiry: '2027-10-10', status: 'driving', currentVehicleId: 'V011', currentVehiclePlate: '30M-99999', safetyScore: 82, drivingTimeToday: 145, totalTrips: 389, totalKm: 52000, totalDrivingHours: 2000, sleepAlerts: 3, phoneAlerts: 5, speedAlerts: 7, overtimeAlerts: 1, incidents: 0, joinDate: '2021-12-20' },
  { id: 'D009', fullName: 'Bùi Văn Khôi', phone: '0989012345', email: 'khoi.bui@safefleet.vn', licenseClass: 'FC', licenseExpiry: '2026-12-05', status: 'driving', currentVehicleId: 'V013', currentVehiclePlate: '29P-20202', safetyScore: 62, drivingTimeToday: 200, totalTrips: 189, totalKm: 102000, totalDrivingHours: 3500, sleepAlerts: 8, phoneAlerts: 10, speedAlerts: 15, overtimeAlerts: 5, incidents: 2, joinDate: '2020-04-10' },
  { id: 'D010', fullName: 'Lý Văn Long', phone: '0990123456', email: 'long.ly@safefleet.vn', licenseClass: 'C', licenseExpiry: '2028-03-22', status: 'driving', currentVehicleId: 'V014', currentVehiclePlate: '30Q-30303', safetyScore: 90, drivingTimeToday: 110, totalTrips: 98, totalKm: 12400, totalDrivingHours: 450, sleepAlerts: 0, phoneAlerts: 1, speedAlerts: 2, overtimeAlerts: 0, incidents: 0, joinDate: '2023-05-15' },
  { id: 'D011', fullName: 'Trịnh Văn Minh', phone: '0901112233', email: 'minh.trinh@safefleet.vn', licenseClass: 'C', licenseExpiry: '2027-07-18', status: 'driving', currentVehicleId: 'V016', currentVehiclePlate: '30S-50505', safetyScore: 75, drivingTimeToday: 170, totalTrips: 478, totalKm: 55000, totalDrivingHours: 2200, sleepAlerts: 4, phoneAlerts: 6, speedAlerts: 9, overtimeAlerts: 2, incidents: 1, joinDate: '2021-03-01' },
  { id: 'D012', fullName: 'Phan Văn Nam', phone: '0912223344', email: 'nam.phan@safefleet.vn', licenseClass: 'C', licenseExpiry: '2027-09-25', status: 'driving', currentVehicleId: 'V018', currentVehiclePlate: '30U-70707', safetyScore: 87, drivingTimeToday: 90, totalTrips: 234, totalKm: 36700, totalDrivingHours: 1400, sleepAlerts: 2, phoneAlerts: 3, speedAlerts: 4, overtimeAlerts: 0, incidents: 0, joinDate: '2022-07-10' },
  { id: 'D013', fullName: 'Cao Văn Oanh', phone: '0923334455', email: 'oanh.cao@safefleet.vn', licenseClass: 'D', licenseExpiry: '2028-08-12', status: 'driving', currentVehicleId: 'V019', currentVehiclePlate: '30V-80808', safetyScore: 91, drivingTimeToday: 65, totalTrips: 167, totalKm: 22300, totalDrivingHours: 850, sleepAlerts: 1, phoneAlerts: 0, speedAlerts: 2, overtimeAlerts: 0, incidents: 0, joinDate: '2023-01-15' },
  { id: 'D014', fullName: 'Đinh Văn Phong', phone: '0934445566', email: 'phong.dinh@safefleet.vn', licenseClass: 'B2', licenseExpiry: '2027-05-30', status: 'resting', currentVehicleId: undefined, currentVehiclePlate: undefined, safetyScore: 68, drivingTimeToday: 0, totalTrips: 345, totalKm: 41000, totalDrivingHours: 1650, sleepAlerts: 6, phoneAlerts: 8, speedAlerts: 10, overtimeAlerts: 4, incidents: 1, joinDate: '2021-10-05' },
  { id: 'D015', fullName: 'Mai Văn Quân', phone: '0945556677', email: 'quan.mai@safefleet.vn', licenseClass: 'C', licenseExpiry: '2026-09-15', status: 'available', currentVehicleId: undefined, currentVehiclePlate: undefined, safetyScore: 83, drivingTimeToday: 0, totalTrips: 290, totalKm: 34500, totalDrivingHours: 1300, sleepAlerts: 2, phoneAlerts: 3, speedAlerts: 5, overtimeAlerts: 1, incidents: 0, joinDate: '2022-04-20' },
];

// ===================================================================
// MOCK TRIPS — 10 chuyến, tuyến nội thành Hà Nội
// ===================================================================
export const mockTrips: Trip[] = [
  { id: 'T001', code: 'SF-2026-0001', type: 'delivery', vehicleId: 'V001', vehiclePlate: '30A-12345', driverId: 'D001', driverName: 'Nguyễn Văn An', origin: 'Kho hàng Mỹ Đình', destination: 'Siêu thị Hà Đông', waypoints: ['Nguyễn Trãi', 'Quang Trung'], scheduledStart: '2026-07-08T06:00:00', scheduledEnd: '2026-07-08T09:00:00', actualStart: '2026-07-08T06:15:00', eta: '2026-07-08T08:45:00', progress: 65, status: 'in_progress', riskLevel: 'low', totalKm: 18, notes: 'Hàng điện tử' },
  { id: 'T002', code: 'SF-2026-0002', type: 'passenger', vehicleId: 'V002', vehiclePlate: '30B-67890', driverId: 'D002', driverName: 'Trần Văn Bình', origin: 'Bến xe Mỹ Đình', destination: 'Cầu Giấy', waypoints: [], scheduledStart: '2026-07-08T07:00:00', scheduledEnd: '2026-07-08T08:30:00', actualStart: '2026-07-08T07:05:00', eta: '2026-07-08T08:20:00', progress: 80, status: 'in_progress', riskLevel: 'medium', totalKm: 12 },
  { id: 'T003', code: 'SF-2026-0003', type: 'delivery', vehicleId: 'V004', vehiclePlate: '30D-11111', driverId: 'D003', driverName: 'Lê Văn Cường', origin: 'Phú Diễn', destination: 'Kiều Mai', waypoints: ['Hồ Tùng Mậu'], scheduledStart: '2026-07-08T08:00:00', scheduledEnd: '2026-07-08T10:00:00', actualStart: '2026-07-08T08:10:00', eta: '2026-07-08T09:50:00', progress: 40, status: 'in_progress', riskLevel: 'low', totalKm: 8 },
  { id: 'T004', code: 'SF-2026-0004', type: 'delivery', vehicleId: 'V005', vehiclePlate: '30E-22222', driverId: 'D004', driverName: 'Phạm Văn Đức', origin: 'Đại lộ Thăng Long', destination: 'Hồ Tùng Mậu', waypoints: ['Phạm Văn Đồng'], scheduledStart: '2026-07-08T05:30:00', scheduledEnd: '2026-07-08T09:00:00', actualStart: '2026-07-08T05:40:00', eta: '2026-07-08T09:15:00', progress: 70, status: 'in_progress', riskLevel: 'high', totalKm: 25, notes: 'Container hàng nặng' },
  { id: 'T005', code: 'SF-2026-0005', type: 'transfer', vehicleId: 'V008', vehiclePlate: '29H-55555', driverId: 'D005', driverName: 'Hoàng Văn Em', origin: 'Cầu Giấy', destination: 'Phạm Văn Đồng', waypoints: [], scheduledStart: '2026-07-08T09:00:00', scheduledEnd: '2026-07-08T11:00:00', actualStart: '2026-07-08T09:05:00', eta: '2026-07-08T10:45:00', progress: 30, status: 'in_progress', riskLevel: 'low', totalKm: 10 },
  { id: 'T006', code: 'SF-2026-0006', type: 'delivery', vehicleId: 'V010', vehiclePlate: '30L-77777', driverId: 'D007', driverName: 'Ngô Văn Hải', origin: 'Hà Đông', destination: 'Mỹ Đình', waypoints: ['Nguyễn Trãi'], scheduledStart: '2026-07-08T10:00:00', scheduledEnd: '2026-07-08T12:00:00', progress: 0, status: 'pending', riskLevel: 'low', totalKm: 15 },
  { id: 'T007', code: 'SF-2026-0007', type: 'delivery', vehicleId: 'V011', vehiclePlate: '30M-99999', driverId: 'D008', driverName: 'Đỗ Văn Ích', origin: 'Kiều Mai', destination: 'Cầu Giấy', waypoints: [], scheduledStart: '2026-07-08T06:30:00', scheduledEnd: '2026-07-08T08:00:00', actualStart: '2026-07-08T06:35:00', actualEnd: '2026-07-08T07:50:00', progress: 100, status: 'completed', riskLevel: 'low', totalKm: 7 },
  { id: 'T008', code: 'SF-2026-0008', type: 'passenger', vehicleId: 'V019', vehiclePlate: '30V-80808', driverId: 'D013', driverName: 'Cao Văn Oanh', origin: 'Phạm Văn Đồng', destination: 'Hà Đông', waypoints: ['Cầu Giấy', 'Nguyễn Trãi'], scheduledStart: '2026-07-08T07:30:00', scheduledEnd: '2026-07-08T10:00:00', actualStart: '2026-07-08T07:35:00', eta: '2026-07-08T09:50:00', progress: 55, status: 'in_progress', riskLevel: 'low', totalKm: 20 },
  { id: 'T009', code: 'SF-2026-0009', type: 'delivery', vehicleId: 'V013', vehiclePlate: '29P-20202', driverId: 'D009', driverName: 'Bùi Văn Khôi', origin: 'Đại lộ Thăng Long', destination: 'Phú Diễn', waypoints: [], scheduledStart: '2026-07-08T05:00:00', scheduledEnd: '2026-07-08T08:00:00', actualStart: '2026-07-08T05:10:00', eta: '2026-07-08T08:30:00', progress: 85, status: 'in_progress', riskLevel: 'high', totalKm: 22, notes: 'Container quá tải trọng' },
  { id: 'T010', code: 'SF-2026-0010', type: 'return', vehicleId: 'V016', vehiclePlate: '30S-50505', driverId: 'D011', driverName: 'Trịnh Văn Minh', origin: 'Mỹ Đình', destination: 'Hà Đông', waypoints: [], scheduledStart: '2026-07-08T11:00:00', scheduledEnd: '2026-07-08T13:00:00', progress: 0, status: 'pending', riskLevel: 'low', totalKm: 14 },
];

// ===================================================================
// MOCK ALERTS — 15 cảnh báo AI
// ===================================================================
export const mockAlerts: Alert[] = [
  { id: 'A001', type: 'drowsy', severity: 'critical', vehicleId: 'V005', vehiclePlate: '30E-22222', driverId: 'D004', driverName: 'Phạm Văn Đức', message: 'Ngủ gật lặp lại 3 lần trong 5 phút', timestamp: minutesAgo(2), lat: 21.0540, lng: 105.7160, speed: 60, drivingTime: 230, repeatCount: 3, status: 'new' },
  { id: 'A002', type: 'overtime', severity: 'high', vehicleId: 'V002', vehiclePlate: '30B-67890', driverId: 'D002', driverName: 'Trần Văn Bình', message: 'Đã lái 3h50m liên tục', timestamp: minutesAgo(5), lat: 21.0070, lng: 105.8200, speed: 55, drivingTime: 230, status: 'new' },
  { id: 'A003', type: 'phone_usage', severity: 'high', vehicleId: 'V011', vehiclePlate: '30M-99999', driverId: 'D008', driverName: 'Đỗ Văn Ích', message: 'Sử dụng điện thoại khi lái xe', timestamp: minutesAgo(8), lat: 21.0330, lng: 105.8900, speed: 52, drivingTime: 145, status: 'acknowledged', handledBy: 'Điều phối viên Minh' },
  { id: 'A004', type: 'speeding', severity: 'medium', vehicleId: 'V013', vehiclePlate: '29P-20202', driverId: 'D009', driverName: 'Bùi Văn Khôi', message: 'Vượt tốc độ 80km/h trong khu vực giới hạn 60km/h', timestamp: minutesAgo(12), lat: 21.0680, lng: 105.7500, speed: 82, status: 'acknowledged' },
  { id: 'A005', type: 'near_flood', severity: 'medium', vehicleId: 'V004', vehiclePlate: '30D-11111', driverId: 'D003', driverName: 'Lê Văn Cường', message: 'Sắp đi vào điểm ngập nặng Nguyễn Trãi', timestamp: minutesAgo(15), lat: 21.0050, lng: 105.8030, status: 'new' },
  { id: 'A006', type: 'distraction', severity: 'medium', vehicleId: 'V018', vehiclePlate: '30U-70707', driverId: 'D012', driverName: 'Phan Văn Nam', message: 'Mất tập trung liên tục 30 giây', timestamp: minutesAgo(18), lat: 21.0560, lng: 105.8250, speed: 50, status: 'resolved', handledBy: 'Hệ thống', handledAt: minutesAgo(15) },
  { id: 'A007', type: 'connection_lost', severity: 'low', vehicleId: 'V009', vehiclePlate: '30K-66666', driverId: 'D006', driverName: 'Vũ Văn Giang', message: 'Mất kết nối GPS 45 phút', timestamp: minutesAgo(45), lat: 21.0100, lng: 105.8400, status: 'new' },
  { id: 'A008', type: 'route_deviation', severity: 'medium', vehicleId: 'V014', vehiclePlate: '30Q-30303', driverId: 'D010', driverName: 'Lý Văn Long', message: 'Lệch tuyến đường đã lập kế hoạch 2.5km', timestamp: minutesAgo(20), lat: 21.0450, lng: 105.8350, speed: 45, status: 'new' },
  { id: 'A009', type: 'drowsy', severity: 'high', vehicleId: 'V016', vehiclePlate: '30S-50505', driverId: 'D011', driverName: 'Trịnh Văn Minh', message: 'Phát hiện dấu hiệu ngủ gật', timestamp: minutesAgo(25), lat: 21.0380, lng: 105.7950, speed: 40, drivingTime: 170, status: 'acknowledged' },
  { id: 'A010', type: 'abnormal_stop', severity: 'low', vehicleId: 'V019', vehiclePlate: '30V-80808', driverId: 'D013', driverName: 'Cao Văn Oanh', message: 'Dừng bất thường tại vị trí không phải điểm dừng', timestamp: minutesAgo(30), lat: 21.0300, lng: 105.8100, status: 'resolved', handledBy: 'Cao Văn Oanh', handledAt: minutesAgo(28) },
  { id: 'A011', type: 'phone_usage', severity: 'medium', vehicleId: 'V001', vehiclePlate: '30A-12345', driverId: 'D001', driverName: 'Nguyễn Văn An', message: 'Nhắn tin khi dừng đèn đỏ', timestamp: minutesAgo(35), lat: 21.0285, lng: 105.8542, speed: 0, status: 'resolved', handledBy: 'Hệ thống', handledAt: minutesAgo(33) },
  { id: 'A012', type: 'speeding', severity: 'high', vehicleId: 'V005', vehiclePlate: '30E-22222', driverId: 'D004', driverName: 'Phạm Văn Đức', message: 'Vượt tốc độ 90km/h trên đường có giới hạn 60km/h', timestamp: minutesAgo(40), lat: 21.0600, lng: 105.7200, speed: 92, status: 'acknowledged' },
  { id: 'A013', type: 'overtime', severity: 'medium', vehicleId: 'V013', vehiclePlate: '29P-20202', driverId: 'D009', driverName: 'Bùi Văn Khôi', message: 'Đã lái 3h20m liên tục', timestamp: minutesAgo(50), lat: 21.0700, lng: 105.7450, drivingTime: 200, status: 'new' },
  { id: 'A014', type: 'near_flood', severity: 'high', vehicleId: 'V002', vehiclePlate: '30B-67890', driverId: 'D002', driverName: 'Trần Văn Bình', message: 'Đang tiến gần điểm ngập vừa tại Phạm Văn Đồng', timestamp: minutesAgo(55), lat: 21.0400, lng: 105.7850, status: 'acknowledged' },
  { id: 'A015', type: 'connection_lost', severity: 'low', vehicleId: 'V017', vehiclePlate: '29T-60606', driverId: undefined as unknown as string, driverName: 'Không xác định', message: 'Mất kết nối GPS 2 giờ', timestamp: minutesAgo(120), lat: 21.0050, lng: 105.8500, status: 'new' },
];

// ===================================================================
// MOCK INCIDENTS — 5 sự cố SOS
// ===================================================================
export const mockIncidents: Incident[] = [
  {
    id: 'I001', type: 'sos', vehicleId: 'V005', vehiclePlate: '30E-22222', driverId: 'D004', driverName: 'Phạm Văn Đức',
    location: 'Đại lộ Thăng Long, Km 12', lat: 21.0540, lng: 105.7160, timestamp: minutesAgo(2),
    status: 'open', priority: 'critical', description: 'Tài xế bấm nút SOS, nghi ngờ buồn ngủ gây mất lái',
    timeline: [
      { time: minutesAgo(2), action: 'Tài xế gửi SOS' },
      { time: minutesAgo(2), action: 'Hệ thống ghi nhận vị trí GPS' },
    ],
  },
  {
    id: 'I002', type: 'accident', vehicleId: 'V009', vehiclePlate: '30K-66666', driverId: 'D006', driverName: 'Vũ Văn Giang',
    location: 'Ngã tư Nguyễn Trãi - Khuất Duy Tiến', lat: 21.0000, lng: 105.8020, timestamp: minutesAgo(30),
    status: 'in_progress', priority: 'high', description: 'Va chạm nhẹ với xe máy, không có thương vong',
    timeline: [
      { time: minutesAgo(30), action: 'Phát hiện va chạm qua cảm biến' },
      { time: minutesAgo(28), action: 'Hệ thống tự động tạo sự cố' },
      { time: minutesAgo(25), action: 'Điều phối viên Minh tiếp nhận', actor: 'Điều phối viên Minh' },
      { time: minutesAgo(20), action: 'Đã gọi tài xế - xác nhận an toàn', actor: 'Điều phối viên Minh' },
      { time: minutesAgo(15), action: 'Chuyển đội hỗ trợ khu vực Hà Đông', actor: 'Hệ thống' },
    ],
    assignedTo: 'Điều phối viên Minh',
  },
  {
    id: 'I003', type: 'breakdown', vehicleId: 'V007', vehiclePlate: '30G-44444', driverId: 'D006', driverName: 'Vũ Văn Giang',
    location: 'Phạm Văn Đồng, gần cầu vượt', lat: 21.0450, lng: 105.7900, timestamp: minutesAgo(180),
    status: 'resolved', priority: 'medium', description: 'Hỏng hệ thống phanh, xe được kéo về xưởng',
    timeline: [
      { time: minutesAgo(180), action: 'Tài xế báo hỏng phanh' },
      { time: minutesAgo(175), action: 'Điều phối viên tiếp nhận', actor: 'Điều phối viên An' },
      { time: minutesAgo(170), action: 'Gọi xe cứu hộ' },
      { time: minutesAgo(120), action: 'Xe cứu hộ đến nơi' },
      { time: minutesAgo(90), action: 'Xe được kéo về xưởng bảo trì' },
      { time: minutesAgo(60), action: 'Đóng sự cố', actor: 'Điều phối viên An' },
    ],
    assignedTo: 'Điều phối viên An',
  },
  {
    id: 'I004', type: 'sos', vehicleId: 'V013', vehiclePlate: '29P-20202', driverId: 'D009', driverName: 'Bùi Văn Khôi',
    location: 'Phú Diễn, gần KCN', lat: 21.0600, lng: 105.7450, timestamp: minutesAgo(10),
    status: 'in_progress', priority: 'critical', description: 'SOS tự động kích hoạt do phát hiện dừng đột ngột + quá giờ lái',
    timeline: [
      { time: minutesAgo(10), action: 'SOS tự động kích hoạt' },
      { time: minutesAgo(9), action: 'Hệ thống ghi nhận: dừng đột ngột + lái 3h20m' },
      { time: minutesAgo(7), action: 'Điều phối viên Minh tiếp nhận', actor: 'Điều phối viên Minh' },
      { time: minutesAgo(5), action: 'Đã gọi tài xế - đang nghe máy', actor: 'Điều phối viên Minh' },
    ],
    assignedTo: 'Điều phối viên Minh',
  },
  {
    id: 'I005', type: 'medical', vehicleId: 'V002', vehiclePlate: '30B-67890', driverId: 'D002', driverName: 'Trần Văn Bình',
    location: 'Cầu Giấy, đường Xuân Thủy', lat: 21.0350, lng: 105.7820, timestamp: minutesAgo(60),
    status: 'resolved', priority: 'high', description: 'Tài xế báo đau ngực, đã gọi cấp cứu',
    timeline: [
      { time: minutesAgo(60), action: 'Tài xế bấm SOS + gọi báo đau ngực' },
      { time: minutesAgo(58), action: 'Hệ thống ghi nhận vị trí', },
      { time: minutesAgo(55), action: 'Điều phối viên gọi 115', actor: 'Điều phối viên An' },
      { time: minutesAgo(40), action: 'Xe cấp cứu đến nơi' },
      { time: minutesAgo(30), action: 'Tài xế được đưa đi bệnh viện' },
      { time: minutesAgo(15), action: 'Xe thay thế và tài xế thay thế đã đến', actor: 'Điều phối viên Minh' },
      { time: minutesAgo(10), action: 'Đóng sự cố', actor: 'Điều phối viên An' },
    ],
    assignedTo: 'Điều phối viên An',
  },
];

// ===================================================================
// MOCK FLOOD POINTS — 8 điểm ngập khu vực Hà Nội
// ===================================================================
export const mockFloodPoints: FloodPoint[] = [
  { id: 'F001', location: 'Nguyễn Trãi - Hà Đông', lat: 20.9800, lng: 105.7870, severity: 'heavy', verified: true, reportCount: 5, confidence: 92, lastUpdated: minutesAgo(8), affectedVehicles: 3, affectedRoutes: ['SF-2026-0001', 'SF-2026-0003'], source: '5 tài xế báo cáo' },
  { id: 'F002', location: 'Phạm Văn Đồng - Cầu Giấy', lat: 21.0400, lng: 105.7850, severity: 'moderate', verified: true, reportCount: 3, confidence: 78, lastUpdated: minutesAgo(15), affectedVehicles: 2, affectedRoutes: ['SF-2026-0002'], source: '3 tài xế báo cáo' },
  { id: 'F003', location: 'Hồ Tùng Mậu - Cầu Diễn', lat: 21.0380, lng: 105.7600, severity: 'light', verified: true, reportCount: 2, confidence: 65, lastUpdated: minutesAgo(25), affectedVehicles: 1, affectedRoutes: ['SF-2026-0003'], source: '2 tài xế báo cáo' },
  { id: 'F004', location: 'Đại lộ Thăng Long - Km 8', lat: 21.0250, lng: 105.7300, severity: 'heavy', verified: false, reportCount: 4, confidence: 87, lastUpdated: minutesAgo(10), affectedVehicles: 2, affectedRoutes: ['SF-2026-0004', 'SF-2026-0009'], source: '4 tài xế + cảm biến IoT' },
  { id: 'F005', location: 'Kiều Mai - Phú Diễn', lat: 21.0550, lng: 105.7500, severity: 'moderate', verified: true, reportCount: 3, confidence: 75, lastUpdated: minutesAgo(20), affectedVehicles: 1, affectedRoutes: ['SF-2026-0009'], source: '3 tài xế báo cáo' },
  { id: 'F006', location: 'Ngã tư Khuất Duy Tiến - Nguyễn Trãi', lat: 21.0000, lng: 105.8020, severity: 'impassable', verified: true, reportCount: 8, confidence: 95, lastUpdated: minutesAgo(5), affectedVehicles: 4, affectedRoutes: ['SF-2026-0001', 'SF-2026-0006'], source: '8 tài xế + cảm biến IoT' },
  { id: 'F007', location: 'Phú Diễn - gần KCN', lat: 21.0580, lng: 105.7420, severity: 'light', verified: false, reportCount: 1, confidence: 45, lastUpdated: minutesAgo(35), affectedVehicles: 0, affectedRoutes: [], source: '1 tài xế báo cáo' },
  { id: 'F008', location: 'Mỹ Đình - Đường Lê Đức Thọ', lat: 21.0300, lng: 105.7700, severity: 'moderate', verified: true, reportCount: 3, confidence: 72, lastUpdated: minutesAgo(18), affectedVehicles: 1, affectedRoutes: ['SF-2026-0006'], source: '3 tài xế báo cáo' },
];

// ===================================================================
// MOCK COMMAND CENTER STATS
// ===================================================================
export const mockStats: CommandCenterStats = {
  totalOperating: 12,
  alertsToday: 15,
  openSos: 2,
  driversNearOvertime: 3,
  vehiclesOffline: 2,
  activeFloodPoints: 6,
};
