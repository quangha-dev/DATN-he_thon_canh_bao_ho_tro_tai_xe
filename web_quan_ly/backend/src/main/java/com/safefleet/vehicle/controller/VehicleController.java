package com.safefleet.vehicle.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.safety.dto.response.SafetyEventResponse;
import com.safefleet.safety.service.SafetyEventService;
import com.safefleet.trip.dto.response.TripResponse;
import com.safefleet.trip.service.TripService;
import com.safefleet.vehicle.dto.request.CreateVehicleRequest;
import com.safefleet.vehicle.dto.request.UpdateVehicleRequest;
import com.safefleet.vehicle.dto.response.VehicleRealtimeStatusResponse;
import com.safefleet.vehicle.dto.response.VehicleResponse;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.enums.VehicleType;
import com.safefleet.vehicle.service.VehicleService;
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

import java.util.List;

@Tag(name = "Vehicles", description = "Vehicle management and realtime vehicle state")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/vehicles")
public class VehicleController {

    private final VehicleService vehicleService;
    private final TripService tripService;
    private final SafetyEventService safetyEventService;

    @Operation(summary = "Search vehicles by plate, type, status and GPS online state")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<PageResponse<VehicleResponse>> search(@RequestParam(required = false) String plateNumber,
                                                             @RequestParam(required = false) VehicleType vehicleType,
                                                             @RequestParam(required = false) VehicleStatus status,
                                                             @RequestParam(required = false) Boolean gpsOnline,
                                                             Pageable pageable) {
        return ApiResponse.ok(vehicleService.search(plateNumber, vehicleType, status, gpsOnline, pageable));
    }

    @Operation(summary = "Create vehicle")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<VehicleResponse> create(@Valid @RequestBody CreateVehicleRequest request) {
        return ApiResponse.ok("Vehicle created", vehicleService.create(request));
    }

    @Operation(summary = "Get vehicle detail")
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<VehicleResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(vehicleService.get(id));
    }

    @Operation(summary = "Update vehicle")
    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<VehicleResponse> update(@PathVariable Long id,
                                               @Valid @RequestBody UpdateVehicleRequest request) {
        return ApiResponse.ok("Vehicle updated", vehicleService.update(id, request));
    }

    @Operation(summary = "Soft delete vehicle")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<Void> delete(@PathVariable Long id) {
        vehicleService.delete(id);
        return ApiResponse.ok("Vehicle deleted");
    }

    @Operation(summary = "Get current realtime vehicle state")
    @GetMapping("/{id}/realtime-status")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<VehicleRealtimeStatusResponse> realtimeStatus(@PathVariable Long id) {
        return ApiResponse.ok(vehicleService.realtimeStatus(id));
    }

    @Operation(summary = "Get vehicle trip history")
    @GetMapping("/{id}/trips")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<PageResponse<TripResponse>> trips(@PathVariable Long id, Pageable pageable) {
        return ApiResponse.ok(tripService.tripsByVehicle(id, pageable));
    }

    @Operation(summary = "Get vehicle safety alert history")
    @GetMapping("/{id}/safety-events")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<PageResponse<SafetyEventResponse>> safetyEvents(@PathVariable Long id, Pageable pageable) {
        return ApiResponse.ok(safetyEventService.byVehicle(id, pageable));
    }

    @Operation(summary = "Get current positions for all vehicles on map")
    @GetMapping("/map/positions")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<List<VehicleRealtimeStatusResponse>> currentPositions() {
        return ApiResponse.ok(vehicleService.currentPositions());
    }
}
