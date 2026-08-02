package com.safefleet.mobile.service;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.safefleet.mobile.dto.request.MobileAgentChatRequest;
import com.safefleet.mobile.dto.response.MobileAgentChatResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.List;

@Slf4j
@Service
public class AgentConversationService {

    private final RestClient restClient;
    private final boolean enabled;

    public AgentConversationService(
            RestClient.Builder builder,
            @Value("${app.ai-service.url:http://localhost:8000}") String aiServiceUrl,
            @Value("${app.ai-service.enabled:false}") boolean enabled) {
        this.restClient = builder.baseUrl(aiServiceUrl).build();
        this.enabled = enabled;
    }

    public MobileAgentChatResponse respond(MobileAgentChatRequest request) {
        if (enabled) {
            try {
                AiChatResponse response = restClient.post()
                        .uri("/chat/respond")
                        .body(new AiChatRequest(request.messages()))
                        .retrieve()
                        .body(AiChatResponse.class);
                if (response != null && response.responseText() != null) {
                    return new MobileAgentChatResponse(
                            response.responseText(), response.model(), response.source());
                }
            } catch (Exception exception) {
                log.warn("AI conversation unavailable ({})", exception.getClass().getSimpleName());
            }
        }
        return new MobileAgentChatResponse(
                "Trợ lý hội thoại đang tạm ngoại tuyến. Các lệnh an toàn cốt lõi vẫn hoạt động.",
                "backend-safe-fallback",
                "BACKEND_FALLBACK"
        );
    }

    private record AiChatRequest(List<MobileAgentChatRequest.Message> messages) {
    }

    private record AiChatResponse(
            @JsonProperty("response_text") String responseText,
            String model,
            String source
    ) {
    }
}
