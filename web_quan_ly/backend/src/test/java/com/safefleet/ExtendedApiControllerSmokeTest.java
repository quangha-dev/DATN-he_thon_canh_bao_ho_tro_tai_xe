package com.safefleet;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.safefleet.account.controller.AccountController;
import com.safefleet.account.service.AccountService;
import com.safefleet.auth.controller.AuthController;
import com.safefleet.auth.service.AuthService;
import com.safefleet.common.exception.GlobalExceptionHandler;
import com.safefleet.evidence.controller.EvidenceController;
import com.safefleet.evidence.dto.EvidenceContent;
import com.safefleet.evidence.dto.EvidenceResponse;
import com.safefleet.evidence.service.EvidenceService;
import com.safefleet.flood.controller.FloodReportController;
import com.safefleet.flood.service.FloodReportService;
import com.safefleet.infrastructure.ai.SafeFleetAiGateway;
import com.safefleet.location.controller.LocationController;
import com.safefleet.location.service.LocationService;
import com.safefleet.mobile.controller.AgentAiConfigurationController;
import com.safefleet.mobile.controller.DocumentPlateReviewController;
import com.safefleet.mobile.controller.MobileController;
import com.safefleet.mobile.service.DocumentOcrJobService;
import com.safefleet.mobile.service.DocumentOcrService;
import com.safefleet.mobile.service.DocumentPlateReviewService;
import com.safefleet.mobile.service.MobileAppService;
import com.safefleet.navigation.MobileNavigationController;
import com.safefleet.navigation.NavigationService;
import com.safefleet.notification.service.PushNotificationService;
import com.safefleet.warehouse.controller.WarehouseIssueController;
import com.safefleet.warehouse.service.WarehouseIssueService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.data.web.PageableHandlerMethodArgumentResolver;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.converter.ByteArrayHttpMessageConverter;
import org.springframework.http.converter.ResourceHttpMessageConverter;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.validation.beanvalidation.LocalValidatorFactoryBean;

import java.time.LocalDateTime;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.setup.MockMvcBuilders.standaloneSetup;

@ExtendWith(MockitoExtension.class)
class ExtendedApiControllerSmokeTest {

    @Mock private AuthService authService;
    @Mock private AccountService accountService;
    @Mock private FloodReportService floodReportService;
    @Mock private MobileAppService mobileAppService;
    @Mock private PushNotificationService pushNotificationService;
    @Mock private SafeFleetAiGateway aiGateway;
    @Mock private DocumentOcrService documentOcrService;
    @Mock private DocumentOcrJobService documentOcrJobService;
    @Mock private WarehouseIssueService warehouseIssueService;
    @Mock private DocumentPlateReviewService documentPlateReviewService;
    @Mock private EvidenceService evidenceService;
    @Mock private LocationService locationService;
    @Mock private NavigationService navigationService;

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
                new FloodReportController(floodReportService),
                new MobileController(
                        mobileAppService,
                        pushNotificationService,
                        aiGateway,
                        documentOcrService,
                        documentOcrJobService,
                        warehouseIssueService
                ),
                new MobileNavigationController(locationService, navigationService),
                new LocationController(locationService),
                new EvidenceController(evidenceService),
                new WarehouseIssueController(warehouseIssueService),
                new DocumentPlateReviewController(documentPlateReviewService),
                new AgentAiConfigurationController(aiGateway)
        )
                .setControllerAdvice(new GlobalExceptionHandler())
                .setCustomArgumentResolvers(new PageableHandlerMethodArgumentResolver())
                .setMessageConverters(
                        new MappingJackson2HttpMessageConverter(objectMapper),
                        new ByteArrayHttpMessageConverter(),
                        new ResourceHttpMessageConverter()
                )
                .setValidator(validator)
                .build();
    }

    @Test
    void extendedAuthAccountFloodAndLocationApisHaveOneHappyCase() throws Exception {
        expectOk(json(post("/api/v1/auth/refresh"), """
                {"refreshToken":"valid-refresh-token"}
                """));
        expectOk(json(post("/api/v1/auth/logout"), """
                {"refreshToken":"valid-refresh-token"}
                """));
        expectOk(json(post("/api/v1/auth/change-password"), """
                {"currentPassword":"12345678","newPassword":"new-password-123"}
                """));
        expectOk(json(post("/api/v1/accounts/{id}/reset-password", 1), """
                {"newPassword":"reset-password-123"}
                """));
        expectOk(post("/api/v1/flood-reports/{id}/warn-nearby", 1));
        expectOk(get("/api/v1/locations/autocomplete").param("query", "My Dinh").param("limit", "5"));
        expectOk(json(post("/api/v1/locations/route"), routeJson()));
    }

    @Test
    void mobileReadApisHaveOneHappyCase() throws Exception {
        expectOk(get("/api/v1/mobile/me"));
        expectOk(get("/api/v1/mobile/bootstrap"));
        expectOk(get("/api/v1/mobile/safety-summary"));
        expectOk(get("/api/v1/mobile/activity/monthly").param("month", "2026-08"));
        expectOk(get("/api/v1/mobile/config"));
        expectOk(get("/api/v1/mobile/current-assignment"));
        expectOk(get("/api/v1/mobile/trips/today"));
        expectOk(get("/api/v1/mobile/trips").param("statuses", "ASSIGNED").param("limit", "20"));
        expectOk(get("/api/v1/mobile/trips/{id}", 1));
        expectOk(get("/api/v1/mobile/trips/{id}/warehouse-issue", 1));
        expectOk(get("/api/v1/mobile/trips/{id}/summary", 1));
        expectOk(get("/api/v1/mobile/driving-sessions/current"));
        expectOk(get("/api/v1/mobile/safety-events/today"));
        expectOk(get("/api/v1/mobile/incidents"));
        expectOk(get("/api/v1/mobile/incidents/{id}", 1));
        expectOk(get("/api/v1/mobile/incidents/{id}/timeline", 1));
        expectOk(get("/api/v1/mobile/flood-points/nearby")
                .param("lat", "21.0285").param("lng", "105.8542").param("radiusKm", "2"));
        expectOk(get("/api/v1/mobile/agent/history"));
        expectOk(get("/api/v1/mobile/notifications"));
    }

    @Test
    void mobileTripLifecycleApisHaveOneHappyCase() throws Exception {
        expectOk(json(post("/api/v1/mobile/trips/{id}/pre-trip-checklist", 1), """
                {
                  "exteriorChecked":true,"tiresChecked":true,"brakeChecked":true,
                  "lightsChecked":true,"cameraChecked":true,"gpsChecked":true,
                  "documentsChecked":true,"note":"Happy path checklist"
                }
                """));
        expectOk(json(post("/api/v1/mobile/trips/{id}/accept", 1), actionJson("accept-1")));
        expectOk(json(post("/api/v1/mobile/trips/{id}/start", 1), actionJson("start-1")));
        expectOk(json(post("/api/v1/mobile/trips/{id}/pause", 1), actionJson("pause-1")));
        expectOk(json(post("/api/v1/mobile/trips/{id}/resume", 1), actionJson("resume-1")));
        expectOk(json(post("/api/v1/mobile/trips/{id}/complete", 1), actionJson("complete-1")));
        expectOk(json(post("/api/v1/mobile/trips/{id}/start-workflow", 1), actionJson("workflow-start-1")));
        expectOk(json(post("/api/v1/mobile/trips/{id}/pause-workflow", 1), actionJson("workflow-pause-1")));
        expectOk(json(post("/api/v1/mobile/trips/{id}/resume-workflow", 1), actionJson("workflow-resume-1")));
        expectOk(json(post("/api/v1/mobile/trips/{id}/complete-workflow", 1), actionJson("workflow-complete-1")));
    }

    @Test
    void mobileTelemetrySafetyIncidentFloodAndNotificationApisHaveOneHappyCase() throws Exception {
        expectOk(json(post("/api/v1/mobile/telemetry"), telemetryJson("gps-1")));
        expectOk(json(post("/api/v1/mobile/telemetry/batch"), """
                {"batchId":"batch-1","items":[%s]}
                """.formatted(telemetryJson("gps-batch-1"))));
        expectOk(json(post("/api/v1/mobile/safety-events"), """
                {"eventType":"DROWSINESS","severity":"HIGH","vehicleId":1,
                 "lat":21.0285,"lng":105.8542,"confidence":0.93,"clientEventId":"safety-1"}
                """));
        expectOk(json(post("/api/v1/mobile/incidents/sos"), """
                {"lat":21.0285,"lng":105.8542,"severity":"CRITICAL",
                 "description":"Happy path SOS","clientEventId":"sos-1"}
                """));
        expectOk(json(post("/api/v1/mobile/flood-reports"), """
                {"lat":21.0285,"lng":105.8542,"severity":"HIGH","source":"DRIVER_REPORT"}
                """));
        expectOk(json(post("/api/v1/mobile/flood-reports/quick"), """
                {"lat":21.0285,"lng":105.8542,"severity":"HIGH","clientEventId":"flood-1"}
                """));
        expectOk(json(post("/api/v1/mobile/route-check"), routeCheckJson()));
        expectOk(patch("/api/v1/mobile/notifications/{id}/read", 1));
        expectOk(patch("/api/v1/mobile/notifications/read-all"));
        expectOk(json(post("/api/v1/mobile/push-tokens"), """
                {"deviceUuid":"device-1","platform":"ANDROID","provider":"FCM",
                 "token":"happy-path-token","appVersion":"1.0.0"}
                """));
        expectOk(delete("/api/v1/mobile/push-tokens/{deviceUuid}", "device-1"));
    }

    @Test
    void mobileAgentNavigationAndDocumentApisHaveOneHappyCase() throws Exception {
        expectOk(json(post("/api/v1/mobile/agent/command"), """
                {"commandType":"TEXT","tripId":1,"transcript":"Tôi còn được lái bao lâu"}
                """));
        expectOk(json(post("/api/v1/mobile/agent/commands/{id}/confirm", 1), "{}"));
        expectOk(post("/api/v1/mobile/agent/commands/{id}/cancel", 1));
        expectOk(json(post("/api/v1/mobile/agent/chat")
                .header(HttpHeaders.AUTHORIZATION, "Bearer test-token"), """
                {"messages":[{"role":"user","content":"Tình trạng chuyến đi"}]}
                """));
        expectOk(get("/api/v1/mobile/locations/autocomplete").param("query", "My Dinh").param("limit", "5"));
        expectOk(json(post("/api/v1/mobile/navigation/routes"), """
                {"originLat":21.0285,"originLng":105.8542,"destinationLat":21.0315,
                 "destinationLng":105.7667,"destinationName":"My Dinh","tripId":1}
                """));
        expectOk(json(post("/api/v1/mobile/navigation/reroute"), """
                {"sessionId":"nav-1","currentLat":21.0285,"currentLng":105.8542,
                 "gpsAccuracyMeters":8,"reason":"OFF_ROUTE_CONFIRMED"}
                """));
        expectOk(json(post("/api/v1/mobile/navigation/events"), """
                {"sessionId":"nav-1","eventType":"LOCATION_UPDATE","lat":21.0285,
                 "lng":105.8542,"distanceToRouteMeters":10,"gpsAccuracyMeters":8}
                """));
        expectOk(get("/api/v1/mobile/navigation/current"));

        MockMultipartFile image = new MockMultipartFile(
                "file", "voucher.jpg", MediaType.IMAGE_JPEG_VALUE, new byte[]{1, 2, 3}
        );
        expectOk(multipart("/api/v1/mobile/documents/ocr").file(image));
        expectOk(multipart("/api/v1/mobile/documents/ocr/jobs").file(image));
        expectOk(get("/api/v1/mobile/documents/ocr/jobs/{id}", 1));
        expectOk(delete("/api/v1/mobile/documents/ocr/jobs/{id}", 1));
        expectOk(multipart("/api/v1/mobile/evidence").file(image).param("incidentId", "1"));
    }

    @Test
    void warehouseReviewEvidenceAndAgentConfigurationApisHaveOneHappyCase() throws Exception {
        String warehouse = """
                {
                  "tripId":1,"issueDate":"2026-08-15","warehouseName":"Kho Hà Nội",
                  "projectName":"Dự án SafeFleet","recipientName":"Nguyễn Văn Nhận",
                  "items":[{"description":"Thiết bị GPS","unit":"cái","issuedQuantity":1}]
                }
                """;
        expectOk(json(post("/api/v1/warehouse-issues"), warehouse));
        expectOk(json(put("/api/v1/warehouse-issues/{id}", 1), warehouse));
        expectOk(get("/api/v1/warehouse-issues").param("status", "DRAFT"));
        expectOk(get("/api/v1/warehouse-issues/{id}", 1));
        expectOk(get("/api/v1/warehouse-issues/by-trip/{tripId}", 1));
        expectOk(post("/api/v1/warehouse-issues/{id}/issue", 1));
        expectOk(json(post("/api/v1/warehouse-issues/{id}/confirm", 1), """
                {"role":"DRIVER","status":"CONFIRMED","signerName":"Nguyễn Văn Tài"}
                """));

        expectOk(get("/api/v1/document-reviews").param("status", "REVIEW_REQUIRED"));
        expectOk(get("/api/v1/document-reviews/{id}", 1));
        when(documentPlateReviewService.image(1L)).thenReturn(
                new DocumentPlateReviewService.ReviewImage(new byte[]{1, 2, 3}, "image/jpeg", "voucher.jpg")
        );
        mockMvc.perform(get("/api/v1/document-reviews/{id}/image", 1)).andExpect(status().isOk());
        expectOk(json(post("/api/v1/document-reviews/{id}/approve", 1), "{\"note\":\"Khớp biển số\"}"));
        expectOk(json(post("/api/v1/document-reviews/{id}/reject", 1), "{\"note\":\"Sai biển số\"}"));

        expectOk(get("/api/v1/agent/config"));
        expectOk(json(put("/api/v1/agent/config"), "{\"enabled\":false}"));
        expectOk(post("/api/v1/agent/config/test"));

        EvidenceResponse metadata = new EvidenceResponse(
                1L, null, 1L, "evidence.jpg", "image/jpeg", 3,
                "sha256", LocalDateTime.now(), LocalDateTime.now(), "/api/v1/evidence/1/content"
        );
        when(evidenceService.content(1L)).thenReturn(
                new EvidenceContent(metadata, new ByteArrayResource(new byte[]{1, 2, 3}))
        );
        expectOk(get("/api/v1/evidence/{id}", 1));
        mockMvc.perform(get("/api/v1/evidence/{id}/content", 1)).andExpect(status().isOk());
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

    private String actionJson(String id) {
        return "{\"note\":\"Happy path\",\"clientEventId\":\"" + id + "\"}";
    }

    private String telemetryJson(String id) {
        return """
                {"clientEventId":"%s","vehicleId":1,"driverId":1,"tripId":1,
                 "lat":21.0285,"lng":105.8542,"speed":40,"heading":90,
                 "batteryLevel":90,"gpsStatus":"GOOD"}
                """.formatted(id);
    }

    private String routeJson() {
        return """
                {"startLat":21.0285,"startLng":105.8542,"endLat":21.0315,"endLng":105.7667}
                """;
    }

    private String routeCheckJson() {
        return """
                {"points":[{"lat":21.0285,"lng":105.8542},{"lat":21.0315,"lng":105.7667}]}
                """;
    }
}
