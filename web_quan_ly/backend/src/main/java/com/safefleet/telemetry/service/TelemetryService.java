package com.safefleet.telemetry.service;

import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.telemetry.dto.request.TelemetryRequest;
import com.safefleet.telemetry.dto.response.TelemetryResponse;
import com.safefleet.telemetry.entity.TelemetryLog;
import com.safefleet.telemetry.enums.GpsStatus;
import com.safefleet.telemetry.mapper.TelemetryMapper;
import com.safefleet.telemetry.repository.TelemetryLogRepository;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.dto.response.VehicleRealtimeStatusResponse;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.mapper.VehicleMapper;
import com.safefleet.vehicle.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class TelemetryService {

    private static final long MAX_FUTURE_CLOCK_SKEW_MINUTES = 5;
    private static final long MAX_REALTIME_POSITION_AGE_MINUTES = 2;
    private static final double MAX_REALTIME_GPS_ACCURACY_METERS = 50.0;

    private final TelemetryLogRepository telemetryLogRepository;
    private final VehicleRepository vehicleRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final SimpMessagingTemplate messagingTemplate;

    @Transactional(noRollbackFor = {
            BadRequestException.class,
            ForbiddenActionException.class,
            NotFoundException.class
    })
    public TelemetryResponse ingest(TelemetryRequest request) {
        Vehicle vehicle = vehicleRepository.findByIdForUpdate(request.vehicleId())
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", request.vehicleId()));
        Driver driver = request.driverId() == null ? null : driverRepository.findById(request.driverId())
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", request.driverId()));
        Trip trip = request.tripId() == null ? null : tripRepository.findById(request.tripId())
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Trip", request.tripId()));

        assertDriverCanIngest(driver);
        assertDriverAssignment(driver, vehicle, trip);

        if (driver != null && request.clientEventId() != null && !request.clientEventId().isBlank()) {
            Optional<TelemetryLog> existing = telemetryLogRepository.findByDriverIdAndClientEventId(
                    driver.getId(),
                    request.clientEventId().trim()
            );
            if (existing.isPresent()) {
                return TelemetryMapper.toResponse(existing.get());
            }
        }

        LocalDateTime receivedAt = LocalDateTime.now();
        LocalDateTime recordedAt = request.createdAt() == null ? receivedAt : request.createdAt();
        if (recordedAt.isAfter(receivedAt.plusMinutes(MAX_FUTURE_CLOCK_SKEW_MINUTES))) {
            throw new BadRequestException("Thời điểm GPS vượt quá độ lệch cho phép");
        }
        TelemetryLog log = new TelemetryLog();
        log.setVehicle(vehicle);
        log.setDriver(driver);
        log.setTrip(trip);
        log.setLat(request.lat());
        log.setLng(request.lng());
        log.setSpeed(request.speed());
        log.setHeading(request.heading());
        log.setBatteryLevel(request.batteryLevel());
        GpsStatus gpsStatus = request.gpsStatus() == null ? GpsStatus.GOOD : request.gpsStatus();
        log.setGpsAccuracyMeters(request.gpsAccuracyMeters());
        log.setGpsStatus(gpsStatus);
        log.setClientEventId(request.clientEventId() == null ? null : request.clientEventId().trim());
        log.setRecordedAt(recordedAt);
        log.setReceivedAt(receivedAt);
        log.setCreatedAt(recordedAt);

        boolean newestPosition = vehicle.getLastUpdatedAt() == null || !recordedAt.isBefore(vehicle.getLastUpdatedAt());
        boolean positionAccepted = newestPosition
                && shouldAcceptRealtimePosition(gpsStatus, request.gpsAccuracyMeters(), recordedAt, receivedAt);
        log.setPositionAccepted(positionAccepted);
        if (positionAccepted) {
            vehicle.setLastLat(request.lat());
            vehicle.setLastLng(request.lng());
            vehicle.setLastSpeed(request.speed());
            vehicle.setLastUpdatedAt(recordedAt);
        }

        TelemetryResponse response = TelemetryMapper.toResponse(telemetryLogRepository.save(log));
        if (positionAccepted) {
            VehicleRealtimeStatusResponse status = VehicleMapper.toRealtimeStatus(vehicle);
            publishAfterCommit(vehicle.getId(), status);
        }
        return response;
    }

    boolean shouldAcceptRealtimePosition(GpsStatus gpsStatus,
                                         Double accuracyMeters,
                                         LocalDateTime recordedAt,
                                         LocalDateTime receivedAt) {
        if (gpsStatus == GpsStatus.LOST || gpsStatus == GpsStatus.OFFLINE) return false;
        boolean accurate = accuracyMeters == null
                ? gpsStatus == GpsStatus.GOOD
                : accuracyMeters <= MAX_REALTIME_GPS_ACCURACY_METERS;
        boolean fresh = !recordedAt.isBefore(receivedAt.minusMinutes(MAX_REALTIME_POSITION_AGE_MINUTES));
        return accurate && fresh;
    }

    void publishAfterCommit(Long vehicleId, VehicleRealtimeStatusResponse status) {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                messagingTemplate.convertAndSend("/topic/vehicles/positions", status);
                messagingTemplate.convertAndSend("/topic/vehicles/" + vehicleId + "/position", status);
            }
        });
    }

    @Transactional(readOnly = true)
    public Optional<TelemetryResponse> findByClientEvent(Long driverId, String clientEventId) {
        if (driverId == null || clientEventId == null || clientEventId.isBlank()) {
            return Optional.empty();
        }
        return telemetryLogRepository.findByDriverIdAndClientEventId(driverId, clientEventId.trim())
                .map(TelemetryMapper::toResponse);
    }

    @Transactional(readOnly = true)
    public List<VehicleRealtimeStatusResponse> currentVehicles() {
        return vehicleRepository.findAll((root, query, cb) -> cb.isFalse(root.get("deleted"))).stream()
                .map(VehicleMapper::toRealtimeStatus)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<TelemetryResponse> tripHistory(Long tripId, LocalDateTime from, LocalDateTime to) {
        Trip trip = tripRepository.findById(tripId)
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Trip", tripId));
        assertDriverCanReadTrip(trip);
        List<TelemetryLog> logs = (from == null || to == null)
                ? telemetryLogRepository.findByTripIdOrderByCreatedAtAsc(tripId)
                : telemetryLogRepository.findByTripIdAndCreatedAtBetweenOrderByCreatedAtAsc(tripId, from, to);
        return logs.stream().map(TelemetryMapper::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<TelemetryResponse> replay(Long tripId) {
        return tripHistory(tripId, null, null);
    }

    private void assertDriverCanIngest(Driver driver) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        if (driver == null || driver.getUser() == null || !driver.getUser().getId().equals(SecurityUtils.currentUserId())) {
            throw new ForbiddenActionException("Tài xế chỉ được gửi GPS của chính mình");
        }
    }

    private void assertDriverAssignment(Driver driver, Vehicle vehicle, Trip trip) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        if (driver.getCurrentVehicle() == null
                || !driver.getCurrentVehicle().getId().equals(vehicle.getId())) {
            throw new ForbiddenActionException("Tài xế chỉ được gửi GPS cho xe đang được phân công");
        }
        if (trip != null && (trip.getDriver() == null
                || !trip.getDriver().getId().equals(driver.getId())
                || trip.getVehicle() == null
                || !trip.getVehicle().getId().equals(vehicle.getId()))) {
            throw new ForbiddenActionException("Tài xế chỉ được gửi GPS cho chuyến đang được phân công");
        }
    }

    private void assertDriverCanReadTrip(Trip trip) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        if (trip.getDriver() == null || trip.getDriver().getUser() == null
                || !trip.getDriver().getUser().getId().equals(SecurityUtils.currentUserId())) {
            throw new ForbiddenActionException("Tài xế chỉ được xem GPS chuyến của chính mình");
        }
    }
}
