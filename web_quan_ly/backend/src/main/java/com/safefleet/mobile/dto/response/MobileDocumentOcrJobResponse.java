package com.safefleet.mobile.dto.response;

import com.safefleet.mobile.enums.DocumentOcrJobStatus;
import com.safefleet.mobile.enums.PlateReviewStatus;

import java.time.LocalDateTime;
import java.time.LocalDate;
import java.util.Map;

public record MobileDocumentOcrJobResponse(
        Long id,
        DocumentOcrJobStatus status,
        String projectAddress,
        LocalDate voucherDate,
        String voucherNumber,
        String vehiclePlate,
        String expectedVehiclePlate,
        PlateReviewStatus plateReviewStatus,
        String plateReviewReason,
        String driverName,
        Integer tripCount,
        String rawText,
        Map<String, Double> fieldConfidences,
        String engine,
        Long elapsedMs,
        String errorMessage,
        LocalDateTime createdAt,
        LocalDateTime completedAt
) {
}
