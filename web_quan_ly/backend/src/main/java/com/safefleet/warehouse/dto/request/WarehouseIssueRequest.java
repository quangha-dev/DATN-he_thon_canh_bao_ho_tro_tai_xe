package com.safefleet.warehouse.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;

public record WarehouseIssueRequest(
        Long tripId,
        @Size(max = 50) String issueNumber,
        @NotNull LocalDate issueDate,
        @Size(max = 200) String companyName,
        @Size(max = 255) String companyAddress,
        @Size(max = 500) String issueReason,
        @NotBlank @Size(max = 150) String warehouseName,
        @Size(max = 150) String warehouseLocation,
        @NotBlank @Size(max = 200) String projectName,
        @Size(max = 200) String workItem,
        @NotBlank @Size(max = 150) String recipientName,
        @Size(max = 20) String recipientPhone,
        @Size(max = 255) String deliveryAddress,
        @Size(max = 150) String deliveryPersonName,
        @Size(max = 500) String quantityInWords,
        @Size(max = 1000) String notes,
        @NotEmpty List<@Valid WarehouseIssueItemRequest> items
) {}
