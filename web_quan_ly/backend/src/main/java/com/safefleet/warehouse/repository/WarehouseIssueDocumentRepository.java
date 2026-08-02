package com.safefleet.warehouse.repository;

import com.safefleet.warehouse.entity.WarehouseIssueDocument;
import com.safefleet.warehouse.enums.WarehouseIssueStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface WarehouseIssueDocumentRepository extends JpaRepository<WarehouseIssueDocument, Long> {
    Optional<WarehouseIssueDocument> findByIdAndDeletedFalse(Long id);
    Optional<WarehouseIssueDocument> findByTripIdAndDeletedFalse(Long tripId);
    boolean existsByIssueNumberAndDeletedFalse(String issueNumber);
    List<WarehouseIssueDocument> findByDeletedFalseOrderByCreatedAtDesc();
    List<WarehouseIssueDocument> findByDeletedFalseAndStatusOrderByCreatedAtDesc(WarehouseIssueStatus status);
}
