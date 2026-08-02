package com.safefleet.evidence.controller;

import com.safefleet.common.dto.ApiResponse;
import com.safefleet.evidence.dto.EvidenceContent;
import com.safefleet.evidence.dto.EvidenceResponse;
import com.safefleet.evidence.service.EvidenceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.CacheControl;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;

@Tag(name = "Protected Evidence")
@RestController
@RequiredArgsConstructor
public class EvidenceController {

    private final EvidenceService evidenceService;

    @Operation(summary = "Upload protected safety/SOS evidence")
    @PostMapping(value = "/api/v1/mobile/evidence", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('DRIVER')")
    public ApiResponse<EvidenceResponse> upload(
            @RequestParam(required = false) Long safetyEventId,
            @RequestParam(required = false) Long incidentId,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime capturedAt,
            @RequestParam MultipartFile file) {
        return ApiResponse.ok(
                "Evidence đã được lưu an toàn",
                evidenceService.upload(safetyEventId, incidentId, capturedAt, file)
        );
    }

    @Operation(summary = "Get protected evidence metadata")
    @GetMapping("/api/v1/evidence/{id}")
    public ApiResponse<EvidenceResponse> metadata(@PathVariable Long id) {
        return ApiResponse.ok(evidenceService.metadata(id));
    }

    @Operation(summary = "Stream protected evidence after ownership/RBAC check")
    @GetMapping("/api/v1/evidence/{id}/content")
    public ResponseEntity<org.springframework.core.io.Resource> content(@PathVariable Long id) {
        EvidenceContent content = evidenceService.content(id);
        String filename = content.metadata().originalFilename() == null
                ? "evidence"
                : content.metadata().originalFilename();
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .header("X-Content-Type-Options", "nosniff")
                .header(
                        HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.inline()
                                .filename(filename, StandardCharsets.UTF_8)
                                .build()
                                .toString()
                )
                .contentLength(content.metadata().sizeBytes())
                .contentType(MediaType.parseMediaType(content.metadata().contentType()))
                .body(content.resource());
    }
}
