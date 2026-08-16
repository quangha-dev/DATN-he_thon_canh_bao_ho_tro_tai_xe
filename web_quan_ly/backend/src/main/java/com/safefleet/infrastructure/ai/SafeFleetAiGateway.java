package com.safefleet.infrastructure.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.safefleet.common.exception.BusinessException;
import com.safefleet.mobile.dto.request.MobileAgentChatRequest;
import com.safefleet.mobile.dto.response.MobileAgentChatResponse;
import com.safefleet.mobile.enums.AgentIntent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

/**
 * Thin HTTP boundary to safefleet_ai. Model calls, prompts, planning, tools and
 * secret storage deliberately do not live in the business backend.
 */
@Component
public class SafeFleetAiGateway {

    private static final String SERVICE_TOKEN_HEADER = "X-SafeFleet-Service-Token";
    private static final String USER_AUTHORIZATION_HEADER = "X-User-Authorization";

    private final RestClient client;
    private final ObjectMapper objectMapper;
    private final String serviceToken;

    public SafeFleetAiGateway(
            RestClient.Builder builder,
            ObjectMapper objectMapper,
            @Value("${app.ai-service.url:http://localhost:8000}") String aiServiceUrl,
            @Value("${app.ai-service.internal-token:}") String serviceToken,
            @Value("${app.ai-service.connect-timeout-ms:5000}") int connectTimeoutMs,
            @Value("${app.ai-service.read-timeout-ms:120000}") int readTimeoutMs
    ) {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(connectTimeoutMs);
        requestFactory.setReadTimeout(readTimeoutMs);
        this.client = builder.baseUrl(aiServiceUrl).requestFactory(requestFactory).build();
        this.objectMapper = objectMapper;
        this.serviceToken = serviceToken;
    }

    public MobileAgentChatResponse respond(MobileAgentChatRequest request, String userAuthorization) {
        requireServiceToken();
        try {
            MobileAgentChatResponse response = client.post()
                    .uri("/agent/respond")
                    .header(SERVICE_TOKEN_HEADER, serviceToken)
                    .header(USER_AUTHORIZATION_HEADER, userAuthorization)
                    .body(request)
                    .retrieve()
                    .body(MobileAgentChatResponse.class);
            if (response == null) {
                throw new BusinessException(HttpStatus.BAD_GATEWAY, "AI service không trả về kết quả agent");
            }
            return response;
        } catch (RestClientResponseException exception) {
            throw translate(exception);
        } catch (BusinessException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "Không thể kết nối SafeFleet AI");
        }
    }

    public Classification classify(String transcript) {
        requireServiceToken();
        try {
            IntentResponse response = client.post()
                    .uri("/intent/classify")
                    .header(SERVICE_TOKEN_HEADER, serviceToken)
                    .body(new IntentRequest(transcript))
                    .retrieve()
                    .body(IntentResponse.class);
            if (response == null || response.intent() == null) {
                throw new BusinessException(HttpStatus.BAD_GATEWAY, "AI service không phân loại được lệnh");
            }
            return new Classification(
                    response.intent(),
                    Math.max(0.0, Math.min(1.0, response.confidence() == null ? 0.0 : response.confidence())),
                    Boolean.TRUE.equals(response.requiresConfirmation()),
                    response.source() == null ? "SAFEFLEET_AI" : response.source()
            );
        } catch (RestClientResponseException exception) {
            throw translate(exception);
        } catch (BusinessException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "Không thể kết nối SafeFleet AI");
        }
    }

    public JsonNode getConfiguration() {
        return exchangeConfiguration("GET", null, "/agent/config");
    }

    public JsonNode updateConfiguration(JsonNode request) {
        return exchangeConfiguration("PUT", request, "/agent/config");
    }

    public void testConfiguration() {
        requireServiceToken();
        try {
            client.post()
                    .uri("/agent/config/test")
                    .header(SERVICE_TOKEN_HEADER, serviceToken)
                    .retrieve()
                    .toBodilessEntity();
        } catch (RestClientResponseException exception) {
            throw translate(exception);
        } catch (RuntimeException exception) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "Không thể kết nối SafeFleet AI");
        }
    }

    private JsonNode exchangeConfiguration(String method, JsonNode body, String path) {
        requireServiceToken();
        try {
            RestClient.RequestBodySpec request = "PUT".equals(method)
                    ? client.put().uri(path).header(SERVICE_TOKEN_HEADER, serviceToken)
                    : client.method(org.springframework.http.HttpMethod.GET).uri(path)
                            .header(SERVICE_TOKEN_HEADER, serviceToken);
            JsonNode response = body == null
                    ? request.retrieve().body(JsonNode.class)
                    : request.body(body).retrieve().body(JsonNode.class);
            if (response == null) {
                throw new BusinessException(HttpStatus.BAD_GATEWAY, "AI service không trả cấu hình");
            }
            return response;
        } catch (RestClientResponseException exception) {
            throw translate(exception);
        } catch (BusinessException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "Không thể kết nối SafeFleet AI");
        }
    }

    private void requireServiceToken() {
        if (serviceToken == null || serviceToken.isBlank()) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "AI_INTERNAL_TOKEN chưa được cấu hình");
        }
    }

    private BusinessException translate(RestClientResponseException exception) {
        String message = "SafeFleet AI trả về lỗi " + exception.getStatusCode().value();
        try {
            JsonNode payload = objectMapper.readTree(exception.getResponseBodyAsString());
            if (payload.path("detail").isTextual()) {
                message = payload.path("detail").asText();
            }
        } catch (Exception ignored) {
            // Keep the safe generic message.
        }
        HttpStatus status = exception.getStatusCode().is4xxClientError()
                ? HttpStatus.BAD_REQUEST
                : HttpStatus.BAD_GATEWAY;
        return new BusinessException(status, message);
    }

    private record IntentRequest(String transcript) {
    }

    private record IntentResponse(
            AgentIntent intent,
            Double confidence,
            @com.fasterxml.jackson.annotation.JsonProperty("requires_confirmation") Boolean requiresConfirmation,
            String source
    ) {
    }

    public record Classification(
            AgentIntent intent,
            double confidence,
            boolean requiresConfirmation,
            String source
    ) {
    }
}
