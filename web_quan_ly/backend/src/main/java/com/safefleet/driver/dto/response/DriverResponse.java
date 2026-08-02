package com.safefleet.driver.dto.response;

import com.safefleet.driver.enums.DriverStatus;

import java.time.LocalDate;

public record DriverResponse(
        Long id,
        Long userId,
        String fullName,
        String phone,
        String email,
        String address,
        String licenseNumber,
        String licenseClass,
        LocalDate licenseExpiredAt,
        DriverStatus status,
        Long currentVehicleId,
        String currentVehiclePlateNumber,
        Integer safetyScore,
        Integer drivingTimeTodayMinutes,
        Integer continuousDrivingMinutes,
        Integer totalTrips,
        Integer totalAlerts
) {
}
