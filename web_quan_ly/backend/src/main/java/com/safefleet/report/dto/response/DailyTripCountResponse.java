package com.safefleet.report.dto.response;

import java.time.LocalDate;

public record DailyTripCountResponse(
        LocalDate date,
        long totalTrips
) {
}
