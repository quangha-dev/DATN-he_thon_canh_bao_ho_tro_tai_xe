package com.safefleet.maintenance.dto.request;

import com.safefleet.maintenance.enums.MaintenancePriority;
import com.safefleet.maintenance.enums.MaintenanceStatus;
import com.safefleet.maintenance.enums.MaintenanceType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;

public record UpdateMaintenanceOrderRequest(
        @NotNull Long vehicleId,
        @NotNull MaintenanceType type,
        @NotBlank @Size(max = 150) String title,
        @Size(max = 1000) String description,
        LocalDate scheduledDate,
        LocalDate completedDate,
        BigDecimal cost,
        @NotNull MaintenanceStatus status,
        @NotNull MaintenancePriority priority,
        Long assignedTo,
        @Size(max = 1000) String note
) {
}
