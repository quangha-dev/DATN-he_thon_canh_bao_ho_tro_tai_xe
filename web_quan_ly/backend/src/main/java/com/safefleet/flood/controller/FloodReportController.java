package com.safefleet.flood.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.flood.dto.request.CreateFloodReportRequest;
import com.safefleet.flood.dto.request.FloodActionRequest;
import com.safefleet.flood.dto.request.RouteCheckRequest;
import com.safefleet.flood.dto.response.FloodReportResponse;
import com.safefleet.flood.dto.response.RouteRiskSummaryResponse;
import com.safefleet.flood.dto.response.FloodWarningResponse;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.enums.FloodStatus;
import com.safefleet.flood.service.FloodReportService;
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

@Tag(name = "Flood Reports", description = "Flood point management and route risk APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/flood-reports")
public class FloodReportController {

    private final FloodReportService floodReportService;

    @Operation(summary = "App reports flood point")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<FloodReportResponse> create(@Valid @RequestBody CreateFloodReportRequest request) {
        return ApiResponse.ok("Flood report created", floodReportService.create(request));
    }

    @Operation(summary = "View flood points as table")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<PageResponse<FloodReportResponse>> search(@RequestParam(required = false) FloodSeverity severity,
                                                                 @RequestParam(required = false) FloodSource source,
                                                                 @RequestParam(required = false) FloodStatus status,
                                                                 Pageable pageable) {
        return ApiResponse.ok(floodReportService.search(severity, source, status, pageable));
    }

    @Operation(summary = "View flood points as map markers")
    @GetMapping("/map")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<List<FloodReportResponse>> map() {
        return ApiResponse.ok(floodReportService.map());
    }

    @Operation(summary = "Verify flood point")
    @PostMapping("/{id}/verify")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<FloodReportResponse> verify(@PathVariable Long id,
                                                   @RequestBody(required = false) FloodActionRequest request) {
        return ApiResponse.ok("Flood report verified",
                floodReportService.verify(id, request == null ? new FloodActionRequest(null) : request));
    }

    @Operation(summary = "Mark flood point as resolved")
    @PostMapping("/{id}/resolve")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<FloodReportResponse> resolve(@PathVariable Long id,
                                                    @RequestBody(required = false) FloodActionRequest request) {
        return ApiResponse.ok("Flood report resolved",
                floodReportService.resolve(id, request == null ? new FloodActionRequest(null) : request));
    }

    @Operation(summary = "Send a flood warning to drivers near the report")
    @PostMapping("/{id}/warn-nearby")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<FloodWarningResponse> warnNearby(@PathVariable Long id) {
        return ApiResponse.ok("Flood warning sent", floodReportService.warnNearby(id));
    }

    @Operation(summary = "Check whether route intersects risky flood points")
    @PostMapping("/route-check")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<RouteRiskSummaryResponse> routeCheck(@Valid @RequestBody RouteCheckRequest request) {
        return ApiResponse.ok(floodReportService.routeRisk(request));
    }

    @Operation(summary = "Get route flood risk summary")
    @PostMapping("/route-risk-summary")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<RouteRiskSummaryResponse> routeRiskSummary(@Valid @RequestBody RouteCheckRequest request) {
        return ApiResponse.ok(floodReportService.routeRisk(request));
    }
}
