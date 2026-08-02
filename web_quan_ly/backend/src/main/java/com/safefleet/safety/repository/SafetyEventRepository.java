package com.safefleet.safety.repository;

import com.safefleet.safety.entity.SafetyEvent;
import com.safefleet.safety.enums.SafetyEventStatus;
import com.safefleet.safety.enums.SafetyEventType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.Collection;
import java.time.LocalDateTime;
import java.util.Optional;

public interface SafetyEventRepository extends JpaRepository<SafetyEvent, Long>, JpaSpecificationExecutor<SafetyEvent> {

    Page<SafetyEvent> findByVehicleIdOrderByCreatedAtDesc(Long vehicleId, Pageable pageable);

    Page<SafetyEvent> findByDriverIdOrderByCreatedAtDesc(Long driverId, Pageable pageable);

    long countByStatusIn(Collection<SafetyEventStatus> statuses);

    long countByEventType(SafetyEventType eventType);

    Optional<SafetyEvent> findByDriverIdAndClientEventId(Long driverId, String clientEventId);

    Optional<SafetyEvent> findFirstByDriverIdAndEventTypeAndCreatedAtAfterOrderByCreatedAtDesc(
            Long driverId,
            SafetyEventType eventType,
            LocalDateTime after
    );

    long countByDriverId(Long driverId);

    long countByVehicleId(Long vehicleId);
}
