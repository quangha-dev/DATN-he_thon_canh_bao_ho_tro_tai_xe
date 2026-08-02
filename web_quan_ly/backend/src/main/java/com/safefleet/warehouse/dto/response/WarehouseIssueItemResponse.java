package com.safefleet.warehouse.dto.response;

import java.math.BigDecimal;

public record WarehouseIssueItemResponse(
        Long id, Integer lineNumber, String itemCode, String description,
        String specification, String unit, BigDecimal requestedQuantity,
        BigDecimal issuedQuantity, BigDecimal returnedQuantity,
        BigDecimal deliveredQuantity, String conditionNote, String confirmationNote
) {}
