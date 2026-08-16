package com.safefleet.mobile.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.safefleet.account.entity.UserAccount;
import com.safefleet.account.repository.UserAccountRepository;
import com.safefleet.common.dto.PageResponse;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.common.util.GeoUtils;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.mapper.DriverMapper;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.flood.dto.request.CreateFloodReportRequest;
import com.safefleet.flood.dto.request.RouteCheckRequest;
import com.safefleet.flood.dto.response.FloodReportResponse;
import com.safefleet.flood.dto.response.RouteRiskSummaryResponse;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.service.FloodReportService;
import com.safefleet.incident.dto.request.SosRequest;
import com.safefleet.incident.dto.response.IncidentResponse;
import com.safefleet.incident.dto.response.IncidentTimelineResponse;
import com.safefleet.incident.enums.IncidentStatus;
import com.safefleet.incident.service.IncidentService;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.infrastructure.security.ActionRateLimiter;
import com.safefleet.infrastructure.ai.SafeFleetAiGateway;
import com.safefleet.mobile.dto.request.MobileAgentCommandRequest;
import com.safefleet.mobile.dto.request.MobileAgentConfirmRequest;
import com.safefleet.mobile.dto.request.MobilePreTripChecklistRequest;
import com.safefleet.mobile.dto.request.MobileQuickFloodReportRequest;
import com.safefleet.mobile.dto.request.MobileTelemetryBatchRequest;
import com.safefleet.mobile.dto.response.MobileAgentCommandResponse;
import com.safefleet.mobile.dto.response.MobileBootstrapResponse;
import com.safefleet.mobile.dto.response.MobileConfigResponse;
import com.safefleet.mobile.dto.response.MobileMonthlyActivityResponse;
import com.safefleet.mobile.dto.response.MobileCurrentAssignmentResponse;
import com.safefleet.mobile.dto.response.MobilePreTripChecklistResponse;
import com.safefleet.mobile.dto.response.MobileProfileResponse;
import com.safefleet.mobile.dto.response.MobileSafetySummaryResponse;
import com.safefleet.mobile.dto.response.MobileTripSummaryResponse;
import com.safefleet.mobile.dto.response.MobileTelemetryBatchItemResponse;
import com.safefleet.mobile.dto.response.MobileTelemetryBatchResponse;
import com.safefleet.mobile.dto.response.MobileWorkflowResponse;
import com.safefleet.mobile.entity.AgentCommand;
import com.safefleet.mobile.entity.MobileCommandReceipt;
import com.safefleet.mobile.entity.PreTripChecklist;
import com.safefleet.mobile.enums.AgentCommandStatus;
import com.safefleet.mobile.enums.AgentCommandType;
import com.safefleet.mobile.enums.AgentIntent;
import com.safefleet.mobile.repository.AgentCommandRepository;
import com.safefleet.mobile.repository.MobileCommandReceiptRepository;
import com.safefleet.mobile.repository.PreTripChecklistRepository;
import com.safefleet.notification.dto.response.NotificationResponse;
import com.safefleet.notification.service.NotificationService;
import com.safefleet.safety.dto.request.CreateSafetyEventRequest;
import com.safefleet.safety.dto.request.StartDrivingSessionRequest;
import com.safefleet.safety.dto.response.DrivingSessionResponse;
import com.safefleet.safety.dto.response.SafetyEventResponse;
import com.safefleet.safety.enums.AlertSeverity;
import com.safefleet.safety.enums.DrivingSessionStatus;
import com.safefleet.safety.service.DrivingTimeService;
import com.safefleet.safety.service.SafetyEventService;
import com.safefleet.settings.service.SystemSettingService;
import com.safefleet.telemetry.dto.request.TelemetryRequest;
import com.safefleet.telemetry.dto.response.TelemetryResponse;
import com.safefleet.telemetry.service.TelemetryService;
import com.safefleet.trip.dto.request.TripActionRequest;
import com.safefleet.trip.dto.response.TripResponse;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.enums.TripStatus;
import com.safefleet.trip.mapper.TripMapper;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.trip.service.TripService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.Duration;
import java.time.YearMonth;
import java.util.LinkedHashMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class MobileAppService {

    private static final List<TripStatus> ACTIVE_TRIP_STATUSES = List.of(
            TripStatus.ASSIGNED,
            TripStatus.ACCEPTED,
            TripStatus.IN_PROGRESS,
            TripStatus.RESTING
    );

    private final UserAccountRepository userAccountRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final PreTripChecklistRepository checklistRepository;
    private final AgentCommandRepository agentCommandRepository;
    private final MobileCommandReceiptRepository commandReceiptRepository;
    private final TripService tripService;
    private final TelemetryService telemetryService;
    private final SafetyEventService safetyEventService;
    private final DrivingTimeService drivingTimeService;
    private final IncidentService incidentService;
    private final FloodReportService floodReportService;
    private final NotificationService notificationService;
    private final SystemSettingService settingService;
    private final ObjectMapper objectMapper;
    private final JdbcTemplate jdbcTemplate;
    private final ActionRateLimiter actionRateLimiter;
    private final SafeFleetAiGateway aiGateway;

    @Transactional(readOnly = true)
    public MobileProfileResponse profile() {
        UserAccount user = currentUser();
        Driver driver = currentDriver();
        return new MobileProfileResponse(
                user.getId(),
                user.getUsername(),
                user.getEmail(),
                user.getFullName(),
                user.getPhone(),
                user.getRole().getName().name(),
                DriverMapper.toResponse(driver)
        );
    }

    @Transactional(readOnly = true)
    public MobileBootstrapResponse bootstrap() {
        return new MobileBootstrapResponse(
                profile(),
                safetySummary(),
                config(),
                currentAssignment(),
                todayTrips(),
                floodReportService.map(),
                notificationService.currentUserNotifications(PageRequest.of(0, 20)).items(),
                LocalDateTime.now()
        );
    }

    @Transactional(readOnly = true)
    public MobileSafetySummaryResponse safetySummary() {
        Driver driver = currentDriver();
        int maxContinuousMinutes = settingService.getInt(SystemSettingService.DRIVING_MAX_CONTINUOUS_MINUTES, 240);
        return new MobileSafetySummaryResponse(
                driver.getId(),
                driver.getStatus(),
                driver.getSafetyScore(),
                driver.getDrivingTimeTodayMinutes(),
                driver.getContinuousDrivingMinutes(),
                Math.max(0, maxContinuousMinutes - driver.getContinuousDrivingMinutes()),
                driver.getTotalTrips(),
                driver.getTotalAlerts()
        );
    }

    @Transactional(readOnly = true)
    public MobileMonthlyActivityResponse monthlyActivity(YearMonth requestedMonth) {
        Driver driver = currentDriver();
        YearMonth month = requestedMonth == null ? YearMonth.now() : requestedMonth;
        LocalDate startDate = month.atDay(1);
        LocalDate endDate = month.plusMonths(1).atDay(1);
        LocalDateTime start = startDate.atStartOfDay();
        LocalDateTime end = endDate.atStartOfDay();

        int totalTrips = number("""
                SELECT COUNT(*) FROM trips
                WHERE driver_id = ? AND deleted = FALSE
                  AND COALESCE(actual_start_time, planned_start_time, created_at) >= ?
                  AND COALESCE(actual_start_time, planned_start_time, created_at) < ?
                """, driver.getId(), start, end);
        int completedTrips = number("""
                SELECT COUNT(*) FROM trips
                WHERE driver_id = ? AND deleted = FALSE AND status = 'COMPLETED'
                  AND COALESCE(actual_end_time, actual_start_time, planned_start_time, created_at) >= ?
                  AND COALESCE(actual_end_time, actual_start_time, planned_start_time, created_at) < ?
                """, driver.getId(), start, end);
        int drivingMinutes = number("""
                SELECT COALESCE(SUM(driving_minutes), 0) FROM driver_work_logs
                WHERE driver_id = ? AND deleted = FALSE AND work_date >= ? AND work_date < ?
                """, driver.getId(), startDate, endDate);
        int restMinutes = number("""
                SELECT COALESCE(SUM(rest_minutes), 0) FROM driver_work_logs
                WHERE driver_id = ? AND deleted = FALSE AND work_date >= ? AND work_date < ?
                """, driver.getId(), startDate, endDate);
        int alerts = number("""
                SELECT COUNT(*) FROM safety_events
                WHERE driver_id = ? AND deleted = FALSE AND created_at >= ? AND created_at < ?
                """, driver.getId(), start, end);
        int criticalAlerts = number("""
                SELECT COUNT(*) FROM safety_events
                WHERE driver_id = ? AND deleted = FALSE AND severity = 'CRITICAL'
                  AND created_at >= ? AND created_at < ?
                """, driver.getId(), start, end);
        int onTimeTrips = number("""
                SELECT COUNT(*) FROM trips
                WHERE driver_id = ? AND deleted = FALSE AND status = 'COMPLETED'
                  AND actual_end_time IS NOT NULL AND estimated_end_time IS NOT NULL
                  AND actual_end_time <= estimated_end_time
                  AND actual_end_time >= ? AND actual_end_time < ?
                """, driver.getId(), start, end);
        int activeDays = number("""
                SELECT COUNT(DISTINCT DATE(COALESCE(actual_start_time, planned_start_time, created_at)))
                FROM trips WHERE driver_id = ? AND deleted = FALSE
                  AND COALESCE(actual_start_time, planned_start_time, created_at) >= ?
                  AND COALESCE(actual_start_time, planned_start_time, created_at) < ?
                """, driver.getId(), start, end);
        int alertFreeDays = number("""
                SELECT COUNT(*) FROM (
                    SELECT DISTINCT DATE(COALESCE(t.actual_start_time, t.planned_start_time, t.created_at)) activity_date
                    FROM trips t
                    WHERE t.driver_id = ? AND t.deleted = FALSE
                      AND COALESCE(t.actual_start_time, t.planned_start_time, t.created_at) >= ?
                      AND COALESCE(t.actual_start_time, t.planned_start_time, t.created_at) < ?
                      AND NOT EXISTS (
                          SELECT 1 FROM safety_events se
                          WHERE se.driver_id = t.driver_id AND se.deleted = FALSE
                            AND DATE(se.created_at) = DATE(COALESCE(t.actual_start_time, t.planned_start_time, t.created_at))
                      )
                ) safe_days
                """, driver.getId(), start, end);
        double distanceKm = decimal("""
                SELECT COALESCE(SUM(
                    CAST(planned_route_json::jsonb #>> '{route,distanceKm}' AS DECIMAL(12,2))
                ), 0)
                FROM trips WHERE driver_id = ? AND deleted = FALSE
                  AND COALESCE(actual_start_time, planned_start_time, created_at) >= ?
                  AND COALESCE(actual_start_time, planned_start_time, created_at) < ?
                """, driver.getId(), start, end);
        int completionRate = totalTrips == 0 ? 0 : (int) Math.round(completedTrips * 100.0 / totalTrips);
        int onTimeRate = completedTrips == 0 ? 0 : (int) Math.round(onTimeTrips * 100.0 / completedTrips);
        String achievementLevel;
        String achievementTitle;
        if (driver.getSafetyScore() >= 95 && criticalAlerts == 0 && completionRate >= 90) {
            achievementLevel = "GOLD";
            achievementTitle = "Tay lái vàng";
        } else if (driver.getSafetyScore() >= 85 && criticalAlerts == 0) {
            achievementLevel = "SILVER";
            achievementTitle = "Tài xế an toàn";
        } else {
            achievementLevel = "BRONZE";
            achievementTitle = "Đang xây dựng thành tích";
        }
        List<MobileMonthlyActivityResponse.Achievement> achievements = List.of(
                new MobileMonthlyActivityResponse.Achievement(
                        "SAFE_DRIVER", "Tài xế an toàn", "Điểm an toàn từ 90", driver.getSafetyScore() >= 90,
                        Math.min(100, driver.getSafetyScore() * 100 / 90)),
                new MobileMonthlyActivityResponse.Achievement(
                        "ON_TIME", "Giao hàng đúng hẹn", "Ít nhất 90% chuyến hoàn thành đúng giờ",
                        completedTrips > 0 && onTimeRate >= 90, Math.min(100, onTimeRate * 100 / 90)),
                new MobileMonthlyActivityResponse.Achievement(
                        "ZERO_CRITICAL", "Tháng lái xe bình an", "Không có cảnh báo nghiêm trọng",
                        criticalAlerts == 0, criticalAlerts == 0 ? 100 : 0),
                new MobileMonthlyActivityResponse.Achievement(
                        "ROAD_WARRIOR", "Bền bỉ cung đường", "Hoàn thành 500 km trong tháng",
                        distanceKm >= 500, Math.min(100, (int) Math.round(distanceKm * 100 / 500)))
        );

        Map<LocalDate, int[]> daily = new LinkedHashMap<>();
        for (int day = 1; day <= month.lengthOfMonth(); day++) {
            daily.put(month.atDay(day), new int[4]);
        }
        jdbcTemplate.query("""
                        SELECT DATE(COALESCE(actual_start_time, planned_start_time, created_at)) activity_date,
                               COUNT(*) total
                        FROM trips
                        WHERE driver_id = ? AND deleted = FALSE
                          AND COALESCE(actual_start_time, planned_start_time, created_at) >= ?
                          AND COALESCE(actual_start_time, planned_start_time, created_at) < ?
                        GROUP BY activity_date
                        """,
                rs -> {
                    daily.get(rs.getDate("activity_date").toLocalDate())[0] = rs.getInt("total");
                },
                driver.getId(), start, end);
        jdbcTemplate.query("""
                        SELECT work_date, SUM(driving_minutes) driving, SUM(rest_minutes) resting
                        FROM driver_work_logs
                        WHERE driver_id = ? AND deleted = FALSE AND work_date >= ? AND work_date < ?
                        GROUP BY work_date
                        """,
                rs -> {
                    int[] values = daily.get(rs.getDate("work_date").toLocalDate());
                    values[1] = rs.getInt("driving");
                    values[2] = rs.getInt("resting");
                }, driver.getId(), startDate, endDate);
        jdbcTemplate.query("""
                        SELECT DATE(created_at) activity_date, COUNT(*) total
                        FROM safety_events
                        WHERE driver_id = ? AND deleted = FALSE AND created_at >= ? AND created_at < ?
                        GROUP BY activity_date
                        """,
                rs -> {
                    daily.get(rs.getDate("activity_date").toLocalDate())[3] = rs.getInt("total");
                },
                driver.getId(), start, end);

        List<MobileMonthlyActivityResponse.DailyActivity> days = daily.entrySet().stream()
                .map(entry -> new MobileMonthlyActivityResponse.DailyActivity(
                        entry.getKey(), entry.getValue()[0], entry.getValue()[1],
                        entry.getValue()[2], entry.getValue()[3]))
                .toList();
        return new MobileMonthlyActivityResponse(
                month, driver.getSafetyScore(), totalTrips, completedTrips,
                drivingMinutes, restMinutes, alerts, criticalAlerts,
                completionRate, onTimeTrips, onTimeRate, distanceKm, activeDays,
                alertFreeDays, achievementLevel, achievementTitle, achievements, days);
    }

    private int number(String sql, Object... arguments) {
        Number value = jdbcTemplate.queryForObject(sql, Number.class, arguments);
        return value == null ? 0 : value.intValue();
    }

    private double decimal(String sql, Object... arguments) {
        Number value = jdbcTemplate.queryForObject(sql, Number.class, arguments);
        return value == null ? 0 : Math.round(value.doubleValue() * 10.0) / 10.0;
    }

    @Transactional(readOnly = true)
    public MobileConfigResponse config() {
        return new MobileConfigResponse(
                settingService.getInt(SystemSettingService.DRIVING_MAX_CONTINUOUS_MINUTES, 240),
                settingService.getInt(SystemSettingService.DRIVING_WARN_1_MINUTES, 180),
                settingService.getInt(SystemSettingService.DRIVING_WARN_2_MINUTES, 210),
                settingService.getInt(SystemSettingService.DRIVING_CRITICAL_MINUTES, 230),
                10,
                3,
                settingService.getInt(SystemSettingService.FLOOD_EXPIRATION_MINUTES, 180)
        );
    }

    @Transactional(readOnly = true)
    public MobileCurrentAssignmentResponse currentAssignment() {
        Driver driver = currentDriver();
        return tripRepository.findByDeletedFalseAndDriverIdAndStatusInOrderByPlannedStartTimeAsc(
                        driver.getId(),
                        ACTIVE_TRIP_STATUSES
                )
                .stream()
                .findFirst()
                .map(trip -> new MobileCurrentAssignmentResponse(
                        TripMapper.toResponse(trip),
                        checklistSubmitted(trip.getId(), driver.getId())
                ))
                .orElseGet(() -> new MobileCurrentAssignmentResponse(null, false));
    }

    @Transactional(readOnly = true)
    public List<TripResponse> todayTrips() {
        Driver driver = currentDriver();
        LocalDate today = LocalDate.now();
        return tripRepository.findMobileDaySchedule(
                        driver.getId(),
                        today.atStartOfDay(),
                        today.plusDays(1).atStartOfDay(),
                        ACTIVE_TRIP_STATUSES
                )
                .stream()
                .map(TripMapper::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<TripResponse> trips(
            List<TripStatus> statuses,
            LocalDate startDate,
            LocalDate endDate,
            int requestedLimit
    ) {
        if (statuses == null || statuses.isEmpty()) {
            throw new BadRequestException("Cần chọn ít nhất một trạng thái chuyến");
        }
        if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
            throw new BadRequestException("Ngày kết thúc phải từ ngày bắt đầu trở đi");
        }
        Driver driver = currentDriver();
        int limit = Math.max(1, Math.min(50, requestedLimit));
        LocalDateTime from = startDate == null ? null : startDate.atStartOfDay();
        LocalDateTime to = endDate == null ? null : endDate.plusDays(1).atStartOfDay();
        List<TripStatus> requestedStatuses = statuses.stream().distinct().toList();
        PageRequest page = PageRequest.of(0, limit);
        List<Trip> trips;
        if (from == null && to == null) {
            trips = tripRepository.findDriverTripsWithoutDate(driver.getId(), requestedStatuses, page);
        } else if (to == null) {
            trips = tripRepository.findDriverTripsFrom(driver.getId(), requestedStatuses, from, page);
        } else if (from == null) {
            trips = tripRepository.findDriverTripsTo(driver.getId(), requestedStatuses, to, page);
        } else {
            trips = tripRepository.findDriverTripsBetween(driver.getId(), requestedStatuses, from, to, page);
        }
        return trips
                .stream()
                .map(TripMapper::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public TripResponse trip(Long id) {
        Driver driver = currentDriver();
        Trip trip = tripService.findTrip(id);
        assertDriverOwnsTrip(driver, trip);
        return TripMapper.toResponse(trip);
    }

    @Transactional(readOnly = true)
    public MobileTripSummaryResponse tripSummary(Long id) {
        Driver driver = currentDriver();
        Trip trip = tripService.findTrip(id);
        assertDriverOwnsTrip(driver, trip);
        return new MobileTripSummaryResponse(
                TripMapper.toResponse(trip),
                checklistSubmitted(trip.getId(), driver.getId()),
                nextAction(trip)
        );
    }

    @Transactional
    public TripResponse acceptTrip(Long id, TripActionRequest request) {
        return tripService.accept(id, defaultAction(request));
    }

    @Transactional
    public TripResponse startTrip(Long id, TripActionRequest request) {
        return tripService.start(id, defaultAction(request));
    }

    @Transactional
    public TripResponse pauseTrip(Long id, TripActionRequest request) {
        return tripService.pause(id, defaultAction(request));
    }

    @Transactional
    public TripResponse resumeTrip(Long id, TripActionRequest request) {
        return tripService.resume(id, defaultAction(request));
    }

    @Transactional
    public TripResponse completeTrip(Long id, TripActionRequest request) {
        return tripService.complete(id, defaultAction(request));
    }

    @Transactional
    public MobileWorkflowResponse startWorkflow(Long tripId, TripActionRequest request) {
        Driver driver = currentDriver();
        Trip trip = tripService.findTrip(tripId);
        assertDriverOwnsTrip(driver, trip);
        MobileWorkflowResponse replay = replayWorkflow("START", tripId, request);
        if (replay != null) {
            return replay;
        }
        if (trip.getVehicle() == null) {
            throw new BadRequestException("Chuyến chưa được gán xe");
        }
        PreTripChecklist checklist = checklistRepository
                .findTopByTripIdAndDriverIdAndDeletedFalseOrderByCreatedAtDesc(tripId, driver.getId())
                .orElseThrow(() -> new BadRequestException("Phải hoàn thành checklist trước khi bắt đầu"));
        if (!checklistPassed(checklist)) {
            throw new BadRequestException("Checklist chưa đạt, không thể bắt đầu chuyến");
        }

        TripResponse tripResponse = tripService.start(tripId, defaultAction(request));
        DrivingSessionResponse drivingSession = drivingTimeService.start(new StartDrivingSessionRequest(
                driver.getId(),
                trip.getVehicle().getId(),
                tripId
        ));
        String navigationSessionId = ensureNavigationSession(trip, driver);
        return rememberWorkflow(
                "START",
                tripId,
                request,
                new MobileWorkflowResponse("STARTED", tripResponse, drivingSession, navigationSessionId)
        );
    }

    @Transactional
    public MobileWorkflowResponse pauseWorkflow(Long tripId, TripActionRequest request) {
        Driver driver = currentDriver();
        Trip trip = tripService.findTrip(tripId);
        assertDriverOwnsTrip(driver, trip);
        MobileWorkflowResponse replay = replayWorkflow("PAUSE", tripId, request);
        if (replay != null) {
            return replay;
        }
        assertCurrentDrivingSession(driver, tripId, List.of(DrivingSessionStatus.ACTIVE));
        TripResponse tripResponse = tripService.pause(tripId, defaultAction(request));
        DrivingSessionResponse drivingSession = drivingTimeService.pauseCurrent(driver.getId());
        updateNavigationStatus(tripId, driver.getId(), "PAUSED", false);
        return rememberWorkflow(
                "PAUSE",
                tripId,
                request,
                new MobileWorkflowResponse(
                        "PAUSED",
                        tripResponse,
                        drivingSession,
                        currentNavigationSessionId(tripId, driver.getId())
                )
        );
    }

    @Transactional
    public MobileWorkflowResponse resumeWorkflow(Long tripId, TripActionRequest request) {
        Driver driver = currentDriver();
        Trip trip = tripService.findTrip(tripId);
        assertDriverOwnsTrip(driver, trip);
        MobileWorkflowResponse replay = replayWorkflow("RESUME", tripId, request);
        if (replay != null) {
            return replay;
        }
        assertCurrentDrivingSession(driver, tripId, List.of(DrivingSessionStatus.PAUSED));
        TripResponse tripResponse = tripService.resume(tripId, defaultAction(request));
        DrivingSessionResponse drivingSession = drivingTimeService.resumeCurrent(driver.getId());
        updateNavigationStatus(tripId, driver.getId(), "ACTIVE", false);
        return rememberWorkflow(
                "RESUME",
                tripId,
                request,
                new MobileWorkflowResponse(
                        "RESUMED",
                        tripResponse,
                        drivingSession,
                        currentNavigationSessionId(tripId, driver.getId())
                )
        );
    }

    @Transactional
    public MobileWorkflowResponse completeWorkflow(Long tripId, TripActionRequest request) {
        Driver driver = currentDriver();
        Trip trip = tripService.findTrip(tripId);
        assertDriverOwnsTrip(driver, trip);
        MobileWorkflowResponse replay = replayWorkflow("COMPLETE", tripId, request);
        if (replay != null) {
            return replay;
        }
        assertCurrentDrivingSession(
                driver,
                tripId,
                List.of(DrivingSessionStatus.ACTIVE, DrivingSessionStatus.PAUSED)
        );
        TripResponse tripResponse = tripService.complete(tripId, defaultAction(request));
        DrivingSessionResponse drivingSession = drivingTimeService.finishCurrent(driver.getId());
        String navigationSessionId = currentNavigationSessionId(tripId, driver.getId());
        updateNavigationStatus(tripId, driver.getId(), "COMPLETED", true);
        return rememberWorkflow(
                "COMPLETE",
                tripId,
                request,
                new MobileWorkflowResponse("COMPLETED", tripResponse, drivingSession, navigationSessionId)
        );
    }

    @Transactional(readOnly = true)
    public DrivingSessionResponse currentDrivingSession() {
        return drivingTimeService.currentForDriver(currentDriver().getId());
    }

    @Transactional
    public MobilePreTripChecklistResponse submitChecklist(Long tripId, MobilePreTripChecklistRequest request) {
        Driver driver = currentDriver();
        Trip trip = tripService.findTrip(tripId);
        assertDriverOwnsTrip(driver, trip);

        PreTripChecklist checklist = new PreTripChecklist();
        checklist.setTrip(trip);
        checklist.setDriver(driver);
        checklist.setVehicle(trip.getVehicle());
        checklist.setExteriorChecked(request.exteriorChecked());
        checklist.setTiresChecked(request.tiresChecked());
        checklist.setBrakeChecked(request.brakeChecked());
        checklist.setLightsChecked(request.lightsChecked());
        checklist.setCameraChecked(request.cameraChecked());
        checklist.setGpsChecked(request.gpsChecked());
        checklist.setDocumentsChecked(request.documentsChecked());
        checklist.setChecklistJson(toChecklistJson(request));
        checklist.setNote(request.note());
        return toChecklistResponse(checklistRepository.save(checklist));
    }

    @Transactional
    public TelemetryResponse ingestTelemetry(TelemetryRequest request) {
        return telemetryService.ingest(request);
    }

    @Transactional
    public MobileTelemetryBatchResponse ingestTelemetryBatch(MobileTelemetryBatchRequest request) {
        Driver driver = currentDriver();
        String batchId = request.batchId().trim();
        int inserted = jdbcTemplate.update("""
                INSERT INTO sync_batches
                    (batch_uuid, user_id, item_count, status, received_at)
                VALUES (?, ?, ?, 'RECEIVING', CURRENT_TIMESTAMP(6))
                ON CONFLICT (batch_uuid) DO NOTHING
                """, batchId, SecurityUtils.currentUserId(), request.items().size());
        Map<String, Object> batch = jdbcTemplate.queryForMap("""
                SELECT id, user_id, item_count, status
                FROM sync_batches
                WHERE batch_uuid = ?
                """, batchId);
        Long ownerId = ((Number) batch.get("user_id")).longValue();
        if (!SecurityUtils.currentUserId().equals(ownerId)) {
            throw new ForbiddenActionException("Batch đồng bộ thuộc về người dùng khác");
        }
        Long syncBatchId = ((Number) batch.get("id")).longValue();
        if (inserted == 0 && "COMPLETED".equals(batch.get("status"))) {
            if (((Number) batch.get("item_count")).intValue() != request.items().size()) {
                throw new BadRequestException("batchId đã được dùng với số lượng phần tử khác");
            }
            return completedTelemetryBatch(batchId, syncBatchId);
        }

        int accepted = 0;
        int duplicates = 0;
        int rejected = 0;
        List<MobileTelemetryBatchItemResponse> acknowledgements = new ArrayList<>();
        for (int itemIndex = 0; itemIndex < request.items().size(); itemIndex++) {
            TelemetryRequest item = request.items().get(itemIndex);
            String clientEventId = item.clientEventId() == null ? null : item.clientEventId().trim();
            MobileTelemetryBatchItemResponse acknowledgement;
            if (clientEventId == null || clientEventId.isBlank()) {
                rejected++;
                acknowledgement = new MobileTelemetryBatchItemResponse(
                        null,
                        "REJECTED",
                        null,
                        "clientEventId là bắt buộc trong batch"
                );
            } else if (item.driverId() == null || !driver.getId().equals(item.driverId())) {
                rejected++;
                acknowledgement = new MobileTelemetryBatchItemResponse(
                        clientEventId,
                        "REJECTED",
                        null,
                        "driverId không thuộc tài khoản hiện tại"
                );
            } else {
                var existing = telemetryService.findByClientEvent(driver.getId(), clientEventId);
                if (existing.isPresent()) {
                    duplicates++;
                    acknowledgement = new MobileTelemetryBatchItemResponse(
                            clientEventId,
                            "DUPLICATE",
                            existing.get().id(),
                            "Telemetry đã được đồng bộ trước đó"
                    );
                } else {
                    try {
                        TelemetryResponse response = telemetryService.ingest(item);
                        jdbcTemplate.update(
                                "UPDATE telemetry_logs SET sync_batch_id = ? WHERE id = ?",
                                syncBatchId,
                                response.id()
                        );
                        accepted++;
                        acknowledgement = new MobileTelemetryBatchItemResponse(
                                clientEventId,
                                "ACCEPTED",
                                response.id(),
                                null
                        );
                    } catch (BadRequestException | ForbiddenActionException | NotFoundException exception) {
                        rejected++;
                        acknowledgement = new MobileTelemetryBatchItemResponse(
                                clientEventId,
                                "REJECTED",
                                null,
                                exception.getMessage()
                        );
                    }
                }
            }
            acknowledgements.add(acknowledgement);
            jdbcTemplate.update("""
                    INSERT INTO sync_batch_items (
                        sync_batch_id, item_index, client_event_id, item_type,
                        item_status, entity_id, error_message, created_at
                    ) VALUES (?, ?, ?, 'TELEMETRY', ?, ?, ?, CURRENT_TIMESTAMP(6))
                    """,
                    syncBatchId,
                    itemIndex,
                    acknowledgement.clientEventId(),
                    acknowledgement.status(),
                    acknowledgement.telemetryId(),
                    acknowledgement.message()
            );
        }

        jdbcTemplate.update("""
                UPDATE sync_batches
                SET accepted_count = ?,
                    duplicate_count = ?,
                    rejected_count = ?,
                    status = 'COMPLETED',
                    completed_at = CURRENT_TIMESTAMP(6)
                WHERE id = ?
                """, accepted, duplicates, rejected, syncBatchId);
        return new MobileTelemetryBatchResponse(batchId, accepted, duplicates, rejected, acknowledgements);
    }

    private MobileTelemetryBatchResponse completedTelemetryBatch(String batchId, Long syncBatchId) {
        Map<String, Object> counts = jdbcTemplate.queryForMap("""
                SELECT accepted_count, duplicate_count, rejected_count
                FROM sync_batches
                WHERE id = ?
                """, syncBatchId);
        List<MobileTelemetryBatchItemResponse> items = jdbcTemplate.query("""
                SELECT client_event_id, item_status, entity_id, error_message
                FROM sync_batch_items
                WHERE sync_batch_id = ?
                ORDER BY item_index
                """, (resultSet, rowNumber) -> new MobileTelemetryBatchItemResponse(
                resultSet.getString("client_event_id"),
                resultSet.getString("item_status"),
                resultSet.getObject("entity_id") == null ? null : resultSet.getLong("entity_id"),
                resultSet.getString("error_message")
        ), syncBatchId);
        return new MobileTelemetryBatchResponse(
                batchId,
                ((Number) counts.get("accepted_count")).intValue(),
                ((Number) counts.get("duplicate_count")).intValue(),
                ((Number) counts.get("rejected_count")).intValue(),
                items
        );
    }

    @Transactional(readOnly = true)
    public PageResponse<SafetyEventResponse> todaySafetyEvents(Pageable pageable) {
        Driver driver = currentDriver();
        LocalDate today = LocalDate.now();
        return safetyEventService.search(
                null,
                null,
                null,
                null,
                driver.getId(),
                today.atStartOfDay(),
                today.plusDays(1).atStartOfDay(),
                pageable
        );
    }

    @Transactional
    public SafetyEventResponse createSafetyEvent(CreateSafetyEventRequest request) {
        Driver driver = currentDriver();
        Trip trip = activeTripFor(driver);
        Long vehicleId = trip != null && trip.getVehicle() != null
                ? trip.getVehicle().getId()
                : driver.getCurrentVehicle() == null ? null : driver.getCurrentVehicle().getId();
        return safetyEventService.create(new CreateSafetyEventRequest(
                request.eventType(),
                request.severity(),
                vehicleId,
                driver.getId(),
                trip == null ? null : trip.getId(),
                request.lat(),
                request.lng(),
                request.speed(),
                request.confidence(),
                null,
                request.createdAt(),
                request.note(),
                request.clientEventId()
        ));
    }

    @Transactional
    public IncidentResponse sendSos(SosRequest request) {
        Driver driver = currentDriver();
        Trip trip = activeTripFor(driver);
        Long vehicleId = trip != null && trip.getVehicle() != null
                ? trip.getVehicle().getId()
                : driver.getCurrentVehicle() == null ? null : driver.getCurrentVehicle().getId();
        return incidentService.sos(new SosRequest(
                vehicleId,
                driver.getId(),
                trip == null ? null : trip.getId(),
                request.lat(),
                request.lng(),
                request.severity(),
                request.description(),
                request.clientEventId()
        ));
    }

    @Transactional(readOnly = true)
    public PageResponse<IncidentResponse> incidents(IncidentStatus status, Pageable pageable) {
        Driver driver = currentDriver();
        return incidentService.search(null, null, status, null, driver.getId(), pageable);
    }

    @Transactional(readOnly = true)
    public IncidentResponse incident(Long id) {
        Driver driver = currentDriver();
        IncidentResponse response = incidentService.get(id);
        if (response.driverId() == null || !response.driverId().equals(driver.getId())) {
            throw new ForbiddenActionException("Tài xế chỉ được xem sự cố của chính mình");
        }
        return response;
    }

    @Transactional(readOnly = true)
    public List<IncidentTimelineResponse> incidentTimeline(Long id) {
        incident(id);
        return incidentService.timeline(id);
    }

    @Transactional
    public FloodReportResponse createFloodReport(CreateFloodReportRequest request) {
        return floodReportService.create(request);
    }

    @Transactional
    public FloodReportResponse quickFloodReport(MobileQuickFloodReportRequest request) {
        Driver driver = currentDriver();
        return floodReportService.create(new CreateFloodReportRequest(
                request.lat(),
                request.lng(),
                request.address(),
                request.severity(),
                FloodSource.DRIVER_REPORT,
                driver.getId(),
                request.imageUrl(),
                request.clientEventId()
        ));
    }

    @Transactional(readOnly = true)
    public List<FloodReportResponse> nearbyFloodPoints(Double lat, Double lng, Double radiusKm) {
        double effectiveRadius = radiusKm == null ? 3.0 : Math.max(0.1, Math.min(radiusKm, 20.0));
        return floodReportService.map().stream()
                .filter(report -> GeoUtils.distanceKm(lat, lng, report.lat(), report.lng()) <= effectiveRadius)
                .toList();
    }

    @Transactional(readOnly = true)
    public RouteRiskSummaryResponse routeCheck(RouteCheckRequest request) {
        return floodReportService.routeRisk(request);
    }

    @Transactional
    public MobileAgentCommandResponse submitAgentCommand(MobileAgentCommandRequest request) {
        actionRateLimiter.check(SecurityUtils.currentUserId(), "AGENT", 10, Duration.ofMinutes(1));
        UserAccount user = currentUser();
        Driver driver = currentDriver();
        Trip trip = request.tripId() == null
                ? activeTripFor(driver)
                : tripService.findTrip(request.tripId());
        if (trip != null) {
            assertDriverOwnsTrip(driver, trip);
        }

        SafeFleetAiGateway.Classification classification =
                aiGateway.classify(request.transcript().trim());
        AgentCommand command = new AgentCommand();
        command.setUser(user);
        command.setDriver(driver);
        command.setTrip(trip);
        command.setCommandType(request.commandType() == null ? AgentCommandType.TEXT : request.commandType());
        command.setTranscript(request.transcript().trim());
        command.setNormalizedCommand(classification.intent().name());
        command.setInterpretedIntent(classification.intent());
        command.setConfidence(classification.confidence());
        command.setRequiresConfirmation(classification.requiresConfirmation());
        command.setClassificationSource(classification.source());
        applyAgentClassification(command, driver);
        return toAgentCommandResponse(agentCommandRepository.save(command));
    }

    @Transactional
    public MobileAgentCommandResponse confirmAgentCommand(Long commandId,
                                                          MobileAgentConfirmRequest request) {
        AgentCommand command = ownedAgentCommand(commandId);
        if (command.getStatus() == AgentCommandStatus.EXECUTED) {
            return toAgentCommandResponse(command);
        }
        if (command.getStatus() == AgentCommandStatus.CANCELLED) {
            throw new BadRequestException("Lệnh đã bị hủy");
        }
        if (!command.isRequiresConfirmation() || command.getInterpretedIntent() == null) {
            throw new BadRequestException("Lệnh này không cần hoặc không thể xác nhận");
        }

        String clientEventId = "agent-" + command.getId() + "-"
                + command.getInterpretedIntent().name().toLowerCase();
        switch (command.getInterpretedIntent()) {
            case START_TRIP -> {
                MobileWorkflowResponse result = startWorkflow(
                        requireAgentTrip(command).getId(),
                        new TripActionRequest("Xác nhận qua trợ lý SafeFleet", clientEventId)
                );
                rememberAgentExecution(command, "TRIP", result.trip().id(), "Đã bắt đầu chuyến.");
            }
            case PAUSE_TRIP -> {
                MobileWorkflowResponse result = pauseWorkflow(
                        requireAgentTrip(command).getId(),
                        new TripActionRequest("Xác nhận qua trợ lý SafeFleet", clientEventId)
                );
                rememberAgentExecution(command, "TRIP", result.trip().id(), "Đã tạm nghỉ chuyến.");
            }
            case RESUME_TRIP -> {
                MobileWorkflowResponse result = resumeWorkflow(
                        requireAgentTrip(command).getId(),
                        new TripActionRequest("Xác nhận qua trợ lý SafeFleet", clientEventId)
                );
                rememberAgentExecution(command, "TRIP", result.trip().id(), "Đã tiếp tục chuyến.");
            }
            case COMPLETE_TRIP -> {
                MobileWorkflowResponse result = completeWorkflow(
                        requireAgentTrip(command).getId(),
                        new TripActionRequest("Xác nhận qua trợ lý SafeFleet", clientEventId)
                );
                rememberAgentExecution(command, "TRIP", result.trip().id(), "Đã hoàn thành chuyến.");
            }
            case SEND_SOS -> {
                requireAgentCoordinates(request);
                IncidentResponse result = sendSos(new SosRequest(
                        null,
                        null,
                        command.getTrip() == null ? null : command.getTrip().getId(),
                        request.lat(),
                        request.lng(),
                        AlertSeverity.CRITICAL,
                        request.description() == null
                                ? "SOS được tài xế xác nhận qua trợ lý SafeFleet"
                                : request.description(),
                        clientEventId
                ));
                rememberAgentExecution(command, "INCIDENT", result.id(), "SOS đã được gửi.");
            }
            case REPORT_FLOOD -> {
                requireAgentCoordinates(request);
                FloodReportResponse result = quickFloodReport(new MobileQuickFloodReportRequest(
                        request.lat(),
                        request.lng(),
                        request.address(),
                        request.floodSeverity() == null
                                ? FloodSeverity.MEDIUM
                                : request.floodSeverity(),
                        null,
                        clientEventId
                ));
                rememberAgentExecution(command, "FLOOD_REPORT", result.id(), "Điểm ngập đã được báo.");
            }
            default -> throw new BadRequestException("Intent không hỗ trợ thực thi xác nhận");
        }
        return toAgentCommandResponse(command);
    }

    @Transactional
    public MobileAgentCommandResponse cancelAgentCommand(Long commandId) {
        AgentCommand command = ownedAgentCommand(commandId);
        if (command.getStatus() == AgentCommandStatus.EXECUTED) {
            throw new BadRequestException("Lệnh đã được thực thi");
        }
        command.setStatus(AgentCommandStatus.CANCELLED);
        command.setResponseText("Đã hủy lệnh, không có hành động nào được thực thi.");
        return toAgentCommandResponse(command);
    }

    private Trip activeTripFor(Driver driver) {
        return tripRepository.findByDeletedFalseAndDriverIdAndStatusInOrderByPlannedStartTimeAsc(
                        driver.getId(),
                        ACTIVE_TRIP_STATUSES
                )
                .stream()
                .findFirst()
                .orElse(null);
    }

    @Transactional(readOnly = true)
    public PageResponse<MobileAgentCommandResponse> agentHistory(Pageable pageable) {
        return PageResponse.from(agentCommandRepository.findByUserIdAndDeletedFalseOrderByCreatedAtDesc(
                SecurityUtils.currentUserId(),
                pageable
        ).map(this::toAgentCommandResponse));
    }

    @Transactional(readOnly = true)
    public PageResponse<NotificationResponse> notifications(Pageable pageable) {
        return notificationService.currentUserNotifications(pageable);
    }

    @Transactional
    public NotificationResponse markNotificationRead(Long id) {
        return notificationService.markRead(id);
    }

    @Transactional
    public void markAllNotificationsRead() {
        notificationService.markAllRead();
    }

    private UserAccount currentUser() {
        Long userId = SecurityUtils.currentUserId();
        return userAccountRepository.findById(userId)
                .filter(user -> !user.isDeleted())
                .orElseThrow(() -> new NotFoundException("User", userId));
    }

    private Driver currentDriver() {
        return driverRepository.findByUserId(SecurityUtils.currentUserId())
                .filter(driver -> !driver.isDeleted())
                .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"));
    }

    private void assertDriverOwnsTrip(Driver driver, Trip trip) {
        if (trip.getDriver() == null || !driver.getId().equals(trip.getDriver().getId())) {
            throw new ForbiddenActionException("Tài xế chỉ được thao tác chuyến của chính mình");
        }
    }

    private boolean checklistSubmitted(Long tripId, Long driverId) {
        return checklistRepository.findTopByTripIdAndDriverIdAndDeletedFalseOrderByCreatedAtDesc(tripId, driverId)
                .isPresent();
    }

    private boolean checklistPassed(PreTripChecklist checklist) {
        return checklist.isExteriorChecked()
                && checklist.isTiresChecked()
                && checklist.isBrakeChecked()
                && checklist.isLightsChecked()
                && checklist.isCameraChecked()
                && checklist.isGpsChecked()
                && checklist.isDocumentsChecked();
    }

    private void assertCurrentDrivingSession(Driver driver,
                                             Long tripId,
                                             List<DrivingSessionStatus> allowedStatuses) {
        DrivingSessionResponse current = drivingTimeService.currentForDriver(driver.getId());
        if (current == null || current.tripId() == null) {
            throw new BadRequestException("Không có phiên lái hiện tại cho chuyến này");
        }
        if (!tripId.equals(current.tripId())) {
            throw new BadRequestException(
                    "Phiên lái hiện tại thuộc chuyến " + current.tripId()
                            + ", không phải chuyến " + tripId
            );
        }
        if (!allowedStatuses.contains(current.status())) {
            throw new BadRequestException(
                    "Trạng thái phiên lái " + current.status() + " không phù hợp với thao tác"
            );
        }
    }

    private String ensureNavigationSession(Trip trip, Driver driver) {
        String existing = currentNavigationSessionId(trip.getId(), driver.getId());
        if (existing != null) {
            updateNavigationStatus(trip.getId(), driver.getId(), "ACTIVE", false);
            return existing;
        }
        String sessionId = UUID.randomUUID().toString();
        jdbcTemplate.update("""
                INSERT INTO navigation_sessions (
                    session_uuid, driver_id, vehicle_id, trip_id,
                    origin_lat, origin_lng, destination_lat, destination_lng,
                    destination_name, status, started_at, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE', CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6))
                """,
                sessionId,
                driver.getId(),
                trip.getVehicle().getId(),
                trip.getId(),
                coordinateOrZero(trip.getStartLat()),
                coordinateOrZero(trip.getStartLng()),
                coordinateOrZero(trip.getEndLat()),
                coordinateOrZero(trip.getEndLng()),
                trip.getEndLocation()
        );
        return sessionId;
    }

    private String currentNavigationSessionId(Long tripId, Long driverId) {
        List<String> ids = jdbcTemplate.queryForList("""
                SELECT session_uuid
                FROM navigation_sessions
                WHERE trip_id = ? AND driver_id = ? AND deleted = FALSE
                ORDER BY created_at DESC
                LIMIT 1
                """, String.class, tripId, driverId);
        return ids.isEmpty() ? null : ids.get(0);
    }

    private void updateNavigationStatus(Long tripId, Long driverId, String status, boolean ended) {
        jdbcTemplate.update("""
                UPDATE navigation_sessions
                SET status = ?,
                    updated_at = CURRENT_TIMESTAMP(6),
                    ended_at = CASE WHEN ? THEN CURRENT_TIMESTAMP(6) ELSE ended_at END
                WHERE trip_id = ? AND driver_id = ? AND deleted = FALSE
                """, status, ended, tripId, driverId);
    }

    private double coordinateOrZero(Double value) {
        return value == null ? 0.0 : value;
    }

    private TripActionRequest defaultAction(TripActionRequest request) {
        return request == null ? new TripActionRequest(null, null) : request;
    }

    private MobileWorkflowResponse replayWorkflow(String operation,
                                                  Long tripId,
                                                  TripActionRequest request) {
        String clientEventId = workflowClientEventId(request);
        if (clientEventId == null) {
            return null;
        }
        return commandReceiptRepository
                .findByUserIdAndClientEventIdAndDeletedFalse(
                        SecurityUtils.currentUserId(),
                        clientEventId
                )
                .map(receipt -> {
                    if (!operation.equals(receipt.getOperation())
                            || !tripId.equals(receipt.getTripId())) {
                        throw new BadRequestException(
                                "clientEventId đã được dùng cho thao tác khác"
                        );
                    }
                    try {
                        return objectMapper.readValue(
                                receipt.getResponseJson(),
                                MobileWorkflowResponse.class
                        );
                    } catch (JsonProcessingException exception) {
                        throw new BadRequestException(
                                "Không thể đọc workflow receipt đã lưu"
                        );
                    }
                })
                .orElse(null);
    }

    private MobileWorkflowResponse rememberWorkflow(String operation,
                                                    Long tripId,
                                                    TripActionRequest request,
                                                    MobileWorkflowResponse response) {
        String clientEventId = workflowClientEventId(request);
        if (clientEventId == null) {
            return response;
        }
        try {
            MobileCommandReceipt receipt = new MobileCommandReceipt();
            receipt.setUser(currentUser());
            receipt.setClientEventId(clientEventId);
            receipt.setOperation(operation);
            receipt.setTripId(tripId);
            receipt.setResponseJson(objectMapper.writeValueAsString(response));
            commandReceiptRepository.save(receipt);
            return response;
        } catch (JsonProcessingException exception) {
            throw new BadRequestException("Không thể lưu workflow receipt");
        }
    }

    private String workflowClientEventId(TripActionRequest request) {
        if (request == null
                || request.clientEventId() == null
                || request.clientEventId().isBlank()) {
            return null;
        }
        return request.clientEventId().trim();
    }

    private String nextAction(Trip trip) {
        return switch (trip.getStatus()) {
            case ASSIGNED -> "ACCEPT";
            case ACCEPTED -> "START";
            case IN_PROGRESS -> "PAUSE_OR_COMPLETE";
            case RESTING -> "RESUME";
            default -> "NONE";
        };
    }

    private String toChecklistJson(MobilePreTripChecklistRequest request) {
        try {
            return objectMapper.writeValueAsString(Map.of(
                    "exteriorChecked", request.exteriorChecked(),
                    "tiresChecked", request.tiresChecked(),
                    "brakeChecked", request.brakeChecked(),
                    "lightsChecked", request.lightsChecked(),
                    "cameraChecked", request.cameraChecked(),
                    "gpsChecked", request.gpsChecked(),
                    "documentsChecked", request.documentsChecked()
            ));
        } catch (JsonProcessingException exception) {
            throw new BadRequestException("Dữ liệu checklist không hợp lệ");
        }
    }

    private MobilePreTripChecklistResponse toChecklistResponse(PreTripChecklist checklist) {
        boolean passed = checklist.isExteriorChecked()
                && checklist.isTiresChecked()
                && checklist.isBrakeChecked()
                && checklist.isLightsChecked()
                && checklist.isCameraChecked()
                && checklist.isGpsChecked()
                && checklist.isDocumentsChecked();
        return new MobilePreTripChecklistResponse(
                checklist.getId(),
                checklist.getTrip().getId(),
                checklist.getDriver().getId(),
                checklist.getVehicle() == null ? null : checklist.getVehicle().getId(),
                checklist.isExteriorChecked(),
                checklist.isTiresChecked(),
                checklist.isBrakeChecked(),
                checklist.isLightsChecked(),
                checklist.isCameraChecked(),
                checklist.isGpsChecked(),
                checklist.isDocumentsChecked(),
                passed,
                checklist.getNote(),
                checklist.getCreatedAt()
        );
    }

    private void applyAgentClassification(AgentCommand command, Driver driver) {
        AgentIntent intent = command.getInterpretedIntent();
        if (intent == null || intent == AgentIntent.UNKNOWN) {
            command.setStatus(AgentCommandStatus.UNSUPPORTED);
            command.setResponseText("Lệnh chưa được hỗ trợ; không có hành động nào được thực thi.");
            return;
        }
        if (intent == AgentIntent.GET_DRIVING_TIME) {
            int limit = settingService.getInt(
                    SystemSettingService.DRIVING_MAX_CONTINUOUS_MINUTES,
                    240
            );
            int remaining = Math.max(0, limit - driver.getContinuousDrivingMinutes());
            command.setStatus(AgentCommandStatus.EXECUTED);
            command.setResponseText("Bạn còn " + remaining + " phút lái liên tục.");
            return;
        }
        if (intent == AgentIntent.READ_LATEST_WARNING) {
            List<NotificationResponse> notifications =
                    notificationService.currentUserNotifications(PageRequest.of(0, 1)).items();
            command.setStatus(AgentCommandStatus.EXECUTED);
            command.setResponseText(notifications.isEmpty()
                    ? "Bạn chưa có cảnh báo mới."
                    : notifications.getFirst().title() + ": " + notifications.getFirst().content());
            return;
        }
        command.setStatus(AgentCommandStatus.UNDERSTOOD);
        command.setResponseText(switch (intent) {
            case START_TRIP -> "Đã hiểu yêu cầu bắt đầu chuyến. Vui lòng xác nhận.";
            case PAUSE_TRIP -> "Đã hiểu yêu cầu tạm nghỉ. Vui lòng xác nhận.";
            case RESUME_TRIP -> "Đã hiểu yêu cầu tiếp tục chuyến. Vui lòng xác nhận.";
            case COMPLETE_TRIP -> "Đã hiểu yêu cầu hoàn thành chuyến. Vui lòng xác nhận.";
            case REPORT_FLOOD -> "Đã hiểu yêu cầu báo ngập. Vui lòng xác nhận vị trí.";
            case SEND_SOS -> "Đã hiểu yêu cầu SOS. Vui lòng xác nhận gửi cứu hộ.";
            default -> "Lệnh đã được nhận.";
        });
    }

    private AgentCommand ownedAgentCommand(Long commandId) {
        return agentCommandRepository.findByIdAndUserIdAndDeletedFalse(
                        commandId,
                        SecurityUtils.currentUserId()
                )
                .orElseThrow(() -> new NotFoundException("AgentCommand", commandId));
    }

    private Trip requireAgentTrip(AgentCommand command) {
        if (command.getTrip() == null) {
            throw new BadRequestException("Không có chuyến hiện hành cho lệnh này");
        }
        return command.getTrip();
    }

    private void requireAgentCoordinates(MobileAgentConfirmRequest request) {
        if (request == null || request.lat() == null || request.lng() == null) {
            throw new BadRequestException("Cần vị trí GPS để xác nhận hành động này");
        }
    }

    private void rememberAgentExecution(AgentCommand command,
                                        String referenceType,
                                        Long referenceId,
                                        String responseText) {
        command.setStatus(AgentCommandStatus.EXECUTED);
        command.setExecutedReferenceType(referenceType);
        command.setExecutedReferenceId(referenceId);
        command.setResponseText(responseText);
    }

    private MobileAgentCommandResponse toAgentCommandResponse(AgentCommand command) {
        return new MobileAgentCommandResponse(
                command.getId(),
                command.getCommandType(),
                command.getTrip() == null ? null : command.getTrip().getId(),
                command.getTranscript(),
                command.getNormalizedCommand(),
                command.getInterpretedIntent(),
                command.getConfidence(),
                command.isRequiresConfirmation(),
                command.getClassificationSource(),
                command.getStatus(),
                command.getResponseText(),
                command.getExecutedReferenceType(),
                command.getExecutedReferenceId(),
                command.getCreatedAt()
        );
    }
}
