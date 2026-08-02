package com.safefleet.device.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.device.dto.request.AssignDeviceVehicleRequest;
import com.safefleet.device.dto.request.CreateDeviceRequest;
import com.safefleet.device.dto.request.UpdateDeviceRequest;
import com.safefleet.device.dto.request.UpdateDeviceStatusRequest;
import com.safefleet.device.dto.response.DeviceConnectionLogResponse;
import com.safefleet.device.dto.response.DeviceResponse;
import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.device.enums.DeviceType;
import com.safefleet.device.service.DeviceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Devices", description = "GPS, cameras, driver phones and IoT device management")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/devices")
public class DeviceController {

    private final DeviceService deviceService;

    @Operation(summary = "Search devices")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<PageResponse<DeviceResponse>> search(@RequestParam(required = false) DeviceType type,
                                                            @RequestParam(required = false) DeviceStatus status,
                                                            @RequestParam(required = false) Long vehicleId,
                                                            Pageable pageable) {
        return ApiResponse.ok(deviceService.search(type, status, vehicleId, pageable));
    }

    @Operation(summary = "Get device detail")
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<DeviceResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(deviceService.get(id));
    }

    @Operation(summary = "Create device")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<DeviceResponse> create(@Valid @RequestBody CreateDeviceRequest request) {
        return ApiResponse.ok("Device created", deviceService.create(request));
    }

    @Operation(summary = "Update device")
    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<DeviceResponse> update(@PathVariable Long id, @Valid @RequestBody UpdateDeviceRequest request) {
        return ApiResponse.ok("Device updated", deviceService.update(id, request));
    }

    @Operation(summary = "Delete device")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<Void> delete(@PathVariable Long id) {
        deviceService.delete(id);
        return ApiResponse.ok("Device deleted");
    }

    @Operation(summary = "Assign device to vehicle")
    @PostMapping("/{id}/assign-vehicle")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<DeviceResponse> assignVehicle(@PathVariable Long id,
                                                     @Valid @RequestBody AssignDeviceVehicleRequest request) {
        return ApiResponse.ok("Device assigned", deviceService.assignVehicle(id, request));
    }

    @Operation(summary = "Update online/offline status")
    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<DeviceResponse> updateStatus(@PathVariable Long id,
                                                    @Valid @RequestBody UpdateDeviceStatusRequest request) {
        return ApiResponse.ok("Device status updated", deviceService.updateStatus(id, request));
    }

    @Operation(summary = "Get device connection logs")
    @GetMapping("/{id}/connection-logs")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<PageResponse<DeviceConnectionLogResponse>> connectionLogs(@PathVariable Long id,
                                                                                 Pageable pageable) {
        return ApiResponse.ok(deviceService.connectionLogs(id, pageable));
    }
}
