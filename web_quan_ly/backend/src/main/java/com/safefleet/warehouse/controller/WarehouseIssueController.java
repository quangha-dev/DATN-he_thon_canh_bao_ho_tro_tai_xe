package com.safefleet.warehouse.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.warehouse.dto.request.WarehouseIssueConfirmationRequest;
import com.safefleet.warehouse.dto.request.WarehouseIssueRequest;
import com.safefleet.warehouse.dto.response.WarehouseIssueResponse;
import com.safefleet.warehouse.enums.WarehouseIssueStatus;
import com.safefleet.warehouse.service.WarehouseIssueService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@Tag(name = "Warehouse issues", description = "Electronic warehouse issue documents and confirmations")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/warehouse-issues")
public class WarehouseIssueController {
    private final WarehouseIssueService service;

    @PostMapping
    @Operation(summary = "Create a draft warehouse issue")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<WarehouseIssueResponse> create(@Valid @RequestBody WarehouseIssueRequest request) {
        return ApiResponse.ok("Đã lưu phiếu xuất kho nháp", service.create(request));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<WarehouseIssueResponse> update(@PathVariable Long id,
                                                       @Valid @RequestBody WarehouseIssueRequest request) {
        return ApiResponse.ok("Đã cập nhật phiếu xuất kho", service.update(id, request));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<List<WarehouseIssueResponse>> search(@RequestParam(required = false) WarehouseIssueStatus status) {
        return ApiResponse.ok(service.search(status));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<WarehouseIssueResponse> get(@PathVariable Long id) {
        return ApiResponse.ok(service.get(id));
    }

    @GetMapping("/by-trip/{tripId}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER') or hasRole('DRIVER')")
    public ApiResponse<WarehouseIssueResponse> getByTrip(@PathVariable Long tripId) {
        return ApiResponse.ok(service.getByTrip(tripId));
    }

    @PostMapping("/{id}/issue")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER')")
    public ApiResponse<WarehouseIssueResponse> issue(@PathVariable Long id) {
        return ApiResponse.ok("Đã phát hành phiếu xuất kho", service.issue(id));
    }

    @PostMapping("/{id}/confirm")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER') or hasRole('DRIVER')")
    public ApiResponse<WarehouseIssueResponse> confirm(@PathVariable Long id,
                                                        @Valid @RequestBody WarehouseIssueConfirmationRequest request) {
        return ApiResponse.ok("Đã ghi nhận xác nhận điện tử", service.confirm(id, request));
    }
}
