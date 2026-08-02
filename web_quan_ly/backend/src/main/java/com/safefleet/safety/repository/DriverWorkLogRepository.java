package com.safefleet.safety.repository;

import com.safefleet.safety.entity.DriverWorkLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Optional;

public interface DriverWorkLogRepository extends JpaRepository<DriverWorkLog, Long> {

    Optional<DriverWorkLog> findByDriverIdAndWorkDateAndTripId(Long driverId, LocalDate workDate, Long tripId);
}
