package com.safefleet.mobile.dto.response;

public record MobileAgentChatResponse(
        String responseText,
        String model,
        String source
) {
}
