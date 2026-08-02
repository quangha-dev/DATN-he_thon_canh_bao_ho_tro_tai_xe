package com.safefleet.mobile.dto.response;

import java.time.LocalDateTime;

public record MobilePreTripChecklistResponse(
        Long id,
        Long tripId,
        Long driverId,
        Long vehicleId,
        boolean exteriorChecked,
        boolean tiresChecked,
        boolean brakeChecked,
        boolean lightsChecked,
        boolean cameraChecked,
        boolean gpsChecked,
        boolean documentsChecked,
        boolean passed,
        String note,
        LocalDateTime createdAt
) {
}
