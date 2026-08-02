package com.safefleet.evidence.dto;

import java.time.LocalDateTime;

public record EvidenceResponse(
        Long id,
        Long safetyEventId,
        Long incidentId,
        String originalFilename,
        String contentType,
        long sizeBytes,
        String sha256,
        LocalDateTime capturedAt,
        LocalDateTime createdAt,
        String protectedContentUrl
) {
}
