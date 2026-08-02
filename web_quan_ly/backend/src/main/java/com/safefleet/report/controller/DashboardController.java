package com.safefleet.report.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.report.dto.response.DashboardSummaryResponse;
import com.safefleet.report.service.DashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Dashboard", description = "Dashboard overview APIs")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/dashboard")
public class DashboardController {

    private final DashboardService dashboardService;

    @Operation(summary = "Get fleet dashboard summary")
    @GetMapping("/summary")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
    public ApiResponse<DashboardSummaryResponse> summary() {
        return ApiResponse.ok(dashboardService.summary());
    }
}
