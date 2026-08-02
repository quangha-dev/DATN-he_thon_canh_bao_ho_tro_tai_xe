package com.safefleet.safety.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.enums.DriverStatus;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.incident.dto.response.IncidentResponse;
import com.safefleet.incident.service.IncidentService;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.notification.enums.NotificationType;
import com.safefleet.notification.service.NotificationService;
import com.safefleet.safety.dto.request.CreateSafetyEventRequest;
import com.safefleet.safety.dto.request.SafetyEventActionRequest;
import com.safefleet.safety.dto.response.SafetyEventResponse;
import com.safefleet.safety.entity.SafetyEvent;
import com.safefleet.safety.enums.AlertSeverity;
import com.safefleet.safety.enums.SafetyEventStatus;
import com.safefleet.safety.enums.SafetyEventType;
import com.safefleet.safety.mapper.SafetyEventMapper;
import com.safefleet.safety.repository.SafetyEventRepository;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.repository.VehicleRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SafetyEventService {

    private final SafetyEventRepository safetyEventRepository;
    private final VehicleRepository vehicleRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final UserAccountRepository userAccountRepository;
    private final NotificationService notificationService;
    private final IncidentService incidentService;
    private final SimpMessagingTemplate messagingTemplate;

    @Value("${app.safety.cooldown-seconds:30}")
    private long cooldownSeconds;

    @Transactional
    public SafetyEventResponse create(CreateSafetyEventRequest request) {
        Vehicle vehicle = request.vehicleId() == null ? null : findVehicle(request.vehicleId());
        Driver driver = request.driverId() == null ? null : findDriver(request.driverId());
        Trip trip = request.tripId() == null ? null : findTrip(request.tripId());
        assertDriverCanSubmit(driver);
        String clientEventId = normalizeClientEventId(request.clientEventId());
        if (driver != null && clientEventId != null) {
            var duplicate = safetyEventRepository.findByDriverIdAndClientEventId(driver.getId(), clientEventId);
            if (duplicate.isPresent()) {
                return SafetyEventMapper.toResponse(duplicate.get());
            }
        }
        if (SecurityUtils.hasRole("DRIVER") && driver != null) {
            var recent = safetyEventRepository
                    .findFirstByDriverIdAndEventTypeAndCreatedAtAfterOrderByCreatedAtDesc(
                            driver.getId(),
                            request.eventType(),
                            LocalDateTime.now().minusSeconds(Math.max(1, cooldownSeconds))
                    );
            if (recent.isPresent()) {
                return SafetyEventMapper.toResponse(recent.get());
            }
        }

        SafetyEvent event = new SafetyEvent();
        event.setEventType(request.eventType());
        event.setSeverity(request.severity());
        event.setVehicle(vehicle);
        event.setDriver(driver);
        event.setTrip(trip);
        event.setLat(request.lat());
        event.setLng(request.lng());
        event.setSpeed(request.speed());
        event.setConfidence(request.confidence());
        event.setEvidenceUrl(request.evidenceUrl());
        event.setCreatedAt(request.createdAt() == null ? LocalDateTime.now() : request.createdAt());
        event.setNote(request.note());
        event.setClientEventId(clientEventId);
        event.setReceivedAt(LocalDateTime.now());
        SafetyEvent saved = safetyEventRepository.save(event);

        applySafetyScoreImpact(saved);
        publishSafetyEvent(saved);
        return SafetyEventMapper.toResponse(saved);
    }

    @Transactional
    public SafetyEventResponse createSystemEvent(SafetyEventType eventType,
                                                 AlertSeverity severity,
                                                 Vehicle vehicle,
                                                 Driver driver,
                                                 Trip trip,
                                                 Double lat,
                                                 Double lng,
                                                 Double speed,
                                                 String note) {
        SafetyEvent event = new SafetyEvent();
        event.setEventType(eventType);
        event.setSeverity(severity);
        event.setVehicle(vehicle);
        event.setDriver(driver);
        event.setTrip(trip);
        event.setLat(lat);
        event.setLng(lng);
        event.setSpeed(speed);
        event.setConfidence(1.0);
        event.setNote(note);
        event.setReceivedAt(LocalDateTime.now());
        SafetyEvent saved = safetyEventRepository.save(event);
        applySafetyScoreImpact(saved);
        publishSafetyEvent(saved);
        return SafetyEventMapper.toResponse(saved);
    }

    @Transactional(readOnly = true)
    public PageResponse<SafetyEventResponse> search(SafetyEventType eventType,
                                                    AlertSeverity severity,
                                                    SafetyEventStatus status,
                                                    Long vehicleId,
                                                    Long driverId,
                                                    LocalDateTime from,
                                                    LocalDateTime to,
                                                    Pageable pageable) {
        Long scopedDriverId = driverId;
        if (SecurityUtils.hasRole("DRIVER")) {
            scopedDriverId = driverRepository.findByUserId(SecurityUtils.currentUserId())
                    .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"))
                    .getId();
        }
        Long finalDriverId = scopedDriverId;
        Specification<SafetyEvent> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (eventType != null) {
                predicates.add(cb.equal(root.get("eventType"), eventType));
            }
            if (severity != null) {
                predicates.add(cb.equal(root.get("severity"), severity));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (vehicleId != null) {
                predicates.add(cb.equal(root.get("vehicle").get("id"), vehicleId));
            }
            if (finalDriverId != null) {
                predicates.add(cb.equal(root.get("driver").get("id"), finalDriverId));
            }
            if (from != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("createdAt"), from));
            }
            if (to != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("createdAt"), to));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.from(safetyEventRepository.findAll(spec, pageable).map(SafetyEventMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public SafetyEventResponse get(Long id) {
        SafetyEvent event = findEvent(id);
        assertDriverCanRead(event);
        return SafetyEventMapper.toResponse(event);
    }

    @Transactional
    public SafetyEventResponse acknowledge(Long id, SafetyEventActionRequest request) {
        return changeStatus(id, SafetyEventStatus.ACKNOWLEDGED, request.note());
    }

    @Transactional
    public SafetyEventResponse resolve(Long id, SafetyEventActionRequest request) {
        return changeStatus(id, SafetyEventStatus.RESOLVED, request.note());
    }

    @Transactional
    public SafetyEventResponse dismiss(Long id, SafetyEventActionRequest request) {
        return changeStatus(id, SafetyEventStatus.DISMISSED, request.note());
    }

    @Transactional
    public IncidentResponse createIncident(Long id) {
        SafetyEvent event = findEvent(id);
        IncidentResponse incident = incidentService.createFromSafetyEvent(event);
        event.setStatus(SafetyEventStatus.PROCESSING);
        event.setHandledBy(currentActor());
        event.setHandledAt(LocalDateTime.now());
        event.setNote(appendNote(event.getNote(), "Incident created: " + incident.incidentCode()));
        return incident;
    }

    @Transactional(readOnly = true)
    public PageResponse<SafetyEventResponse> byVehicle(Long vehicleId, Pageable pageable) {
        return PageResponse.from(safetyEventRepository.findByVehicleIdOrderByCreatedAtDesc(vehicleId, pageable)
                .map(SafetyEventMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public PageResponse<SafetyEventResponse> byDriver(Long driverId, Pageable pageable) {
        if (SecurityUtils.hasRole("DRIVER")) {
            Driver currentDriver = driverRepository.findByUserId(SecurityUtils.currentUserId())
                    .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"));
            if (!currentDriver.getId().equals(driverId)) {
                throw new ForbiddenActionException("Tài xế chỉ được xem cảnh báo của chính mình");
            }
        }
        return PageResponse.from(safetyEventRepository.findByDriverIdOrderByCreatedAtDesc(driverId, pageable)
                .map(SafetyEventMapper::toResponse));
    }

    public SafetyEvent findEvent(Long id) {
        return safetyEventRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Safety event", id));
    }

    private SafetyEventResponse changeStatus(Long id, SafetyEventStatus status, String note) {
        SafetyEvent event = findEvent(id);
        event.setStatus(status);
        event.setHandledBy(currentActor());
        event.setHandledAt(LocalDateTime.now());
        event.setNote(appendNote(event.getNote(), note));
        return SafetyEventMapper.toResponse(event);
    }

    private void applySafetyScoreImpact(SafetyEvent event) {
        if (event.getDriver() == null) {
            return;
        }
        int penalty = switch (event.getSeverity()) {
            case LOW -> 1;
            case MEDIUM -> 3;
            case HIGH -> 7;
            case CRITICAL -> 12;
        };
        Driver driver = event.getDriver();
        driver.setTotalAlerts(driver.getTotalAlerts() + 1);
        driver.setSafetyScore(Math.max(0, driver.getSafetyScore() - penalty));
        if (driver.getSafetyScore() < 50 && driver.getStatus() != DriverStatus.SUSPENDED) {
            driver.setStatus(DriverStatus.HIGH_RISK);
        }
    }

    private void publishSafetyEvent(SafetyEvent event) {
        SafetyEventResponse response = SafetyEventMapper.toResponse(event);
        messagingTemplate.convertAndSend("/topic/safety-events", response);
        notificationService.createGlobal(NotificationType.AI_ALERT,
                "Canh bao AI moi",
                event.getEventType() + " - " + event.getSeverity(),
                "SAFETY_EVENT",
                event.getId());
    }

    private String appendNote(String oldNote, String newNote) {
        if (newNote == null || newNote.isBlank()) {
            return oldNote;
        }
        if (oldNote == null || oldNote.isBlank()) {
            return newNote;
        }
        return oldNote + "\n" + newNote;
    }

    private String normalizeClientEventId(String clientEventId) {
        if (clientEventId == null || clientEventId.isBlank()) {
            return null;
        }
        return clientEventId.trim();
    }

    private void assertDriverCanSubmit(Driver driver) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        if (driver == null || driver.getUser() == null || !driver.getUser().getId().equals(SecurityUtils.currentUserId())) {
            throw new ForbiddenActionException("Tài xế chỉ được gửi cảnh báo của chính mình");
        }
    }

    private void assertDriverCanRead(SafetyEvent event) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return;
        }
        if (event.getDriver() == null || event.getDriver().getUser() == null
                || !event.getDriver().getUser().getId().equals(SecurityUtils.currentUserId())) {
            throw new ForbiddenActionException("Tài xế chỉ được xem cảnh báo của chính mình");
        }
    }

    private UserAccount currentActor() {
        try {
            return userAccountRepository.findById(SecurityUtils.currentUserId()).orElse(null);
        } catch (RuntimeException ignored) {
            return null;
        }
    }

    private Vehicle findVehicle(Long id) {
        return vehicleRepository.findById(id)
                .filter(vehicle -> !vehicle.isDeleted())
                .orElseThrow(() -> new NotFoundException("Vehicle", id));
    }

    private Driver findDriver(Long id) {
        return driverRepository.findById(id)
                .filter(driver -> !driver.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", id));
    }

    private Trip findTrip(Long id) {
        return tripRepository.findById(id)
                .filter(trip -> !trip.isDeleted())
                .orElseThrow(() -> new NotFoundException("Trip", id));
    }
}
