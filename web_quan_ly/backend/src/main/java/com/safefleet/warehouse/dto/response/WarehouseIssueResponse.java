package com.safefleet.warehouse.dto.response;

import com.safefleet.warehouse.enums.WarehouseIssueStatus;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public record WarehouseIssueResponse(
        Long id, Long tripId, String tripCode, String issueNumber,
        LocalDate issueDate, WarehouseIssueStatus status, Integer documentVersion,
        String companyName, String companyAddress, String issueReason,
        String warehouseName, String warehouseLocation, String projectName,
        String workItem, String recipientName, String recipientPhone,
        String deliveryAddress, String preparedByName, String deliveryPersonName,
        Long driverId, String driverName, Long vehicleId, String vehiclePlateNumber,
        String quantityInWords, String notes, LocalDateTime issuedAt,
        LocalDateTime completedAt, LocalDateTime createdAt, LocalDateTime updatedAt,
        List<WarehouseIssueItemResponse> items,
        List<WarehouseIssueConfirmationResponse> confirmations,
        List<WarehouseIssueAuditResponse> auditLogs
) {}
