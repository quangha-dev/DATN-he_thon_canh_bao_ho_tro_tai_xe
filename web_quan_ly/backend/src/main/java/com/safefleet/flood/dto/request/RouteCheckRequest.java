package com.safefleet.flood.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record RouteCheckRequest(@Valid @NotEmpty List<RoutePointRequest> points) {
}
