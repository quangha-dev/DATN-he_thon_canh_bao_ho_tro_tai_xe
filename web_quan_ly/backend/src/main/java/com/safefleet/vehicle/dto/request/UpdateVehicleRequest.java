package com.safefleet.vehicle.dto.request;

import com.safefleet.vehicle.enums.FuelType;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.enums.VehicleType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record UpdateVehicleRequest(
        @NotNull VehicleType vehicleType,
        @Size(max = 80) String brand,
        @Size(max = 80) String model,
        Integer year,
        @PositiveOrZero BigDecimal loadCapacity,
        @PositiveOrZero Integer seatCount,
        FuelType fuelType,
        @NotNull VehicleStatus status,
        Long currentDriverId,
        Long gpsDeviceId,
        Long cameraDeviceId,
        LocalDate inspectionExpiredAt,
        LocalDate insuranceExpiredAt
) {
}
