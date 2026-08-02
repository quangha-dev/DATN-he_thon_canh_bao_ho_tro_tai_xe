package com.safefleet.safety.repository;

import com.safefleet.safety.entity.DrivingSession;
import com.safefleet.safety.enums.DrivingSessionStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.Optional;

public interface DrivingSessionRepository extends JpaRepository<DrivingSession, Long> {

    Optional<DrivingSession> findFirstByDriverIdAndStatusInOrderByStartedAtDesc(Long driverId, Collection<DrivingSessionStatus> statuses);
}
