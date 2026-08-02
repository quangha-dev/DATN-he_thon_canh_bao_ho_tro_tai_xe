package com.safefleet.trip.mapper;

import com.safefleet.trip.dto.response.TripResponse;
import com.safefleet.trip.dto.response.TripTimelineResponse;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.entity.TripTimeline;

public final class TripMapper {

    private TripMapper() {
    }

    public static TripResponse toResponse(Trip trip) {
        return new TripResponse(
                trip.getId(),
                trip.getTripCode(),
                trip.getVehicle() == null ? null : trip.getVehicle().getId(),
                trip.getVehicle() == null ? null : trip.getVehicle().getPlateNumber(),
                trip.getDriver() == null ? null : trip.getDriver().getId(),
                trip.getDriver() == null ? null : trip.getDriver().getFullName(),
                trip.getStartLocation(),
                trip.getStartLat(),
                trip.getStartLng(),
                trip.getEndLocation(),
                trip.getEndLat(),
                trip.getEndLng(),
                trip.getWaypoints(),
                trip.getPlannedRoute(),
                trip.getActualRoute(),
                trip.getPlannedStartTime(),
                trip.getActualStartTime(),
                trip.getEstimatedEndTime(),
                trip.getActualEndTime(),
                trip.getStatus(),
                trip.getProgress(),
                trip.getRiskLevel()
        );
    }

    public static TripTimelineResponse toResponse(TripTimeline timeline) {
        return new TripTimelineResponse(
                timeline.getId(),
                timeline.getTrip().getId(),
                timeline.getAction(),
                timeline.getActor() == null ? null : timeline.getActor().getId(),
                timeline.getActor() == null ? null : timeline.getActor().getFullName(),
                timeline.getNote(),
                timeline.getCreatedAt()
        );
    }
}
