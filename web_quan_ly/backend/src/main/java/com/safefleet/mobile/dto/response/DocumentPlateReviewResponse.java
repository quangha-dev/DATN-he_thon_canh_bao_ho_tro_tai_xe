package com.safefleet.mobile.dto.response;

import com.safefleet.mobile.enums.PlateReviewStatus;

import java.time.LocalDate;
import java.time.LocalDateTime;

public record DocumentPlateReviewResponse(
        Long id,
        Long driverId,
        String driverName,
        Long tripId,
        String tripCode,
        String expectedVehiclePlate,
        String recognizedVehiclePlate,
        PlateReviewStatus reviewStatus,
        String reviewReason,
        String reviewNote,
        Long reviewedByUserId,
        String reviewedByName,
        LocalDateTime reviewedAt,
        String voucherNumber,
        LocalDate voucherDate,
        String projectAddress,
        String originalFilename,
        String imageUrl,
        LocalDateTime createdAt,
        LocalDateTime completedAt
) {
}
