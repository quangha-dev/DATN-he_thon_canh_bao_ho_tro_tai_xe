package com.safefleet.maintenance.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.maintenance.dto.request.CreateMaintenanceOrderRequest;
import com.safefleet.maintenance.dto.request.UpdateMaintenanceOrderRequest;
import com.safefleet.maintenance.dto.response.DocumentExpiryAlertResponse;
import com.safefleet.maintenance.dto.response.MaintenanceOrderResponse;
import com.safefleet.maintenance.enums.MaintenanceStatus;
import com.safefleet.maintenance.service.MaintenanceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
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

import java.time.LocalDate;
import java.util.List;

@Tag(name = "Maintenance", description = "Vehicle maintenance and document expiry APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/maintenance-orders")
public class MaintenanceController {

    private final MaintenanceService maintenanceService;

    @Operation(summary = "Create maintenance order")
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<MaintenanceOrderResponse> create(@Valid @RequestBody CreateMaintenanceOrderRequest request) {
        return ApiResponse.ok("Maintenance order created", maintenanceService.create(request));
    }

    @Operation(summary = "Search maintenance orders")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<PageResponse<MaintenanceOrderResponse>> search(
            @RequestParam(required = false) Long vehicleId,
            @RequestParam(required = false) MaintenanceStatus status,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            Pageable pageable) {
        return ApiResponse.ok(maintenanceService.search(vehicleId, status, from, to, pageable));
    }

    @Operation(summary = "Get maintenance order detail")
    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<MaintenanceOrderResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(maintenanceService.get(id));
    }

    @Operation(summary = "Update maintenance order")
    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<MaintenanceOrderResponse> update(@PathVariable Long id,
                                                        @Valid @RequestBody UpdateMaintenanceOrderRequest request) {
        return ApiResponse.ok("Maintenance order updated", maintenanceService.update(id, request));
    }

    @Operation(summary = "Soft delete maintenance order")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<Void> delete(@PathVariable Long id) {
        maintenanceService.delete(id);
        return ApiResponse.ok("Maintenance order deleted");
    }

    @Operation(summary = "Get maintenance orders due soon")
    @GetMapping("/due-alerts")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<List<MaintenanceOrderResponse>> dueAlerts() {
        return ApiResponse.ok(maintenanceService.dueAlerts());
    }

    @Operation(summary = "Get vehicle inspection and insurance expiry alerts")
    @GetMapping("/document-expiry-alerts")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<List<DocumentExpiryAlertResponse>> documentExpiryAlerts() {
        return ApiResponse.ok(maintenanceService.documentExpiryAlerts());
    }
}
