package com.safefleet.vehicle.dto.request;

import com.safefleet.vehicle.enums.FuelType;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.enums.VehicleType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
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
        @DecimalMin("0.5") @DecimalMax("6.0") BigDecimal heightMeters,
        @DecimalMin("0.5") @DecimalMax("4.0") BigDecimal widthMeters,
        @DecimalMin("1.0") @DecimalMax("30.0") BigDecimal lengthMeters,
        @DecimalMin("0.1") @DecimalMax("100.0") BigDecimal grossWeightTons,
        @DecimalMin("0.1") @DecimalMax("30.0") BigDecimal axleLoadTons,
        @Min(1) @Max(12) Integer axleCount,
        @DecimalMin("10.0") @DecimalMax("252.0") BigDecimal topSpeedKph,
        Boolean hazardousGoods,
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
