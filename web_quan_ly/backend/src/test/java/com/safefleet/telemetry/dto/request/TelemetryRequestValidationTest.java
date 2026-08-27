package com.safefleet.telemetry.dto.request;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class TelemetryRequestValidationTest {

    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();

    @Test
    void rejectsNegativeSpeedOutOfRangeHeadingAndBattery() {
        TelemetryRequest request = new TelemetryRequest(
                1L, null, null, 21.0, 105.0,
                -0.1, 360.1, 101, -1.0, null, null, "invalid-device-values"
        );

        assertThat(validator.validate(request))
                .extracting(violation -> violation.getPropertyPath().toString())
                .containsExactlyInAnyOrder("speed", "heading", "batteryLevel", "gpsAccuracyMeters");
    }

    @Test
    void acceptsBoundaryValues() {
        TelemetryRequest request = new TelemetryRequest(
                1L, null, null, 21.0, 105.0,
                0.0, 360.0, 100, 50.0, null, null, "valid-device-values"
        );

        assertThat(validator.validate(request)).isEmpty();
    }
}
