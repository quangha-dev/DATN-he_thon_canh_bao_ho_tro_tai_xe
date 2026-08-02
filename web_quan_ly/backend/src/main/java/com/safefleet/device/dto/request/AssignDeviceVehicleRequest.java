package com.safefleet.device.dto.request;

import jakarta.validation.constraints.NotNull;

public record AssignDeviceVehicleRequest(@NotNull Long vehicleId) {
}
