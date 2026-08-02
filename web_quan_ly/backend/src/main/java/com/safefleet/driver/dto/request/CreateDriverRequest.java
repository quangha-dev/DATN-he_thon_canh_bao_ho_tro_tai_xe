package com.safefleet.driver.dto.request;

import com.safefleet.driver.enums.DriverStatus;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record CreateDriverRequest(
        Long userId,
        @NotBlank @Size(max = 150) String fullName,
        @NotBlank @Size(max = 20) String phone,
        @Email @Size(max = 120) String email,
        @Size(max = 255) String address,
        @NotBlank @Size(max = 50) String licenseNumber,
        @NotBlank @Size(max = 20) String licenseClass,
        @NotNull LocalDate licenseExpiredAt,
        DriverStatus status,
        Long currentVehicleId
) {
}
