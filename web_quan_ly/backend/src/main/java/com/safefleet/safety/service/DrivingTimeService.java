package com.safefleet.safety.service;

import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.safety.dto.request.StartDrivingSessionRequest;
import com.safefleet.safety.dto.response.DrivingSessionResponse;
import com.safefleet.safety.dto.response.RemainingDrivingTimeResponse;
import com.safefleet.safety.entity.DriverWorkLog;
import com.safefleet.safety.entity.DrivingSession;
import com.safefleet.safety.enums.AlertSeverity;
import com.safefleet.safety.enums.DrivingSessionStatus;
import com.safefleet.safety.enums.SafetyEventType;
import com.safefleet.safety.mapper.DrivingSessionMapper;
import com.safefleet.safety.repository.DriverWorkLogRepository;
import com.safefleet.safety.repository.DrivingSessionRepository;
import com.safefleet.settings.service.SystemSettingService;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.VehicleStatus;
import com.safefleet.vehicle.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DrivingTimeService {

    private final DrivingSessionRepository sessionRepository;
    private final DriverWorkLogRepository workLogRepository;
    private final DriverRepository driverRepository;
    private final VehicleRepository vehicleRepository;
    private final TripRepository tripRepository;
    private final SystemSettingService settingService;
    private final SafetyEventService safetyEventService;

    @Transactional
    public DrivingSessionResponse start(StartDrivingSessionRequest request) {
        Driver driver = findDriver(request.driverId());
        assertDriverOwner(driver);
        sessionRepository.findFirstByDriverIdAndStatusInOrderByStartedAtDesc(
                driver.getId(), List.of(DrivingSessionStatus.ACTIVE, DrivingSessionStatus.PAUSED)
        ).ifPresent(existing -> {
            throw new BadRequestException("Tài xế đang có phiên lái hoạt động");
        });

        Vehicle vehicle = request.vehicleId() == null ? null : findVehicle(request.vehicleId());
        Trip trip = request.tripId() == null ? null : findTrip(request.tripId());
        LocalDateTime now = LocalDateTime.now();

        DrivingSession session = new DrivingSession();
        session.setDriver(driver);
        session.setVehicle(vehicle);
        session.setTrip(trip);
        session.setStartedAt(now);
        session.setResumedAt(now);
        session.setStatus(DrivingSessionStatus.ACTIVE);

        driver.setStatus(DriverStatus.DRIVING);
        if (vehicle != null) {
            vehicle.setStatus(VehicleStatus.RUNNING);
        }
        return DrivingSessionMapper.toResponse(sessionRepository.save(session));
    }

    @Transactional
    public DrivingSessionResponse pause(Long sessionId) {
        DrivingSession session = findSession(sessionId);
        assertDriverOwner(session.getDriver());
        requireStatus(session, DrivingSessionStatus.ACTIVE);
        addActiveMinutes(session, LocalDateTime.now());
        session.setStatus(DrivingSessionStatus.PAUSED);
        session.setPausedAt(LocalDateTime.now());
        session.getDriver().setStatus(DriverStatus.RESTING);
        if (session.getVehicle() != null) {
            session.getVehicle().setStatus(VehicleStatus.RESTING);
        }
        updateDriverSnapshot(session);
        return DrivingSessionMapper.toResponse(session);
    }

    @Transactional
    public DrivingSessionResponse resume(Long sessionId) {
        DrivingSession session = findSession(sessionId);
        assertDriverOwner(session.getDriver());
        requireStatus(session, DrivingSessionStatus.PAUSED);
        session.setStatus(DrivingSessionStatus.ACTIVE);
        session.setResumedAt(LocalDateTime.now());
        session.setPausedAt(null);
        session.getDriver().setStatus(DriverStatus.DRIVING);
        if (session.getVehicle() != null) {
            session.getVehicle().setStatus(VehicleStatus.RUNNING);
        }
        return DrivingSessionMapper.toResponse(session);
    }

    @Transactional
    public DrivingSessionResponse finish(Long sessionId) {
        DrivingSession session = findSession(sessionId);
        assertDriverOwner(session.getDriver());
        if (session.getStatus() == DrivingSessionStatus.ACTIVE) {
            addActiveMinutes(session, LocalDateTime.now());
        }
        session.setStatus(DrivingSessionStatus.FINISHED);
        session.setEndedAt(LocalDateTime.now());
        session.getDriver().setStatus(DriverStatus.AVAILABLE);
        session.getDriver().setContinuousDrivingMinutes(0);
        session.getDriver().setDrivingTimeTodayMinutes(session.getDriver().getDrivingTimeTodayMinutes() + session.getTotalMinutes());
        if (session.getVehicle() != null) {
            session.getVehicle().setStatus(VehicleStatus.AVAILABLE);
        }
        upsertWorkLog(session);
        return DrivingSessionMapper.toResponse(session);
    }

    @Transactional(readOnly = true)
    public DrivingSessionResponse currentForDriver(Long driverId) {
        Driver driver = findDriver(driverId);
        assertDriverOwner(driver);
        return activeSession(driverId)
                .map(DrivingSessionMapper::toResponse)
                .orElse(null);
    }

    @Transactional
    public DrivingSessionResponse pauseCurrent(Long driverId) {
        return pause(requireActiveSession(driverId).getId());
    }

    @Transactional
    public DrivingSessionResponse resumeCurrent(Long driverId) {
        return resume(requireActiveSession(driverId).getId());
    }

    @Transactional
    public DrivingSessionResponse finishCurrent(Long driverId) {
        return finish(requireActiveSession(driverId).getId());
    }

    @Transactional
    public RemainingDrivingTimeResponse remainingTime(Long driverId) {
        Driver driver = findDriver(driverId);
        assertDriverOwner(driver);
        DrivingSession session = sessionRepository.findFirstByDriverIdAndStatusInOrderByStartedAtDesc(
                driverId, List.of(DrivingSessionStatus.ACTIVE, DrivingSessionStatus.PAUSED)
        ).orElse(null);

        int max = maxContinuousMinutes();
        if (session == null) {
            return new RemainingDrivingTimeResponse(driverId, null, null, max, driver.getContinuousDrivingMinutes(),
                    Math.max(0, max - driver.getContinuousDrivingMinutes()), warningLevel(driver.getContinuousDrivingMinutes()));
        }

        int current = currentContinuousMinutes(session);
        driver.setContinuousDrivingMinutes(current);
        maybeCreateOverDrivingEvent(session, current, max);
        return new RemainingDrivingTimeResponse(
                driverId,
                session.getId(),
                session.getStatus(),
                max,
                current,
                Math.max(0, max - current),
                warningLevel(current)
        );
    }

    private void maybeCreateOverDrivingEvent(DrivingSession session, int currentMinutes, int maxMinutes) {
        if (currentMinutes < maxMinutes || session.isOverDrivingAlertCreated()) {
            return;
        }
        safetyEventService.createSystemEvent(
                SafetyEventType.OVER_DRIVING_TIME,
                AlertSeverity.HIGH,
                session.getVehicle(),
                session.getDriver(),
                session.getTrip(),
                session.getVehicle() == null ? null : session.getVehicle().getLastLat(),
                session.getVehicle() == null ? null : session.getVehicle().getLastLng(),
                session.getVehicle() == null ? null : session.getVehicle().getLastSpeed(),
                "Driver exceeded configured continuous driving limit: " + maxMinutes + " minutes"
        );
        session.setOverDrivingAlertCreated(true);
    }

    private void addActiveMinutes(DrivingSession session, LocalDateTime now) {
        LocalDateTime checkpoint = session.getResumedAt() == null ? session.getStartedAt() : session.getResumedAt();
        int minutes = Math.max(0, (int) Duration.between(checkpoint, now).toMinutes());
        session.setContinuousMinutes(session.getContinuousMinutes() + minutes);
        session.setTotalMinutes(session.getTotalMinutes() + minutes);
        session.setResumedAt(now);
    }

    private int currentContinuousMinutes(DrivingSession session) {
        if (session.getStatus() != DrivingSessionStatus.ACTIVE) {
            return session.getContinuousMinutes();
        }
        LocalDateTime checkpoint = session.getResumedAt() == null ? session.getStartedAt() : session.getResumedAt();
        return session.getContinuousMinutes() + Math.max(0, (int) Duration.between(checkpoint, LocalDateTime.now()).toMinutes());
    }

    private String warningLevel(int minutes) {
        if (minutes >= maxContinuousMinutes()) {
            return "OVER_LIMIT";
        }
        if (minutes >= criticalMinutes()) {
            return "CRITICAL";
        }
        if (minutes >= warn2Minutes()) {
            return "WARNING_2";
        }
        if (minutes >= warn1Minutes()) {
            return "WARNING_1";
        }
        return "NORMAL";
    }

    private void updateDriverSnapshot(DrivingSession session) {
        session.getDriver().setContinuousDrivingMinutes(session.getContinuousMinutes());
    }

    private void upsertWorkLog(DrivingSession session) {
        Long tripId = session.getTrip() == null ? null : session.getTrip().getId();
        DriverWorkLog log = workLogRepository.findByDriverIdAndWorkDateAndTripId(
                session.getDriver().getId(), LocalDate.now(), tripId
        ).orElseGet(() -> {
            DriverWorkLog created = new DriverWorkLog();
            created.setDriver(session.getDriver());
            created.setTrip(session.getTrip());
            created.setWorkDate(LocalDate.now());
            return created;
        });
        log.setDrivingMinutes(log.getDrivingMinutes() + session.getTotalMinutes());
        workLogRepository.save(log);
    }

    private int maxContinuousMinutes() {
        return settingService.getInt(SystemSettingService.DRIVING_MAX_CONTINUOUS_MINUTES, 240);
    }

    private int warn1Minutes() {
        return settingService.getInt(SystemSettingService.DRIVING_WARN_1_MINUTES, 180);
    }

    private int warn2Minutes() {
        return settingService.getInt(SystemSettingService.DRIVING_WARN_2_MINUTES, 210);
    }

    private int criticalMinutes() {
        return settingService.getInt(SystemSettingService.DRIVING_CRITICAL_MINUTES, 230);
    }

    private DrivingSession findSession(Long id) {
        return sessionRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Driving session", id));
    }

    private java.util.Optional<DrivingSession> activeSession(Long driverId) {
        return sessionRepository.findFirstByDriverIdAndStatusInOrderByStartedAtDesc(
                driverId,
                List.of(DrivingSessionStatus.ACTIVE, DrivingSessionStatus.PAUSED)
        );
    }

    private DrivingSession requireActiveSession(Long driverId) {
        Driver driver = findDriver(driverId);
        assertDriverOwner(driver);
        return activeSession(driverId)
                .orElseThrow(() -> new BadRequestException("Không có phiên lái đang hoạt động"));
    }

    private Driver findDriver(Long id) {
        return driverRepository.findById(id)
                .filter(driver -> !driver.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", id));
    }

    private Vehicle findVehicle(Long id) {
        return vehicleRepository.findById(id)
                .filter(vehicle -> !vehicle.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", id));
    }

    private Trip findTrip(Long id) {
        return tripRepository.findById(id)
                .filter(trip -> !trip.isDeleted())
                .orElseThrow(() -> new NotFoundException("Trip", id));
    }

    private void requireStatus(DrivingSession session, DrivingSessionStatus status) {
        if (session.getStatus() != status) {
            throw new BadRequestException("Trạng thái phiên lái không hợp lệ");
        }
    }

    private void assertDriverOwner(Driver driver) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        if (driver.getUser() == null || !driver.getUser().getId().equals(SecurityUtils.currentUserId())) {
            throw new ForbiddenActionException("Tài xế chỉ được quản lý phiên lái của chính mình");
        }
    }
}
