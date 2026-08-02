package com.safefleet.trip.repository;

import com.safefleet.trip.entity.TripTimeline;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TripTimelineRepository extends JpaRepository<TripTimeline, Long> {

    List<TripTimeline> findByTripIdOrderByCreatedAtAsc(Long tripId);
}
