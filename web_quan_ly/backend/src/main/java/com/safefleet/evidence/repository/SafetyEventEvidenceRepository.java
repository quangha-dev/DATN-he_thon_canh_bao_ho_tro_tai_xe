package com.safefleet.evidence.repository;

import com.safefleet.evidence.entity.SafetyEventEvidence;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface SafetyEventEvidenceRepository extends JpaRepository<SafetyEventEvidence, Long> {

    Optional<SafetyEventEvidence> findByIdAndDeletedFalse(Long id);
}
