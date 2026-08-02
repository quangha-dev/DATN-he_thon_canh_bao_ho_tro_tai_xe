package com.safefleet.safety.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.safety.dto.request.StartDrivingSessionRequest;
import com.safefleet.safety.dto.response.DrivingSessionResponse;
import com.safefleet.safety.dto.response.RemainingDrivingTimeResponse;
import com.safefleet.safety.service.DrivingTimeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Driving Time", description = "Configurable driving time rule engine APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/driving-sessions")
public class DrivingSessionController {

    private final DrivingTimeService drivingTimeService;

    @Operation(summary = "App starts driving session")
    @PostMapping("/start")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<DrivingSessionResponse> start(@Valid @RequestBody StartDrivingSessionRequest request) {
        return ApiResponse.ok("Driving session started", drivingTimeService.start(request));
    }

    @Operation(summary = "App pauses driving session")
    @PostMapping("/{id}/pause")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<DrivingSessionResponse> pause(@PathVariable Long id) {
        return ApiResponse.ok("Driving session paused", drivingTimeService.pause(id));
    }

    @Operation(summary = "App resumes driving session")
    @PostMapping("/{id}/resume")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<DrivingSessionResponse> resume(@PathVariable Long id) {
        return ApiResponse.ok("Driving session resumed", drivingTimeService.resume(id));
    }

    @Operation(summary = "App finishes driving session")
    @PostMapping("/{id}/finish")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<DrivingSessionResponse> finish(@PathVariable Long id) {
        return ApiResponse.ok("Driving session finished", drivingTimeService.finish(id));
    }

    @Operation(summary = "Check how long driver can continue driving")
    @GetMapping("/drivers/{driverId}/remaining-time")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<RemainingDrivingTimeResponse> remainingTime(@PathVariable Long driverId) {
        return ApiResponse.ok(drivingTimeService.remainingTime(driverId));
    }
}
