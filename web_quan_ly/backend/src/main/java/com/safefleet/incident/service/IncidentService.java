package com.safefleet.incident.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.common.util.CodeGenerator;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.incident.dto.request.AssignIncidentRequest;
import com.safefleet.incident.dto.request.CreateIncidentRequest;
import com.safefleet.incident.dto.request.IncidentTimelineRequest;
import com.safefleet.incident.dto.request.SosRequest;
import com.safefleet.incident.dto.response.IncidentResponse;
import com.safefleet.incident.dto.response.IncidentTimelineResponse;
import com.safefleet.incident.entity.Incident;
import com.safefleet.incident.entity.IncidentTimeline;
import com.safefleet.incident.enums.IncidentStatus;
import com.safefleet.incident.enums.IncidentType;
import com.safefleet.incident.mapper.IncidentMapper;
import com.safefleet.incident.repository.IncidentRepository;
import com.safefleet.incident.repository.IncidentTimelineRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.infrastructure.security.ActionRateLimiter;
import com.safefleet.notification.enums.NotificationType;
import com.safefleet.notification.service.NotificationService;
import com.safefleet.safety.entity.SafetyEvent;
import com.safefleet.safety.enums.AlertSeverity;
import com.safefleet.safety.enums.SafetyEventType;
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
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class IncidentService {

    private final IncidentRepository incidentRepository;
    private final IncidentTimelineRepository timelineRepository;
    private final VehicleRepository vehicleRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final UserAccountRepository userAccountRepository;
    private final NotificationService notificationService;
    private final SimpMessagingTemplate messagingTemplate;
    private final ActionRateLimiter actionRateLimiter;

    @Value("${app.sos.cooldown-seconds:30}")
    private long sosCooldownSeconds;

    @Transactional(readOnly = true)
    public PageResponse<IncidentResponse> search(IncidentType type,
                                                 AlertSeverity severity,
                                                 IncidentStatus status,
                                                 Long vehicleId,
                                                 Long driverId,
                                                 Pageable pageable) {
        Specification<Incident> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isFalse(root.get("deleted")));
            if (type != null) {
                predicates.add(cb.equal(root.get("type"), type));
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
            if (driverId != null) {
                predicates.add(cb.equal(root.get("driver").get("id"), driverId));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.from(incidentRepository.findAll(spec, pageable).map(IncidentMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public IncidentResponse get(Long id) {
        return IncidentMapper.toResponse(findIncident(id));
    }

    @Transactional
    public IncidentResponse create(CreateIncidentRequest request) {
        Incident incident = new Incident();
        incident.setIncidentCode(CodeGenerator.code("INC"));
        incident.setType(request.type());
        incident.setSeverity(request.severity());
        incident.setVehicle(request.vehicleId() == null ? null : findVehicle(request.vehicleId()));
        incident.setDriver(request.driverId() == null ? null : findDriver(request.driverId()));
        incident.setTrip(request.tripId() == null ? null : findTrip(request.tripId()));
        incident.setLat(request.lat());
        incident.setLng(request.lng());
        incident.setDescription(request.description());
        Incident saved = incidentRepository.save(incident);
        addTimeline(saved, "CREATED", "Incident created manually");
        publishIncident(saved, NotificationType.SYSTEM, "Incident moi", saved.getDescription());
        return IncidentMapper.toResponse(saved);
    }

    @Transactional
    public IncidentResponse sos(SosRequest request) {
        Driver driver = resolveSosDriver(request.driverId());
        String clientEventId = normalizeClientEventId(request.clientEventId());
        if (driver != null && clientEventId != null) {
            var duplicate = incidentRepository.findByDriverIdAndClientEventId(driver.getId(), clientEventId);
            if (duplicate.isPresent()) {
                return IncidentMapper.toResponse(duplicate.get());
            }
        }
        if (SecurityUtils.hasRole("DRIVER")) {
            actionRateLimiter.check(SecurityUtils.currentUserId(), "SOS", 3, Duration.ofMinutes(1));
        }
        if (driver != null) {
            var recent = incidentRepository.findFirstByDriverIdAndTypeAndCreatedAtAfterOrderByCreatedAtDesc(
                    driver.getId(),
                    IncidentType.SOS,
                    LocalDateTime.now().minusSeconds(Math.max(1, sosCooldownSeconds))
            );
            if (recent.isPresent()) {
                return IncidentMapper.toResponse(recent.get());
            }
        }
        Incident incident = new Incident();
        incident.setIncidentCode(CodeGenerator.code("SOS"));
        incident.setType(IncidentType.SOS);
        incident.setSeverity(request.severity() == null ? AlertSeverity.CRITICAL : request.severity());
        incident.setVehicle(request.vehicleId() == null ? null : findVehicle(request.vehicleId()));
        incident.setDriver(driver);
        incident.setTrip(request.tripId() == null ? null : findTrip(request.tripId()));
        incident.setLat(request.lat());
        incident.setLng(request.lng());
        incident.setDescription(request.description() == null ? "Driver SOS" : request.description());
        incident.setClientEventId(clientEventId);
        incident.setReceivedAt(LocalDateTime.now());
        Incident saved = incidentRepository.save(incident);
        addTimeline(saved, "SOS_CREATED", "SOS submitted from driver app");
        publishIncident(saved, NotificationType.SOS, "SOS moi", saved.getDescription());
        return IncidentMapper.toResponse(saved);
    }

    @Transactional
    public IncidentResponse createFromSafetyEvent(SafetyEvent event) {
        Incident incident = new Incident();
        incident.setIncidentCode(CodeGenerator.code("INC"));
        incident.setType(mapIncidentType(event.getEventType()));
        incident.setSeverity(event.getSeverity());
        incident.setVehicle(event.getVehicle());
        incident.setDriver(event.getDriver());
        incident.setTrip(event.getTrip());
        incident.setLat(event.getLat());
        incident.setLng(event.getLng());
        incident.setDescription("Created from safety event " + event.getEventType());
        Incident saved = incidentRepository.save(incident);
        addTimeline(saved, "CREATED_FROM_SAFETY_EVENT", "Safety event id: " + event.getId());
        publishIncident(saved, NotificationType.AI_ALERT, "Incident tu canh bao AI", saved.getDescription());
        return IncidentMapper.toResponse(saved);
    }

    @Transactional
    public IncidentResponse accept(Long id) {
        Incident incident = findIncident(id);
        incident.setStatus(IncidentStatus.ACCEPTED);
        incident.setAcceptedAt(LocalDateTime.now());
        addTimeline(incident, "ACCEPTED", "Incident accepted");
        return IncidentMapper.toResponse(incident);
    }

    @Transactional
    public IncidentResponse assign(Long id, AssignIncidentRequest request) {
        Incident incident = findIncident(id);
        UserAccount rescue = userAccountRepository.findById(request.rescueUserId())
                .orElseThrow(() -> new NotFoundException("User", request.rescueUserId()));
        incident.setAssignedTo(rescue);
        incident.setStatus(IncidentStatus.PROCESSING);
        addTimeline(incident, "ASSIGNED", request.note());
        return IncidentMapper.toResponse(incident);
    }

    @Transactional
    public IncidentTimelineResponse addTimeline(Long id, IncidentTimelineRequest request) {
        Incident incident = findIncident(id);
        IncidentTimeline timeline = addTimeline(incident, request.action(), request.note());
        return IncidentMapper.toResponse(timeline);
    }

    @Transactional
    public IncidentResponse close(Long id, IncidentTimelineRequest request) {
        Incident incident = findIncident(id);
        incident.setStatus(IncidentStatus.CLOSED);
        incident.setResolvedAt(LocalDateTime.now());
        addTimeline(incident, request.action() == null ? "CLOSED" : request.action(), request.note());
        return IncidentMapper.toResponse(incident);
    }

    @Transactional(readOnly = true)
    public List<IncidentTimelineResponse> timeline(Long id) {
        return timelineRepository.findByIncidentIdOrderByCreatedAtAsc(id).stream()
                .map(IncidentMapper::toResponse)
                .toList();
    }

    public Incident findIncident(Long id) {
        return incidentRepository.findById(id)
                .filter(incident -> !incident.isDeleted())
                .orElseThrow(() -> new NotFoundException("Incident", id));
    }

    private Driver resolveSosDriver(Long requestDriverId) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return requestDriverId == null ? null : findDriver(requestDriverId);
        }
        Driver currentDriver = driverRepository.findByUserId(SecurityUtils.currentUserId())
                .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"));
        if (requestDriverId != null && !requestDriverId.equals(currentDriver.getId())) {
            throw new ForbiddenActionException("Tài xế chỉ được gửi SOS của chính mình");
        }
        return currentDriver;
    }

    private String normalizeClientEventId(String clientEventId) {
        if (clientEventId == null || clientEventId.isBlank()) {
            return null;
        }
        return clientEventId.trim();
    }

    private IncidentTimeline addTimeline(Incident incident, String action, String note) {
        IncidentTimeline timeline = new IncidentTimeline();
        timeline.setIncident(incident);
        timeline.setAction(action);
        timeline.setActor(currentActor());
        timeline.setNote(note);
        return timelineRepository.save(timeline);
    }

    private void publishIncident(Incident incident, NotificationType type, String title, String content) {
        IncidentResponse response = IncidentMapper.toResponse(incident);
        messagingTemplate.convertAndSend("/topic/incidents", response);
        notificationService.createGlobal(type, title, content == null ? incident.getIncidentCode() : content,
                "INCIDENT", incident.getId());
    }

    private IncidentType mapIncidentType(SafetyEventType eventType) {
        return switch (eventType) {
            case GPS_LOST -> IncidentType.GPS_LOST;
            case FLOOD_RISK -> IncidentType.FLOOD_STUCK;
            case DROWSINESS, OVER_DRIVING_TIME -> IncidentType.DRIVER_UNRESPONSIVE;
            default -> IncidentType.ACCIDENT;
        };
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

    private UserAccount currentActor() {
        try {
            return userAccountRepository.findById(SecurityUtils.currentUserId()).orElse(null);
        } catch (RuntimeException ignored) {
            return null;
        }
    }
}
