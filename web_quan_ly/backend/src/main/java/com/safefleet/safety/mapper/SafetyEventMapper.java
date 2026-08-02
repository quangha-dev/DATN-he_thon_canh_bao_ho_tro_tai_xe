package com.safefleet.safety.mapper;

import com.safefleet.safety.dto.response.SafetyEventResponse;
import com.safefleet.safety.entity.SafetyEvent;

public final class SafetyEventMapper {

    private SafetyEventMapper() {
    }

    public static SafetyEventResponse toResponse(SafetyEvent event) {
        return new SafetyEventResponse(
                event.getId(),
                event.getClientEventId(),
                event.getEventType(),
                event.getSeverity(),
                event.getVehicle() == null ? null : event.getVehicle().getId(),
                event.getVehicle() == null ? null : event.getVehicle().getPlateNumber(),
                event.getDriver() == null ? null : event.getDriver().getId(),
                event.getDriver() == null ? null : event.getDriver().getFullName(),
                event.getTrip() == null ? null : event.getTrip().getId(),
                event.getLat(),
                event.getLng(),
                event.getSpeed(),
                event.getConfidence(),
                event.getEvidenceUrl(),
                event.getStatus(),
                event.getHandledBy() == null ? null : event.getHandledBy().getId(),
                event.getHandledBy() == null ? null : event.getHandledBy().getFullName(),
                event.getHandledAt(),
                event.getNote(),
                event.getCreatedAt(),
                event.getReceivedAt()
        );
    }
}
