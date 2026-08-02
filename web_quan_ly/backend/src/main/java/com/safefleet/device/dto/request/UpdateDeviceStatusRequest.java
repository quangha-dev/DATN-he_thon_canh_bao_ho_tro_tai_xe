package com.safefleet.device.dto.request;

import com.safefleet.device.enums.DeviceStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpdateDeviceStatusRequest(
        @NotNull DeviceStatus status,
        Double lat,
        Double lng,
        @Size(max = 255) String note
) {
}
