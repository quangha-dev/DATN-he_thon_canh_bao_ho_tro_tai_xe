package com.safefleet.warehouse.dto.response;

import com.safefleet.warehouse.enums.ConfirmationRole;
import com.safefleet.warehouse.enums.ConfirmationStatus;
import java.time.LocalDateTime;

public record WarehouseIssueConfirmationResponse(
        Long id, ConfirmationRole role, ConfirmationStatus status,
        String signerName, String signerPhone, LocalDateTime signedAt,
        Double lat, Double lng, String evidenceUrl, String note
) {}
