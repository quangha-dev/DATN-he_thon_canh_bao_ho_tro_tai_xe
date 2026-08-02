package com.safefleet.safety.dto.request;

import jakarta.validation.constraints.Size;

public record SafetyEventActionRequest(@Size(max = 500) String note) {
}
