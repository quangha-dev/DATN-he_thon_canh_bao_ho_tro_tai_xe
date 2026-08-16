package com.safefleet.telemetry.service;

import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.telemetry.repository.TelemetryLogRepository;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.dto.response.VehicleRealtimeStatusResponse;
import com.safefleet.vehicle.repository.VehicleRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

class TelemetryAfterCommitPublishTest {

    @AfterEach
    void clearSynchronization() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void defersRealtimeMessagesUntilTransactionCommitCallback() {
        SimpMessagingTemplate messaging = mock(SimpMessagingTemplate.class);
        TelemetryService service = new TelemetryService(
                mock(TelemetryLogRepository.class),
                mock(VehicleRepository.class),
                mock(DriverRepository.class),
                mock(TripRepository.class),
                messaging
        );
        VehicleRealtimeStatusResponse status = mock(VehicleRealtimeStatusResponse.class);
        TransactionSynchronizationManager.initSynchronization();

        service.publishAfterCommit(42L, status);

        verifyNoInteractions(messaging);
        TransactionSynchronizationManager.getSynchronizations().forEach(synchronization -> synchronization.afterCommit());
        verify(messaging).convertAndSend("/topic/vehicles/positions", status);
        verify(messaging).convertAndSend("/topic/vehicles/42/position", status);
    }
}
