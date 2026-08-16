package com.safefleet.mobile.service;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.BusinessException;
import com.safefleet.mobile.dto.response.MobileDocumentOcrResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.LocalDate;
import java.util.Map;
import java.util.Set;

@Service
public class DocumentOcrService {

    private static final String SERVICE_TOKEN_HEADER = "X-SafeFleet-Service-Token";

    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
            MediaType.IMAGE_JPEG_VALUE,
            MediaType.IMAGE_PNG_VALUE,
            "image/webp"
    );

    private final RestClient restClient;
    private final boolean enabled;
    private final long maximumBytes;
    private final String serviceToken;

    public DocumentOcrService(
            RestClient.Builder builder,
            @Value("${app.ai-service.url:http://localhost:8000}") String aiServiceUrl,
            @Value("${app.ai-service.ocr-enabled:true}") boolean enabled,
            @Value("${app.ai-service.ocr-max-upload-bytes:10485760}") long maximumBytes,
            @Value("${app.ai-service.internal-token:}") String serviceToken,
            @Value("${app.ai-service.ocr-connect-timeout-ms:5000}") int connectTimeoutMs,
            @Value("${app.ai-service.ocr-read-timeout-ms:120000}") int readTimeoutMs) {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(connectTimeoutMs);
        requestFactory.setReadTimeout(readTimeoutMs);
        this.restClient = builder
                .baseUrl(aiServiceUrl)
                .requestFactory(requestFactory)
                .build();
        this.enabled = enabled;
        this.maximumBytes = maximumBytes;
        this.serviceToken = serviceToken;
    }

    public MobileDocumentOcrResponse recognize(MultipartFile file) {
        return recognize(readUpload(file));
    }

    public UploadedDocument readUpload(MultipartFile file) {
        validate(file);
        try {
            return new UploadedDocument(
                    file.getBytes(),
                    file.getContentType(),
                    file.getOriginalFilename() == null ? "voucher.jpg" : file.getOriginalFilename()
            );
        } catch (IOException exception) {
            throw new BadRequestException("Không đọc được ảnh phiếu");
        }
    }

    public MobileDocumentOcrResponse recognize(UploadedDocument upload) {
        if (!enabled) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "OCR server đang tạm tắt");
        }
        if (serviceToken == null || serviceToken.isBlank()) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "AI_INTERNAL_TOKEN chưa được cấu hình");
        }
        try {
            ByteArrayResource image = new ByteArrayResource(upload.bytes()) {
                @Override
                public String getFilename() {
                    return upload.originalFilename();
                }
            };
            HttpHeaders imageHeaders = new HttpHeaders();
            imageHeaders.setContentType(MediaType.parseMediaType(upload.contentType()));
            MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
            body.add("file", new HttpEntity<>(image, imageHeaders));

            AiOcrResponse response = restClient.post()
                    .uri("/ocr/driving-log")
                    .header(SERVICE_TOKEN_HEADER, serviceToken)
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(body)
                    .retrieve()
                    .body(AiOcrResponse.class);
            if (response == null || response.fields() == null
                    || response.fields().projectAddress() == null) {
                throw new BusinessException(HttpStatus.BAD_GATEWAY, "OCR server trả dữ liệu không hợp lệ");
            }
            return new MobileDocumentOcrResponse(
                    response.fields().projectAddress(),
                    response.fields().voucherDate(),
                    response.fields().voucherNumber(),
                    response.fields().vehiclePlate(),
                    response.fields().driverName(),
                    response.fields().tripCount(),
                    response.fields().rawText(),
                    response.fields().confidences() == null ? Map.of() : response.fields().confidences(),
                    response.engine(),
                    response.elapsedMs()
            );
        } catch (BusinessException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "Không thể kết nối OCR server");
        }
    }

    public record UploadedDocument(byte[] bytes, String contentType, String originalFilename) {
    }

    private void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("Ảnh phiếu không được để trống");
        }
        if (file.getSize() > maximumBytes) {
            throw new BadRequestException("Ảnh phiếu vượt quá dung lượng cho phép");
        }
        if (!ALLOWED_CONTENT_TYPES.contains(file.getContentType())) {
            throw new BadRequestException("Chỉ chấp nhận ảnh JPEG, PNG hoặc WebP");
        }
    }

    private record AiOcrResponse(
            String engine,
            @JsonProperty("elapsed_ms") long elapsedMs,
            AiOcrFields fields
    ) {
    }

    private record AiOcrFields(
            @JsonProperty("project_address") String projectAddress,
            @JsonProperty("voucher_date") LocalDate voucherDate,
            @JsonProperty("voucher_number") String voucherNumber,
            @JsonProperty("vehicle_plate") String vehiclePlate,
            @JsonProperty("driver_name") String driverName,
            @JsonProperty("trip_count") Integer tripCount,
            @JsonProperty("raw_text") String rawText,
            Map<String, Double> confidences
    ) {
    }
}
