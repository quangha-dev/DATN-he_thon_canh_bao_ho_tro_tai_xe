package com.safefleet.navigation;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.common.exception.ForbiddenActionException;
import com.safefleet.common.exception.NotFoundException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.flood.entity.FloodReport;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodStatus;
import com.safefleet.flood.repository.FloodReportRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.navigation.provider.RoutingProvider;
import com.safefleet.navigation.provider.RoutingProvider.GeoPoint;
import com.safefleet.navigation.provider.RoutingProvider.ProviderRoute;
import com.safefleet.navigation.provider.RoutingProvider.TurnStep;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.repository.TripRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class NavigationService {

    private static final int MAX_CONTINUOUS_DRIVING_MINUTES = 240;
    private static final double OFF_ROUTE_THRESHOLD_METERS = 75;
    private static final double MAX_VALID_GPS_ACCURACY_METERS = 50;
    private static final int OFF_ROUTE_CONFIRM_SECONDS = 15;

    private final RoutingProvider routingProvider;
    private final FloodReportRepository floodReportRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    @Transactional
    public NavigationSessionResponse routes(NavigationRouteRequest request) {
        Driver driver = currentDriver();
        Trip trip = ownedTrip(driver, request.tripId());
        Long vehicleId = trip != null && trip.getVehicle() != null
                ? trip.getVehicle().getId()
                : driver.getCurrentVehicle() == null ? null : driver.getCurrentVehicle().getId();
        Long sessionDatabaseId = findReusableSession(driver.getId(), request.tripId());
        String sessionId;
        if (sessionDatabaseId == null) {
            sessionId = UUID.randomUUID().toString();
            sessionDatabaseId = insertSession(sessionId, driver.getId(), vehicleId, request);
        } else {
            sessionId = sessionUuid(sessionDatabaseId);
            updateSessionCoordinates(sessionDatabaseId, vehicleId, request);
        }
        computeAndPersist(sessionDatabaseId, driver, request);
        return loadSession(sessionId, driver.getId());
    }

    @Transactional
    public NavigationSessionResponse reroute(NavigationRerouteRequest request) {
        Driver driver = currentDriver();
        SessionRow session = ownedSession(request.sessionId(), driver.getId());
        NavigationRouteRequest routeRequest = new NavigationRouteRequest(
                request.currentLat(),
                request.currentLng(),
                session.destinationLat(),
                session.destinationLng(),
                session.destinationName(),
                session.tripId()
        );
        jdbcTemplate.update("""
                INSERT INTO navigation_events (
                    navigation_session_id, event_type, lat, lng,
                    gps_accuracy_meters, payload_json, occurred_at, created_at
                ) VALUES (?, 'REROUTE_REQUESTED', ?, ?, ?, ?, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6))
                """,
                session.id(),
                request.currentLat(),
                request.currentLng(),
                request.gpsAccuracyMeters(),
                json(Map.of("reason", request.reason() == null ? "OFF_ROUTE" : request.reason()))
        );
        updateSessionCoordinates(session.id(), session.vehicleId(), routeRequest);
        computeAndPersist(session.id(), driver, routeRequest);
        return loadSession(request.sessionId(), driver.getId());
    }

    @Transactional
    public NavigationEventResponse event(NavigationEventRequest request) {
        Driver driver = currentDriver();
        SessionRow session = ownedSession(request.sessionId(), driver.getId());
        LocalDateTime occurredAt = request.occurredAt() == null ? LocalDateTime.now() : request.occurredAt();
        if (occurredAt.isAfter(LocalDateTime.now().plusMinutes(1))) {
            throw new BadRequestException("occurredAt không được nằm trong tương lai");
        }
        boolean accuracyValid = request.gpsAccuracyMeters() == null
                || request.gpsAccuracyMeters() <= MAX_VALID_GPS_ACCURACY_METERS;
        boolean offRoute = accuracyValid
                && request.distanceToRouteMeters() != null
                && request.distanceToRouteMeters() > OFF_ROUTE_THRESHOLD_METERS;

        int offRouteSeconds = 0;
        boolean rerouteRequired = false;
        String storedType = request.eventType().trim().toUpperCase(Locale.ROOT);
        if ("LOCATION_UPDATE".equals(storedType)) {
            if (offRoute) {
                LocalDateTime start = offRouteStart(session.id(), occurredAt);
                offRouteSeconds = Math.max(0, (int) Duration.between(start, occurredAt).getSeconds());
                rerouteRequired = offRouteSeconds >= OFF_ROUTE_CONFIRM_SECONDS;
                storedType = rerouteRequired ? "OFF_ROUTE_CONFIRMED" : "OFF_ROUTE_CANDIDATE";
            } else {
                storedType = "ON_ROUTE";
            }
        }

        String eventType = storedType;
        KeyHolder keyHolder = new GeneratedKeyHolder();
        int distance = request.distanceToRouteMeters() == null
                ? 0
                : Math.max(0, (int) Math.round(request.distanceToRouteMeters()));
        jdbcTemplate.update(connection -> {
            PreparedStatement statement = connection.prepareStatement("""
                    INSERT INTO navigation_events (
                        navigation_session_id, event_type, lat, lng,
                        distance_to_route_meters, gps_accuracy_meters,
                        payload_json, occurred_at, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP(6))
                    """, new String[]{"id"});
            statement.setLong(1, session.id());
            statement.setString(2, eventType);
            statement.setObject(3, request.lat());
            statement.setObject(4, request.lng());
            statement.setInt(5, distance);
            statement.setObject(6, request.gpsAccuracyMeters());
            statement.setString(7, json(Map.of(
                    "sourceEventType", request.eventType(),
                    "metadata", request.metadata() == null ? "" : request.metadata()
            )));
            statement.setTimestamp(8, Timestamp.valueOf(occurredAt));
            return statement;
        }, keyHolder);
        long eventId = keyHolder.getKey().longValue();
        return new NavigationEventResponse(
                eventId,
                request.sessionId(),
                eventType,
                offRoute,
                offRouteSeconds,
                rerouteRequired,
                occurredAt
        );
    }

    @Transactional(readOnly = true)
    public NavigationSessionResponse current() {
        Driver driver = currentDriver();
        List<String> sessions = jdbcTemplate.queryForList("""
                SELECT session_uuid
                FROM navigation_sessions
                WHERE driver_id = ? AND status IN ('ACTIVE', 'PAUSED') AND deleted = FALSE
                ORDER BY updated_at DESC, created_at DESC
                LIMIT 1
                """, String.class, driver.getId());
        if (sessions.isEmpty()) {
            throw new NotFoundException("Không có phiên dẫn đường đang hoạt động");
        }
        return loadSession(sessions.get(0), driver.getId());
    }

    private void computeAndPersist(Long sessionId, Driver driver, NavigationRouteRequest request) {
        GeoPoint origin = new GeoPoint(request.originLat(), request.originLng());
        GeoPoint destination = new GeoPoint(request.destinationLat(), request.destinationLng());
        List<FloodReport> floods = activeFloodReports();
        List<ScoredRoute> scored = routingProvider.routes(List.of(origin, destination), true).stream()
                .map(route -> score(route, floods, driver))
                .toList();
        if (scored.isEmpty()) {
            throw new BadRequestException("Không thể tạo tuyến đường");
        }

        List<ScoredRoute> expanded = new ArrayList<>(scored);
        if (scored.stream().allMatch(ScoredRoute::blocked)) {
            FloodReport danger = mostDangerousFlood(floods, scored.get(0).route());
            if (danger != null) {
                for (GeoPoint waypoint : detourWaypoints(scored.get(0).route(), danger)) {
                    routingProvider.routes(List.of(origin, waypoint, destination), false).stream()
                            .map(route -> score(route, floods, driver))
                            .forEach(expanded::add);
                }
            }
        }

        int selectedIndex = 0;
        for (int index = 1; index < expanded.size(); index++) {
            if (routeComparator().compare(expanded.get(index), expanded.get(selectedIndex)) < 0) {
                selectedIndex = index;
            }
        }
        persistCandidates(sessionId, expanded, selectedIndex);
    }

    private ScoredRoute score(ProviderRoute route, List<FloodReport> floods, Driver driver) {
        double floodPenalty = 0;
        boolean blocked = false;
        int intersections = 0;
        List<String> warnings = new ArrayList<>();
        LocalDateTime now = LocalDateTime.now();
        for (FloodReport flood : floods) {
            double distance = distanceToPolylineMeters(new GeoPoint(flood.getLat(), flood.getLng()), route.geometry());
            double distanceFactor = distanceFactor(distance);
            if (distanceFactor == 0) {
                continue;
            }
            intersections++;
            double freshness = freshnessFactor(flood.getCreatedAt(), now);
            double penalty = severityPenalty(flood.getSeverity()) * distanceFactor * freshness;
            floodPenalty += penalty;
            if (flood.getSeverity() == FloodSeverity.BLOCKED) {
                blocked = true;
            }
            warnings.add("%s cách tuyến %.0f m%s".formatted(
                    flood.getSeverity().name(),
                    distance,
                    flood.getAddress() == null ? "" : " tại " + flood.getAddress()
            ));
        }

        double durationMinutes = route.durationSeconds() / 60.0;
        double distanceKm = route.distanceMeters() / 1000.0;
        int remainingMinutes = Math.max(
                0,
                MAX_CONTINUOUS_DRIVING_MINUTES - safeInteger(driver.getContinuousDrivingMinutes())
        );
        double driverPenalty = durationMinutes > remainingMinutes
                ? (durationMinutes - remainingMinutes) * 2.0
                : 0;
        if (driverPenalty > 0) {
            warnings.add("ETA vượt thời gian lái liên tục còn lại %.0f phút".formatted(
                    durationMinutes - remainingMinutes
            ));
        }
        double vehiclePenalty = 0;
        double totalScore = durationMinutes + distanceKm + floodPenalty + vehiclePenalty + driverPenalty;
        return new ScoredRoute(
                route,
                roundThree(floodPenalty),
                vehiclePenalty,
                roundThree(driverPenalty),
                roundThree(totalScore),
                intersections,
                blocked,
                List.copyOf(warnings)
        );
    }

    private void persistCandidates(Long sessionId, List<ScoredRoute> routes, int selectedIndex) {
        jdbcTemplate.update("UPDATE navigation_sessions SET selected_candidate_id = NULL WHERE id = ?", sessionId);
        jdbcTemplate.update("DELETE FROM navigation_route_candidates WHERE navigation_session_id = ?", sessionId);

        Long selectedCandidateId = null;
        for (int index = 0; index < routes.size(); index++) {
            ScoredRoute scored = routes.get(index);
            boolean recommended = index == selectedIndex;
            String label = recommended ? "Đề xuất ít rủi ro nhất" : "Phương án " + (index + 1);
            List<List<Double>> geometry = scored.route().geometry().stream()
                    .map(point -> List.of(point.lng(), point.lat()))
                    .toList();
            List<NavigationStepResponse> steps = scored.route().steps().stream()
                    .map(this::toStep)
                    .toList();
            KeyHolder keyHolder = new GeneratedKeyHolder();
            int routeIndex = index;
            jdbcTemplate.update(connection -> {
                PreparedStatement statement = connection.prepareStatement("""
                        INSERT INTO navigation_route_candidates (
                            navigation_session_id, route_index, label,
                            distance_meters, duration_seconds,
                            risk_score, total_score, flood_penalty,
                            vehicle_restriction_penalty, driver_time_penalty,
                            flood_intersection_count, safe, blocked, is_recommended,
                            geometry_json, steps_json, warnings_json, provider, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP(6))
                        """, new String[]{"id"});
                statement.setLong(1, sessionId);
                statement.setInt(2, routeIndex);
                statement.setString(3, label);
                statement.setInt(4, Math.max(1, (int) Math.round(scored.route().distanceMeters())));
                statement.setInt(5, Math.max(1, (int) Math.round(scored.route().durationSeconds())));
                statement.setBigDecimal(6, BigDecimal.valueOf(scored.floodPenalty()));
                statement.setBigDecimal(7, BigDecimal.valueOf(scored.totalScore()));
                statement.setBigDecimal(8, BigDecimal.valueOf(scored.floodPenalty()));
                statement.setBigDecimal(9, BigDecimal.valueOf(scored.vehiclePenalty()));
                statement.setBigDecimal(10, BigDecimal.valueOf(scored.driverPenalty()));
                statement.setInt(11, scored.floodIntersections());
                statement.setBoolean(12, !scored.blocked());
                statement.setBoolean(13, scored.blocked());
                statement.setBoolean(14, recommended);
                statement.setString(15, json(geometry));
                statement.setString(16, json(steps));
                statement.setString(17, json(scored.warnings()));
                statement.setString(18, scored.route().provider());
                return statement;
            }, keyHolder);
            if (recommended) {
                selectedCandidateId = keyHolder.getKey().longValue();
            }
        }
        jdbcTemplate.update("""
                UPDATE navigation_sessions
                SET selected_candidate_id = ?, status = 'ACTIVE', started_at = COALESCE(started_at, CURRENT_TIMESTAMP(6)),
                    ended_at = NULL, updated_at = CURRENT_TIMESTAMP(6)
                WHERE id = ?
                """, selectedCandidateId, sessionId);
    }

    private Long insertSession(String sessionUuid,
                               Long driverId,
                               Long vehicleId,
                               NavigationRouteRequest request) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement statement = connection.prepareStatement("""
                    INSERT INTO navigation_sessions (
                        session_uuid, driver_id, vehicle_id, trip_id,
                        origin_lat, origin_lng, destination_lat, destination_lng,
                        destination_name, status, started_at, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE',
                              CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6))
                    """, new String[]{"id"});
            statement.setString(1, sessionUuid);
            statement.setLong(2, driverId);
            statement.setObject(3, vehicleId);
            statement.setObject(4, request.tripId());
            statement.setDouble(5, request.originLat());
            statement.setDouble(6, request.originLng());
            statement.setDouble(7, request.destinationLat());
            statement.setDouble(8, request.destinationLng());
            statement.setString(9, request.destinationName());
            return statement;
        }, keyHolder);
        return keyHolder.getKey().longValue();
    }

    private void updateSessionCoordinates(Long sessionId, Long vehicleId, NavigationRouteRequest request) {
        jdbcTemplate.update("""
                UPDATE navigation_sessions
                SET vehicle_id = COALESCE(?, vehicle_id), trip_id = COALESCE(?, trip_id),
                    origin_lat = ?, origin_lng = ?,
                    destination_lat = ?, destination_lng = ?, destination_name = ?,
                    status = 'ACTIVE', ended_at = NULL, updated_at = CURRENT_TIMESTAMP(6)
                WHERE id = ?
                """,
                vehicleId,
                request.tripId(),
                request.originLat(),
                request.originLng(),
                request.destinationLat(),
                request.destinationLng(),
                request.destinationName(),
                sessionId
        );
    }

    private NavigationSessionResponse loadSession(String sessionUuid, Long driverId) {
        SessionRow session = ownedSession(sessionUuid, driverId);
        List<NavigationRouteCandidateResponse> routes = jdbcTemplate.query("""
                SELECT id, route_index, label, distance_meters, duration_seconds,
                       total_score, flood_penalty, vehicle_restriction_penalty, driver_time_penalty,
                       flood_intersection_count, safe, blocked, is_recommended,
                       geometry_json, steps_json, warnings_json, provider
                FROM navigation_route_candidates
                WHERE navigation_session_id = ?
                ORDER BY route_index
                """, (rs, rowNum) -> new NavigationRouteCandidateResponse(
                rs.getLong("id"),
                rs.getInt("route_index"),
                rs.getString("label"),
                rs.getInt("distance_meters"),
                rs.getInt("duration_seconds"),
                rs.getDouble("total_score"),
                rs.getDouble("flood_penalty"),
                rs.getDouble("vehicle_restriction_penalty"),
                rs.getDouble("driver_time_penalty"),
                rs.getInt("flood_intersection_count"),
                rs.getBoolean("safe"),
                rs.getBoolean("blocked"),
                rs.getBoolean("is_recommended"),
                rs.getString("provider"),
                !"OSRM".equals(rs.getString("provider")),
                readJson(rs.getString("geometry_json"), new TypeReference<>() {
                }),
                readJson(rs.getString("steps_json"), new TypeReference<>() {
                }),
                readJson(rs.getString("warnings_json"), new TypeReference<>() {
                })
        ), session.id());
        NavigationRouteCandidateResponse selected = routes.stream()
                .filter(route -> Boolean.TRUE.equals(route.recommended()))
                .findFirst()
                .orElse(null);
        return new NavigationSessionResponse(
                session.uuid(),
                session.tripId(),
                session.vehicleId(),
                session.status(),
                session.originLat(),
                session.originLng(),
                session.destinationLat(),
                session.destinationLng(),
                session.destinationName(),
                selected == null || selected.safe(),
                selected == null ? null : selected.routeIndex(),
                routes,
                session.startedAt(),
                session.updatedAt()
        );
    }

    private SessionRow ownedSession(String uuid, Long driverId) {
        List<SessionRow> rows = jdbcTemplate.query("""
                SELECT id, session_uuid, trip_id, vehicle_id, status,
                       origin_lat, origin_lng, destination_lat, destination_lng,
                       destination_name, started_at, updated_at
                FROM navigation_sessions
                WHERE session_uuid = ? AND driver_id = ? AND deleted = FALSE
                """, (rs, rowNum) -> new SessionRow(
                rs.getLong("id"),
                rs.getString("session_uuid"),
                nullableLong(rs.getObject("trip_id")),
                nullableLong(rs.getObject("vehicle_id")),
                rs.getString("status"),
                rs.getDouble("origin_lat"),
                rs.getDouble("origin_lng"),
                rs.getDouble("destination_lat"),
                rs.getDouble("destination_lng"),
                rs.getString("destination_name"),
                timestamp(rs.getTimestamp("started_at")),
                timestamp(rs.getTimestamp("updated_at"))
        ), uuid, driverId);
        if (rows.isEmpty()) {
            throw new NotFoundException("Không tìm thấy phiên dẫn đường hoặc phiên không thuộc tài xế");
        }
        return rows.get(0);
    }

    private Long findReusableSession(Long driverId, Long tripId) {
        if (tripId == null) {
            return null;
        }
        List<Long> ids = jdbcTemplate.queryForList("""
                SELECT id
                FROM navigation_sessions
                WHERE driver_id = ? AND trip_id = ? AND status IN ('ACTIVE', 'PAUSED') AND deleted = FALSE
                ORDER BY created_at DESC
                LIMIT 1
                """, Long.class, driverId, tripId);
        return ids.isEmpty() ? null : ids.get(0);
    }

    private String sessionUuid(Long id) {
        return jdbcTemplate.queryForObject(
                "SELECT session_uuid FROM navigation_sessions WHERE id = ?",
                String.class,
                id
        );
    }

    private LocalDateTime offRouteStart(Long sessionId, LocalDateTime occurredAt) {
        List<LocalDateTime> starts = jdbcTemplate.query("""
                SELECT MIN(occurred_at) AS started_at
                FROM navigation_events
                WHERE navigation_session_id = ?
                  AND event_type IN ('OFF_ROUTE_CANDIDATE', 'OFF_ROUTE_CONFIRMED')
                  AND occurred_at > COALESCE((
                      SELECT MAX(on_route.occurred_at)
                      FROM navigation_events on_route
                      WHERE on_route.navigation_session_id = ?
                        AND on_route.event_type = 'ON_ROUTE'
                  ), '1970-01-01 00:00:00')
                  AND occurred_at >= ?
                """, (rs, rowNum) -> timestamp(rs.getTimestamp("started_at")),
                sessionId,
                sessionId,
                Timestamp.valueOf(occurredAt.minusMinutes(5))
        );
        return starts.isEmpty() || starts.get(0) == null ? occurredAt : starts.get(0);
    }

    private Driver currentDriver() {
        return driverRepository.findByUserId(SecurityUtils.currentUserId())
                .filter(driver -> !driver.isDeleted())
                .orElseThrow(() -> new ForbiddenActionException("Không tìm thấy hồ sơ tài xế"));
    }

    private Trip ownedTrip(Driver driver, Long tripId) {
        if (tripId == null) {
            return null;
        }
        Trip trip = tripRepository.findById(tripId)
                .filter(item -> !item.isDeleted())
                .orElseThrow(() -> new NotFoundException("Trip", tripId));
        if (trip.getDriver() == null || !driver.getId().equals(trip.getDriver().getId())) {
            throw new ForbiddenActionException("Tài xế chỉ được dẫn đường cho chuyến của chính mình");
        }
        return trip;
    }

    private List<FloodReport> activeFloodReports() {
        LocalDateTime now = LocalDateTime.now();
        return floodReportRepository.findByStatusIn(List.of(FloodStatus.UNVERIFIED, FloodStatus.VERIFIED)).stream()
                .filter(report -> !report.isDeleted())
                .filter(report -> report.getExpiredAt() != null && report.getExpiredAt().isAfter(now))
                .filter(report -> report.getSeverity().ordinal() >= FloodSeverity.MEDIUM.ordinal())
                .toList();
    }

    private FloodReport mostDangerousFlood(List<FloodReport> floods, ProviderRoute route) {
        return floods.stream()
                .filter(flood -> distanceToPolylineMeters(
                        new GeoPoint(flood.getLat(), flood.getLng()),
                        route.geometry()
                ) <= 300)
                .max(Comparator
                        .comparingInt((FloodReport flood) -> flood.getSeverity().ordinal())
                        .thenComparing(FloodReport::getCreatedAt))
                .orElse(null);
    }

    private List<GeoPoint> detourWaypoints(ProviderRoute route, FloodReport danger) {
        List<GeoPoint> geometry = route.geometry();
        if (geometry.size() < 2) {
            return List.of();
        }
        GeoPoint flood = new GeoPoint(danger.getLat(), danger.getLng());
        int nearestIndex = 0;
        double nearestDistance = Double.MAX_VALUE;
        for (int index = 1; index < geometry.size(); index++) {
            double distance = distanceToSegmentMeters(flood, geometry.get(index - 1), geometry.get(index));
            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearestIndex = index - 1;
            }
        }
        GeoPoint first = geometry.get(nearestIndex);
        GeoPoint second = geometry.get(nearestIndex + 1);
        double dLat = second.lat() - first.lat();
        double dLng = second.lng() - first.lng();
        double norm = Math.max(0.000001, Math.sqrt(dLat * dLat + dLng * dLng));
        double offsetMeters = 1_000;
        double latDegrees = offsetMeters / 111_320.0;
        double lngDegrees = offsetMeters / (111_320.0 * Math.max(0.2, Math.cos(Math.toRadians(flood.lat()))));
        double perpendicularLat = -dLng / norm * latDegrees;
        double perpendicularLng = dLat / norm * lngDegrees;
        return List.of(
                new GeoPoint(flood.lat() + perpendicularLat, flood.lng() + perpendicularLng),
                new GeoPoint(flood.lat() - perpendicularLat, flood.lng() - perpendicularLng)
        );
    }

    private Comparator<ScoredRoute> routeComparator() {
        return Comparator
                .comparing(ScoredRoute::blocked)
                .thenComparingDouble(ScoredRoute::totalScore);
    }

    private double distanceToPolylineMeters(GeoPoint point, List<GeoPoint> geometry) {
        if (geometry == null || geometry.size() < 2) {
            return Double.MAX_VALUE;
        }
        double distance = Double.MAX_VALUE;
        for (int index = 1; index < geometry.size(); index++) {
            distance = Math.min(
                    distance,
                    distanceToSegmentMeters(point, geometry.get(index - 1), geometry.get(index))
            );
        }
        return distance;
    }

    private double distanceToSegmentMeters(GeoPoint point, GeoPoint start, GeoPoint end) {
        double referenceLat = Math.toRadians(point.lat());
        double metersPerLat = 111_320.0;
        double metersPerLng = 111_320.0 * Math.cos(referenceLat);
        double px = (point.lng() - start.lng()) * metersPerLng;
        double py = (point.lat() - start.lat()) * metersPerLat;
        double dx = (end.lng() - start.lng()) * metersPerLng;
        double dy = (end.lat() - start.lat()) * metersPerLat;
        double lengthSquared = dx * dx + dy * dy;
        if (lengthSquared == 0) {
            return Math.sqrt(px * px + py * py);
        }
        double projection = Math.max(0, Math.min(1, (px * dx + py * dy) / lengthSquared));
        double nearestX = projection * dx;
        double nearestY = projection * dy;
        return Math.sqrt(Math.pow(px - nearestX, 2) + Math.pow(py - nearestY, 2));
    }

    private double distanceFactor(double distanceMeters) {
        if (distanceMeters <= 100) {
            return 1.0;
        }
        if (distanceMeters <= 200) {
            return 0.7;
        }
        if (distanceMeters <= 300) {
            return 0.4;
        }
        return 0;
    }

    private double freshnessFactor(LocalDateTime createdAt, LocalDateTime now) {
        if (createdAt == null) {
            return 0.5;
        }
        long minutes = Math.max(0, Duration.between(createdAt, now).toMinutes());
        if (minutes <= 30) {
            return 1.0;
        }
        if (minutes <= 90) {
            return 0.8;
        }
        if (minutes <= 180) {
            return 0.5;
        }
        return 0;
    }

    private double severityPenalty(FloodSeverity severity) {
        return switch (severity) {
            case NONE -> 0;
            case LOW -> 5;
            case MEDIUM -> 30;
            case HIGH -> 100;
            case BLOCKED -> 1_000;
        };
    }

    private NavigationStepResponse toStep(TurnStep step) {
        return new NavigationStepResponse(
                step.instruction(),
                step.roadName(),
                roundThree(step.distanceMeters()),
                roundThree(step.durationSeconds()),
                step.maneuverType(),
                step.modifier(),
                step.location().lat(),
                step.location().lng()
        );
    }

    private String json(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException exception) {
            throw new BadRequestException("Không thể tuần tự dữ liệu dẫn đường");
        }
    }

    private <T> T readJson(String value, TypeReference<T> type) {
        try {
            return value == null ? null : objectMapper.readValue(value, type);
        } catch (JsonProcessingException exception) {
            throw new BadRequestException("Dữ liệu dẫn đường trong cơ sở dữ liệu không hợp lệ");
        }
    }

    private Long nullableLong(Object value) {
        return value == null ? null : ((Number) value).longValue();
    }

    private LocalDateTime timestamp(Timestamp value) {
        return value == null ? null : value.toLocalDateTime();
    }

    private int safeInteger(Integer value) {
        return value == null ? 0 : value;
    }

    private double roundThree(double value) {
        return Math.round(value * 1_000.0) / 1_000.0;
    }

    private record ScoredRoute(
            ProviderRoute route,
            double floodPenalty,
            double vehiclePenalty,
            double driverPenalty,
            double totalScore,
            int floodIntersections,
            boolean blocked,
            List<String> warnings
    ) {
    }

    private record SessionRow(
            Long id,
            String uuid,
            Long tripId,
            Long vehicleId,
            String status,
            Double originLat,
            Double originLng,
            Double destinationLat,
            Double destinationLng,
            String destinationName,
            LocalDateTime startedAt,
            LocalDateTime updatedAt
    ) {
    }
}
