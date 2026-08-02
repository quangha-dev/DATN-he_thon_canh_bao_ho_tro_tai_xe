package com.safefleet.device.dto.response;

import com.safefleet.device.enums.DeviceStatus;

import java.time.LocalDateTime;

public record DeviceConnectionLogResponse(
        Long id,
        Long deviceId,
        DeviceStatus status,
        Double lat,
        Double lng,
        String note,
        LocalDateTime createdAt
) {
}
