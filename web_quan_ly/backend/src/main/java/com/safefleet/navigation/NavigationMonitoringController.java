package com.safefleet.navigation;

import com.safefleet.common.dto.ApiResponse;
import jakarta.validation.constraints.Positive;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/navigation/monitoring")
@PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER','RESCUE_TEAM')")
public class NavigationMonitoringController {

    private final NavigationService navigationService;

    @GetMapping("/active")
    public ApiResponse<NavigationSessionResponse> activeRoute(
            @RequestParam @Positive Long vehicleId) {
        return ApiResponse.ok(navigationService.activeForVehicle(vehicleId));
    }
}
