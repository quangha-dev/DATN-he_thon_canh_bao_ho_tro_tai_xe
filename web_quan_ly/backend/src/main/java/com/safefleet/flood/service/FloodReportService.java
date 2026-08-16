package com.safefleet.flood.service;

import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.common.util.GeoUtils;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.flood.dto.request.CreateFloodReportRequest;
import com.safefleet.flood.dto.request.FloodActionRequest;
import com.safefleet.flood.dto.request.RouteCheckRequest;
import com.safefleet.flood.dto.response.FloodReportResponse;
import com.safefleet.flood.dto.response.RouteRiskSummaryResponse;
import com.safefleet.flood.dto.response.FloodWarningResponse;
import com.safefleet.flood.entity.FloodReport;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.enums.FloodStatus;
import com.safefleet.flood.mapper.FloodReportMapper;
import com.safefleet.flood.repository.FloodReportRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.notification.enums.NotificationType;
import com.safefleet.notification.service.NotificationService;
import com.safefleet.settings.service.SystemSettingService;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.HashSet;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class FloodReportService {

    private static final double ROUTE_RISK_RADIUS_KM = 0.5;
    private static final double NEARBY_CLUSTER_RADIUS_KM = 0.3;
    private static final double DRIVER_WARNING_RADIUS_KM = 10.0;

    private final FloodReportRepository floodReportRepository;
    private final DriverRepository driverRepository;
    private final UserAccountRepository userAccountRepository;
    private final NotificationService notificationService;
    private final SystemSettingService settingService;
    private final SimpMessagingTemplate messagingTemplate;

    @Transactional
    public FloodReportResponse create(CreateFloodReportRequest request) {
        Driver driver = resolveReporter(request.reportedByDriverId());
        String clientEventId = normalizeClientEventId(request.clientEventId());
        if (driver != null && clientEventId != null) {
            var duplicate = floodReportRepository
                    .findByReportedByDriverIdAndClientEventIdAndDeletedFalse(
                            driver.getId(),
                            clientEventId
                    );
            if (duplicate.isPresent()) {
                return FloodReportMapper.toResponse(duplicate.get());
            }
        }
        FloodReport report = new FloodReport();
        report.setLat(request.lat());
        report.setLng(request.lng());
        report.setAddress(request.address());
        report.setSeverity(request.severity());
        report.setSource(request.source());
        report.setReportedByDriver(driver);
        report.setImageUrl(request.imageUrl());
        report.setClientEventId(clientEventId);
        report.setExpiredAt(LocalDateTime.now().plusMinutes(
                settingService.getInt(SystemSettingService.FLOOD_EXPIRATION_MINUTES, 180)
        ));
        report.setConfidence(calculateConfidence(report, false));
        FloodReport saved = floodReportRepository.save(report);
        publish(saved);
        return FloodReportMapper.toResponse(saved);
    }

    @Transactional(readOnly = true)
    public PageResponse<FloodReportResponse> search(FloodSeverity severity,
                                                    FloodSource source,
                                                    FloodStatus status,
                                                    Pageable pageable) {
        Specification<FloodReport> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isFalse(root.get("deleted")));
            if (severity != null) {
                predicates.add(cb.equal(root.get("severity"), severity));
            }
            if (source != null) {
                predicates.add(cb.equal(root.get("source"), source));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        return PageResponse.from(floodReportRepository.findAll(spec, pageable).map(FloodReportMapper::toResponse));
    }

    @Transactional(readOnly = true)
    public List<FloodReportResponse> map() {
        return floodReportRepository.findByStatusIn(List.of(FloodStatus.UNVERIFIED, FloodStatus.VERIFIED)).stream()
                .filter(report -> !report.isDeleted())
                .filter(this::notExpired)
                .map(FloodReportMapper::toResponse)
                .toList();
    }

    @Transactional
    public FloodReportResponse verify(Long id, FloodActionRequest request) {
        FloodReport report = findReport(id);
        report.setStatus(FloodStatus.VERIFIED);
        report.setVerifiedBy(currentActor());
        report.setVerifiedAt(LocalDateTime.now());
        report.setConfidence(calculateConfidence(report, true));
        publish(report);
        return FloodReportMapper.toResponse(report);
    }

    @Transactional
    public FloodReportResponse resolve(Long id, FloodActionRequest request) {
        FloodReport report = findReport(id);
        report.setStatus(FloodStatus.RESOLVED);
        report.setConfidence(Math.min(report.getConfidence() == null ? 0.0 : report.getConfidence(), 0.3));
        publish(report);
        return FloodReportMapper.toResponse(report);
    }

    @Transactional
    public FloodWarningResponse warnNearby(Long id) {
        FloodReport report = findReport(id);
        if (report.getStatus() == FloodStatus.RESOLVED || !notExpired(report)) {
            throw new com.safefleet.common.exception.BadRequestException("Không thể gửi cảnh báo cho điểm ngập đã hết hiệu lực");
        }
        Set<Long> notifiedUsers = new HashSet<>();
        driverRepository.findAll().stream()
                .filter(driver -> !driver.isDeleted())
                .filter(driver -> driver.getUser() != null && !driver.getUser().isDeleted())
                .filter(driver -> driver.getUser().getStatus() == com.safefleet.account.enums.AccountStatus.ACTIVE)
                .filter(driver -> driver.getCurrentVehicle() != null)
                .filter(driver -> driver.getCurrentVehicle().getLastLat() != null && driver.getCurrentVehicle().getLastLng() != null)
                .filter(driver -> GeoUtils.distanceKm(
                        driver.getCurrentVehicle().getLastLat(), driver.getCurrentVehicle().getLastLng(),
                        report.getLat(), report.getLng()) <= DRIVER_WARNING_RADIUS_KM)
                .filter(driver -> notifiedUsers.add(driver.getUser().getId()))
                .forEach(driver -> notificationService.createForUser(
                        driver.getUser().getId(), NotificationType.FLOOD,
                        "Cảnh báo điểm ngập gần xe",
                        report.getAddress() == null ? "Phát hiện điểm ngập trong bán kính 10 km" : report.getAddress(),
                        "FLOOD_REPORT", report.getId()));
        return new FloodWarningResponse(report.getId(), notifiedUsers.size(), DRIVER_WARNING_RADIUS_KM);
    }

    @Transactional(readOnly = true)
    public RouteRiskSummaryResponse routeRisk(RouteCheckRequest request) {
        List<FloodReport> activeReports = floodReportRepository.findByStatusIn(List.of(FloodStatus.UNVERIFIED, FloodStatus.VERIFIED));
        List<FloodReportResponse> matched = activeReports.stream()
                .filter(report -> !report.isDeleted())
                .filter(this::notExpired)
                .filter(report -> report.getSeverity().ordinal() >= FloodSeverity.MEDIUM.ordinal())
                .filter(report -> request.points().stream()
                        .anyMatch(point -> GeoUtils.distanceKm(point.lat(), point.lng(), report.getLat(), report.getLng()) <= ROUTE_RISK_RADIUS_KM))
                .map(FloodReportMapper::toResponse)
                .toList();
        FloodSeverity highest = matched.stream()
                .map(FloodReportResponse::severity)
                .max(Comparator.comparingInt(Enum::ordinal))
                .orElse(FloodSeverity.NONE);
        return new RouteRiskSummaryResponse(!matched.isEmpty(), highest, matched.size(), matched);
    }

    private boolean notExpired(FloodReport report) {
        return report.getExpiredAt() != null && report.getExpiredAt().isAfter(LocalDateTime.now());
    }

    private double calculateConfidence(FloodReport report, boolean verified) {
        double score = switch (report.getSource()) {
            case DRIVER_REPORT -> 0.45;
            case IOT_SENSOR -> 0.65;
            case TRAFFIC_CAMERA -> 0.6;
            case WEATHER -> 0.5;
            case MANUAL -> 0.7;
        };
        long nearby = floodReportRepository.findByStatusIn(List.of(FloodStatus.UNVERIFIED, FloodStatus.VERIFIED)).stream()
                .filter(existing -> !existing.isDeleted())
                .filter(existing -> existing.getId() == null || !existing.getId().equals(report.getId()))
                .filter(existing -> GeoUtils.distanceKm(existing.getLat(), existing.getLng(), report.getLat(), report.getLng()) <= NEARBY_CLUSTER_RADIUS_KM)
                .count();
        score += Math.min(0.3, nearby * 0.1);
        if (verified) {
            score += 0.2;
        }
        return Math.min(0.99, score);
    }

    private void publish(FloodReport report) {
        FloodReportResponse response = FloodReportMapper.toResponse(report);
        messagingTemplate.convertAndSend("/topic/flood-reports", response);
    }

    private Driver resolveReporter(Long driverId) {
        if (!SecurityUtils.hasRole("DRIVER")) {
            return driverId == null ? null : findDriver(driverId);
        }
        Driver currentDriver = driverRepository.findByUserId(SecurityUtils.currentUserId())
                .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"));
        if (driverId != null && !currentDriver.getId().equals(driverId)) {
            throw new ForbiddenActionException("Tài xế chỉ được báo cáo điểm ngập của chính mình");
        }
        return currentDriver;
    }

    private String normalizeClientEventId(String clientEventId) {
        if (clientEventId == null || clientEventId.isBlank()) {
            return null;
        }
        return clientEventId.trim();
    }

    private FloodReport findReport(Long id) {
        return floodReportRepository.findById(id)
                .filter(report -> !report.isDeleted())
                .orElseThrow(() -> new NotFoundException("Flood report", id));
    }

    private Driver findDriver(Long id) {
        return driverRepository.findById(id)
                .filter(driver -> !driver.isDeleted())
                .orElseThrow(() -> new NotFoundException("Driver", id));
    }

    private UserAccount currentActor() {
        try {
            return userAccountRepository.findById(SecurityUtils.currentUserId()).orElse(null);
        } catch (RuntimeException ignored) {
            return null;
        }
    }
}
