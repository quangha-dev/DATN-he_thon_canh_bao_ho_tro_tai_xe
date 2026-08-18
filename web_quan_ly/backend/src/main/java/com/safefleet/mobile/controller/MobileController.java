package com.safefleet.mobile.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.flood.dto.request.CreateFloodReportRequest;
import com.safefleet.flood.dto.request.RouteCheckRequest;
import com.safefleet.flood.dto.response.FloodReportResponse;
import com.safefleet.flood.dto.response.RouteRiskSummaryResponse;
import com.safefleet.incident.dto.request.SosRequest;
import com.safefleet.incident.dto.response.IncidentResponse;
import com.safefleet.incident.dto.response.IncidentTimelineResponse;
import com.safefleet.incident.enums.IncidentStatus;
import com.safefleet.mobile.dto.request.MobileAgentCommandRequest;
import com.safefleet.mobile.dto.request.MobileAgentChatRequest;
import com.safefleet.mobile.dto.request.MobileAgentConfirmRequest;
import com.safefleet.mobile.dto.request.MobilePreTripChecklistRequest;
import com.safefleet.mobile.dto.request.MobilePushTokenRequest;
import com.safefleet.mobile.dto.request.MobileQuickFloodReportRequest;
import com.safefleet.mobile.dto.request.MobileTelemetryBatchRequest;
import com.safefleet.mobile.dto.response.MobileAgentCommandResponse;
import com.safefleet.mobile.dto.response.MobileAgentChatResponse;
import com.safefleet.mobile.dto.response.MobileBootstrapResponse;
import com.safefleet.mobile.dto.response.MobileConfigResponse;
import com.safefleet.mobile.dto.response.MobileMonthlyActivityResponse;
import com.safefleet.mobile.dto.response.MobileCurrentAssignmentResponse;
import com.safefleet.mobile.dto.response.MobileDocumentOcrResponse;
import com.safefleet.mobile.dto.response.MobileDocumentOcrJobResponse;
import com.safefleet.mobile.dto.response.MobilePreTripChecklistResponse;
import com.safefleet.mobile.dto.response.MobileProfileResponse;
import com.safefleet.mobile.dto.response.MobilePushTokenResponse;
import com.safefleet.mobile.dto.response.MobileSafetySummaryResponse;
import com.safefleet.mobile.dto.response.MobileTripSummaryResponse;
import com.safefleet.mobile.dto.response.MobileTelemetryBatchResponse;
import com.safefleet.mobile.dto.response.MobileWorkflowResponse;
import com.safefleet.safety.dto.response.DrivingSessionResponse;
import com.safefleet.mobile.service.MobileAppService;
import com.safefleet.infrastructure.ai.SafeFleetAiGateway;
import com.safefleet.mobile.service.DocumentOcrService;
import com.safefleet.mobile.service.DocumentOcrJobService;
import com.safefleet.notification.dto.response.NotificationResponse;
import com.safefleet.notification.service.PushNotificationService;
import com.safefleet.safety.dto.request.CreateSafetyEventRequest;
import com.safefleet.safety.dto.response.SafetyEventResponse;
import com.safefleet.telemetry.dto.request.TelemetryRequest;
import com.safefleet.telemetry.dto.response.TelemetryResponse;
import com.safefleet.trip.dto.request.TripActionRequest;
import com.safefleet.trip.dto.response.TripResponse;
import com.safefleet.warehouse.dto.response.WarehouseIssueResponse;
import com.safefleet.warehouse.service.WarehouseIssueService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.http.MediaType;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.time.LocalDate;
import java.time.YearMonth;
import com.safefleet.trip.enums.TripStatus;

@Validated
@Tag(name = "Mobile Driver App", description = "Facade APIs for the driver mobile application")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/mobile")
@PreAuthorize("hasRole('DRIVER')")
public class MobileController {

    private final MobileAppService mobileAppService;
    private final PushNotificationService pushNotificationService;
    private final SafeFleetAiGateway aiGateway;
    private final DocumentOcrService documentOcrService;
    private final DocumentOcrJobService documentOcrJobService;
    private final WarehouseIssueService warehouseIssueService;

    @Operation(summary = "Get current driver mobile profile")
    @GetMapping("/me")
    public ApiResponse<MobileProfileResponse> profile() {
        return ApiResponse.ok(mobileAppService.profile());
    }

    @Operation(summary = "Bootstrap all data required for the driver home screen")
    @GetMapping("/bootstrap")
    public ApiResponse<MobileBootstrapResponse> bootstrap() {
        return ApiResponse.ok(mobileAppService.bootstrap());
    }

    @Operation(summary = "Get current driver safety summary")
    @GetMapping("/safety-summary")
    public ApiResponse<MobileSafetySummaryResponse> safetySummary() {
        return ApiResponse.ok(mobileAppService.safetySummary());
    }

    @Operation(summary = "Get authenticated driver's monthly activity overview")
    @GetMapping("/activity/monthly")
    public ApiResponse<MobileMonthlyActivityResponse> monthlyActivity(
            @RequestParam(required = false) YearMonth month) {
        return ApiResponse.ok(mobileAppService.monthlyActivity(month));
    }

    @Operation(summary = "Chat with the SafeFleet driver assistant")
    @PostMapping("/agent/chat")
    public ApiResponse<MobileAgentChatResponse> agentChat(
            @Valid @RequestBody MobileAgentChatRequest request,
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
        return ApiResponse.ok(aiGateway.respond(request, authorization));
    }

    @Operation(summary = "Get mobile runtime config")
    @GetMapping("/config")
    public ApiResponse<MobileConfigResponse> config() {
        return ApiResponse.ok(mobileAppService.config());
    }

    @Operation(summary = "OCR a warehouse issue/driving-log photo on the server")
    @PostMapping(value = "/documents/ocr", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<MobileDocumentOcrResponse> documentOcr(@RequestParam MultipartFile file) {
        return ApiResponse.ok("Đã nhận dạng phiếu", documentOcrService.recognize(file));
    }

    @Operation(summary = "Submit a warehouse issue/driving-log photo for asynchronous OCR")
    @PostMapping(value = "/documents/ocr/jobs", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<MobileDocumentOcrJobResponse> submitDocumentOcr(@RequestParam MultipartFile file) {
        return ApiResponse.ok("Ảnh đã được gửi lên máy chủ", documentOcrJobService.submit(file));
    }

    @Operation(summary = "Get the authenticated driver's OCR job status and result")
    @GetMapping("/documents/ocr/jobs/{id}")
    public ApiResponse<MobileDocumentOcrJobResponse> documentOcrJob(@PathVariable Long id) {
        return ApiResponse.ok(documentOcrJobService.get(id));
    }

    @Operation(summary = "Cancel and delete the authenticated driver's OCR job")
    @DeleteMapping("/documents/ocr/jobs/{id}")
    public ApiResponse<Void> deleteDocumentOcrJob(@PathVariable Long id) {
        documentOcrJobService.delete(id);
        return ApiResponse.ok("Đã xoá tác vụ OCR");
    }

    @Operation(summary = "Get current active assignment for driver")
    @GetMapping("/current-assignment")
    public ApiResponse<MobileCurrentAssignmentResponse> currentAssignment() {
        return ApiResponse.ok(mobileAppService.currentAssignment());
    }

    @Operation(summary = "Get today's trips for driver")
    @GetMapping("/trips/today")
    public ApiResponse<List<TripResponse>> todayTrips() {
        return ApiResponse.ok(mobileAppService.todayTrips());
    }

    @Operation(summary = "Query authenticated driver's trips")
    @GetMapping("/trips")
    public ApiResponse<List<TripResponse>> trips(
            @RequestParam List<TripStatus> statuses,
            @RequestParam(required = false) LocalDate startDate,
            @RequestParam(required = false) LocalDate endDate,
            @RequestParam(defaultValue = "20") int limit) {
        return ApiResponse.ok(mobileAppService.trips(statuses, startDate, endDate, limit));
    }

    @Operation(summary = "Get mobile trip detail")
    @GetMapping("/trips/{id}")
    public ApiResponse<TripResponse> trip(@PathVariable Long id) {
        return ApiResponse.ok(mobileAppService.trip(id));
    }

    @Operation(summary = "Get normalized warehouse issue for a driver trip")
    @GetMapping("/trips/{id}/warehouse-issue")
    public ApiResponse<WarehouseIssueResponse> warehouseIssue(@PathVariable Long id) {
        return ApiResponse.ok(warehouseIssueService.getByTrip(id));
    }

    @Operation(summary = "Get mobile trip summary")
    @GetMapping("/trips/{id}/summary")
    public ApiResponse<MobileTripSummaryResponse> tripSummary(@PathVariable Long id) {
        return ApiResponse.ok(mobileAppService.tripSummary(id));
    }

    @Operation(summary = "Submit pre-trip checklist")
    @PostMapping("/trips/{id}/pre-trip-checklist")
    public ApiResponse<MobilePreTripChecklistResponse> submitChecklist(@PathVariable Long id,
                                                                       @Valid @RequestBody MobilePreTripChecklistRequest request) {
        return ApiResponse.ok("Checklist đã được ghi nhận", mobileAppService.submitChecklist(id, request));
    }

    @Operation(summary = "Accept assigned trip")
    @PostMapping("/trips/{id}/accept")
    public ApiResponse<TripResponse> acceptTrip(@PathVariable Long id,
                                                @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã nhận chuyến", mobileAppService.acceptTrip(id, request));
    }

    @Operation(summary = "Reject assigned trip")
    @PostMapping("/trips/{id}/reject")
    public ApiResponse<TripResponse> rejectTrip(@PathVariable Long id,
                                                @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã từ chối chuyến", mobileAppService.rejectTrip(id, request));
    }

    @Operation(summary = "Start trip")
    @PostMapping("/trips/{id}/start")
    public ApiResponse<TripResponse> startTrip(@PathVariable Long id,
                                               @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã bắt đầu chuyến", mobileAppService.startTrip(id, request));
    }

    @Operation(summary = "Pause trip")
    @PostMapping("/trips/{id}/pause")
    public ApiResponse<TripResponse> pauseTrip(@PathVariable Long id,
                                               @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã tạm nghỉ", mobileAppService.pauseTrip(id, request));
    }

    @Operation(summary = "Resume trip")
    @PostMapping("/trips/{id}/resume")
    public ApiResponse<TripResponse> resumeTrip(@PathVariable Long id,
                                                @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã tiếp tục chuyến", mobileAppService.resumeTrip(id, request));
    }

    @Operation(summary = "Complete trip")
    @PostMapping("/trips/{id}/complete")
    public ApiResponse<TripResponse> completeTrip(@PathVariable Long id,
                                                  @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã hoàn thành chuyến", mobileAppService.completeTrip(id, request));
    }

    @Operation(summary = "Atomically start trip, driving and navigation workflows")
    @PostMapping("/trips/{id}/start-workflow")
    public ApiResponse<MobileWorkflowResponse> startWorkflow(@PathVariable Long id,
                                                             @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã bắt đầu quy trình chuyến", mobileAppService.startWorkflow(id, request));
    }

    @Operation(summary = "Atomically pause trip, driving and navigation workflows")
    @PostMapping("/trips/{id}/pause-workflow")
    public ApiResponse<MobileWorkflowResponse> pauseWorkflow(@PathVariable Long id,
                                                             @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã tạm nghỉ quy trình chuyến", mobileAppService.pauseWorkflow(id, request));
    }

    @Operation(summary = "Atomically resume trip, driving and navigation workflows")
    @PostMapping("/trips/{id}/resume-workflow")
    public ApiResponse<MobileWorkflowResponse> resumeWorkflow(@PathVariable Long id,
                                                              @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã tiếp tục quy trình chuyến", mobileAppService.resumeWorkflow(id, request));
    }

    @Operation(summary = "Atomically complete trip, driving and navigation workflows")
    @PostMapping("/trips/{id}/complete-workflow")
    public ApiResponse<MobileWorkflowResponse> completeWorkflow(@PathVariable Long id,
                                                                @RequestBody(required = false) TripActionRequest request) {
        return ApiResponse.ok("Đã hoàn thành quy trình chuyến", mobileAppService.completeWorkflow(id, request));
    }

    @Operation(summary = "Get current driving session")
    @GetMapping("/driving-sessions/current")
    public ApiResponse<DrivingSessionResponse> currentDrivingSession() {
        return ApiResponse.ok(mobileAppService.currentDrivingSession());
    }

    @Operation(summary = "Send telemetry from driver app")
    @PostMapping("/telemetry")
    public ApiResponse<TelemetryResponse> ingestTelemetry(@Valid @RequestBody TelemetryRequest request) {
        return ApiResponse.ok("GPS đã được ghi nhận", mobileAppService.ingestTelemetry(request));
    }

    @Operation(summary = "Ingest an offline telemetry batch with per-item acknowledgements")
    @PostMapping("/telemetry/batch")
    public ApiResponse<MobileTelemetryBatchResponse> ingestTelemetryBatch(
            @Valid @RequestBody MobileTelemetryBatchRequest request) {
        return ApiResponse.ok("Đã đồng bộ batch GPS", mobileAppService.ingestTelemetryBatch(request));
    }

    @Operation(summary = "Get today's safety events for driver")
    @GetMapping("/safety-events/today")
    public ApiResponse<PageResponse<SafetyEventResponse>> todaySafetyEvents(Pageable pageable) {
        return ApiResponse.ok(mobileAppService.todaySafetyEvents(pageable));
    }

    @Operation(summary = "Submit AI safety event from driver app")
    @PostMapping("/safety-events")
    public ApiResponse<SafetyEventResponse> createSafetyEvent(@Valid @RequestBody CreateSafetyEventRequest request) {
        return ApiResponse.ok("Cảnh báo đã được ghi nhận", mobileAppService.createSafetyEvent(request));
    }

    @Operation(summary = "Send SOS from driver app")
    @PostMapping("/incidents/sos")
    public ApiResponse<IncidentResponse> sendSos(@Valid @RequestBody SosRequest request) {
        return ApiResponse.ok("SOS đã được gửi", mobileAppService.sendSos(request));
    }

    @Operation(summary = "Get driver incidents")
    @GetMapping("/incidents")
    public ApiResponse<PageResponse<IncidentResponse>> incidents(@RequestParam(required = false) IncidentStatus status,
                                                                 Pageable pageable) {
        return ApiResponse.ok(mobileAppService.incidents(status, pageable));
    }

    @Operation(summary = "Get driver incident detail")
    @GetMapping("/incidents/{id}")
    public ApiResponse<IncidentResponse> incident(@PathVariable Long id) {
        return ApiResponse.ok(mobileAppService.incident(id));
    }

    @Operation(summary = "Get owned incident timeline")
    @GetMapping("/incidents/{id}/timeline")
    public ApiResponse<List<IncidentTimelineResponse>> incidentTimeline(@PathVariable Long id) {
        return ApiResponse.ok(mobileAppService.incidentTimeline(id));
    }

    @Operation(summary = "Submit flood report")
    @PostMapping("/flood-reports")
    public ApiResponse<FloodReportResponse> createFloodReport(@Valid @RequestBody CreateFloodReportRequest request) {
        return ApiResponse.ok("Điểm ngập đã được ghi nhận", mobileAppService.createFloodReport(request));
    }

    @Operation(summary = "Submit quick flood report using current driver")
    @PostMapping("/flood-reports/quick")
    public ApiResponse<FloodReportResponse> quickFloodReport(@Valid @RequestBody MobileQuickFloodReportRequest request) {
        return ApiResponse.ok("Điểm ngập đã được ghi nhận", mobileAppService.quickFloodReport(request));
    }

    @Operation(summary = "Get nearby active flood points")
    @GetMapping("/flood-points/nearby")
    public ApiResponse<List<FloodReportResponse>> nearbyFloodPoints(
            @RequestParam @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
            @RequestParam @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double lng,
            @RequestParam(required = false) Double radiusKm) {
        return ApiResponse.ok(mobileAppService.nearbyFloodPoints(lat, lng, radiusKm));
    }

    @Operation(summary = "Check flood risk for route")
    @PostMapping("/route-check")
    public ApiResponse<RouteRiskSummaryResponse> routeCheck(@Valid @RequestBody RouteCheckRequest request) {
        return ApiResponse.ok(mobileAppService.routeCheck(request));
    }

    @Operation(summary = "Submit driver agent command")
    @PostMapping("/agent/command")
    public ApiResponse<MobileAgentCommandResponse> submitAgentCommand(@Valid @RequestBody MobileAgentCommandRequest request) {
        return ApiResponse.ok("Lệnh đã được ghi nhận", mobileAppService.submitAgentCommand(request));
    }

    @Operation(summary = "Confirm and execute an understood driver agent command")
    @PostMapping("/agent/commands/{id}/confirm")
    public ApiResponse<MobileAgentCommandResponse> confirmAgentCommand(
            @PathVariable Long id,
            @Valid @RequestBody(required = false) MobileAgentConfirmRequest request) {
        return ApiResponse.ok(
                "Lệnh đã được xác nhận và thực thi",
                mobileAppService.confirmAgentCommand(
                        id,
                        request == null
                                ? new MobileAgentConfirmRequest(null, null, null, null, null)
                                : request
                )
        );
    }

    @Operation(summary = "Cancel an understood driver agent command")
    @PostMapping("/agent/commands/{id}/cancel")
    public ApiResponse<MobileAgentCommandResponse> cancelAgentCommand(@PathVariable Long id) {
        return ApiResponse.ok("Lệnh đã được hủy", mobileAppService.cancelAgentCommand(id));
    }

    @Operation(summary = "Get driver agent command history")
    @GetMapping("/agent/history")
    public ApiResponse<PageResponse<MobileAgentCommandResponse>> agentHistory(Pageable pageable) {
        return ApiResponse.ok(mobileAppService.agentHistory(pageable));
    }

    @Operation(summary = "Get current user notifications")
    @GetMapping("/notifications")
    public ApiResponse<PageResponse<NotificationResponse>> notifications(Pageable pageable) {
        return ApiResponse.ok(mobileAppService.notifications(pageable));
    }

    @Operation(summary = "Mark notification as read")
    @PatchMapping("/notifications/{id}/read")
    public ApiResponse<NotificationResponse> markNotificationRead(@PathVariable Long id) {
        return ApiResponse.ok("Đã đọc thông báo", mobileAppService.markNotificationRead(id));
    }

    @Operation(summary = "Mark all notifications as read")
    @PatchMapping("/notifications/read-all")
    public ApiResponse<Void> markAllNotificationsRead() {
        mobileAppService.markAllNotificationsRead();
        return ApiResponse.ok("Đã đọc tất cả thông báo");
    }

    @Operation(summary = "Register or refresh this device push token")
    @PostMapping("/push-tokens")
    public ApiResponse<MobilePushTokenResponse> registerPushToken(
            @Valid @RequestBody MobilePushTokenRequest request) {
        return ApiResponse.ok("Push token đã được đăng ký", pushNotificationService.register(request));
    }

    @Operation(summary = "Disable push tokens belonging to this device")
    @DeleteMapping("/push-tokens/{deviceUuid}")
    public ApiResponse<Void> unregisterPushToken(@PathVariable String deviceUuid) {
        pushNotificationService.unregister(deviceUuid);
        return ApiResponse.ok("Push token đã được vô hiệu hóa");
    }
}
