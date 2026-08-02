package com.safefleet.incident.mapper;

import com.safefleet.incident.dto.response.IncidentResponse;
import com.safefleet.incident.dto.response.IncidentTimelineResponse;
import com.safefleet.incident.entity.Incident;
import com.safefleet.incident.entity.IncidentTimeline;

public final class IncidentMapper {

    private IncidentMapper() {
    }

    public static IncidentResponse toResponse(Incident incident) {
        return new IncidentResponse(
                incident.getId(),
                incident.getIncidentCode(),
                incident.getType(),
                incident.getSeverity(),
                incident.getVehicle() == null ? null : incident.getVehicle().getId(),
                incident.getVehicle() == null ? null : incident.getVehicle().getPlateNumber(),
                incident.getDriver() == null ? null : incident.getDriver().getId(),
                incident.getDriver() == null ? null : incident.getDriver().getFullName(),
                incident.getTrip() == null ? null : incident.getTrip().getId(),
                incident.getLat(),
                incident.getLng(),
                incident.getDescription(),
                incident.getStatus(),
                incident.getAssignedTo() == null ? null : incident.getAssignedTo().getId(),
                incident.getAssignedTo() == null ? null : incident.getAssignedTo().getFullName(),
                incident.getCreatedAt(),
                incident.getAcceptedAt(),
                incident.getResolvedAt()
        );
    }

    public static IncidentTimelineResponse toResponse(IncidentTimeline timeline) {
        return new IncidentTimelineResponse(
                timeline.getId(),
                timeline.getIncident().getId(),
                timeline.getAction(),
                timeline.getActor() == null ? null : timeline.getActor().getId(),
                timeline.getActor() == null ? null : timeline.getActor().getFullName(),
                timeline.getNote(),
                timeline.getCreatedAt()
        );
    }
}
