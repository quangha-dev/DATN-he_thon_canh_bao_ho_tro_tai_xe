package com.safefleet.driver.mapper;

import com.safefleet.driver.dto.response.DriverResponse;
import com.safefleet.driver.dto.response.DrivingTimeTodayResponse;
import com.safefleet.driver.entity.Driver;

public final class DriverMapper {

    private static final int MAX_CONTINUOUS_MINUTES = 240;

    private DriverMapper() {
    }

    public static DriverResponse toResponse(Driver driver) {
        return new DriverResponse(
                driver.getId(),
                driver.getUser() == null ? null : driver.getUser().getId(),
                driver.getFullName(),
                driver.getPhone(),
                driver.getEmail(),
                driver.getAddress(),
                driver.getLicenseNumber(),
                driver.getLicenseClass(),
                driver.getLicenseExpiredAt(),
                driver.getStatus(),
                driver.getCurrentVehicle() == null ? null : driver.getCurrentVehicle().getId(),
                driver.getCurrentVehicle() == null ? null : driver.getCurrentVehicle().getPlateNumber(),
                driver.getSafetyScore(),
                driver.getDrivingTimeTodayMinutes(),
                driver.getContinuousDrivingMinutes(),
                driver.getTotalTrips(),
                driver.getTotalAlerts()
        );
    }

    public static DrivingTimeTodayResponse toDrivingTime(Driver driver) {
        int remaining = Math.max(0, MAX_CONTINUOUS_MINUTES - driver.getContinuousDrivingMinutes());
        return new DrivingTimeTodayResponse(
                driver.getId(),
                driver.getDrivingTimeTodayMinutes(),
                driver.getContinuousDrivingMinutes(),
                remaining
        );
    }
}
