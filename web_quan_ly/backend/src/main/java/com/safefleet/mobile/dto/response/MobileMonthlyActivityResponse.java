package com.safefleet.mobile.dto.response;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;

public record MobileMonthlyActivityResponse(
        YearMonth month,
        Integer safetyScore,
        Integer totalTrips,
        Integer completedTrips,
        Integer drivingMinutes,
        Integer restMinutes,
        Integer alertCount,
        Integer criticalAlertCount,
        Integer completionRate,
        Integer onTimeTrips,
        Integer onTimeRate,
        Double distanceKm,
        Integer activeDays,
        Integer alertFreeDays,
        String achievementLevel,
        String achievementTitle,
        List<Achievement> achievements,
        List<DailyActivity> days
) {
    public record Achievement(
            String code,
            String title,
            String description,
            Boolean unlocked,
            Integer progress
    ) {
    }

    public record DailyActivity(
            LocalDate date,
            Integer trips,
            Integer drivingMinutes,
            Integer restMinutes,
            Integer alerts
    ) {
    }
}
