package com.safefleet.flood.dto.request;

import jakarta.validation.constraints.Size;

public record FloodActionRequest(@Size(max = 500) String note) {
}
