package com.safefleet.mobile.service;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.safefleet.mobile.enums.AgentIntent;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Locale;
import java.util.Set;

@Slf4j
@Service
public class AgentIntentClassificationService {

    private static final Set<AgentIntent> CONFIRMATION_REQUIRED = Set.of(
            AgentIntent.START_TRIP,
            AgentIntent.PAUSE_TRIP,
            AgentIntent.RESUME_TRIP,
            AgentIntent.COMPLETE_TRIP,
            AgentIntent.REPORT_FLOOD,
            AgentIntent.SEND_SOS
    );

    private final RestClient restClient;
    private final boolean aiServiceEnabled;

    public AgentIntentClassificationService(
            RestClient.Builder builder,
            @Value("${app.ai-service.url:http://localhost:8000}") String aiServiceUrl,
            @Value("${app.ai-service.enabled:false}") boolean aiServiceEnabled) {
        this.restClient = builder.baseUrl(aiServiceUrl).build();
        this.aiServiceEnabled = aiServiceEnabled;
    }

    public Classification classify(String transcript) {
        if (aiServiceEnabled) {
            try {
                AiIntentResponse response = restClient.post()
                        .uri("/intent/classify")
                        .body(new AiIntentRequest(transcript))
                        .retrieve()
                        .body(AiIntentResponse.class);
                if (response != null && response.intent() != null) {
                    return new Classification(
                            response.intent(),
                            clamp(response.confidence()),
                            CONFIRMATION_REQUIRED.contains(response.intent()),
                            response.source() == null ? "AI_SERVICE" : response.source()
                    );
                }
            } catch (Exception exception) {
                log.warn(
                        "AI intent service unavailable; using deterministic local rules ({})",
                        exception.getClass().getSimpleName()
                );
            }
        }
        return localClassification(transcript);
    }

    Classification localClassification(String transcript) {
        String normalized = transcript == null
                ? ""
                : transcript.trim().toLowerCase(Locale.forLanguageTag("vi-VN"));
        AgentIntent intent;
        if (containsAny(normalized, "sos", "cứu hộ", "cuu ho", "khẩn cấp", "khan cap")) {
            intent = AgentIntent.SEND_SOS;
        } else if (containsAny(
                normalized,
                "báo ngập", "bao ngap",
                "điểm ngập", "diem ngap",
                "đang ngập", "dang ngap"
        )) {
            intent = AgentIntent.REPORT_FLOOD;
        } else if (containsAny(normalized, "tạm dừng", "tam dung", "tạm nghỉ", "tam nghi")) {
            intent = AgentIntent.PAUSE_TRIP;
        } else if (containsAny(normalized, "tiếp tục", "tiep tuc")) {
            intent = AgentIntent.RESUME_TRIP;
        } else if (containsAny(normalized, "hoàn thành", "hoan thanh", "kết thúc chuyến", "ket thuc chuyen")) {
            intent = AgentIntent.COMPLETE_TRIP;
        } else if (containsAny(normalized, "bắt đầu chuyến", "bat dau chuyen", "khởi hành", "khoi hanh")) {
            intent = AgentIntent.START_TRIP;
        } else if (containsAny(
                normalized,
                "giờ lái", "gio lai",
                "còn lái", "con lai",
                "lái bao lâu", "lai bao lau",
                "thời gian lái", "thoi gian lai"
        )) {
            intent = AgentIntent.GET_DRIVING_TIME;
        } else if (containsAny(normalized, "cảnh báo mới", "canh bao moi", "đọc cảnh báo", "doc canh bao")) {
            intent = AgentIntent.READ_LATEST_WARNING;
        } else {
            intent = AgentIntent.UNKNOWN;
        }
        return new Classification(
                intent,
                intent == AgentIntent.UNKNOWN ? 0.0 : 0.95,
                CONFIRMATION_REQUIRED.contains(intent),
                "BACKEND_LOCAL_RULE"
        );
    }

    private boolean containsAny(String value, String... phrases) {
        for (String phrase : phrases) {
            if (value.contains(phrase)) {
                return true;
            }
        }
        return false;
    }

    private double clamp(Double confidence) {
        return confidence == null ? 0.0 : Math.max(0.0, Math.min(1.0, confidence));
    }

    public record Classification(
            AgentIntent intent,
            double confidence,
            boolean requiresConfirmation,
            String source
    ) {
    }

    private record AiIntentRequest(String transcript) {
    }

    private record AiIntentResponse(
            AgentIntent intent,
            Double confidence,
            @JsonProperty("requires_confirmation") Boolean requiresConfirmation,
            String source
    ) {
    }
}
