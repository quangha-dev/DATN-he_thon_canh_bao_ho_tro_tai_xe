package com.safefleet.mobile.dto.request;

import com.safefleet.mobile.enums.AgentCommandType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record MobileAgentCommandRequest(
        AgentCommandType commandType,
        Long tripId,
        @NotBlank @Size(max = 1000) String transcript
) {
}
