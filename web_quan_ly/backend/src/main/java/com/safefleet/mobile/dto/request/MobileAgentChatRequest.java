package com.safefleet.mobile.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

public record MobileAgentChatRequest(
        @NotEmpty @Size(max = 20) List<@Valid Message> messages
) {
    public record Message(
            @Pattern(regexp = "user|assistant") String role,
            @NotBlank @Size(max = 4000) String content
    ) {
    }
}
