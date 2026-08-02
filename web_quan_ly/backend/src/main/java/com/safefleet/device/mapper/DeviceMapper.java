package com.safefleet.device.mapper;

import com.safefleet.device.dto.response.DeviceConnectionLogResponse;
import com.safefleet.device.dto.response.DeviceResponse;
import com.safefleet.device.entity.Device;
import com.safefleet.device.entity.DeviceConnectionLog;

public final class DeviceMapper {

    private DeviceMapper() {
    }

    public static DeviceResponse toResponse(Device device) {
        return new DeviceResponse(
                device.getId(),
                device.getDeviceCode(),
                device.getName(),
                device.getType(),
                device.getStatus(),
                device.getVehicle() == null ? null : device.getVehicle().getId(),
                device.getVehicle() == null ? null : device.getVehicle().getPlateNumber(),
                device.getPhone(),
                device.getSerialNumber(),
                device.getFirmwareVersion(),
                device.getLastSeenAt()
        );
    }

    public static DeviceConnectionLogResponse toResponse(DeviceConnectionLog log) {
        return new DeviceConnectionLogResponse(
                log.getId(),
                log.getDevice().getId(),
                log.getStatus(),
                log.getLat(),
                log.getLng(),
                log.getNote(),
                log.getCreatedAt()
        );
    }
}
