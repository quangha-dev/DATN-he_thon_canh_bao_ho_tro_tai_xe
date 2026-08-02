package com.safefleet.mobile.dto.request;

import jakarta.validation.constraints.Size;

public record MobilePreTripChecklistRequest(
        boolean exteriorChecked,
        boolean tiresChecked,
        boolean brakeChecked,
        boolean lightsChecked,
        boolean cameraChecked,
        boolean gpsChecked,
        boolean documentsChecked,
        @Size(max = 500) String note
) {
}
