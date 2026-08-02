package com.safefleet.flood.repository;

import com.safefleet.flood.entity.FloodReport;
import com.safefleet.flood.enums.FloodStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface FloodReportRepository extends JpaRepository<FloodReport, Long>, JpaSpecificationExecutor<FloodReport> {

    List<FloodReport> findByStatusIn(Collection<FloodStatus> statuses);

    Optional<FloodReport> findByReportedByDriverIdAndClientEventIdAndDeletedFalse(
            Long driverId,
            String clientEventId
    );

    long countByDeletedFalse();
}
