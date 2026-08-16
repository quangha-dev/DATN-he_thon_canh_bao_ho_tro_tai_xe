package com.safefleet.mobile.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.safefleet.common.dto.ApiResponse;
import com.safefleet.infrastructure.ai.SafeFleetAiGateway;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Agent AI Configuration", description = "Secure server-side OpenAI agent configuration")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/agent/config")
@PreAuthorize("hasRole('ADMIN')")
public class AgentAiConfigurationController {

    private final SafeFleetAiGateway aiGateway;

    @Operation(summary = "Get masked agent AI configuration")
    @GetMapping
    public ApiResponse<JsonNode> get() {
        return ApiResponse.ok(aiGateway.getConfiguration());
    }

    @Operation(summary = "Update encrypted OpenAI agent configuration")
    @PutMapping
    public ApiResponse<JsonNode> update(
            @RequestBody JsonNode request
    ) {
        return ApiResponse.ok("Đã lưu cấu hình agent", aiGateway.updateConfiguration(request));
    }

    @Operation(summary = "Test the configured OpenAI API key")
    @PostMapping("/test")
    public ApiResponse<Void> test() {
        aiGateway.testConfiguration();
        return ApiResponse.ok("Kết nối OpenAI gpt-4o-mini thành công");
    }
}
