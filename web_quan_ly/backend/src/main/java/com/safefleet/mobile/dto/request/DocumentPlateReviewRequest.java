package com.safefleet.mobile.dto.request;

import jakarta.validation.constraints.Size;

public record DocumentPlateReviewRequest(
        @Size(max = 500) String note
) {
}
