package com.safefleet.warehouse.dto.request;

import com.safefleet.warehouse.enums.ConfirmationRole;
import com.safefleet.warehouse.enums.ConfirmationStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record WarehouseIssueConfirmationRequest(
        @NotNull ConfirmationRole role,
        @NotNull ConfirmationStatus status,
        @NotBlank @Size(max = 150) String signerName,
        @Size(max = 20) String signerPhone,
        Double lat,
        Double lng,
        @Size(max = 500) String evidenceUrl,
        @Size(max = 500) String note
) {}
