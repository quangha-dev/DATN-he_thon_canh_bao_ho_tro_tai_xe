package com.safefleet.telemetry.service;

import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.telemetry.enums.GpsStatus;
import com.safefleet.telemetry.repository.TelemetryLogRepository;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.repository.VehicleRepository;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class TelemetryGpsQualityTest {

    private final TelemetryService service = new TelemetryService(
            mock(TelemetryLogRepository.class),
            mock(VehicleRepository.class),
            mock(DriverRepository.class),
            mock(TripRepository.class),
            mock(SimpMessagingTemplate.class)
    );

    @Test
    void acceptsFreshAccurateGpsButRejectsWeakStaleOrLostPositions() {
        LocalDateTime now = LocalDateTime.now();

        assertThat(service.shouldAcceptRealtimePosition(GpsStatus.GOOD, 8.0, now, now)).isTrue();
        assertThat(service.shouldAcceptRealtimePosition(GpsStatus.WEAK, 35.0, now, now)).isTrue();
        assertThat(service.shouldAcceptRealtimePosition(GpsStatus.WEAK, 75.0, now, now)).isFalse();
        assertThat(service.shouldAcceptRealtimePosition(GpsStatus.LOST, 5.0, now, now)).isFalse();
        assertThat(service.shouldAcceptRealtimePosition(
                GpsStatus.GOOD, 5.0, now.minusMinutes(3), now
        )).isFalse();
    }

    @Test
    void legacyTelemetryWithoutAccuracyIsAcceptedOnlyWhenDeviceClaimsGoodGps() {
        LocalDateTime now = LocalDateTime.now();

        assertThat(service.shouldAcceptRealtimePosition(GpsStatus.GOOD, null, now, now)).isTrue();
        assertThat(service.shouldAcceptRealtimePosition(GpsStatus.WEAK, null, now, now)).isFalse();
    }
}
