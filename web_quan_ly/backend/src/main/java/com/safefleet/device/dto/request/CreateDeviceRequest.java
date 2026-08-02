package com.safefleet.device.dto.request;

import com.safefleet.device.enums.DeviceStatus;
import com.safefleet.device.enums.DeviceType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateDeviceRequest(
        @NotBlank @Size(max = 50) String deviceCode,
        @NotBlank @Size(max = 120) String name,
        @NotNull DeviceType type,
        DeviceStatus status,
        Long vehicleId,
        @Size(max = 20) String phone,
        @Size(max = 80) String serialNumber,
        @Size(max = 40) String firmwareVersion
) {
}
