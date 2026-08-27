package com.safefleet.location.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.location.dto.request.RouteRequest;
import com.safefleet.location.dto.response.LocationSuggestionResponse;
import com.safefleet.location.dto.response.RouteResponse;
import com.safefleet.location.service.LocationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Validated
@Tag(name = "Locations", description = "Location autocomplete and route calculation without Google Maps key")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/locations")
public class LocationController {

    private final LocationService locationService;

    @Operation(summary = "Autocomplete real locations using OpenStreetMap Photon")
    @GetMapping("/autocomplete")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<List<LocationSuggestionResponse>> autocomplete(
            @RequestParam @Size(min = 2, max = 120) String query,
            @RequestParam(defaultValue = "6") @Min(1) @Max(10) Integer limit) {
        return ApiResponse.ok(locationService.autocomplete(query, limit));
    }

    @Operation(summary = "Name a point picked on the map")
    @GetMapping("/reverse")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<LocationSuggestionResponse> reverse(
            @RequestParam @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
            @RequestParam @DecimalMin("-180.0") @DecimalMax("180.0") Double lng) {
        return ApiResponse.ok(locationService.reverse(lat, lng));
    }

    @Operation(summary = "Calculate route distance and ETA using OSRM with local fallback")
    @PostMapping("/route")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<RouteResponse> route(@Valid @RequestBody RouteRequest request) {
        return ApiResponse.ok(locationService.route(request));
    }
}
