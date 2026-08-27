package com.safefleet.vehicle.dto.response;

import com.safefleet.vehicle.enums.FuelType;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.enums.VehicleType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public record VehicleResponse(
        Long id,
        String plateNumber,
        VehicleType vehicleType,
        String brand,
        String model,
        Integer year,
        BigDecimal loadCapacity,
        BigDecimal heightMeters,
        BigDecimal widthMeters,
        BigDecimal lengthMeters,
        BigDecimal grossWeightTons,
        BigDecimal axleLoadTons,
        Integer axleCount,
        BigDecimal topSpeedKph,
        boolean hazardousGoods,
        Integer seatCount,
        FuelType fuelType,
        VehicleStatus status,
        Long currentDriverId,
        String currentDriverName,
        Long gpsDeviceId,
        String gpsDeviceCode,
        Long cameraDeviceId,
        String cameraDeviceCode,
        LocalDate inspectionExpiredAt,
        LocalDate insuranceExpiredAt,
        Double lastLat,
        Double lastLng,
        Double lastSpeed,
        LocalDateTime lastUpdatedAt
) {
}
