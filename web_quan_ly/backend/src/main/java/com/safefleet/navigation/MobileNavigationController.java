package com.safefleet.navigation;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.location.dto.response.LocationSuggestionResponse;
import com.safefleet.location.service.LocationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
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
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/mobile")
@PreAuthorize("hasRole('DRIVER')")
@Tag(name = "Mobile Navigation", description = "Hanoi routing, flood avoidance and off-route handling")
public class MobileNavigationController {

    private final LocationService locationService;
    private final NavigationService navigationService;

    @GetMapping("/locations/autocomplete")
    @Operation(summary = "Search Hanoi destinations through backend Photon proxy with local fallback")
    public ApiResponse<List<LocationSuggestionResponse>> autocomplete(
            @RequestParam @Size(min = 2, max = 120) String query,
            @RequestParam(defaultValue = "6") @Min(1) @Max(10) Integer limit) {
        return ApiResponse.ok(locationService.autocomplete(query, limit));
    }

    @PostMapping("/navigation/routes")
    @Operation(summary = "Create alternatives, score active floods and select the least-risk route")
    public ApiResponse<NavigationSessionResponse> routes(
            @Valid @RequestBody NavigationRouteRequest request) {
        return ApiResponse.ok("Đã tạo các phương án dẫn đường", navigationService.routes(request));
    }

    @PostMapping("/navigation/reroute")
    @Operation(summary = "Recalculate a driver-owned active navigation session")
    public ApiResponse<NavigationSessionResponse> reroute(
            @Valid @RequestBody NavigationRerouteRequest request) {
        return ApiResponse.ok("Đã tính lại tuyến đường", navigationService.reroute(request));
    }

    @PostMapping("/navigation/events")
    @Operation(summary = "Store navigation event and confirm off-route after 15 continuous seconds")
    public ApiResponse<NavigationEventResponse> event(
            @Valid @RequestBody NavigationEventRequest request) {
        return ApiResponse.ok("Đã ghi nhận sự kiện dẫn đường", navigationService.event(request));
    }

    @GetMapping("/navigation/current")
    @Operation(summary = "Get current navigation session with offline-cacheable geometry and steps")
    public ApiResponse<NavigationSessionResponse> current() {
        return ApiResponse.ok(navigationService.current());
    }
}
