package com.safefleet.warehouse.dto.response;

import com.safefleet.warehouse.enums.WarehouseIssueStatus;
import java.time.LocalDateTime;

public record WarehouseIssueAuditResponse(
        Long id, String action, WarehouseIssueStatus fromStatus,
        WarehouseIssueStatus toStatus, String actorName, String note,
        LocalDateTime createdAt
) {}
