package com.safefleet.maintenance.dto.response;

import java.time.LocalDate;

public record DocumentExpiryAlertResponse(
        Long vehicleId,
        String plateNumber,
        String documentType,
        LocalDate expiredAt,
        long daysRemaining
) {
}
