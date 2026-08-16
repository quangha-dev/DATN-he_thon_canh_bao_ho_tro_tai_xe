package com.safefleet;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.safefleet.infrastructure.ai.SafeFleetAiGateway;
import com.safefleet.mobile.enums.AgentIntent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "spring.jpa.hibernate.ddl-auto=validate",
                "spring.flyway.enabled=true",
                "spring.flyway.baseline-on-migrate=false",
                "app.seed.enabled=true",
                "app.seed.hanoi-demo-data-enabled=true",
                "app.jwt.secret=integration-test-secret-at-least-32-characters-long",
                "logging.level.org.springframework=WARN",
                "logging.level.org.hibernate=WARN"
        }
)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@Testcontainers
class RealPostgreSqlApiIntegrationTest {

    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final AtomicInteger SEQUENCE = new AtomicInteger((int) (System.currentTimeMillis() % 1_000_000));

    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:17-alpine")
            .withDatabaseName("safefleet_test")
            .withUsername("safefleet_test")
            .withPassword("safefleet_test");

    @DynamicPropertySource
    static void postgresqlProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("app.location.osrm-url", () -> "http://127.0.0.1:1/route/v1/driving");
        registry.add("app.location.photon-url", () -> "http://127.0.0.1:1/api/");
        registry.add(
                "app.evidence.storage-path",
                () -> System.getProperty("java.io.tmpdir") + "/safefleet-evidence-integration"
        );
    }

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockBean
    private SafeFleetAiGateway aiGateway;

    @BeforeEach
    void stubSafeFleetAiBoundary() {
        when(aiGateway.classify(anyString())).thenAnswer(invocation -> {
            String transcript = invocation.getArgument(0, String.class).toLowerCase();
            if (transcript.contains("ngập")) {
                return new SafeFleetAiGateway.Classification(
                        AgentIntent.REPORT_FLOOD, 0.98, true, "LOCAL_RULE"
                );
            }
            if (transcript.contains("còn được lái")) {
                return new SafeFleetAiGateway.Classification(
                        AgentIntent.GET_DRIVING_TIME, 0.96, false, "LOCAL_RULE"
                );
            }
            return new SafeFleetAiGateway.Classification(
                    AgentIntent.SEND_SOS, 0.99, true, "LOCAL_RULE"
            );
        });
    }

    @Test
    @Order(1)
    void realPostgreSqlBootstrapsFlywaySeedAndJwtAuth() {
        String adminToken = login("admin", "123456");

        ResponseEntity<JsonNode> me = get("/api/v1/auth/me", adminToken);
        assertSuccess(me, HttpStatus.OK);
        assertThat(data(me).path("username").asText()).isEqualTo("admin");

        ResponseEntity<JsonNode> vehicles = get("/api/v1/vehicles?page=0&size=1", adminToken);
        assertSuccess(vehicles, HttpStatus.OK);
        assertThat(data(vehicles).path("totalElements").asLong()).isGreaterThanOrEqualTo(1);

        ResponseEntity<JsonNode> drivers = get("/api/v1/drivers?page=0&size=1", adminToken);
        assertSuccess(drivers, HttpStatus.OK);
        assertThat(data(drivers).path("totalElements").asLong()).isGreaterThanOrEqualTo(1);

        ResponseEntity<JsonNode> accounts = get("/api/v1/accounts?page=0&size=10", adminToken);
        assertSuccess(accounts, HttpStatus.OK);
        assertThat(data(accounts).path("totalElements").asLong()).isGreaterThanOrEqualTo(2);

        ResponseEntity<JsonNode> matchingAccounts = get("/api/v1/accounts?keyword=admin&page=0&size=10", adminToken);
        assertSuccess(matchingAccounts, HttpStatus.OK);
        assertThat(data(matchingAccounts).path("items").isArray()).isTrue();
        assertThat(data(matchingAccounts).path("items").toString()).contains("admin");

        assertSuccess(get("/api/v1/dashboard/summary", adminToken), HttpStatus.OK);
    }

    @Test
    @Order(2)
    void frontendCorsPreflightAndAuthErrorsUseSoftMessages() {
        HttpResponse<String> preflight = preflight("/api/v1/vehicles", "GET");
        assertThat(preflight.statusCode()).isEqualTo(HttpStatus.OK.value());
        assertThat(preflight.headers().firstValue("Access-Control-Allow-Origin")).contains("http://localhost:5173");
        assertThat(preflight.headers().firstValue("Access-Control-Allow-Methods").orElse(""))
                .contains("GET");
        assertThat(preflight.headers().firstValue("Access-Control-Allow-Headers").orElse("").toLowerCase())
                .contains("authorization");

        HttpResponse<String> untrustedLocalPort = preflight(
                "/api/v1/vehicles",
                "GET",
                "http://localhost:63333"
        );
        assertThat(untrustedLocalPort.headers().firstValue("Access-Control-Allow-Origin")).isEmpty();

        ResponseEntity<JsonNode> anonymous = get("/api/v1/vehicles", null);
        assertFailure(anonymous, HttpStatus.UNAUTHORIZED, "Vui lòng đăng nhập");

        ResponseEntity<JsonNode> invalidToken = getWithRawAuthorization("/api/v1/vehicles", "Bearer invalid.jwt.token");
        assertFailure(invalidToken, HttpStatus.UNAUTHORIZED, "Vui lòng đăng nhập");
    }

    @Test
    @Order(3)
    void realCrudTripTelemetryMaintenanceAndDispatchFlowPersistsToPostgreSql() {
        String adminToken = login("admin", "123456");
        FleetFixture fixture = createAvailableFleet(adminToken);

        ResponseEntity<JsonNode> vehicleDetail = get("/api/v1/vehicles/" + fixture.vehicleId(), adminToken);
        assertSuccess(vehicleDetail, HttpStatus.OK);
        assertThat(data(vehicleDetail).path("plateNumber").asText()).isEqualTo(fixture.plateNumber());

        ResponseEntity<JsonNode> vehicleUpdate = put("/api/v1/vehicles/" + fixture.vehicleId(), adminToken, """
                {
                  "vehicleType": "VAN",
                  "brand": "Toyota",
                  "model": "Hiace Updated",
                  "year": 2025,
                  "loadCapacity": 1600,
                  "seatCount": 16,
                  "fuelType": "DIESEL",
                  "status": "AVAILABLE",
                  "currentDriverId": %d,
                  "gpsDeviceId": %d,
                  "inspectionExpiredAt": "2031-01-01",
                  "insuranceExpiredAt": "2031-01-01"
                }
                """.formatted(fixture.driverId(), fixture.gpsDeviceId()));
        assertSuccess(vehicleUpdate, HttpStatus.OK);
        assertThat(data(vehicleUpdate).path("model").asText()).isEqualTo("Hiace Updated");

        ResponseEntity<JsonNode> tripCreate = post("/api/v1/trips", adminToken, """
                {
                  "vehicleId": %d,
                  "driverId": %d,
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
                """.formatted(fixture.vehicleId(), fixture.driverId()));
        assertSuccess(tripCreate, HttpStatus.OK);
        long tripId = data(tripCreate).path("id").asLong();

        assertThat(data(tripCreate).path("status").asText()).isEqualTo("ASSIGNED");

        assertSuccess(post("/api/v1/trips/" + tripId + "/accept", adminToken, null), HttpStatus.OK);
        ResponseEntity<JsonNode> startedTrip = post("/api/v1/trips/" + tripId + "/start", adminToken, null);
        assertSuccess(startedTrip, HttpStatus.OK);
        assertThat(data(startedTrip).path("status").asText()).isEqualTo("IN_PROGRESS");

        ResponseEntity<JsonNode> telemetry = post("/api/v1/telemetry", adminToken, """
                {
                  "vehicleId": %d,
                  "driverId": %d,
                  "tripId": %d,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "speed": 46.5,
                  "heading": 178.0,
                  "batteryLevel": 91,
                  "gpsStatus": "GOOD"
                }
                """.formatted(fixture.vehicleId(), fixture.driverId(), tripId));
        assertSuccess(telemetry, HttpStatus.OK);
        assertThat(data(telemetry).path("lat").asDouble()).isEqualTo(21.0285);

        ResponseEntity<JsonNode> realtime = get("/api/v1/vehicles/" + fixture.vehicleId() + "/realtime-status", adminToken);
        assertSuccess(realtime, HttpStatus.OK);
        assertThat(data(realtime).path("lat").asDouble()).isEqualTo(21.0285);
        assertThat(data(realtime).path("speed").asDouble()).isEqualTo(46.5);

        ResponseEntity<JsonNode> telemetryHistory = get("/api/v1/telemetry/trips/" + tripId + "/history", adminToken);
        assertSuccess(telemetryHistory, HttpStatus.OK);
        assertThat(data(telemetryHistory)).hasSizeGreaterThanOrEqualTo(1);

        assertSuccess(post("/api/v1/trips/" + tripId + "/pause", adminToken, null), HttpStatus.OK);
        assertSuccess(post("/api/v1/trips/" + tripId + "/resume", adminToken, null), HttpStatus.OK);
        ResponseEntity<JsonNode> completedTrip = post("/api/v1/trips/" + tripId + "/complete", adminToken, null);
        assertSuccess(completedTrip, HttpStatus.OK);
        assertThat(data(completedTrip).path("status").asText()).isEqualTo("COMPLETED");
        assertSuccess(get("/api/v1/trips/" + tripId + "/timeline", adminToken), HttpStatus.OK);

        ResponseEntity<JsonNode> availability = get("/api/v1/dispatch/availability?vehicleId="
                + fixture.vehicleId() + "&driverId=" + fixture.driverId(), adminToken);
        assertSuccess(availability, HttpStatus.OK);
        assertThat(data(availability).path("assignable").asBoolean()).isTrue();
        assertSuccess(get("/api/v1/dispatch/suggestions?startLat=21.0&startLng=105.8&limit=5", adminToken), HttpStatus.OK);

        ResponseEntity<JsonNode> deviceStatus = patch("/api/v1/devices/" + fixture.gpsDeviceId() + "/status", adminToken, """
                {
                  "status": "ONLINE",
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "note": "Integration heartbeat"
                }
                """);
        assertSuccess(deviceStatus, HttpStatus.OK);
        ResponseEntity<JsonNode> logs = get("/api/v1/devices/" + fixture.gpsDeviceId() + "/connection-logs", adminToken);
        assertSuccess(logs, HttpStatus.OK);
        assertThat(data(logs).path("totalElements").asLong()).isGreaterThanOrEqualTo(1);

        ResponseEntity<JsonNode> maintenance = post("/api/v1/maintenance-orders", adminToken, """
                {
                  "vehicleId": %d,
                  "type": "PERIODIC",
                  "title": "Bao tri integration",
                  "description": "Kiem tra thiet bi GPS va phanh",
                  "scheduledDate": "2026-07-15",
                  "status": "OPEN",
                  "priority": "MEDIUM",
                  "note": "Created by integration test"
                }
                """.formatted(fixture.vehicleId()));
        assertSuccess(maintenance, HttpStatus.OK);
        long maintenanceId = data(maintenance).path("id").asLong();
        assertSuccess(put("/api/v1/maintenance-orders/" + maintenanceId, adminToken, """
                {
                  "vehicleId": %d,
                  "type": "PERIODIC",
                  "title": "Bao tri integration updated",
                  "description": "Kiem tra cap nhat",
                  "scheduledDate": "2026-07-16",
                  "status": "SCHEDULED",
                  "priority": "HIGH",
                  "note": "Updated by integration test"
                }
                """.formatted(fixture.vehicleId())), HttpStatus.OK);
        assertSuccess(get("/api/v1/maintenance-orders/due-alerts", adminToken), HttpStatus.OK);
        assertSuccess(get("/api/v1/maintenance-orders/document-expiry-alerts", adminToken), HttpStatus.OK);
    }

    @Test
    @Order(4)
    void realSafetyIncidentFloodDrivingSettingsNotificationAndReportFlowPersistsToPostgreSql() {
        String adminToken = login("admin", "123456");
        FleetFixture fixture = createAvailableFleet(adminToken);
        long rescueUserId = createStaffUser(adminToken, "RESCUE_TEAM");

        ResponseEntity<JsonNode> safety = post("/api/v1/safety-events", adminToken, """
                {
                  "eventType": "DROWSINESS",
                  "severity": "HIGH",
                  "vehicleId": %d,
                  "driverId": %d,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "speed": 40.0,
                  "confidence": 0.93,
                  "note": "Integration AI alert"
                }
                """.formatted(fixture.vehicleId(), fixture.driverId()));
        assertSuccess(safety, HttpStatus.OK);
        long safetyEventId = data(safety).path("id").asLong();
        assertSuccess(post("/api/v1/safety-events/" + safetyEventId + "/acknowledge", adminToken, """
                {
                  "note": "Dispatcher acknowledged"
                }
                """), HttpStatus.OK);

        ResponseEntity<JsonNode> incidentFromSafety = post("/api/v1/safety-events/" + safetyEventId + "/create-incident", adminToken, null);
        assertSuccess(incidentFromSafety, HttpStatus.OK);
        long incidentId = data(incidentFromSafety).path("id").asLong();
        assertSuccess(post("/api/v1/incidents/" + incidentId + "/timeline", adminToken, """
                {
                  "action": "NOTE",
                  "note": "Rescue team informed"
                }
                """), HttpStatus.OK);

        ResponseEntity<JsonNode> sos = post("/api/v1/incidents/sos", adminToken, """
                {
                  "vehicleId": %d,
                  "driverId": %d,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "severity": "CRITICAL",
                  "description": "Integration SOS"
                }
                """.formatted(fixture.vehicleId(), fixture.driverId()));
        assertSuccess(sos, HttpStatus.OK);
        long sosId = data(sos).path("id").asLong();
        assertSuccess(post("/api/v1/incidents/" + sosId + "/accept", adminToken, null), HttpStatus.OK);
        ResponseEntity<JsonNode> assignedSos = post("/api/v1/incidents/" + sosId + "/assign", adminToken, """
                {
                  "rescueUserId": %d,
                  "note": "Assign integration rescue user"
                }
                """.formatted(rescueUserId));
        assertSuccess(assignedSos, HttpStatus.OK);
        assertThat(data(assignedSos).path("status").asText()).isEqualTo("PROCESSING");
        assertSuccess(post("/api/v1/incidents/" + sosId + "/close", adminToken, """
                {
                  "action": "CLOSED",
                  "note": "Resolved"
                }
                """), HttpStatus.OK);

        ResponseEntity<JsonNode> flood = post("/api/v1/flood-reports", adminToken, """
                {
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "address": "Pham Van Dong",
                  "severity": "HIGH",
                  "source": "DRIVER_REPORT",
                  "reportedByDriverId": %d
                }
                """.formatted(fixture.driverId()));
        assertSuccess(flood, HttpStatus.OK);
        long floodId = data(flood).path("id").asLong();
        assertSuccess(post("/api/v1/flood-reports/" + floodId + "/verify", adminToken, """
                {
                  "note": "Verified by dispatcher"
                }
                """), HttpStatus.OK);
        ResponseEntity<JsonNode> routeRisk = post("/api/v1/flood-reports/route-risk-summary", adminToken, """
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
                """);
        assertSuccess(routeRisk, HttpStatus.OK);
        assertThat(data(routeRisk).path("risky").asBoolean()).isTrue();
        assertSuccess(post("/api/v1/flood-reports/" + floodId + "/resolve", adminToken, null), HttpStatus.OK);

        ResponseEntity<JsonNode> session = post("/api/v1/driving-sessions/start", adminToken, """
                {
                  "driverId": %d,
                  "vehicleId": %d
                }
                """.formatted(fixture.driverId(), fixture.vehicleId()));
        assertSuccess(session, HttpStatus.OK);
        long sessionId = data(session).path("id").asLong();
        assertSuccess(get("/api/v1/driving-sessions/drivers/" + fixture.driverId() + "/remaining-time", adminToken), HttpStatus.OK);
        assertSuccess(post("/api/v1/driving-sessions/" + sessionId + "/pause", adminToken, null), HttpStatus.OK);
        assertSuccess(post("/api/v1/driving-sessions/" + sessionId + "/resume", adminToken, null), HttpStatus.OK);
        assertSuccess(post("/api/v1/driving-sessions/" + sessionId + "/finish", adminToken, null), HttpStatus.OK);

        assertSuccess(get("/api/v1/notifications?page=0&size=10", adminToken), HttpStatus.OK);
        assertSuccess(patch("/api/v1/notifications/read-all", adminToken, null), HttpStatus.OK);

        assertSuccess(get("/api/v1/reports/vehicles/status", adminToken), HttpStatus.OK);
        assertSuccess(get("/api/v1/reports/safety-events/by-type", adminToken), HttpStatus.OK);
        assertSuccess(get("/api/v1/reports/trips/by-day", adminToken), HttpStatus.OK);
        assertSuccess(get("/api/v1/reports/drivers/high-risk", adminToken), HttpStatus.OK);
        assertSuccess(get("/api/v1/reports/flood", adminToken), HttpStatus.OK);
        assertSuccess(get("/api/v1/reports/incidents", adminToken), HttpStatus.OK);

        ResponseEntity<JsonNode> setting = put("/api/v1/settings/driving.max_continuous_minutes", adminToken, """
                {
                  "group": "DRIVING_TIME",
                  "value": "240",
                  "valueType": "INTEGER",
                  "description": "Integration verified value"
                }
                """);
        assertSuccess(setting, HttpStatus.OK);
        assertThat(data(setting).path("value").asText()).isEqualTo("240");
        assertSuccess(get("/api/v1/settings/groups/DRIVING_TIME", adminToken), HttpStatus.OK);
    }

    @Test
    @Order(5)
    void realExceptionCasesReturnExpectedUnifiedErrors() {
        String adminToken = login("admin", "123456");
        String driverToken = login("driver001", "123456");

        ResponseEntity<JsonNode> anonymous = get("/api/v1/vehicles", null);
        assertFailure(anonymous, HttpStatus.UNAUTHORIZED, "Vui lòng đăng nhập");

        ResponseEntity<JsonNode> badLogin = exchangeWithJavaHttpClient(HttpMethod.POST, "/api/v1/auth/login", null, """
                {
                  "usernameOrEmail": "admin",
                  "password": "wrong-password"
                }
                """);
        assertFailure(badLogin, HttpStatus.UNAUTHORIZED, "Tên đăng nhập hoặc mật khẩu không đúng");

        ResponseEntity<JsonNode> validationError = post("/api/v1/auth/login", null, """
                {
                  "usernameOrEmail": "admin"
                }
                """);
        assertFailure(validationError, HttpStatus.BAD_REQUEST, "Dữ liệu không hợp lệ");

        ResponseEntity<JsonNode> malformedJson = postRaw("/api/v1/vehicles", adminToken, "{");
        assertFailure(malformedJson, HttpStatus.BAD_REQUEST, "JSON không hợp lệ");

        ResponseEntity<JsonNode> invalidEnum = get("/api/v1/vehicles?status=NOT_A_STATUS", adminToken);
        assertFailure(invalidEnum, HttpStatus.BAD_REQUEST, "Tham số không hợp lệ: status");

        ResponseEntity<JsonNode> invalidSchedule = post("/api/v1/trips", adminToken, """
                {
                  "startLocation": "My Dinh",
                  "endLocation": "Ha Dong",
                  "plannedStartTime": "2031-01-01T10:00:00",
                  "estimatedEndTime": "2031-01-01T09:00:00"
                }
                """);
        assertFailure(invalidSchedule, HttpStatus.BAD_REQUEST, "Thời gian đến phải sau thời gian đi");

        ResponseEntity<JsonNode> missingSchedule = post("/api/v1/trips", adminToken, """
                {
                  "startLocation": "My Dinh",
                  "endLocation": "Ha Dong"
                }
                """);
        assertThat(missingSchedule.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<JsonNode> missingRequiredParam = get("/api/v1/dispatch/availability?vehicleId=1", adminToken);
        assertFailure(missingRequiredParam, HttpStatus.BAD_REQUEST, "Thiếu tham số: driverId");

        ResponseEntity<JsonNode> notFound = get("/api/v1/vehicles/999999999", adminToken);
        assertFailure(notFound, HttpStatus.NOT_FOUND, "Không tìm thấy phương tiện: 999999999");

        ResponseEntity<JsonNode> accessDenied = get("/api/v1/accounts", driverToken);
        assertFailure(accessDenied, HttpStatus.FORBIDDEN, "Không có quyền truy cập");

        long otherDriverId = createDriverAccount(adminToken).driverId();
        ResponseEntity<JsonNode> forbiddenOwnership = get("/api/v1/drivers/" + otherDriverId, driverToken);
        assertFailure(forbiddenOwnership, HttpStatus.FORBIDDEN, "Tài xế chỉ được xem dữ liệu của chính mình");

        int suffix = SEQUENCE.incrementAndGet();
        String duplicatePlate = "30A-DUP-" + suffix;
        ResponseEntity<JsonNode> vehicle = post("/api/v1/vehicles", adminToken, vehicleJson(duplicatePlate, null, null));
        assertSuccess(vehicle, HttpStatus.OK);
        ResponseEntity<JsonNode> duplicateVehicle = post("/api/v1/vehicles", adminToken, vehicleJson(duplicatePlate, null, null));
        assertFailure(duplicateVehicle, HttpStatus.BAD_REQUEST, "Biển số đã tồn tại");

        ResponseEntity<JsonNode> invalidSettingValue = put("/api/v1/settings/driving.warn_1_minutes", adminToken, """
                {
                  "group": "DRIVING_TIME",
                  "value": "not-a-number",
                  "valueType": "INTEGER",
                  "description": "Invalid integration value"
                }
                """);
        assertFailure(invalidSettingValue, HttpStatus.BAD_REQUEST, "Giá trị cấu hình không hợp lệ");
    }

    @Test
    @Order(6)
    void realMobileDriverFacadeFlowUsesDriverScopeAndPersistsToPostgreSql() {
        String adminToken = login("admin", "123456");
        DriverLogin driver = createDriverAccount(adminToken);
        DriverLogin otherDriver = createDriverAccount(adminToken);
        FleetFixture fixture = createAvailableFleetForDriver(adminToken, driver.driverId());
        FleetFixture otherFixture = createAvailableFleetForDriver(adminToken, otherDriver.driverId());

        String plannedStartTime = LocalDateTime.now().plusHours(1).withNano(0).toString();
        String estimatedEndTime = LocalDateTime.now().plusHours(3).withNano(0).toString();
        ResponseEntity<JsonNode> tripCreate = post("/api/v1/trips", adminToken, """
                {
                  "vehicleId": %d,
                  "driverId": %d,
                  "startLocation": "Ha Dong",
                  "startLat": 20.9711,
                  "startLng": 105.7788,
                  "endLocation": "My Dinh",
                  "endLat": 21.0315,
                  "endLng": 105.7667,
                  "plannedStartTime": "%s",
                  "estimatedEndTime": "%s",
                  "riskLevel": "LOW"
                }
                """.formatted(fixture.vehicleId(), driver.driverId(), plannedStartTime, estimatedEndTime));
        assertSuccess(tripCreate, HttpStatus.OK);
        long tripId = data(tripCreate).path("id").asLong();

        ResponseEntity<JsonNode> tripsWithoutDates = get(
                "/api/v1/mobile/trips?statuses=ASSIGNED&limit=50",
                driver.token()
        );
        assertSuccess(tripsWithoutDates, HttpStatus.OK);
        assertThat(data(tripsWithoutDates).findValue("id").asLong()).isEqualTo(tripId);
        assertSuccess(get(
                "/api/v1/mobile/trips?statuses=ASSIGNED&startDate=2000-01-01&limit=50",
                driver.token()
        ), HttpStatus.OK);
        assertSuccess(get(
                "/api/v1/mobile/trips?statuses=ASSIGNED&endDate=2100-01-01&limit=50",
                driver.token()
        ), HttpStatus.OK);
        assertSuccess(get(
                "/api/v1/mobile/trips?statuses=ASSIGNED&startDate=2000-01-01&endDate=2100-01-01&limit=50",
                driver.token()
        ), HttpStatus.OK);

        ResponseEntity<JsonNode> assignmentNotifications = get(
                "/api/v1/mobile/notifications?page=0&size=10",
                driver.token()
        );
        assertSuccess(assignmentNotifications, HttpStatus.OK);
        boolean assignmentFound = false;
        for (JsonNode item : data(assignmentNotifications).path("items")) {
            if ("TRIP_ASSIGNED".equals(item.path("type").asText())
                    && item.path("referenceId").asLong() == tripId
                    && "Bạn có chuyến mới".equals(item.path("title").asText())) {
                assignmentFound = true;
                break;
            }
        }
        assertThat(assignmentFound).isTrue();

        ResponseEntity<JsonNode> mobileProfile = get("/api/v1/mobile/me", driver.token());
        assertSuccess(mobileProfile, HttpStatus.OK);
        assertThat(data(mobileProfile).path("role").asText()).isEqualTo("DRIVER");
        assertThat(data(mobileProfile).path("driver").path("id").asLong()).isEqualTo(driver.driverId());

        ResponseEntity<JsonNode> adminBlocked = get("/api/v1/mobile/me", adminToken);
        assertFailure(adminBlocked, HttpStatus.FORBIDDEN, "Không có quyền truy cập");

        ResponseEntity<JsonNode> currentAssignment = get("/api/v1/mobile/current-assignment", driver.token());
        assertSuccess(currentAssignment, HttpStatus.OK);
        assertThat(data(currentAssignment).path("trip").path("id").asLong()).isEqualTo(tripId);
        assertThat(data(currentAssignment).path("checklistSubmitted").asBoolean()).isFalse();

        ResponseEntity<JsonNode> todayTrips = get("/api/v1/mobile/trips/today", driver.token());
        assertSuccess(todayTrips, HttpStatus.OK);
        assertThat(data(todayTrips).isArray()).isTrue();
        assertThat(data(todayTrips).findValue("id").asLong()).isEqualTo(tripId);
        assertThat(data(todayTrips).findValue("driverId").asLong()).isEqualTo(driver.driverId());

        ResponseEntity<JsonNode> otherDriverToday = get("/api/v1/mobile/trips/today", otherDriver.token());
        assertSuccess(otherDriverToday, HttpStatus.OK);
        assertThat(data(otherDriverToday).isEmpty()).isTrue();

        assertSuccess(get("/api/v1/mobile/config", driver.token()), HttpStatus.OK);
        ResponseEntity<JsonNode> tripSummary = get("/api/v1/mobile/trips/" + tripId + "/summary", driver.token());
        assertSuccess(tripSummary, HttpStatus.OK);
        assertThat(data(tripSummary).path("nextAction").asText()).isEqualTo("ACCEPT");

        ResponseEntity<JsonNode> blockedWithoutChecklist = post(
                "/api/v1/mobile/trips/" + tripId + "/start-workflow",
                driver.token(),
                "{}"
        );
        assertFailure(
                blockedWithoutChecklist,
                HttpStatus.BAD_REQUEST,
                "Phải hoàn thành checklist trước khi bắt đầu"
        );

        ResponseEntity<JsonNode> checklist = post("/api/v1/mobile/trips/" + tripId + "/pre-trip-checklist", driver.token(), """
                {
                  "exteriorChecked": true,
                  "tiresChecked": true,
                  "brakeChecked": true,
                  "lightsChecked": true,
                  "cameraChecked": true,
                  "gpsChecked": true,
                  "documentsChecked": true,
                  "note": "Mobile integration checklist"
                }
                """);
        assertSuccess(checklist, HttpStatus.OK);
        assertThat(data(checklist).path("passed").asBoolean()).isTrue();

        ResponseEntity<JsonNode> acceptedTrip = post(
                "/api/v1/mobile/trips/" + tripId + "/accept",
                driver.token(),
                """
                        {
                          "note": "Driver accepted assigned trip",
                          "clientEventId": "workflow-accept-%d"
                        }
                        """.formatted(SEQUENCE.incrementAndGet())
        );
        assertSuccess(acceptedTrip, HttpStatus.OK);
        assertThat(data(acceptedTrip).path("status").asText()).isEqualTo("ACCEPTED");

        ResponseEntity<JsonNode> agentCommand = post("/api/v1/mobile/agent/command", driver.token(), """
                {
                  "commandType": "VOICE",
                  "tripId": %d,
                  "transcript": "Tôi cần SOS cứu hộ"
                }
                """.formatted(tripId));
        assertSuccess(agentCommand, HttpStatus.OK);
        assertThat(data(agentCommand).path("status").asText()).isEqualTo("UNDERSTOOD");
        assertSuccess(get("/api/v1/mobile/agent/history?page=0&size=5", driver.token()), HttpStatus.OK);

        ResponseEntity<JsonNode> telemetry = post("/api/v1/mobile/telemetry", driver.token(), """
                {
                  "vehicleId": %d,
                  "driverId": %d,
                  "tripId": %d,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "speed": 36.5,
                  "heading": 90.0,
                  "batteryLevel": 80,
                  "gpsStatus": "GOOD"
                }
                """.formatted(fixture.vehicleId(), driver.driverId(), tripId));
        assertSuccess(telemetry, HttpStatus.OK);

        ResponseEntity<JsonNode> flood = post("/api/v1/mobile/flood-reports/quick", driver.token(), """
                {
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "address": "Pham Van Dong",
                  "severity": "HIGH"
                }
                """);
        assertSuccess(flood, HttpStatus.OK);
        assertThat(data(flood).path("reportedByDriverId").asLong()).isEqualTo(driver.driverId());
        assertSuccess(get("/api/v1/mobile/flood-points/nearby?lat=21.0285&lng=105.8542&radiusKm=1", driver.token()), HttpStatus.OK);

        ResponseEntity<JsonNode> routeRisk = post("/api/v1/mobile/route-check", driver.token(), """
                {
                  "points": [
                    {
                      "lat": 21.0285,
                      "lng": 105.8542
                    }
                  ]
                }
                """);
        assertSuccess(routeRisk, HttpStatus.OK);
        assertThat(data(routeRisk).path("risky").asBoolean()).isTrue();

        ResponseEntity<JsonNode> autocomplete = get(
                "/api/v1/mobile/locations/autocomplete?query=My&limit=5",
                driver.token()
        );
        assertSuccess(autocomplete, HttpStatus.OK);
        assertThat(data(autocomplete).isArray()).isTrue();
        assertThat(data(autocomplete).size()).isGreaterThan(0);

        ResponseEntity<JsonNode> navigation = post("/api/v1/mobile/navigation/routes", driver.token(), """
                {
                  "originLat": 21.0285,
                  "originLng": 105.8542,
                  "destinationLat": 21.0410,
                  "destinationLng": 105.8080,
                  "destinationName": "Ho Tung Mau",
                  "tripId": %d
                }
                """.formatted(tripId));
        assertSuccess(navigation, HttpStatus.OK);
        String navigationSessionId = data(navigation).path("sessionId").asText();
        assertThat(navigationSessionId).isNotBlank();
        assertThat(data(navigation).path("routes").size()).isGreaterThanOrEqualTo(3);
        assertThat(data(navigation).path("selectedRouteIndex").isInt()).isTrue();
        assertSuccess(get("/api/v1/mobile/navigation/current", driver.token()), HttpStatus.OK);

        LocalDateTime offRouteStarted = LocalDateTime.now().minusSeconds(20);
        ResponseEntity<JsonNode> firstOffRoute = post("/api/v1/mobile/navigation/events", driver.token(), """
                {
                  "sessionId": "%s",
                  "eventType": "LOCATION_UPDATE",
                  "lat": 21.0300,
                  "lng": 105.8500,
                  "distanceToRouteMeters": 96,
                  "gpsAccuracyMeters": 8,
                  "occurredAt": "%s"
                }
                """.formatted(navigationSessionId, offRouteStarted));
        assertSuccess(firstOffRoute, HttpStatus.OK);
        assertThat(data(firstOffRoute).path("rerouteRequired").asBoolean()).isFalse();

        ResponseEntity<JsonNode> confirmedOffRoute = post("/api/v1/mobile/navigation/events", driver.token(), """
                {
                  "sessionId": "%s",
                  "eventType": "LOCATION_UPDATE",
                  "lat": 21.0302,
                  "lng": 105.8502,
                  "distanceToRouteMeters": 110,
                  "gpsAccuracyMeters": 7,
                  "occurredAt": "%s"
                }
                """.formatted(navigationSessionId, offRouteStarted.plusSeconds(16)));
        assertSuccess(confirmedOffRoute, HttpStatus.OK);
        assertThat(data(confirmedOffRoute).path("rerouteRequired").asBoolean()).isTrue();
        assertThat(data(confirmedOffRoute).path("offRouteDurationSeconds").asInt()).isGreaterThanOrEqualTo(15);

        ResponseEntity<JsonNode> reroute = post("/api/v1/mobile/navigation/reroute", driver.token(), """
                {
                  "sessionId": "%s",
                  "currentLat": 21.0302,
                  "currentLng": 105.8502,
                  "gpsAccuracyMeters": 7,
                  "reason": "OFF_ROUTE_CONFIRMED"
                }
                """.formatted(navigationSessionId));
        assertSuccess(reroute, HttpStatus.OK);
        assertThat(data(reroute).path("sessionId").asText()).isEqualTo(navigationSessionId);

        ResponseEntity<JsonNode> forgedDrivingSession = post(
                "/api/v1/driving-sessions/start",
                driver.token(),
                """
                        {"driverId":%d,"vehicleId":%d,"tripId":%d}
                        """.formatted(driver.driverId(), otherFixture.vehicleId(), tripId)
        );
        assertFailure(
                forgedDrivingSession,
                HttpStatus.FORBIDDEN,
                "Xe không thuộc phân công hiện tại của tài xế"
        );

        ResponseEntity<JsonNode> startWorkflow = post(
                "/api/v1/mobile/trips/" + tripId + "/start-workflow",
                driver.token(),
                """
                        {
                          "note": "Start unified mobile workflow",
                          "clientEventId": "workflow-start-%d"
                        }
                        """.formatted(SEQUENCE.incrementAndGet())
        );
        assertSuccess(startWorkflow, HttpStatus.OK);
        assertThat(data(startWorkflow).path("trip").path("status").asText()).isEqualTo("IN_PROGRESS");
        assertThat(data(startWorkflow).path("drivingSession").path("status").asText()).isEqualTo("ACTIVE");
        assertThat(data(startWorkflow).path("navigationSessionId").asText()).isNotBlank();
        String startClientEventId = jdbcTemplate.queryForObject(
                "SELECT client_event_id FROM mobile_command_receipts WHERE trip_id = ? AND operation = 'START'",
                String.class,
                tripId
        );
        ResponseEntity<JsonNode> startReplay = post(
                "/api/v1/mobile/trips/" + tripId + "/start-workflow",
                driver.token(),
                """
                        {
                          "note": "Replay after ambiguous network result",
                          "clientEventId": "%s"
                        }
                        """.formatted(startClientEventId)
        );
        assertSuccess(startReplay, HttpStatus.OK);
        assertThat(data(startReplay).path("trip").path("id").asLong()).isEqualTo(tripId);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM mobile_command_receipts WHERE trip_id = ? AND operation = 'START'",
                Integer.class,
                tripId
        )).isEqualTo(1);
        assertSuccess(get("/api/v1/mobile/driving-sessions/current", driver.token()), HttpStatus.OK);

        ResponseEntity<JsonNode> forgedTelemetry = post("/api/v1/mobile/telemetry", driver.token(), """
                {
                  "clientEventId": "gps-forged-%d",
                  "vehicleId": %d,
                  "driverId": %d,
                  "tripId": %d,
                  "lat": 21.0287,
                  "lng": 105.8544
                }
                """.formatted(
                SEQUENCE.incrementAndGet(),
                otherFixture.vehicleId(),
                driver.driverId(),
                tripId
        ));
        assertFailure(
                forgedTelemetry,
                HttpStatus.FORBIDDEN,
                "Tài xế chỉ được gửi GPS cho xe đang được phân công"
        );

        ResponseEntity<JsonNode> futureTelemetry = post("/api/v1/mobile/telemetry", driver.token(), """
                {
                  "clientEventId": "gps-future-%d",
                  "vehicleId": %d,
                  "driverId": %d,
                  "tripId": %d,
                  "lat": 21.0287,
                  "lng": 105.8544,
                  "createdAt": "2099-01-01T00:00:00"
                }
                """.formatted(
                SEQUENCE.incrementAndGet(),
                fixture.vehicleId(),
                driver.driverId(),
                tripId
        ));
        assertFailure(
                futureTelemetry,
                HttpStatus.BAD_REQUEST,
                "Thời điểm GPS vượt quá độ lệch cho phép"
        );

        String firstEventId = "gps-" + SEQUENCE.incrementAndGet();
        String secondEventId = "gps-" + SEQUENCE.incrementAndGet();
        String batchId = "batch-" + SEQUENCE.incrementAndGet();
        ResponseEntity<JsonNode> batch = post("/api/v1/mobile/telemetry/batch", driver.token(), """
                {
                  "batchId": "%s",
                  "items": [
                    {
                      "clientEventId": "%s",
                      "vehicleId": %d,
                      "driverId": %d,
                      "tripId": %d,
                      "lat": 21.0287,
                      "lng": 105.8544,
                      "speed": 35.0,
                      "gpsStatus": "GOOD"
                    },
                    {
                      "clientEventId": "%s",
                      "vehicleId": %d,
                      "driverId": %d,
                      "tripId": %d,
                      "lat": 20.0000,
                      "lng": 105.0000,
                      "speed": 10.0,
                      "gpsStatus": "GOOD",
                      "createdAt": "2020-01-01T00:00:00"
                    }
                  ]
                }
                """.formatted(
                batchId,
                firstEventId,
                fixture.vehicleId(),
                driver.driverId(),
                tripId,
                secondEventId,
                fixture.vehicleId(),
                driver.driverId(),
                tripId
        ));
        assertSuccess(batch, HttpStatus.OK);
        assertThat(data(batch).path("acceptedCount").asInt()).isEqualTo(2);
        assertThat(data(batch).path("duplicateCount").asInt()).isZero();

        ResponseEntity<JsonNode> duplicateBatch = post("/api/v1/mobile/telemetry/batch", driver.token(), """
                {
                  "batchId": "%s",
                  "items": [
                    {
                      "clientEventId": "%s",
                      "vehicleId": %d,
                      "driverId": %d,
                      "tripId": %d,
                      "lat": 21.0287,
                      "lng": 105.8544
                    },
                    {
                      "clientEventId": "%s",
                      "vehicleId": %d,
                      "driverId": %d,
                      "tripId": %d,
                      "lat": 20.0000,
                      "lng": 105.0000
                    }
                  ]
                }
                """.formatted(
                batchId,
                firstEventId,
                fixture.vehicleId(),
                driver.driverId(),
                tripId,
                secondEventId,
                fixture.vehicleId(),
                driver.driverId(),
                tripId
        ));
        assertSuccess(duplicateBatch, HttpStatus.OK);
        assertThat(data(duplicateBatch).path("acceptedCount").asInt()).isEqualTo(2);
        assertThat(data(duplicateBatch).path("duplicateCount").asInt()).isZero();
        assertThat(data(duplicateBatch).path("items").get(0).path("status").asText()).isEqualTo("ACCEPTED");

        ResponseEntity<JsonNode> duplicateEventsInNewBatch = post("/api/v1/mobile/telemetry/batch", driver.token(), """
                {
                  "batchId": "%s-retry",
                  "items": [
                    {
                      "clientEventId": "%s",
                      "vehicleId": %d,
                      "driverId": %d,
                      "tripId": %d,
                      "lat": 21.0287,
                      "lng": 105.8544
                    },
                    {
                      "clientEventId": "%s",
                      "vehicleId": %d,
                      "driverId": %d,
                      "tripId": %d,
                      "lat": 20.0000,
                      "lng": 105.0000
                    }
                  ]
                }
                """.formatted(
                batchId,
                firstEventId,
                fixture.vehicleId(),
                driver.driverId(),
                tripId,
                secondEventId,
                fixture.vehicleId(),
                driver.driverId(),
                tripId
        ));
        assertSuccess(duplicateEventsInNewBatch, HttpStatus.OK);
        assertThat(data(duplicateEventsInNewBatch).path("acceptedCount").asInt()).isZero();
        assertThat(data(duplicateEventsInNewBatch).path("duplicateCount").asInt()).isEqualTo(2);

        ResponseEntity<JsonNode> vehicleAfterOldTelemetry = get(
                "/api/v1/vehicles/" + fixture.vehicleId(),
                adminToken
        );
        assertSuccess(vehicleAfterOldTelemetry, HttpStatus.OK);
        assertThat(data(vehicleAfterOldTelemetry).path("lastLat").asDouble()).isEqualTo(21.0287);
        assertThat(data(vehicleAfterOldTelemetry).path("lastLng").asDouble()).isEqualTo(105.8544);

        ResponseEntity<JsonNode> pauseWorkflow = post(
                "/api/v1/mobile/trips/" + tripId + "/pause-workflow",
                driver.token(),
                """
                        {"clientEventId":"workflow-pause-%d"}
                        """.formatted(SEQUENCE.incrementAndGet())
        );
        assertSuccess(pauseWorkflow, HttpStatus.OK);
        assertThat(data(pauseWorkflow).path("trip").path("status").asText()).isEqualTo("RESTING");
        assertThat(data(pauseWorkflow).path("drivingSession").path("status").asText()).isEqualTo("PAUSED");

        ResponseEntity<JsonNode> resumeWorkflow = post(
                "/api/v1/mobile/trips/" + tripId + "/resume-workflow",
                driver.token(),
                """
                        {"clientEventId":"workflow-resume-%d"}
                        """.formatted(SEQUENCE.incrementAndGet())
        );
        assertSuccess(resumeWorkflow, HttpStatus.OK);
        assertThat(data(resumeWorkflow).path("trip").path("status").asText()).isEqualTo("IN_PROGRESS");
        assertThat(data(resumeWorkflow).path("drivingSession").path("status").asText()).isEqualTo("ACTIVE");

        ResponseEntity<JsonNode> completeWorkflow = post(
                "/api/v1/mobile/trips/" + tripId + "/complete-workflow",
                driver.token(),
                """
                        {"clientEventId":"workflow-complete-%d"}
                        """.formatted(SEQUENCE.incrementAndGet())
        );
        assertSuccess(completeWorkflow, HttpStatus.OK);
        assertThat(data(completeWorkflow).path("trip").path("status").asText()).isEqualTo("COMPLETED");
        assertThat(data(completeWorkflow).path("drivingSession").path("status").asText()).isEqualTo("FINISHED");
        ResponseEntity<JsonNode> completeReplay = post(
                "/api/v1/mobile/trips/" + tripId + "/complete-workflow",
                driver.token(),
                """
                        {
                          "clientEventId": "%s"
                        }
                        """.formatted(jdbcTemplate.queryForObject(
                        "SELECT client_event_id FROM mobile_command_receipts "
                                + "WHERE trip_id = ? AND operation = 'COMPLETE'",
                        String.class,
                        tripId
                ))
        );
        assertSuccess(completeReplay, HttpStatus.OK);
        assertThat(data(completeReplay).path("trip").path("status").asText()).isEqualTo("COMPLETED");

        assertSuccess(get("/api/v1/mobile/notifications?page=0&size=5", driver.token()), HttpStatus.OK);
        ResponseEntity<JsonNode> bootstrap = get("/api/v1/mobile/bootstrap", driver.token());
        assertSuccess(bootstrap, HttpStatus.OK);
        assertThat(data(bootstrap).path("profile").path("driver").path("id").asLong()).isEqualTo(driver.driverId());
        assertThat(data(bootstrap).path("serverTime").asText()).isNotBlank();

        ResponseEntity<JsonNode> otherIncident = post("/api/v1/incidents/sos", adminToken, """
                {
                  "driverId": %d,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "severity": "CRITICAL",
                  "description": "Other driver SOS"
                }
                """.formatted(otherDriver.driverId()));
        assertSuccess(otherIncident, HttpStatus.OK);
        long otherIncidentId = data(otherIncident).path("id").asLong();
        ResponseEntity<JsonNode> forbiddenIncident = get("/api/v1/mobile/incidents/" + otherIncidentId, driver.token());
        assertFailure(forbiddenIncident, HttpStatus.FORBIDDEN, "Tài xế chỉ được xem sự cố của chính mình");
    }

    @Test
    @Order(7)
    void refreshTokenRotationLogoutAndNotificationReadStateAreIsolatedPerUser() {
        JsonNode login = loginResponse("admin", "123456");
        String firstRefreshToken = login.path("refreshToken").asText();
        assertThat(firstRefreshToken).isNotBlank();

        ResponseEntity<JsonNode> refreshed = post("/api/v1/auth/refresh", null, """
                {
                  "refreshToken": "%s"
                }
                """.formatted(firstRefreshToken));
        assertSuccess(refreshed, HttpStatus.OK);
        String rotatedRefreshToken = data(refreshed).path("refreshToken").asText();
        assertThat(rotatedRefreshToken).isNotBlank().isNotEqualTo(firstRefreshToken);

        ResponseEntity<JsonNode> reused = exchangeWithJavaHttpClient(
                HttpMethod.POST,
                "/api/v1/auth/refresh",
                null,
                """
                {
                  "refreshToken": "%s"
                }
                """.formatted(firstRefreshToken)
        );
        assertFailure(reused, HttpStatus.UNAUTHORIZED, "Refresh token không hợp lệ hoặc đã hết hạn");

        ResponseEntity<JsonNode> logout = post("/api/v1/auth/logout", null, """
                {
                  "refreshToken": "%s"
                }
                """.formatted(rotatedRefreshToken));
        assertSuccess(logout, HttpStatus.OK);

        ResponseEntity<JsonNode> revoked = exchangeWithJavaHttpClient(
                HttpMethod.POST,
                "/api/v1/auth/refresh",
                null,
                """
                {
                  "refreshToken": "%s"
                }
                """.formatted(rotatedRefreshToken)
        );
        assertFailure(revoked, HttpStatus.UNAUTHORIZED, "Refresh token không hợp lệ hoặc đã hết hạn");

        String adminToken = login("admin", "123456");
        DriverLogin firstDriver = createDriverAccount(adminToken);
        DriverLogin secondDriver = createDriverAccount(adminToken);
        ResponseEntity<JsonNode> firstNotifications = get(
                "/api/v1/mobile/notifications?page=0&size=100",
                firstDriver.token()
        );
        assertSuccess(firstNotifications, HttpStatus.OK);
        JsonNode items = data(firstNotifications).path("items");
        assertThat(items.isArray()).isTrue();
        assertThat(items.size()).isGreaterThan(0);
        long notificationId = items.get(0).path("id").asLong();

        assertSuccess(
                patch("/api/v1/mobile/notifications/" + notificationId + "/read", firstDriver.token(), null),
                HttpStatus.OK
        );

        JsonNode firstAfter = data(get(
                "/api/v1/mobile/notifications?page=0&size=100",
                firstDriver.token()
        )).path("items");
        JsonNode secondAfter = data(get(
                "/api/v1/mobile/notifications?page=0&size=100",
                secondDriver.token()
        )).path("items");
        assertThat(notificationRead(firstAfter, notificationId)).isTrue();
        assertThat(notificationRead(secondAfter, notificationId)).isFalse();
    }

    @Test
    @Order(8)
    void mobileSafetySosEvidenceAndPushAreOwnedIdempotentAndPersisted() {
        String adminToken = login("admin", "123456");
        DriverLogin driver = createDriverAccount(adminToken);
        DriverLogin otherDriver = createDriverAccount(adminToken);
        String deviceUuid = "it-device-" + SEQUENCE.incrementAndGet();

        ResponseEntity<JsonNode> push = post("/api/v1/mobile/push-tokens", driver.token(), """
                {
                  "deviceUuid": "%s",
                  "platform": "ANDROID",
                  "provider": "FCM",
                  "token": "it-fcm-%d",
                  "appVersion": "1.0.0",
                  "osVersion": "Android 15",
                  "deviceModel": "Integration Device"
                }
                """.formatted(deviceUuid, SEQUENCE.incrementAndGet()));
        assertSuccess(push, HttpStatus.OK);
        assertThat(data(push).path("deviceUuid").asText()).isEqualTo(deviceUuid);
        assertThat(data(push).has("token")).isFalse();

        String floodClientEventId = "flood-" + SEQUENCE.incrementAndGet();
        String floodPayload = """
                {
                  "lat": 21.0312,
                  "lng": 105.7811,
                  "address": "Integration offline flood",
                  "severity": "HIGH",
                  "clientEventId": "%s"
                }
                """.formatted(floodClientEventId);
        ResponseEntity<JsonNode> flood = post(
                "/api/v1/mobile/flood-reports/quick",
                driver.token(),
                floodPayload
        );
        ResponseEntity<JsonNode> floodReplay = post(
                "/api/v1/mobile/flood-reports/quick",
                driver.token(),
                floodPayload
        );
        assertSuccess(flood, HttpStatus.OK);
        assertSuccess(floodReplay, HttpStatus.OK);
        long floodId = data(flood).path("id").asLong();
        assertThat(data(floodReplay).path("id").asLong()).isEqualTo(floodId);
        assertThat(data(flood).path("clientEventId").asText()).isEqualTo(floodClientEventId);
        assertThat(data(flood).path("receivedAt").asText()).isNotBlank();

        String safetyClientEventId = "safety-" + SEQUENCE.incrementAndGet();
        ResponseEntity<JsonNode> safety = post("/api/v1/mobile/safety-events", driver.token(), """
                {
                  "eventType": "PHONE_USAGE",
                  "severity": "HIGH",
                  "driverId": %d,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "speed": 32.0,
                  "confidence": 0.94,
                  "note": "On-device integration alert",
                  "clientEventId": "%s"
                }
                """.formatted(otherDriver.driverId(), safetyClientEventId));
        assertSuccess(safety, HttpStatus.OK);
        long safetyEventId = data(safety).path("id").asLong();
        assertThat(data(safety).path("driverId").asLong()).isEqualTo(driver.driverId());
        assertThat(data(safety).path("clientEventId").asText()).isEqualTo(safetyClientEventId);

        ResponseEntity<JsonNode> safetyReplay = post("/api/v1/mobile/safety-events", driver.token(), """
                {
                  "eventType": "PHONE_USAGE",
                  "severity": "HIGH",
                  "lat": 21.0286,
                  "lng": 105.8543,
                  "clientEventId": "%s"
                }
                """.formatted(safetyClientEventId));
        assertSuccess(safetyReplay, HttpStatus.OK);
        assertThat(data(safetyReplay).path("id").asLong()).isEqualTo(safetyEventId);

        ResponseEntity<JsonNode> cooldownCollapse = post("/api/v1/mobile/safety-events", driver.token(), """
                {
                  "eventType": "PHONE_USAGE",
                  "severity": "HIGH",
                  "lat": 21.0287,
                  "lng": 105.8544,
                  "clientEventId": "safety-cooldown-%d"
                }
                """.formatted(SEQUENCE.incrementAndGet()));
        assertSuccess(cooldownCollapse, HttpStatus.OK);
        assertThat(data(cooldownCollapse).path("id").asLong()).isEqualTo(safetyEventId);

        ResponseEntity<JsonNode> evidence = uploadPngEvidence(
                "/api/v1/mobile/evidence",
                driver.token(),
                safetyEventId
        );
        assertSuccess(evidence, HttpStatus.OK);
        long evidenceId = data(evidence).path("id").asLong();
        assertThat(data(evidence).path("contentType").asText()).isEqualTo("image/png");
        assertThat(data(evidence).path("sha256").asText()).hasSize(64);
        assertThat(data(evidence).path("protectedContentUrl").asText())
                .isEqualTo("/api/v1/evidence/" + evidenceId + "/content");

        ResponseEntity<byte[]> evidenceContent = getBytes(
                "/api/v1/evidence/" + evidenceId + "/content",
                driver.token()
        );
        assertThat(evidenceContent.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(evidenceContent.getHeaders().getContentType()).isEqualTo(MediaType.IMAGE_PNG);
        assertThat(evidenceContent.getHeaders().getCacheControl()).contains("no-store");
        assertThat(evidenceContent.getBody()).isNotEmpty();

        ResponseEntity<JsonNode> forbiddenEvidence = get(
                "/api/v1/evidence/" + evidenceId,
                otherDriver.token()
        );
        assertFailure(
                forbiddenEvidence,
                HttpStatus.FORBIDDEN,
                "Không được truy cập evidence của tài xế khác"
        );

        String sosClientEventId = "sos-" + SEQUENCE.incrementAndGet();
        ResponseEntity<JsonNode> sos = post("/api/v1/mobile/incidents/sos", driver.token(), """
                {
                  "driverId": %d,
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "severity": "CRITICAL",
                  "description": "Mobile integration SOS",
                  "clientEventId": "%s"
                }
                """.formatted(otherDriver.driverId(), sosClientEventId));
        assertSuccess(sos, HttpStatus.OK);
        long sosId = data(sos).path("id").asLong();
        assertThat(data(sos).path("driverId").asLong()).isEqualTo(driver.driverId());

        ResponseEntity<JsonNode> sosReplay = post("/api/v1/mobile/incidents/sos", driver.token(), """
                {
                  "lat": 21.0285,
                  "lng": 105.8542,
                  "clientEventId": "%s"
                }
                """.formatted(sosClientEventId));
        assertSuccess(sosReplay, HttpStatus.OK);
        assertThat(data(sosReplay).path("id").asLong()).isEqualTo(sosId);
        assertSuccess(get("/api/v1/mobile/incidents/" + sosId + "/timeline", driver.token()), HttpStatus.OK);

        assertSuccess(post("/api/v1/incidents/" + sosId + "/accept", adminToken, null), HttpStatus.OK);
        ResponseEntity<JsonNode> acceptedOnMobile = get(
                "/api/v1/mobile/incidents/" + sosId,
                driver.token()
        );
        assertSuccess(acceptedOnMobile, HttpStatus.OK);
        assertThat(data(acceptedOnMobile).path("status").asText()).isEqualTo("ACCEPTED");

        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM safety_event_evidence WHERE id = ? AND uploaded_by IS NOT NULL",
                Integer.class,
                evidenceId
        )).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM pending_push_notifications WHERE user_id = "
                        + "(SELECT user_id FROM drivers WHERE id = ?)",
                Integer.class,
                driver.driverId()
        )).isGreaterThanOrEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM flood_reports WHERE reported_by_driver_id = ? AND client_event_id = ?",
                Integer.class,
                driver.driverId(),
                floodClientEventId
        )).isEqualTo(1);

        ResponseEntity<JsonNode> unregister = exchange(
                HttpMethod.DELETE,
                "/api/v1/mobile/push-tokens/" + deviceUuid,
                driver.token(),
                null
        );
        assertSuccess(unregister, HttpStatus.OK);
        assertThat(jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM push_tokens pt
                JOIN mobile_devices md ON md.id = pt.device_id
                WHERE md.device_uuid = ? AND md.user_id = (
                    SELECT user_id FROM drivers WHERE id = ?
                ) AND pt.enabled = TRUE
                """, Integer.class, deviceUuid, driver.driverId())).isZero();
    }

    @Test
    @Order(9)
    void agentRequiresExplicitConfirmationAndExecutesExactlyOnceForItsOwner() {
        String adminToken = login("admin", "123456");
        DriverLogin driver = createDriverAccount(adminToken);
        DriverLogin otherDriver = createDriverAccount(adminToken);

        ResponseEntity<JsonNode> command = post("/api/v1/mobile/agent/command", driver.token(), """
                {
                  "commandType": "VOICE",
                  "transcript": "Tôi cần SOS cứu hộ"
                }
                """);
        assertSuccess(command, HttpStatus.OK);
        JsonNode understood = data(command);
        long commandId = understood.path("id").asLong();
        assertThat(understood.path("intent").asText()).isEqualTo("SEND_SOS");
        assertThat(understood.path("status").asText()).isEqualTo("UNDERSTOOD");
        assertThat(understood.path("requiresConfirmation").asBoolean()).isTrue();
        assertThat(understood.path("classificationSource").asText()).isEqualTo("LOCAL_RULE");
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM incidents WHERE client_event_id = ?",
                Integer.class,
                "agent-" + commandId + "-send_sos"
        )).isZero();

        ResponseEntity<JsonNode> wrongOwner = post(
                "/api/v1/mobile/agent/commands/" + commandId + "/confirm",
                otherDriver.token(),
                """
                        {"lat":21.0285,"lng":105.8542}
                        """
        );
        assertFailure(
                wrongOwner,
                HttpStatus.NOT_FOUND,
                "Không tìm thấy AgentCommand: " + commandId
        );

        ResponseEntity<JsonNode> confirmed = post(
                "/api/v1/mobile/agent/commands/" + commandId + "/confirm",
                driver.token(),
                """
                        {
                          "lat": 21.0285,
                          "lng": 105.8542,
                          "description": "SOS integration qua agent"
                        }
                        """
        );
        assertSuccess(confirmed, HttpStatus.OK);
        JsonNode executed = data(confirmed);
        assertThat(executed.path("status").asText()).isEqualTo("EXECUTED");
        assertThat(executed.path("executedReferenceType").asText()).isEqualTo("INCIDENT");
        long incidentId = executed.path("executedReferenceId").asLong();
        assertThat(incidentId).isPositive();

        ResponseEntity<JsonNode> replay = post(
                "/api/v1/mobile/agent/commands/" + commandId + "/confirm",
                driver.token(),
                """
                        {"lat":21.0000,"lng":105.0000}
                        """
        );
        assertSuccess(replay, HttpStatus.OK);
        assertThat(data(replay).path("executedReferenceId").asLong()).isEqualTo(incidentId);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM incidents WHERE client_event_id = ?",
                Integer.class,
                "agent-" + commandId + "-send_sos"
        )).isEqualTo(1);

        ResponseEntity<JsonNode> floodCommand = post("/api/v1/mobile/agent/command", driver.token(), """
                {
                  "commandType": "VOICE",
                  "transcript": "Báo đường đang ngập"
                }
                """);
        assertSuccess(floodCommand, HttpStatus.OK);
        long floodCommandId = data(floodCommand).path("id").asLong();
        assertThat(data(floodCommand).path("intent").asText()).isEqualTo("REPORT_FLOOD");
        assertSuccess(
                post("/api/v1/mobile/agent/commands/" + floodCommandId + "/cancel", driver.token(), null),
                HttpStatus.OK
        );
        ResponseEntity<JsonNode> cancelledConfirm = post(
                "/api/v1/mobile/agent/commands/" + floodCommandId + "/confirm",
                driver.token(),
                """
                        {"lat":21.0285,"lng":105.8542}
                        """
        );
        assertFailure(cancelledConfirm, HttpStatus.BAD_REQUEST, "Lệnh đã bị hủy");
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM flood_reports WHERE client_event_id = ?",
                Integer.class,
                "agent-" + floodCommandId + "-report_flood"
        )).isZero();

        ResponseEntity<JsonNode> readOnlyCommand = post("/api/v1/mobile/agent/command", driver.token(), """
                {
                  "commandType": "VOICE",
                  "transcript": "Tôi còn được lái bao lâu"
                }
                """);
        assertSuccess(readOnlyCommand, HttpStatus.OK);
        assertThat(data(readOnlyCommand).path("intent").asText()).isEqualTo("GET_DRIVING_TIME");
        assertThat(data(readOnlyCommand).path("status").asText()).isEqualTo("EXECUTED");
        assertThat(data(readOnlyCommand).path("requiresConfirmation").asBoolean()).isFalse();
    }

    @Test
    @Order(10)
    void concurrentTelemetryCannotMoveLatestPositionBackwardsAndOnlyOneDrivingSessionStarts() throws Exception {
        String adminToken = login("admin", "123456");
        FleetFixture fixture = createAvailableFleet(adminToken);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            String newerTime = LocalDateTime.now().minusMinutes(1).withNano(0).toString();
            String olderTime = LocalDateTime.now().minusMinutes(2).withNano(0).toString();
            List<Callable<ResponseEntity<JsonNode>>> telemetryCalls = List.of(
                    () -> post("/api/v1/telemetry", adminToken, """
                            {"vehicleId":%d,"lat":21.1111,"lng":105.1111,"speed":31.0,
                             "heading":90.0,"batteryLevel":80,"createdAt":"%s","clientEventId":"race-new-%d"}
                            """.formatted(fixture.vehicleId(), newerTime, SEQUENCE.incrementAndGet())),
                    () -> post("/api/v1/telemetry", adminToken, """
                            {"vehicleId":%d,"lat":20.2222,"lng":104.2222,"speed":12.0,
                             "heading":180.0,"batteryLevel":70,"createdAt":"%s","clientEventId":"race-old-%d"}
                            """.formatted(fixture.vehicleId(), olderTime, SEQUENCE.incrementAndGet()))
            );
            for (Future<ResponseEntity<JsonNode>> future : executor.invokeAll(telemetryCalls)) {
                assertSuccess(future.get(), HttpStatus.OK);
            }

            ResponseEntity<JsonNode> vehicle = get("/api/v1/vehicles/" + fixture.vehicleId(), adminToken);
            assertSuccess(vehicle, HttpStatus.OK);
            assertThat(data(vehicle).path("lastLat").asDouble()).isEqualTo(21.1111);
            assertThat(data(vehicle).path("lastLng").asDouble()).isEqualTo(105.1111);
            assertThat(data(vehicle).path("lastUpdatedAt").asText()).startsWith(newerTime);

            String startBody = """
                    {"driverId":%d,"vehicleId":%d}
                    """.formatted(fixture.driverId(), fixture.vehicleId());
            List<Callable<ResponseEntity<JsonNode>>> startCalls = List.of(
                    () -> post("/api/v1/driving-sessions/start", adminToken, startBody),
                    () -> post("/api/v1/driving-sessions/start", adminToken, startBody)
            );
            List<ResponseEntity<JsonNode>> startResponses = executor.invokeAll(startCalls).stream()
                    .map(future -> {
                        try {
                            return future.get();
                        } catch (Exception exception) {
                            throw new IllegalStateException(exception);
                        }
                    })
                    .toList();
            assertThat(startResponses).extracting(ResponseEntity::getStatusCode)
                    .containsExactlyInAnyOrder(HttpStatus.OK, HttpStatus.BAD_REQUEST);
            assertThat(jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM driving_sessions WHERE driver_id = ? AND status IN ('ACTIVE', 'PAUSED')",
                    Integer.class,
                    fixture.driverId()
            )).isEqualTo(1);

            Long activeSessionId = jdbcTemplate.queryForObject(
                    "SELECT id FROM driving_sessions WHERE driver_id = ? AND status IN ('ACTIVE', 'PAUSED')",
                    Long.class,
                    fixture.driverId()
            );
            assertSuccess(post("/api/v1/driving-sessions/" + activeSessionId + "/finish", adminToken, null), HttpStatus.OK);
        } finally {
            executor.shutdownNow();
        }
    }

    private FleetFixture createAvailableFleet(String token) {
        int suffix = SEQUENCE.incrementAndGet();

        ResponseEntity<JsonNode> device = post("/api/v1/devices", token, """
                {
                  "deviceCode": "IT-GPS-%d",
                  "name": "Integration GPS %d",
                  "type": "GPS_TRACKER",
                  "status": "ONLINE",
                  "serialNumber": "IT-SN-%d",
                  "firmwareVersion": "1.0.%d"
                }
                """.formatted(suffix, suffix, suffix, suffix));
        assertSuccess(device, HttpStatus.OK);
        long gpsDeviceId = data(device).path("id").asLong();

        ResponseEntity<JsonNode> driver = post("/api/v1/drivers", token, """
                {
                  "fullName": "Integration Driver %d",
                  "phone": "091%d",
                  "email": "integration.driver.%d@safefleet.vn",
                  "address": "Ha Dong, Ha Noi",
                  "licenseNumber": "IT-LIC-%d",
                  "licenseClass": "D",
                  "licenseExpiredAt": "2032-12-31",
                  "status": "AVAILABLE"
                }
                """.formatted(suffix, suffix, suffix, suffix));
        assertSuccess(driver, HttpStatus.OK);
        long driverId = data(driver).path("id").asLong();

        String plateNumber = "30A-IT-" + suffix;
        ResponseEntity<JsonNode> vehicle = post("/api/v1/vehicles", token, vehicleJson(plateNumber, gpsDeviceId, driverId));
        assertSuccess(vehicle, HttpStatus.OK);
        long vehicleId = data(vehicle).path("id").asLong();

        return new FleetFixture(gpsDeviceId, driverId, vehicleId, plateNumber);
    }

    private FleetFixture createAvailableFleetForDriver(String token, long driverId) {
        int suffix = SEQUENCE.incrementAndGet();

        ResponseEntity<JsonNode> device = post("/api/v1/devices", token, """
                {
                  "deviceCode": "IT-MOBILE-GPS-%d",
                  "name": "Integration Mobile GPS %d",
                  "type": "GPS_TRACKER",
                  "status": "ONLINE",
                  "serialNumber": "IT-MOBILE-SN-%d",
                  "firmwareVersion": "1.0.%d"
                }
                """.formatted(suffix, suffix, suffix, suffix));
        assertSuccess(device, HttpStatus.OK);
        long gpsDeviceId = data(device).path("id").asLong();

        String plateNumber = "30A-MB-" + suffix;
        ResponseEntity<JsonNode> vehicle = post("/api/v1/vehicles", token, vehicleJson(plateNumber, gpsDeviceId, driverId));
        assertSuccess(vehicle, HttpStatus.OK);
        long vehicleId = data(vehicle).path("id").asLong();

        return new FleetFixture(gpsDeviceId, driverId, vehicleId, plateNumber);
    }

    private DriverLogin createDriverAccount(String token) {
        int suffix = SEQUENCE.incrementAndGet();
        String username = "it_mobile_driver_" + suffix;
        String password = "123456";
        ResponseEntity<JsonNode> driver = post("/api/v1/accounts/drivers", token, """
                {
                  "username": "%s",
                  "email": "it.mobile.driver.%d@safefleet.vn",
                  "password": "%s",
                  "fullName": "Integration Mobile Driver %d",
                  "phone": "093%d",
                  "address": "Ha Dong, Ha Noi",
                  "licenseNumber": "IT-MOBILE-LIC-%d",
                  "licenseClass": "D",
                  "licenseExpiredAt": "2032-12-31"
                }
                """.formatted(username, suffix, password, suffix, suffix, suffix));
        assertSuccess(driver, HttpStatus.OK);
        JsonNode login = loginResponse(username, password);
        return new DriverLogin(username, password, login.path("driverId").asLong(), login.path("accessToken").asText());
    }

    private long createStaffUser(String token, String role) {
        int suffix = SEQUENCE.incrementAndGet();
        ResponseEntity<JsonNode> user = post("/api/v1/accounts", token, """
                {
                  "username": "it_%s_%d",
                  "email": "it_%s_%d@safefleet.vn",
                  "password": "123456",
                  "fullName": "Integration %s %d",
                  "phone": "092%d",
                  "role": "%s"
                }
                """.formatted(role.toLowerCase(), suffix, role.toLowerCase(), suffix, role, suffix, suffix, role));
        assertSuccess(user, HttpStatus.OK);
        return data(user).path("id").asLong();
    }

    private String vehicleJson(String plateNumber, Long gpsDeviceId, Long driverId) {
        return """
                {
                  "plateNumber": "%s",
                  "vehicleType": "VAN",
                  "brand": "Toyota",
                  "model": "Hiace",
                  "year": 2025,
                  "loadCapacity": 1500,
                  "seatCount": 16,
                  "fuelType": "DIESEL",
                  "status": "AVAILABLE",
                  "currentDriverId": %s,
                  "gpsDeviceId": %s,
                  "inspectionExpiredAt": "2031-01-01",
                  "insuranceExpiredAt": "2031-01-01"
                }
                """.formatted(plateNumber, jsonNumberOrNull(driverId), jsonNumberOrNull(gpsDeviceId));
    }

    private String jsonNumberOrNull(Long value) {
        return value == null ? "null" : value.toString();
    }

    private String login(String usernameOrEmail, String password) {
        return loginResponse(usernameOrEmail, password).path("accessToken").asText();
    }

    private JsonNode loginResponse(String usernameOrEmail, String password) {
        ResponseEntity<JsonNode> response = post("/api/v1/auth/login", null, """
                {
                  "usernameOrEmail": "%s",
                  "password": "%s"
                }
                """.formatted(usernameOrEmail, password));
        assertSuccess(response, HttpStatus.OK);
        return data(response);
    }

    private ResponseEntity<JsonNode> get(String path, String token) {
        return exchange(HttpMethod.GET, path, token, null);
    }

    private ResponseEntity<JsonNode> getWithRawAuthorization(String path, String authorization) {
        HttpHeaders headers = new HttpHeaders();
        headers.setAccept(List.of(MediaType.APPLICATION_JSON));
        headers.set(HttpHeaders.AUTHORIZATION, authorization);
        return restTemplate.exchange(url(path), HttpMethod.GET, new HttpEntity<>(null, headers), JsonNode.class);
    }

    private ResponseEntity<JsonNode> post(String path, String token, String json) {
        return exchange(HttpMethod.POST, path, token, json);
    }

    private ResponseEntity<JsonNode> put(String path, String token, String json) {
        return exchange(HttpMethod.PUT, path, token, json);
    }

    private ResponseEntity<JsonNode> patch(String path, String token, String json) {
        return exchangeWithJavaHttpClient(HttpMethod.PATCH, path, token, json);
    }

    private ResponseEntity<JsonNode> postRaw(String path, String token, String rawJson) {
        return exchange(HttpMethod.POST, path, token, rawJson);
    }

    private ResponseEntity<JsonNode> uploadPngEvidence(String path, String token, long safetyEventId) {
        byte[] png = Base64.getDecoder().decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        );
        ByteArrayResource resource = new ByteArrayResource(png) {
            @Override
            public String getFilename() {
                return "evidence.png";
            }
        };
        HttpHeaders fileHeaders = new HttpHeaders();
        fileHeaders.setContentType(MediaType.IMAGE_PNG);
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("safetyEventId", Long.toString(safetyEventId));
        body.add("capturedAt", LocalDateTime.now().withNano(0).toString());
        body.add("file", new HttpEntity<>(resource, fileHeaders));
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.setBearerAuth(token);
        return restTemplate.exchange(
                url(path),
                HttpMethod.POST,
                new HttpEntity<>(body, headers),
                JsonNode.class
        );
    }

    private ResponseEntity<byte[]> getBytes(String path, String token) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        return restTemplate.exchange(
                url(path),
                HttpMethod.GET,
                new HttpEntity<>(null, headers),
                byte[].class
        );
    }

    private ResponseEntity<JsonNode> exchangeWithJavaHttpClient(HttpMethod method, String path, String token, String json) {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(url(path)))
                .header(HttpHeaders.ACCEPT, MediaType.APPLICATION_JSON_VALUE)
                .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .method(method.name(), HttpRequest.BodyPublishers.ofString(json == null ? "" : json));
        if (token != null && !token.isBlank()) {
            builder.header(HttpHeaders.AUTHORIZATION, "Bearer " + token);
        }
        try {
            HttpResponse<String> response = HttpClient.newHttpClient()
                    .send(builder.build(), HttpResponse.BodyHandlers.ofString());
            JsonNode body = response.body() == null || response.body().isBlank()
                    ? null
                    : OBJECT_MAPPER.readTree(response.body());
            return ResponseEntity.status(response.statusCode()).body(body);
        } catch (IOException exception) {
            throw new IllegalStateException("HTTP request failed", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("HTTP request interrupted", exception);
        }
    }

    private ResponseEntity<JsonNode> exchange(HttpMethod method, String path, String token, String json) {
        HttpHeaders headers = new HttpHeaders();
        headers.setAccept(List.of(MediaType.APPLICATION_JSON));
        if (json != null || method == HttpMethod.POST || method == HttpMethod.PUT || method == HttpMethod.PATCH) {
            headers.setContentType(MediaType.APPLICATION_JSON);
        }
        if (token != null && !token.isBlank()) {
            headers.setBearerAuth(token);
        }
        return restTemplate.exchange(url(path), method, new HttpEntity<>(json, headers), JsonNode.class);
    }

    private HttpResponse<String> preflight(String path, String method) {
        return preflight(path, method, "http://localhost:5173");
    }

    private HttpResponse<String> preflight(String path, String method, String origin) {
        HttpRequest request = HttpRequest.newBuilder(URI.create(url(path)))
                .method("OPTIONS", HttpRequest.BodyPublishers.noBody())
                .header(HttpHeaders.ORIGIN, origin)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, method)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "Authorization, Content-Type")
                .build();
        try {
            return HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
        } catch (IOException exception) {
            throw new IllegalStateException("CORS preflight failed", exception);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("CORS preflight interrupted", exception);
        }
    }

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

    private void assertSuccess(ResponseEntity<JsonNode> response, HttpStatus status) {
        assertThat(response.getStatusCode()).isEqualTo(status);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().path("success").asBoolean()).isTrue();
        assertThat(response.getBody().path("timestamp").isMissingNode()).isFalse();
    }

    private void assertFailure(ResponseEntity<JsonNode> response, HttpStatus status, String message) {
        assertThat(response.getStatusCode()).isEqualTo(status);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().path("success").asBoolean()).isFalse();
        assertThat(response.getBody().path("message").asText()).isEqualTo(message);
        assertThat(response.getBody().path("timestamp").isMissingNode()).isFalse();
    }

    private JsonNode data(ResponseEntity<JsonNode> response) {
        assertThat(response.getBody()).isNotNull();
        return response.getBody().path("data");
    }

    private boolean notificationRead(JsonNode items, long notificationId) {
        for (JsonNode item : items) {
            if (item.path("id").asLong() == notificationId) {
                return item.path("read").asBoolean();
            }
        }
        throw new AssertionError("Notification " + notificationId + " not found");
    }

    private record FleetFixture(long gpsDeviceId, long driverId, long vehicleId, String plateNumber) {
    }

    private record DriverLogin(String username, String password, long driverId, String token) {
    }
}
