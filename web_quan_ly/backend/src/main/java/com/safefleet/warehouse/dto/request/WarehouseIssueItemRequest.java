package com.safefleet.warehouse.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record WarehouseIssueItemRequest(
        @Size(max = 80) String itemCode,
        @NotBlank @Size(max = 255) String description,
        @Size(max = 255) String specification,
        @NotBlank @Size(max = 40) String unit,
        @DecimalMin(value = "0.0", inclusive = false) BigDecimal requestedQuantity,
        @NotNull @DecimalMin(value = "0.0", inclusive = false) BigDecimal issuedQuantity,
        @DecimalMin("0.0") BigDecimal returnedQuantity,
        @DecimalMin("0.0") BigDecimal deliveredQuantity,
        @Size(max = 500) String conditionNote,
        @Size(max = 500) String confirmationNote
) {}
