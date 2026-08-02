package com.safefleet.incident.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.incident.dto.request.AssignIncidentRequest;
import com.safefleet.incident.dto.request.CreateIncidentRequest;
import com.safefleet.incident.dto.request.IncidentTimelineRequest;
import com.safefleet.incident.dto.request.SosRequest;
import com.safefleet.incident.dto.response.IncidentResponse;
import com.safefleet.incident.dto.response.IncidentTimelineResponse;
import com.safefleet.incident.enums.IncidentStatus;
import com.safefleet.incident.enums.IncidentType;
import com.safefleet.incident.service.IncidentService;
import com.safefleet.safety.enums.AlertSeverity;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Incidents", description = "SOS, rescue and incident management APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/incidents")
public class IncidentController {

    private final IncidentService incidentService;

    @Operation(summary = "Driver submits SOS")
    @PostMapping("/sos")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<IncidentResponse> sos(@Valid @RequestBody SosRequest request) {
        return ApiResponse.ok("SOS submitted", incidentService.sos(request));
    }

    @Operation(summary = "Create manual incident")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<IncidentResponse> create(@Valid @RequestBody CreateIncidentRequest request) {
        return ApiResponse.ok("Incident created", incidentService.create(request));
    }

    @Operation(summary = "Search incidents")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER','RESCUE_TEAM')")
    public ApiResponse<PageResponse<IncidentResponse>> search(@RequestParam(required = false) IncidentType type,
                                                              @RequestParam(required = false) AlertSeverity severity,
                                                              @RequestParam(required = false) IncidentStatus status,
                                                              @RequestParam(required = false) Long vehicleId,
                                                              @RequestParam(required = false) Long driverId,
                                                              Pageable pageable) {
        return ApiResponse.ok(incidentService.search(type, severity, status, vehicleId, driverId, pageable));
    }

    @Operation(summary = "Get incident detail")
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER','RESCUE_TEAM')")
    public ApiResponse<IncidentResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(incidentService.get(id));
    }

    @Operation(summary = "Accept incident")
    @PostMapping("/{id}/accept")
    @PreAuthorize("hasAnyRole('ADMIN','DISPATCHER','RESCUE_TEAM')")
    public ApiResponse<IncidentResponse> accept(@PathVariable Long id) {
        return ApiResponse.ok("Incident accepted", incidentService.accept(id));
    }

    @Operation(summary = "Assign incident to rescue team user")
    @PostMapping("/{id}/assign")
    @PreAuthorize("hasAnyRole('ADMIN','DISPATCHER')")
    public ApiResponse<IncidentResponse> assign(@PathVariable Long id,
                                                @Valid @RequestBody AssignIncidentRequest request) {
        return ApiResponse.ok("Incident assigned", incidentService.assign(id, request));
    }

    @Operation(summary = "Add incident timeline note")
    @PostMapping("/{id}/timeline")
    @PreAuthorize("hasAnyRole('ADMIN','DISPATCHER','SAFETY_OFFICER','RESCUE_TEAM')")
    public ApiResponse<IncidentTimelineResponse> addTimeline(@PathVariable Long id,
                                                             @Valid @RequestBody IncidentTimelineRequest request) {
        return ApiResponse.ok("Timeline added", incidentService.addTimeline(id, request));
    }

    @Operation(summary = "Get incident timeline")
    @GetMapping("/{id}/timeline")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER','RESCUE_TEAM')")
    public ApiResponse<List<IncidentTimelineResponse>> timeline(@PathVariable Long id) {
        return ApiResponse.ok(incidentService.timeline(id));
    }

    @Operation(summary = "Close incident")
    @PostMapping("/{id}/close")
    @PreAuthorize("hasAnyRole('ADMIN','DISPATCHER','RESCUE_TEAM')")
    public ApiResponse<IncidentResponse> close(@PathVariable Long id,
                                               @Valid @RequestBody IncidentTimelineRequest request) {
        return ApiResponse.ok("Incident closed", incidentService.close(id, request));
    }
}
