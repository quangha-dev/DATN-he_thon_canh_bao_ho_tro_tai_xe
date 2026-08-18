package com.safefleet;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.safefleet.account.controller.AccountController;
import com.safefleet.account.service.AccountService;
import com.safefleet.auth.controller.AuthController;
import com.safefleet.auth.service.AuthService;
import com.safefleet.common.exception.GlobalExceptionHandler;
import com.safefleet.device.controller.DeviceController;
import com.safefleet.device.service.DeviceService;
import com.safefleet.dispatch.controller.DispatchController;
import com.safefleet.dispatch.service.DispatchService;
import com.safefleet.driver.controller.DriverController;
import com.safefleet.driver.service.DriverService;
import com.safefleet.flood.controller.FloodReportController;
import com.safefleet.flood.service.FloodReportService;
import com.safefleet.incident.controller.IncidentController;
import com.safefleet.incident.service.IncidentService;
import com.safefleet.maintenance.controller.MaintenanceController;
import com.safefleet.maintenance.service.MaintenanceService;
import com.safefleet.notification.controller.NotificationController;
import com.safefleet.notification.service.NotificationService;
import com.safefleet.report.controller.DashboardController;
import com.safefleet.report.controller.ReportController;
import com.safefleet.report.service.DashboardService;
import com.safefleet.report.service.ReportService;
import com.safefleet.safety.controller.DrivingSessionController;
import com.safefleet.safety.controller.SafetyEventController;
import com.safefleet.safety.service.DrivingTimeService;
import com.safefleet.safety.service.SafetyEventService;
import com.safefleet.settings.controller.SystemSettingController;
import com.safefleet.settings.service.SystemSettingService;
import com.safefleet.telemetry.controller.TelemetryController;
import com.safefleet.telemetry.service.TelemetryService;
import com.safefleet.trip.controller.TripController;
import com.safefleet.trip.service.TripService;
import com.safefleet.vehicle.controller.VehicleController;
import com.safefleet.vehicle.service.VehicleService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.web.PageableHandlerMethodArgumentResolver;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.setup.MockMvcBuilders.standaloneSetup;

@ExtendWith(MockitoExtension.class)
class ApiControllerSmokeTest {

    @Mock
    private AuthService authService;

    @Mock
    private AccountService accountService;

    @Mock
    private VehicleService vehicleService;

    @Mock
    private DriverService driverService;

    @Mock
    private TripService tripService;

    @Mock
    private TelemetryService telemetryService;

    @Mock
    private SafetyEventService safetyEventService;

    @Mock
    private DrivingTimeService drivingTimeService;

    @Mock
    private IncidentService incidentService;

    @Mock
    private FloodReportService floodReportService;

    @Mock
    private DeviceService deviceService;

    @Mock
    private MaintenanceService maintenanceService;

    @Mock
    private DashboardService dashboardService;

    @Mock
    private ReportService reportService;

    @Mock
    private NotificationService notificationService;

    @Mock
    private SystemSettingService systemSettingService;

    @Mock
    private DispatchService dispatchService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        ObjectMapper objectMapper = new ObjectMapper()
                .registerModule(new JavaTimeModule())
                .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

        LocalValidatorFactoryBean validator = new LocalValidatorFactoryBean();
        validator.afterPropertiesSet();

        mockMvc = standaloneSetup(
                new AuthController(authService),
                new AccountController(accountService),
                new VehicleController(vehicleService, tripService, safetyEventService),
                new DriverController(driverService, tripService, safetyEventService),
                new TripController(tripService),
                new TelemetryController(telemetryService),
                new SafetyEventController(safetyEventService),
                new DrivingSessionController(drivingTimeService),
                new IncidentController(incidentService),
                new FloodReportController(floodReportService),
                new DeviceController(deviceService),
                new MaintenanceController(maintenanceService),
                new DashboardController(dashboardService),
                new ReportController(reportService),
                new NotificationController(notificationService),
                new SystemSettingController(systemSettingService),
                new DispatchController(dispatchService)
        )
                .setControllerAdvice(new GlobalExceptionHandler())
                .setCustomArgumentResolvers(new PageableHandlerMethodArgumentResolver())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .setValidator(validator)
                .build();
    }

    @Test
    void authApisReturnUnifiedResponse() throws Exception {
        expectOk(json(post("/api/v1/auth/login"), """
                {
                  "usernameOrEmail": "admin",
                  "password": "123456"
                }
                """));

        expectOk(get("/api/v1/auth/me"));
    }

    @Test
    void accountApisReturnUnifiedResponse() throws Exception {
        expectOk(get("/api/v1/accounts").param("keyword", "admin").param("page", "0").param("size", "10"));
        expectOk(get("/api/v1/accounts/{id}", 1));

        expectOk(json(post("/api/v1/accounts"), """
                {
                  "username": "manager01",
                  "email": "manager01@safefleet.vn",
                  "password": "123456",
                  "fullName": "Nguyen Van Quan",
                  "phone": "0901000001",
                  "role": "FLEET_MANAGER"
                }
                """));

        expectOk(json(post("/api/v1/accounts/drivers"), """
                {
                  "username": "driver01",
                  "email": "driver01@safefleet.vn",
                  "password": "123456",
                  "fullName": "Tran Van Tai",
                  "phone": "0902000001",
                  "address": "Ha Dong, Ha Noi",
                  "licenseNumber": "GPLX000001",
                  "licenseClass": "D",
                  "licenseExpiredAt": "2030-12-31"
                }
                """));

        expectOk(json(patch("/api/v1/accounts/{id}/status", 1), """
                {
                  "status": "ACTIVE"
                }
                """));
    }

    @Test
    void vehicleApisReturnUnifiedResponse() throws Exception {
        expectOk(get("/api/v1/vehicles")
                .param("plateNumber", "30A")
                .param("vehicleType", "VAN")
                .param("status", "AVAILABLE")
                .param("gpsOnline", "true"));

        expectOk(json(post("/api/v1/vehicles"), vehicleCreateJson()));
        expectOk(get("/api/v1/vehicles/{id}", 1));
        expectOk(json(put("/api/v1/vehicles/{id}", 1), vehicleUpdateJson()));
        expectOk(delete("/api/v1/vehicles/{id}", 1));
        expectOk(get("/api/v1/vehicles/{id}/realtime-status", 1));
        expectOk(get("/api/v1/vehicles/{id}/trips", 1));
        expectOk(get("/api/v1/vehicles/{id}/safety-events", 1));
        expectOk(get("/api/v1/vehicles/map/positions"));
    }

    @Test
    void driverApisReturnUnifiedResponse() throws Exception {
        expectOk(get("/api/v1/drivers")
                .param("keyword", "Tai")
                .param("status", "AVAILABLE")
                .param("licenseClass", "D")
                .param("minSafetyScore", "80")
                .param("maxSafetyScore", "100"));

        expectOk(json(post("/api/v1/drivers"), driverCreateJson()));
        expectOk(get("/api/v1/drivers/{id}", 1));
        expectOk(json(put("/api/v1/drivers/{id}", 1), driverUpdateJson()));
        expectOk(delete("/api/v1/drivers/{id}", 1));
        expectOk(get("/api/v1/drivers/{id}/driving-time-today", 1));
        expectOk(get("/api/v1/drivers/{id}/trips", 1));
        expectOk(get("/api/v1/drivers/{id}/safety-events", 1));
        expectOk(post("/api/v1/drivers/{id}/recalculate-safety-score", 1));
    }

    @Test
    void tripAndDispatchApisReturnUnifiedResponse() throws Exception {
        expectOk(json(post("/api/v1/trips"), """
                {
                  "vehicleId": 1,
                  "driverId": 1,
                  "startLocation": "Ha Dong",
                  "startLat": 20.9711,
                  "startLng": 105.7788,
                  "endLocation": "My Dinh",
                  "endLat": 21.0315,
                  "endLng": 105.7667,
                  "plannedStartTime": "2031-01-01T08:00:00",
                  "estimatedEndTime": "2031-01-01T10:00:00",
                  "riskLevel": "LOW"
                }
                """));

        expectOk(get("/api/v1/trips")
                .param("status", "ASSIGNED")
                .param("vehicleId", "1")
                .param("driverId", "1")
                .param("fromDate", "2026-07-08")
                .param("toDate", "2026-07-09"));
        expectOk(get("/api/v1/trips/{id}", 1));
        expectOk(json(put("/api/v1/trips/{id}", 1), """
                {
                  "vehicleId": 1,
                  "driverId": 1,
                  "startLocation": "Ha Dong",
                  "startLat": 20.9711,
                  "startLng": 105.7788,
                  "endLocation": "My Dinh",
                  "endLat": 21.0315,
                  "endLng": 105.7667,
                  "plannedStartTime": "2031-01-01T08:00:00",
                  "estimatedEndTime": "2031-01-01T10:00:00",
                  "riskLevel": "LOW"
                }
                """));
        expectOk(json(post("/api/v1/trips/{id}/assign", 1), """
                {
                  "vehicleId": 1,
                  "driverId": 1
                }
                """));
        expectOk(post("/api/v1/trips/{id}/accept", 1));
        expectOk(post("/api/v1/trips/{id}/reject", 1));
        expectOk(post("/api/v1/trips/{id}/start", 1));
        expectOk(post("/api/v1/trips/{id}/pause", 1));
        expectOk(post("/api/v1/trips/{id}/resume", 1));
        expectOk(post("/api/v1/trips/{id}/complete", 1));
        expectOk(json(post("/api/v1/trips/{id}/cancel", 1), """
                {
                  "reason": "Customer changed schedule"
                }
                """));
        expectOk(get("/api/v1/trips/{id}/timeline", 1));
        expectOk(get("/api/v1/dispatch/suggestions").param("startLat", "21.0").param("startLng", "105.8"));
        expectOk(get("/api/v1/dispatch/availability").param("vehicleId", "1").param("driverId", "1"));
    }

    @Test
    void telemetryApisReturnUnifiedResponse() throws Exception {
        expectOk(json(post("/api/v1/telemetry"), """
                {
                  "vehicleId": 1,
                  "driverId": 1,
                  "tripId": 1,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "speed": 45.5,
                  "heading": 180.0,
                  "batteryLevel": 88,
                  "gpsStatus": "GOOD"
                }
                """));

        expectOk(get("/api/v1/telemetry/vehicles/current"));
        expectOk(get("/api/v1/telemetry/trips/{tripId}/history", 1)
                .param("from", "2026-07-08T08:00:00")
                .param("to", "2026-07-08T09:00:00"));
        expectOk(get("/api/v1/telemetry/trips/{tripId}/replay", 1));
    }

    @Test
    void safetyAndDrivingTimeApisReturnUnifiedResponse() throws Exception {
        expectOk(json(post("/api/v1/safety-events"), """
                {
                  "eventType": "DROWSINESS",
                  "severity": "HIGH",
                  "vehicleId": 1,
                  "driverId": 1,
                  "tripId": 1,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "speed": 42.0,
                  "confidence": 0.91,
                  "note": "AI detected drowsiness"
                }
                """));

        expectOk(get("/api/v1/safety-events")
                .param("eventType", "DROWSINESS")
                .param("severity", "HIGH")
                .param("status", "NEW")
                .param("vehicleId", "1")
                .param("driverId", "1"));
        expectOk(get("/api/v1/safety-events/{id}", 1));
        expectOk(post("/api/v1/safety-events/{id}/acknowledge", 1));
        expectOk(post("/api/v1/safety-events/{id}/resolve", 1));
        expectOk(post("/api/v1/safety-events/{id}/dismiss", 1));
        expectOk(post("/api/v1/safety-events/{id}/create-incident", 1));

        expectOk(json(post("/api/v1/driving-sessions/start"), """
                {
                  "driverId": 1,
                  "vehicleId": 1,
                  "tripId": 1
                }
                """));
        expectOk(post("/api/v1/driving-sessions/{id}/pause", 1));
        expectOk(post("/api/v1/driving-sessions/{id}/resume", 1));
        expectOk(post("/api/v1/driving-sessions/{id}/finish", 1));
        expectOk(get("/api/v1/driving-sessions/drivers/{driverId}/remaining-time", 1));
    }

    @Test
    void incidentApisReturnUnifiedResponse() throws Exception {
        expectOk(json(post("/api/v1/incidents/sos"), """
                {
                  "vehicleId": 1,
                  "driverId": 1,
                  "tripId": 1,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "severity": "CRITICAL",
                  "description": "Driver pressed SOS"
                }
                """));

        expectOk(json(post("/api/v1/incidents"), """
                {
                  "type": "MANUAL",
                  "severity": "HIGH",
                  "vehicleId": 1,
                  "driverId": 1,
                  "tripId": 1,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "description": "Manual incident"
                }
                """));
        expectOk(get("/api/v1/incidents")
                .param("type", "SOS")
                .param("severity", "CRITICAL")
                .param("status", "OPEN")
                .param("vehicleId", "1")
                .param("driverId", "1"));
        expectOk(get("/api/v1/incidents/{id}", 1));
        expectOk(post("/api/v1/incidents/{id}/accept", 1));
        expectOk(json(post("/api/v1/incidents/{id}/assign", 1), """
                {
                  "rescueUserId": 5,
                  "note": "Assign rescue team"
                }
                """));
        expectOk(json(post("/api/v1/incidents/{id}/timeline", 1), timelineJson()));
        expectOk(get("/api/v1/incidents/{id}/timeline", 1));
        expectOk(json(post("/api/v1/incidents/{id}/close", 1), timelineJson()));
    }

    @Test
    void floodApisReturnUnifiedResponse() throws Exception {
        expectOk(json(post("/api/v1/flood-reports"), """
                {
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "address": "Pham Van Dong, Ha Noi",
                  "severity": "HIGH",
                  "source": "DRIVER_REPORT",
                  "reportedByDriverId": 1
                }
                """));

        expectOk(get("/api/v1/flood-reports")
                .param("severity", "HIGH")
                .param("source", "DRIVER_REPORT")
                .param("status", "UNVERIFIED"));
        expectOk(get("/api/v1/flood-reports/map"));
        expectOk(post("/api/v1/flood-reports/{id}/verify", 1));
        expectOk(post("/api/v1/flood-reports/{id}/resolve", 1));
        expectOk(json(post("/api/v1/flood-reports/route-check"), routeCheckJson()));
        expectOk(json(post("/api/v1/flood-reports/route-risk-summary"), routeCheckJson()));
    }

    @Test
    void deviceApisReturnUnifiedResponse() throws Exception {
        expectOk(get("/api/v1/devices")
                .param("type", "GPS_TRACKER")
                .param("status", "ONLINE")
                .param("vehicleId", "1"));
        expectOk(get("/api/v1/devices/{id}", 1));
        expectOk(json(post("/api/v1/devices"), deviceCreateJson()));
        expectOk(json(put("/api/v1/devices/{id}", 1), deviceUpdateJson()));
        expectOk(delete("/api/v1/devices/{id}", 1));
        expectOk(json(post("/api/v1/devices/{id}/assign-vehicle", 1), """
                {
                  "vehicleId": 1
                }
                """));
        expectOk(json(patch("/api/v1/devices/{id}/status", 1), """
                {
                  "status": "ONLINE",
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "note": "Heartbeat"
                }
                """));
        expectOk(get("/api/v1/devices/{id}/connection-logs", 1));
    }

    @Test
    void maintenanceApisReturnUnifiedResponse() throws Exception {
        expectOk(json(post("/api/v1/maintenance-orders"), maintenanceCreateJson()));
        expectOk(get("/api/v1/maintenance-orders")
                .param("vehicleId", "1")
                .param("status", "OPEN")
                .param("from", "2026-07-08")
                .param("to", "2026-07-09"));
        expectOk(get("/api/v1/maintenance-orders/{id}", 1));
        expectOk(json(put("/api/v1/maintenance-orders/{id}", 1), maintenanceUpdateJson()));
        expectOk(delete("/api/v1/maintenance-orders/{id}", 1));
        expectOk(get("/api/v1/maintenance-orders/due-alerts"));
        expectOk(get("/api/v1/maintenance-orders/document-expiry-alerts"));
    }

    @Test
    void notificationReportAndSettingsApisReturnUnifiedResponse() throws Exception {
        expectOk(get("/api/v1/notifications"));
        expectOk(patch("/api/v1/notifications/{id}/read", 1));
        expectOk(patch("/api/v1/notifications/read-all"));

        expectOk(get("/api/v1/dashboard/summary"));
        expectOk(get("/api/v1/reports/vehicles/status"));
        expectOk(get("/api/v1/reports/safety-events/by-type"));
        expectOk(get("/api/v1/reports/trips/by-day")
                .param("from", "2026-07-08")
                .param("to", "2026-07-09"));
        expectOk(get("/api/v1/reports/drivers/high-risk"));
        expectOk(get("/api/v1/reports/drivers/{id}", 1));
        expectOk(get("/api/v1/reports/vehicles/{id}", 1));
        expectOk(get("/api/v1/reports/flood"));
        expectOk(get("/api/v1/reports/incidents"));

        expectOk(get("/api/v1/settings"));
        expectOk(get("/api/v1/settings/{key}", "driving.max_continuous_minutes"));
        expectOk(json(put("/api/v1/settings/{key}", "driving.max_continuous_minutes"), """
                {
                  "group": "DRIVING_TIME",
                  "value": "240",
                  "valueType": "INTEGER",
                  "description": "Maximum continuous driving minutes"
                }
                """));
        expectOk(get("/api/v1/settings/groups/{group}", "DRIVING_TIME"));
    }

    @Test
    void invalidRequestUsesUnifiedErrorResponse() throws Exception {
        mockMvc.perform(json(post("/api/v1/auth/login"), """
                        {
                          "usernameOrEmail": "admin"
                        }
                        """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Dữ liệu không hợp lệ"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    private ResultActions expectOk(MockHttpServletRequestBuilder request) throws Exception {
        return mockMvc.perform(request)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    private MockHttpServletRequestBuilder json(MockHttpServletRequestBuilder request, String content) {
        return request.contentType(MediaType.APPLICATION_JSON).content(content);
    }

    private String vehicleCreateJson() {
        return """
                {
                  "plateNumber": "30A-12345",
                  "vehicleType": "VAN",
                  "brand": "Toyota",
                  "model": "Hiace",
                  "year": 2024,
                  "loadCapacity": 1200,
                  "seatCount": 16,
                  "fuelType": "DIESEL",
                  "status": "AVAILABLE",
                  "inspectionExpiredAt": "2030-01-01",
                  "insuranceExpiredAt": "2030-01-01"
                }
                """;
    }

    private String vehicleUpdateJson() {
        return """
                {
                  "vehicleType": "VAN",
                  "brand": "Toyota",
                  "model": "Hiace",
                  "year": 2024,
                  "loadCapacity": 1200,
                  "seatCount": 16,
                  "fuelType": "DIESEL",
                  "status": "AVAILABLE",
                  "inspectionExpiredAt": "2030-01-01",
                  "insuranceExpiredAt": "2030-01-01"
                }
                """;
    }

    private String driverCreateJson() {
        return """
                {
                  "userId": 1,
                  "fullName": "Tran Van Tai",
                  "phone": "0902000001",
                  "email": "driver01@safefleet.vn",
                  "address": "Ha Dong, Ha Noi",
                  "licenseNumber": "GPLX000001",
                  "licenseClass": "D",
                  "licenseExpiredAt": "2030-12-31",
                  "status": "AVAILABLE",
                  "currentVehicleId": 1
                }
                """;
    }

    private String driverUpdateJson() {
        return """
                {
                  "fullName": "Tran Van Tai",
                  "phone": "0902000001",
                  "email": "driver01@safefleet.vn",
                  "address": "Ha Dong, Ha Noi",
                  "licenseClass": "D",
                  "licenseExpiredAt": "2030-12-31",
                  "status": "AVAILABLE",
                  "currentVehicleId": 1
                }
                """;
    }

    private String timelineJson() {
        return """
                {
                  "action": "NOTE",
                  "note": "Handled by dispatcher"
                }
                """;
    }

    private String routeCheckJson() {
        return """
                {
                  "points": [
                    {
                      "lat": 21.0285,
                      "lng": 105.8542
                    },
                    {
                      "lat": 21.0315,
                      "lng": 105.7667
                    }
                  ]
                }
                """;
    }

    private String deviceCreateJson() {
        return """
                {
                  "deviceCode": "GPS-001",
                  "name": "GPS Tracker 001",
                  "type": "GPS_TRACKER",
                  "status": "ONLINE",
                  "vehicleId": 1,
                  "serialNumber": "SN-GPS-001",
                  "firmwareVersion": "1.0.0"
                }
                """;
    }

    private String deviceUpdateJson() {
        return """
                {
                  "name": "GPS Tracker 001",
                  "type": "GPS_TRACKER",
                  "status": "ONLINE",
                  "vehicleId": 1,
                  "serialNumber": "SN-GPS-001",
                  "firmwareVersion": "1.0.0"
                }
                """;
    }

    private String maintenanceCreateJson() {
        return """
                {
                  "vehicleId": 1,
                  "type": "PERIODIC",
                  "title": "Bao tri dinh ky",
                  "description": "Kiem tra tong quat",
                  "scheduledDate": "2026-07-15",
                  "status": "OPEN",
                  "priority": "MEDIUM",
                  "assignedTo": 1,
                  "note": "Demo maintenance"
                }
                """;
    }

    private String maintenanceUpdateJson() {
        return """
                {
                  "vehicleId": 1,
                  "type": "PERIODIC",
                  "title": "Bao tri dinh ky",
                  "description": "Kiem tra tong quat",
                  "scheduledDate": "2026-07-15",
                  "status": "OPEN",
                  "priority": "MEDIUM",
                  "assignedTo": 1,
                  "note": "Demo maintenance"
                }
                """;
    }
}
