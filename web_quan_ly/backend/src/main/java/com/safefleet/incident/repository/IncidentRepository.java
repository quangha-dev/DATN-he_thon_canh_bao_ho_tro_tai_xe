package com.safefleet.incident.repository;

import com.safefleet.incident.entity.Incident;
import com.safefleet.incident.enums.IncidentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.Collection;
import java.time.LocalDateTime;
import java.util.Optional;

public interface IncidentRepository extends JpaRepository<Incident, Long>, JpaSpecificationExecutor<Incident> {

    long countByStatusIn(Collection<IncidentStatus> statuses);

    long countByDeletedFalse();

    Optional<Incident> findByDriverIdAndClientEventId(Long driverId, String clientEventId);

    Optional<Incident> findFirstByDriverIdAndTypeAndCreatedAtAfterOrderByCreatedAtDesc(
            Long driverId,
            com.safefleet.incident.enums.IncidentType type,
            LocalDateTime after
    );
}
