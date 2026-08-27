package com.safefleet.vehicle.mapper;

import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.vehicle.dto.response.VehicleRealtimeStatusResponse;
import com.safefleet.vehicle.dto.response.VehicleResponse;
import com.safefleet.vehicle.entity.Vehicle;

public final class VehicleMapper {

    private VehicleMapper() {
    }

    public static VehicleResponse toResponse(Vehicle vehicle) {
        return new VehicleResponse(
                vehicle.getId(),
                vehicle.getPlateNumber(),
                vehicle.getVehicleType(),
                vehicle.getBrand(),
                vehicle.getModel(),
                vehicle.getYear(),
                vehicle.getLoadCapacity(),
                vehicle.getHeightMeters(),
                vehicle.getWidthMeters(),
                vehicle.getLengthMeters(),
                vehicle.getGrossWeightTons(),
                vehicle.getAxleLoadTons(),
                vehicle.getAxleCount(),
                vehicle.getTopSpeedKph(),
                vehicle.isHazardousGoods(),
                vehicle.getSeatCount(),
                vehicle.getFuelType(),
                vehicle.getStatus(),
                vehicle.getCurrentDriver() == null ? null : vehicle.getCurrentDriver().getId(),
                vehicle.getCurrentDriver() == null ? null : vehicle.getCurrentDriver().getFullName(),
                vehicle.getGpsDevice() == null ? null : vehicle.getGpsDevice().getId(),
                vehicle.getGpsDevice() == null ? null : vehicle.getGpsDevice().getDeviceCode(),
                vehicle.getCameraDevice() == null ? null : vehicle.getCameraDevice().getId(),
                vehicle.getCameraDevice() == null ? null : vehicle.getCameraDevice().getDeviceCode(),
                vehicle.getInspectionExpiredAt(),
                vehicle.getInsuranceExpiredAt(),
                vehicle.getLastLat(),
                vehicle.getLastLng(),
                vehicle.getLastSpeed(),
                vehicle.getLastUpdatedAt()
        );
    }

    public static VehicleRealtimeStatusResponse toRealtimeStatus(Vehicle vehicle) {
        boolean gpsOnline = vehicle.getGpsDevice() != null && vehicle.getGpsDevice().getStatus() == DeviceStatus.ONLINE;
        return new VehicleRealtimeStatusResponse(
                vehicle.getId(),
                vehicle.getPlateNumber(),
                vehicle.getStatus(),
                vehicle.getLastLat(),
                vehicle.getLastLng(),
                vehicle.getLastSpeed(),
                vehicle.getLastUpdatedAt(),
                gpsOnline
        );
    }
}
