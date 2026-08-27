package com.safefleet.mobile.dto.response;

import java.util.List;

public record MobileAgentChatResponse(
        String responseText,
        String model,
        String source,
        String status,
        List<String> plan,
        List<AgentStep> steps,
        boolean replanned,
        List<ClientAction> clientActions,
        ConfirmationRequest confirmationRequest
) {
    public record AgentStep(
            Integer index,
            String tool,
            String arguments,
            boolean success,
            String planCheck,
            String reason
    ) {
    }

    public record ClientAction(
            String type,
            String destination,
            Long tripId,
            String destinationName,
            String destinationAddress,
            Double destinationLat,
            Double destinationLng,
            Boolean autoStart
    ) {
    }

    public record ConfirmationRequest(
            String type,
            String action,
            Long tripId,
            String note,
            String severity,
            String description,
            String prompt
    ) {
    }
}
