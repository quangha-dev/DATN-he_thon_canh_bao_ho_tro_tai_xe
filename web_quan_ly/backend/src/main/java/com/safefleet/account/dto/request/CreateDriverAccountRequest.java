package com.safefleet.account.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record CreateDriverAccountRequest(
        @NotBlank @Size(max = 80) String username,
        @NotBlank @Email @Size(max = 120) String email,
        @NotBlank @Size(min = 6, max = 100) String password,
        @NotBlank @Size(max = 150) String fullName,
        @NotBlank @Size(max = 20) String phone,
        @Size(max = 255) String address,
        @NotBlank @Size(max = 50) String licenseNumber,
        @NotBlank @Size(max = 20) String licenseClass,
        @NotNull LocalDate licenseExpiredAt
) {
}
