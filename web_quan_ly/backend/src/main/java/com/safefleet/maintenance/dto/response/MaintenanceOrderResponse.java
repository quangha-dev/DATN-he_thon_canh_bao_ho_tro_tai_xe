package com.safefleet.maintenance.dto.response;

import com.safefleet.maintenance.enums.MaintenancePriority;
import com.safefleet.maintenance.enums.MaintenanceStatus;
import com.safefleet.maintenance.enums.MaintenanceType;

import java.math.BigDecimal;
import java.time.LocalDate;

public record MaintenanceOrderResponse(
        Long id,
        String maintenanceCode,
        Long vehicleId,
        String vehiclePlateNumber,
        MaintenanceType type,
        String title,
        String description,
        LocalDate scheduledDate,
        LocalDate completedDate,
        BigDecimal cost,
        MaintenanceStatus status,
        MaintenancePriority priority,
        Long assignedTo,
        String assignedToName,
        String note
) {
}
