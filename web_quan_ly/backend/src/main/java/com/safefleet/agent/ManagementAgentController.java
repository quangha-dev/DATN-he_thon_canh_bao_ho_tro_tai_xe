package com.safefleet.agent;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.infrastructure.ai.SafeFleetAiGateway;
import com.safefleet.mobile.dto.request.MobileAgentChatRequest;
import com.safefleet.mobile.dto.response.MobileAgentChatResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Management Agent", description = "Read-only AI assistant for fleet management data and company policies")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/management/agent")
@PreAuthorize("hasAnyRole('ADMIN','FLEET_MANAGER','DISPATCHER','SAFETY_OFFICER')")
public class ManagementAgentController {

    private final SafeFleetAiGateway aiGateway;

    @Operation(summary = "Chat with the role-scoped SafeFleet management agent")
    @PostMapping("/chat")
    public ApiResponse<MobileAgentChatResponse> chat(
            @Valid @RequestBody MobileAgentChatRequest request,
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization
    ) {
        return ApiResponse.ok(aiGateway.respond(request, authorization));
    }
}
