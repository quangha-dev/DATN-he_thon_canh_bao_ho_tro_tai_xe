package com.safefleet.device.dto.response;

import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.device.enums.DeviceType;

import java.time.LocalDateTime;

public record DeviceResponse(
        Long id,
        String deviceCode,
        String name,
        DeviceType type,
        DeviceStatus status,
        Long vehicleId,
        String vehiclePlateNumber,
        String phone,
        String serialNumber,
        String firmwareVersion,
        LocalDateTime lastSeenAt
) {
}
