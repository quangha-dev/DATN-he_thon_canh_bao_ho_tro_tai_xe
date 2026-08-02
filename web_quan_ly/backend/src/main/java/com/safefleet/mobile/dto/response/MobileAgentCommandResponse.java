package com.safefleet.mobile.dto.response;

import com.safefleet.mobile.enums.AgentCommandStatus;
import com.safefleet.mobile.enums.AgentCommandType;
import com.safefleet.mobile.enums.AgentIntent;

import java.time.LocalDateTime;

public record MobileAgentCommandResponse(
        Long id,
        AgentCommandType commandType,
        Long tripId,
        String transcript,
        String normalizedCommand,
        AgentIntent intent,
        Double confidence,
        boolean requiresConfirmation,
        String classificationSource,
        AgentCommandStatus status,
        String responseText,
        String executedReferenceType,
        Long executedReferenceId,
        LocalDateTime createdAt
) {
}
