package com.safefleet.report.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.driver.dto.response.DriverResponse;
import com.safefleet.report.dto.response.DailyTripCountResponse;
import com.safefleet.report.service.ReportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@Tag(name = "Reports", description = "Fleet, safety, trip, flood and incident reports")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/reports")
public class ReportController {

    private final ReportService reportService;

    @Operation(summary = "Vehicle count by status")
    @GetMapping("/vehicles/status")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<Map<String, Long>> vehicleStatus() {
        return ApiResponse.ok(reportService.vehicleStatus());
    }

    @Operation(summary = "Safety alert count by event type")
    @GetMapping("/safety-events/by-type")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<Map<String, Long>> safetyEventsByType() {
        return ApiResponse.ok(reportService.safetyEventsByType());
    }

    @Operation(summary = "Trip count by day")
    @GetMapping("/trips/by-day")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<List<DailyTripCountResponse>> tripsByDay(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(reportService.tripsByDay(from, to));
    }

    @Operation(summary = "Top high-risk drivers")
    @GetMapping("/drivers/high-risk")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','SAFETY_OFFICER')")
    public ApiResponse<List<DriverResponse>> highRiskDrivers() {
        return ApiResponse.ok(reportService.highRiskDrivers());
    }

    @Operation(summary = "Driver report")
    @GetMapping("/drivers/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','SAFETY_OFFICER')")
    public ApiResponse<Map<String, Object>> driverReport(@PathVariable Long id) {
        return ApiResponse.ok(reportService.driverReport(id));
    }

    @Operation(summary = "Vehicle report")
    @GetMapping("/vehicles/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','SAFETY_OFFICER')")
    public ApiResponse<Map<String, Object>> vehicleReport(@PathVariable Long id) {
        return ApiResponse.ok(reportService.vehicleReport(id));
    }

    @Operation(summary = "Flood report")
    @GetMapping("/flood")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<Map<String, Map<String, Long>>> floodReport() {
        return ApiResponse.ok(reportService.floodReport());
    }

    @Operation(summary = "Incident report")
    @GetMapping("/incidents")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER','RESCUE_TEAM')")
    public ApiResponse<Map<String, Map<String, Long>>> incidentReport() {
        return ApiResponse.ok(reportService.incidentReport());
    }
}
