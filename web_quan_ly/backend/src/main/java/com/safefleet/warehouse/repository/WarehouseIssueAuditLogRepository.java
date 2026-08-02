package com.safefleet.warehouse.repository;

import com.safefleet.warehouse.entity.WarehouseIssueAuditLog;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface WarehouseIssueAuditLogRepository extends JpaRepository<WarehouseIssueAuditLog, Long> {
    List<WarehouseIssueAuditLog> findByDocumentIdOrderByCreatedAtAsc(Long documentId);
}
