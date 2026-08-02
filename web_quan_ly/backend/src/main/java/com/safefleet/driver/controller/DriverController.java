package com.safefleet.driver.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.driver.dto.request.CreateDriverRequest;
import com.safefleet.driver.dto.request.UpdateDriverRequest;
import com.safefleet.driver.dto.response.DriverResponse;
import com.safefleet.driver.dto.response.DrivingTimeTodayResponse;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.service.DriverService;
import com.safefleet.safety.dto.response.SafetyEventResponse;
import com.safefleet.safety.service.SafetyEventService;
import com.safefleet.trip.dto.response.TripResponse;
import com.safefleet.trip.service.TripService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Drivers", description = "Driver management and safety score APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/drivers")
public class DriverController {

    private final DriverService driverService;
    private final TripService tripService;
    private final SafetyEventService safetyEventService;

    @Operation(summary = "Search drivers")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<PageResponse<DriverResponse>> search(@RequestParam(required = false) String keyword,
                                                            @RequestParam(required = false) DriverStatus status,
                                                            @RequestParam(required = false) String licenseClass,
                                                            @RequestParam(required = false) Integer minSafetyScore,
                                                            @RequestParam(required = false) Integer maxSafetyScore,
                                                            Pageable pageable) {
        return ApiResponse.ok(driverService.search(keyword, status, licenseClass, minSafetyScore, maxSafetyScore, pageable));
    }

    @Operation(summary = "Create driver profile")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<DriverResponse> create(@Valid @RequestBody CreateDriverRequest request) {
        return ApiResponse.ok("Driver created", driverService.create(request));
    }

    @Operation(summary = "Get driver detail")
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<DriverResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(driverService.get(id));
    }

    @Operation(summary = "Update driver profile")
    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<DriverResponse> update(@PathVariable Long id,
                                              @Valid @RequestBody UpdateDriverRequest request) {
        return ApiResponse.ok("Driver updated", driverService.update(id, request));
    }

    @Operation(summary = "Soft delete driver")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<Void> delete(@PathVariable Long id) {
        driverService.delete(id);
        return ApiResponse.ok("Driver deleted");
    }

    @Operation(summary = "Get today's driving time")
    @GetMapping("/{id}/driving-time-today")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<DrivingTimeTodayResponse> drivingTimeToday(@PathVariable Long id) {
        return ApiResponse.ok(driverService.drivingTimeToday(id));
    }

    @Operation(summary = "Get driver trip history")
    @GetMapping("/{id}/trips")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<PageResponse<TripResponse>> trips(@PathVariable Long id, Pageable pageable) {
        return ApiResponse.ok(tripService.tripsByDriver(id, pageable));
    }

    @Operation(summary = "Get driver safety alert history")
    @GetMapping("/{id}/safety-events")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<PageResponse<SafetyEventResponse>> safetyEvents(@PathVariable Long id, Pageable pageable) {
        return ApiResponse.ok(safetyEventService.byDriver(id, pageable));
    }

    @Operation(summary = "Recalculate basic driver safety score")
    @PostMapping("/{id}/recalculate-safety-score")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','SAFETY_OFFICER')")
    public ApiResponse<DriverResponse> recalculateSafetyScore(@PathVariable Long id) {
        return ApiResponse.ok("Safety score recalculated", driverService.recalculateSafetyScore(id));
    }
}
