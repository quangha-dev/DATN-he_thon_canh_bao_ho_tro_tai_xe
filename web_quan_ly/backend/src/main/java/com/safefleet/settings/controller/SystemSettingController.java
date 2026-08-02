package com.safefleet.settings.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.settings.dto.request.UpdateSystemSettingRequest;
import com.safefleet.settings.dto.response.SystemSettingResponse;
import com.safefleet.settings.enums.SettingGroup;
import com.safefleet.settings.service.SystemSettingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "System Settings", description = "Runtime configurable rules and system settings")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/settings")
public class SystemSettingController {

    private final SystemSettingService systemSettingService;

    @Operation(summary = "Get all settings")
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<List<SystemSettingResponse>> all() {
        return ApiResponse.ok(systemSettingService.all());
    }

    @Operation(summary = "Get setting by key")
    @GetMapping("/{key}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<SystemSettingResponse> get(@PathVariable String key) {
        return ApiResponse.ok(systemSettingService.get(key));
    }

    @Operation(summary = "Update setting by key")
    @PutMapping("/{key}")
    @PreAuthorize("hasRole('ADMIN')")
    public ApiResponse<SystemSettingResponse> update(@PathVariable String key,
                                                     @Valid @RequestBody UpdateSystemSettingRequest request) {
        return ApiResponse.ok("Setting updated", systemSettingService.update(key, request));
    }

    @Operation(summary = "Get settings by group")
    @GetMapping("/groups/{group}")
    @PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER')")
    public ApiResponse<List<SystemSettingResponse>> byGroup(@PathVariable SettingGroup group) {
        return ApiResponse.ok(systemSettingService.byGroup(group));
    }
}
