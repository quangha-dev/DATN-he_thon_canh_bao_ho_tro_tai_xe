package com.safefleet.infrastructure.seed;

import com.safefleet.account.entity.Role;
import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.enums.AccountStatus;
import com.safefleet.account.enums.RoleName;
import com.safefleet.account.repository.RoleRepository;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.device.entity.Device;
import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.device.enums.DeviceType;
import com.safefleet.device.repository.DeviceRepository;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.flood.entity.FloodReport;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.enums.FloodStatus;
import com.safefleet.flood.repository.FloodReportRepository;
import com.safefleet.incident.entity.Incident;
import com.safefleet.incident.enums.IncidentStatus;
import com.safefleet.incident.enums.IncidentType;
import com.safefleet.incident.repository.IncidentRepository;
import com.safefleet.maintenance.entity.MaintenanceOrder;
import com.safefleet.maintenance.enums.MaintenancePriority;
import com.safefleet.maintenance.enums.MaintenanceStatus;
import com.safefleet.maintenance.enums.MaintenanceType;
import com.safefleet.maintenance.repository.MaintenanceOrderRepository;
import com.safefleet.safety.entity.SafetyEvent;
import com.safefleet.safety.enums.AlertSeverity;
import com.safefleet.safety.enums.SafetyEventStatus;
import com.safefleet.safety.enums.SafetyEventType;
import com.safefleet.safety.repository.SafetyEventRepository;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.enums.RiskLevel;
import com.safefleet.trip.enums.TripStatus;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.FuelType;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.enums.VehicleType;
import com.safefleet.vehicle.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Component
@RequiredArgsConstructor
@ConditionalOnProperty(
        prefix = "app.seed",
        name = {"enabled", "hanoi-demo-data-enabled"},
        havingValue = "true"
)
public class DemoDataSeeder implements CommandLineRunner {

    private final RoleRepository roleRepository;
    private final UserAccountRepository userAccountRepository;
    private final DriverRepository driverRepository;
    private final DeviceRepository deviceRepository;
    private final VehicleRepository vehicleRepository;
    private final TripRepository tripRepository;
    private final SafetyEventRepository safetyEventRepository;
    private final IncidentRepository incidentRepository;
    private final FloodReportRepository floodReportRepository;
    private final MaintenanceOrderRepository maintenanceOrderRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    @Transactional
    public void run(String... args) {
        if (userAccountRepository.count() > 0 || vehicleRepository.count() > 0) {
            return;
        }

        UserAccount admin = createUser("admin", "admin@safefleet.vn", "Quan tri he thong", "0901000001", RoleName.ADMIN);
        createUser("manager", "manager@safefleet.vn", "Quan ly doi xe", "0901000002", RoleName.FLEET_MANAGER);
        UserAccount dispatcher = createUser("dispatcher", "dispatcher@safefleet.vn", "Dieu phoi Ha Noi", "0901000003", RoleName.DISPATCHER);
        createUser("safety", "safety@safefleet.vn", "Nhan vien an toan", "0901000004", RoleName.SAFETY_OFFICER);
        UserAccount rescue = createUser("rescue", "rescue@safefleet.vn", "Doi cuu ho", "0901000005", RoleName.RESCUE_TEAM);

        List<Driver> drivers = seedDrivers();
        List<Device> devices = seedDevices();
        List<Vehicle> vehicles = seedVehicles(drivers, devices);
        seedTrips(vehicles, drivers);
        seedSafetyEvents(vehicles, drivers);
        seedIncidents(vehicles, drivers, rescue);
        seedFloodReports(drivers, dispatcher);
        seedMaintenance(vehicles, admin);
    }

    private UserAccount createUser(String username, String email, String fullName, String phone, RoleName roleName) {
        Role role = roleRepository.findByName(roleName)
                .orElseThrow(() -> new IllegalStateException("Missing role " + roleName));
        UserAccount user = new UserAccount();
        user.setUsername(username);
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode("123456"));
        user.setFullName(fullName);
        user.setPhone(phone);
        user.setStatus(AccountStatus.ACTIVE);
        user.setRole(role);
        return userAccountRepository.save(user);
    }

    private List<Driver> seedDrivers() {
        String[] names = {"Nguyen Van An"};
        List<Driver> drivers = new ArrayList<>();
        for (int i = 0; i < names.length; i++) {
            UserAccount user = createUser(
                    "driver%03d".formatted(i + 1),
                    "driver%03d@safefleet.vn".formatted(i + 1),
                    names[i],
                    "0988%06d".formatted(i + 1),
                    RoleName.DRIVER
            );
            Driver driver = new Driver();
            driver.setUser(user);
            driver.setFullName(names[i]);
            driver.setPhone(user.getPhone());
            driver.setEmail(user.getEmail());
            driver.setAddress(List.of("Ha Dong", "Cau Giay", "My Dinh", "Phu Dien", "Ho Tung Mau").get(i % 5));
            driver.setLicenseNumber("%03d".formatted(i + 1));
            driver.setLicenseClass("B2");
            driver.setLicenseExpiredAt(LocalDate.now().plusYears(2).plusMonths(i));
            driver.setStatus(i == 13 ? DriverStatus.HIGH_RISK : DriverStatus.AVAILABLE);
            driver.setSafetyScore(Math.max(45, 96 - i * 3));
            driver.setDrivingTimeTodayMinutes(i * 12);
            driver.setContinuousDrivingMinutes(i % 5 * 30);
            drivers.add(driverRepository.save(driver));
        }
        return drivers;
    }

    private List<Device> seedDevices() {
        List<Device> devices = new ArrayList<>();
        for (int i = 1; i <= 2; i++) {
            Device device = new Device();
            device.setDeviceCode("DEV-%03d".formatted(i));
            device.setName("Thiet bi %03d".formatted(i));
            device.setType(i == 1 ? DeviceType.GPS_TRACKER : DeviceType.CABIN_CAMERA);
            device.setStatus(DeviceStatus.ONLINE);
            device.setSerialNumber("SN-HN-%05d".formatted(i));
            device.setFirmwareVersion("1.0.%d".formatted(i));
            device.setLastSeenAt(i <= 8 ? LocalDateTime.now().minusMinutes(i * 3L) : null);
            devices.add(deviceRepository.save(device));
        }
        return devices;
    }

    private List<Vehicle> seedVehicles(List<Driver> drivers, List<Device> devices) {
        String[] brands = {"Hyundai", "Thaco", "Toyota", "Ford", "Isuzu"};
        String[] models = {"Mighty", "Frontier", "Hiace", "Transit", "NQR"};
        double[][] coords = {
                {20.9719, 105.7788}, {21.0362, 105.7906}, {21.0285, 105.7784}, {20.9902, 105.8057},
                {21.0123, 105.7621}, {21.0521, 105.7353}, {21.0379, 105.7752}, {21.0386, 105.7465},
                {21.0631, 105.8014}, {21.0348, 105.8083}, {20.9842, 105.7954}, {21.0204, 105.7821},
                {21.0465, 105.7649}, {21.0189, 105.8121}, {21.0703, 105.7832}, {20.9977, 105.8321},
                {21.0242, 105.8211}, {21.0567, 105.8123}, {20.9634, 105.7945}, {21.0412, 105.7305}
        };
        List<Vehicle> vehicles = new ArrayList<>();
        for (int i = 0; i < 1; i++) {
            Vehicle vehicle = new Vehicle();
            vehicle.setPlateNumber("%03d".formatted(i + 1));
            vehicle.setVehicleType(i % 3 == 0 ? VehicleType.TRUCK : (i % 3 == 1 ? VehicleType.VAN : VehicleType.BUS));
            vehicle.setBrand(brands[i % brands.length]);
            vehicle.setModel(models[i % models.length]);
            vehicle.setYear(2020 + (i % 5));
            vehicle.setLoadCapacity(BigDecimal.valueOf(1200 + i * 250L));
            vehicle.setSeatCount(vehicle.getVehicleType() == VehicleType.BUS ? 29 : 3);
            vehicle.setFuelType(i % 4 == 0 ? FuelType.ELECTRIC : FuelType.DIESEL);
            vehicle.setStatus(i == 7 ? VehicleStatus.MAINTENANCE : (i == 9 ? VehicleStatus.OFFLINE : VehicleStatus.AVAILABLE));
            vehicle.setInspectionExpiredAt(LocalDate.now().plusMonths(6).plusDays(i));
            vehicle.setInsuranceExpiredAt(LocalDate.now().plusMonths(9).plusDays(i));
            vehicle.setLastLat(coords[i][0]);
            vehicle.setLastLng(coords[i][1]);
            vehicle.setLastSpeed(i % 5 == 0 ? 0.0 : 35.0 + i);
            vehicle.setLastUpdatedAt(LocalDateTime.now().minusMinutes(i * 5L));
            if (i == 0) {
                vehicle.setGpsDevice(devices.get(i));
            }
            if (i == 0) {
                vehicle.setCameraDevice(devices.get(1));
            }
            if (i < drivers.size()) {
                vehicle.setCurrentDriver(drivers.get(i));
            }
            vehicles.add(vehicleRepository.save(vehicle));
        }
        for (int i = 0; i < vehicles.size(); i++) {
            devices.get(i).setVehicle(vehicles.get(i));
        }
        for (int i = 0; i < drivers.size(); i++) {
            drivers.get(i).setCurrentVehicle(vehicles.get(i));
        }
        return vehicles;
    }

    private void seedTrips(List<Vehicle> vehicles, List<Driver> drivers) {
        String[] starts = {"Ha Dong", "Cau Giay", "My Dinh", "Nguyen Trai", "Dai lo Thang Long"};
        String[] ends = {"Kieu Mai", "Phu Dien", "Ho Tung Mau", "Pham Van Dong", "Cau Giay"};
        for (int i = 0; i < 10; i++) {
            Vehicle vehicle = vehicles.get(i % vehicles.size());
            Driver driver = drivers.get(i % drivers.size());
            Trip trip = new Trip();
            trip.setTripCode("DEMO-TRIP-%03d".formatted(i + 1));
            trip.setVehicle(vehicle);
            trip.setDriver(driver);
            trip.setStartLocation(starts[i % starts.length]);
            trip.setEndLocation(ends[i % ends.length]);
            trip.setStartLat(vehicle.getLastLat());
            trip.setStartLng(vehicle.getLastLng());
            trip.setEndLat(21.02 + i * 0.003);
            trip.setEndLng(105.78 + i * 0.004);
            trip.setWaypoints("[]");
            trip.setPlannedRoute("[]");
            trip.setActualRoute("[]");
            trip.setPlannedStartTime(LocalDateTime.now().minusDays(5L - i));
            trip.setEstimatedEndTime(LocalDateTime.now().minusDays(5L - i).plusHours(2));
            trip.setStatus(i < 4 ? TripStatus.COMPLETED : (i < 7 ? TripStatus.IN_PROGRESS : TripStatus.ASSIGNED));
            trip.setProgress(i < 4 ? 100 : (i < 7 ? 45 + i * 5 : 0));
            trip.setRiskLevel(i % 5 == 0 ? RiskLevel.HIGH : RiskLevel.LOW);
            tripRepository.save(trip);
        }
    }

    private void seedSafetyEvents(List<Vehicle> vehicles, List<Driver> drivers) {
        SafetyEventType[] types = SafetyEventType.values();
        AlertSeverity[] severities = AlertSeverity.values();
        for (int i = 0; i < 15; i++) {
            Driver driver = drivers.get(i % drivers.size());
            SafetyEvent event = new SafetyEvent();
            event.setEventType(types[i % types.length]);
            event.setSeverity(severities[i % severities.length]);
            event.setVehicle(vehicles.get(i % vehicles.size()));
            event.setDriver(driver);
            event.setLat(vehicles.get(i % vehicles.size()).getLastLat());
            event.setLng(vehicles.get(i % vehicles.size()).getLastLng());
            event.setSpeed(40.0 + i);
            event.setConfidence(Math.min(0.99, 0.62 + i * 0.02));
            event.setEvidenceUrl("https://demo.safefleet.vn/evidence/%03d.jpg".formatted(i + 1));
            event.setStatus(i % 4 == 0 ? SafetyEventStatus.ACKNOWLEDGED : SafetyEventStatus.NEW);
            event.setNote("Demo AI safety event around Hanoi");
            event.setCreatedAt(LocalDateTime.now().minusHours(i + 1L));
            safetyEventRepository.save(event);
            driver.setTotalAlerts(driver.getTotalAlerts() + 1);
            driver.setSafetyScore(Math.max(30, driver.getSafetyScore() - 2));
        }
    }

    private void seedIncidents(List<Vehicle> vehicles, List<Driver> drivers, UserAccount rescue) {
        IncidentType[] types = {IncidentType.SOS, IncidentType.ACCIDENT, IncidentType.VEHICLE_BREAKDOWN, IncidentType.GPS_LOST, IncidentType.FLOOD_STUCK};
        for (int i = 0; i < 5; i++) {
            Incident incident = new Incident();
            incident.setIncidentCode("INC-DEMO-%03d".formatted(i + 1));
            incident.setType(types[i]);
            incident.setSeverity(i < 2 ? AlertSeverity.CRITICAL : AlertSeverity.HIGH);
            Vehicle vehicle = vehicles.get(i % vehicles.size());
            Driver driver = drivers.get(i % drivers.size());
            incident.setVehicle(vehicle);
            incident.setDriver(driver);
            incident.setLat(vehicle.getLastLat());
            incident.setLng(vehicle.getLastLng());
            incident.setDescription("Demo incident near " + List.of("Ha Dong", "Cau Giay", "My Dinh", "Nguyen Trai", "Pham Van Dong").get(i));
            incident.setStatus(i == 0 ? IncidentStatus.OPEN : IncidentStatus.PROCESSING);
            incident.setAssignedTo(i == 0 ? null : rescue);
            incidentRepository.save(incident);
        }
    }

    private void seedFloodReports(List<Driver> drivers, UserAccount verifier) {
        String[] addresses = {"Ha Dong", "Cau Giay", "My Dinh", "Nguyen Trai", "Dai lo Thang Long", "Kieu Mai", "Phu Dien", "Ho Tung Mau"};
        double[][] coords = {
                {20.9718, 105.7790}, {21.0365, 105.7909}, {21.0281, 105.7782}, {20.9906, 105.8052},
                {21.0121, 105.7625}, {21.0526, 105.7350}, {21.0383, 105.7754}, {21.0390, 105.7462}
        };
        for (int i = 0; i < 8; i++) {
            FloodReport report = new FloodReport();
            report.setLat(coords[i][0]);
            report.setLng(coords[i][1]);
            report.setAddress("[DEMO] " + addresses[i]);
            report.setSeverity(i % 4 == 0 ? FloodSeverity.BLOCKED : (i % 3 == 0 ? FloodSeverity.HIGH : FloodSeverity.MEDIUM));
            report.setSource(FloodSource.MANUAL);
            report.setReportedByDriver(null);
            report.setImageUrl("https://demo.safefleet.vn/flood/%03d.jpg".formatted(i + 1));
            report.setConfidence(0.55 + i * 0.04);
            report.setStatus(i < 4 ? FloodStatus.VERIFIED : FloodStatus.UNVERIFIED);
            report.setVerifiedBy(i < 4 ? verifier : null);
            report.setVerifiedAt(i < 4 ? LocalDateTime.now().minusHours(i) : null);
            report.setExpiredAt(LocalDateTime.now().plusHours(3));
            floodReportRepository.save(report);
        }
    }

    private void seedMaintenance(List<Vehicle> vehicles, UserAccount assignedTo) {
        for (int i = 0; i < 3; i++) {
            MaintenanceOrder order = new MaintenanceOrder();
            order.setMaintenanceCode("MTN-DEMO-%03d".formatted(i + 1));
            order.setVehicle(vehicles.get(i % vehicles.size()));
            order.setType(i == 0 ? MaintenanceType.PERIODIC : MaintenanceType.REPAIR);
            order.setTitle("Bao tri demo " + (i + 1));
            order.setDescription("Kiem tra phanh, lop, den va thiet bi GPS");
            order.setScheduledDate(LocalDate.now().plusDays(i + 1L));
            order.setStatus(MaintenanceStatus.SCHEDULED);
            order.setPriority(i == 2 ? MaintenancePriority.HIGH : MaintenancePriority.MEDIUM);
            order.setAssignedTo(assignedTo);
            order.setCost(BigDecimal.valueOf(1_500_000L + i * 500_000L));
            maintenanceOrderRepository.save(order);
        }
    }
}
