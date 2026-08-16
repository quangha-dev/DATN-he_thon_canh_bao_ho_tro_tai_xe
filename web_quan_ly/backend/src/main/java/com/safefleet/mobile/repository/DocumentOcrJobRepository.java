package com.safefleet.mobile.repository;

import com.safefleet.mobile.entity.DocumentOcrJob;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.Optional;
import java.util.Collection;
import java.util.List;
import com.safefleet.mobile.enums.DocumentOcrJobStatus;
import com.safefleet.mobile.enums.PlateReviewStatus;

public interface DocumentOcrJobRepository extends JpaRepository<DocumentOcrJob, Long> {
    Optional<DocumentOcrJob> findByIdAndOwnerIdAndDeletedFalse(Long id, Long ownerId);
    List<DocumentOcrJob> findByStatusInAndDeletedFalse(Collection<DocumentOcrJobStatus> statuses);
    Page<DocumentOcrJob> findByDeletedFalseAndPlateReviewStatusOrderByCreatedAtDesc(
            PlateReviewStatus status, Pageable pageable);
}
