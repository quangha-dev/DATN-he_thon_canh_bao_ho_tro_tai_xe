package com.safefleet.mobile.repository;

import com.safefleet.mobile.entity.PreTripChecklist;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PreTripChecklistRepository extends JpaRepository<PreTripChecklist, Long> {

    Optional<PreTripChecklist> findTopByTripIdAndDriverIdAndDeletedFalseOrderByCreatedAtDesc(Long tripId, Long driverId);
}
