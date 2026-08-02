package com.safefleet.telemetry.repository;

import com.safefleet.telemetry.entity.TelemetryLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface TelemetryLogRepository extends JpaRepository<TelemetryLog, Long> {

    List<TelemetryLog> findByTripIdOrderByCreatedAtAsc(Long tripId);

    List<TelemetryLog> findByTripIdAndCreatedAtBetweenOrderByCreatedAtAsc(Long tripId, LocalDateTime from, LocalDateTime to);

    List<TelemetryLog> findTop200ByVehicleIdOrderByCreatedAtDesc(Long vehicleId);

    Optional<TelemetryLog> findByDriverIdAndClientEventId(Long driverId, String clientEventId);
}
