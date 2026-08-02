package com.safefleet.safety.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.incident.dto.response.IncidentResponse;
import com.safefleet.safety.dto.request.CreateSafetyEventRequest;
import com.safefleet.safety.dto.request.SafetyEventActionRequest;
import com.safefleet.safety.dto.response.SafetyEventResponse;
import com.safefleet.safety.enums.AlertSeverity;
import com.safefleet.safety.enums.SafetyEventStatus;
import com.safefleet.safety.enums.SafetyEventType;
import com.safefleet.safety.service.SafetyEventService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;

@Tag(name = "Safety Events", description = "AI driver behavior and safety alert APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/safety-events")
public class SafetyEventController {

    private final SafetyEventService safetyEventService;

    @Operation(summary = "App submits AI safety event")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<SafetyEventResponse> create(@Valid @RequestBody CreateSafetyEventRequest request) {
        return ApiResponse.ok("Safety event created", safetyEventService.create(request));
    }

    @Operation(summary = "Search safety events")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<PageResponse<SafetyEventResponse>> search(
            @RequestParam(required = false) SafetyEventType eventType,
            @RequestParam(required = false) AlertSeverity severity,
            @RequestParam(required = false) SafetyEventStatus status,
            @RequestParam(required = false) Long vehicleId,
            @RequestParam(required = false) Long driverId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to,
            Pageable pageable) {
        return ApiResponse.ok(safetyEventService.search(eventType, severity, status, vehicleId, driverId, from, to, pageable));
    }

    @Operation(summary = "Get safety event detail")
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<SafetyEventResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(safetyEventService.get(id));
    }

    @Operation(summary = "Acknowledge safety event")
    @PostMapping("/{id}/acknowledge")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<SafetyEventResponse> acknowledge(@PathVariable Long id,
                                                        @RequestBody(required = false) SafetyEventActionRequest request) {
        return ApiResponse.ok("Safety event acknowledged",
                safetyEventService.acknowledge(id, request == null ? new SafetyEventActionRequest(null) : request));
    }

    @Operation(summary = "Resolve safety event")
    @PostMapping("/{id}/resolve")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<SafetyEventResponse> resolve(@PathVariable Long id,
                                                    @RequestBody(required = false) SafetyEventActionRequest request) {
        return ApiResponse.ok("Safety event resolved",
                safetyEventService.resolve(id, request == null ? new SafetyEventActionRequest(null) : request));
    }

    @Operation(summary = "Dismiss safety event")
    @PostMapping("/{id}/dismiss")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<SafetyEventResponse> dismiss(@PathVariable Long id,
                                                    @RequestBody(required = false) SafetyEventActionRequest request) {
        return ApiResponse.ok("Safety event dismissed",
                safetyEventService.dismiss(id, request == null ? new SafetyEventActionRequest(null) : request));
    }

    @Operation(summary = "Create incident from safety event")
    @PostMapping("/{id}/create-incident")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<IncidentResponse> createIncident(@PathVariable Long id) {
        return ApiResponse.ok("Incident created from safety event", safetyEventService.createIncident(id));
    }
}
