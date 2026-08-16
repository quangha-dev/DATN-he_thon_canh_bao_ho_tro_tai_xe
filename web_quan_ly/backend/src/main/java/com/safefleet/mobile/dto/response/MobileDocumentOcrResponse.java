package com.safefleet.mobile.dto.response;

import java.time.LocalDate;
import java.util.Map;

public record MobileDocumentOcrResponse(
        String projectAddress,
        LocalDate voucherDate,
        String voucherNumber,
        String vehiclePlate,
        String driverName,
        Integer tripCount,
        String rawText,
        Map<String, Double> fieldConfidences,
        String engine,
        long elapsedMs
) {
}
