package com.safefleet.telemetry.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.telemetry.dto.request.TelemetryRequest;
import com.safefleet.telemetry.dto.response.TelemetryResponse;
import com.safefleet.telemetry.service.TelemetryService;
import com.safefleet.vehicle.dto.response.VehicleRealtimeStatusResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
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
import java.util.List;

@Tag(name = "Telemetry", description = "Realtime GPS telemetry ingestion and replay APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/telemetry")
public class TelemetryController {

    private final TelemetryService telemetryService;

    @Operation(summary = "App submits GPS and speed telemetry")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<TelemetryResponse> ingest(@Valid @RequestBody TelemetryRequest request) {
        return ApiResponse.ok("Telemetry ingested", telemetryService.ingest(request));
    }

    @Operation(summary = "Get all current vehicle positions")
    @GetMapping("/vehicles/current")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<List<VehicleRealtimeStatusResponse>> currentVehicles() {
        return ApiResponse.ok(telemetryService.currentVehicles());
    }

    @Operation(summary = "Get GPS history of a trip")
    @GetMapping("/trips/{tripId}/history")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<List<TelemetryResponse>> tripHistory(
            @PathVariable Long tripId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to) {
        return ApiResponse.ok(telemetryService.tripHistory(tripId, from, to));
    }

    @Operation(summary = "Replay trip GPS path")
    @GetMapping("/trips/{tripId}/replay")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<List<TelemetryResponse>> replay(@PathVariable Long tripId) {
        return ApiResponse.ok(telemetryService.replay(tripId));
    }
}
