package com.safefleet.maintenance.mapper;

import com.safefleet.maintenance.dto.response.MaintenanceOrderResponse;
import com.safefleet.maintenance.entity.MaintenanceOrder;

public final class MaintenanceMapper {

    private MaintenanceMapper() {
    }

    public static MaintenanceOrderResponse toResponse(MaintenanceOrder order) {
        return new MaintenanceOrderResponse(
                order.getId(),
                order.getMaintenanceCode(),
                order.getVehicle().getId(),
                order.getVehicle().getPlateNumber(),
                order.getType(),
                order.getTitle(),
                order.getDescription(),
                order.getScheduledDate(),
                order.getCompletedDate(),
                order.getCost(),
                order.getStatus(),
                order.getPriority(),
                order.getAssignedTo() == null ? null : order.getAssignedTo().getId(),
                order.getAssignedTo() == null ? null : order.getAssignedTo().getFullName(),
                order.getNote()
        );
    }
}
