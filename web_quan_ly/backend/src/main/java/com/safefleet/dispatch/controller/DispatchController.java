package com.safefleet.dispatch.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.dispatch.dto.response.AvailabilityResponse;
import com.safefleet.dispatch.dto.response.DispatchSuggestionResponse;
import com.safefleet.dispatch.service.DispatchService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Dispatch", description = "Vehicle and driver availability and suggestion APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/dispatch")
public class DispatchController {

    private final DispatchService dispatchService;

    @Operation(summary = "Suggest suitable vehicle and driver pairs")
    @GetMapping("/suggestions")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<List<DispatchSuggestionResponse>> suggestions(@RequestParam(required = false) Double startLat,
                                                                     @RequestParam(required = false) Double startLng,
                                                                     @RequestParam(defaultValue = "10") int limit) {
        return ApiResponse.ok(dispatchService.suggestions(startLat, startLng, limit));
    }

    @Operation(summary = "Check vehicle and driver availability before assignment")
    @GetMapping("/availability")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<AvailabilityResponse> availability(@RequestParam Long vehicleId,
                                                          @RequestParam Long driverId) {
        return ApiResponse.ok(dispatchService.availability(vehicleId, driverId));
    }
}
