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
import com.safefleet.flood.enums.FloodGeometryType;
import com.safefleet.flood.enums.FloodStatus;
import com.safefleet.flood.enums.RoadHazardType;
import com.safefleet.flood.repository.FloodReportRepository;
import com.safefleet.infrastructure.security.SecurityUtils;
import com.safefleet.navigation.provider.RoutingProvider;
import com.safefleet.navigation.provider.RoutingProvider.GeoPoint;
import com.safefleet.navigation.provider.RoutingProvider.ProviderRoute;
import com.safefleet.navigation.provider.RoutingProvider.RoutingExclusions;
import com.safefleet.navigation.provider.RoutingProvider.TurnStep;
import com.safefleet.navigation.provider.RoutingProvider.VehicleRoutingProfile;
import com.safefleet.trip.entity.Trip;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.entity.Vehicle;
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
    private static final int MAX_ROUTING_AVOID_LOCATIONS = 48;
    private static final int MAX_ROUTING_AVOID_POLYGONS = 16;
    private static final int MAX_DETOUR_HAZARDS = 4;
    private static final int MAX_DETOUR_ROUTE_REQUESTS = 4;
    private static final int MAX_ROUTE_CANDIDATES = 4;
    private static final double HARD_CLOSURE_BUFFER_METERS = 20.0;
    private static final int UNVERIFIED_BLOCKED_CLOSURE_MINUTES = 30;
    /** Corridor half-width used to turn a reported flooded stretch into a
     *  polygon the router can exclude. Kept tight so a closure on one street
     *  does not also remove the parallel alley that is the natural bypass. */
    private static final double SEGMENT_EXCLUSION_BUFFER_METERS = 22.0;
    /** How far ahead of the driver a hazard is worth announcing or rerouting
     *  around. Beyond this the road situation is likely to change before the
     *  vehicle arrives, and an early reroute only costs distance. */
    private static final double HAZARD_LOOKAHEAD_METERS = 2_500.0;
    private static final double DESTINATION_REUSE_RADIUS_METERS = 120.0;

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
        Long sessionDatabaseId = findReusableSession(driver.getId(), request.tripId(), request);
        String sessionId;
        if (sessionDatabaseId == null) {
            sessionId = UUID.randomUUID().toString();
            sessionDatabaseId = insertSession(sessionId, driver.getId(), vehicleId, request);
        } else {
            sessionId = sessionUuid(sessionDatabaseId);
            updateSessionCoordinates(sessionDatabaseId, vehicleId, request);
        }
        Vehicle vehicle = trip != null ? trip.getVehicle() : driver.getCurrentVehicle();
        computeAndPersist(sessionDatabaseId, driver, request, routingProfile(vehicle));
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
        Trip trip = ownedTrip(driver, session.tripId());
        Vehicle vehicle = trip != null ? trip.getVehicle() : driver.getCurrentVehicle();
        computeAndPersist(session.id(), driver, routeRequest, routingProfile(vehicle));
        return loadSession(request.sessionId(), driver.getId());
    }

    @Transactional
    public NavigationEventResponse event(NavigationEventRequest request) {
        Driver driver = currentDriver();
        SessionRow session = ownedSession(request.sessionId(), driver.getId());
        LocalDateTime occurredAt = NavigationTime.parse(request.occurredAt());
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
        boolean locationUpdate = "LOCATION_UPDATE".equals(storedType);
        if (locationUpdate) {
            if (offRoute) {
                LocalDateTime start = offRouteStart(session.id(), occurredAt);
                offRouteSeconds = Math.max(0, (int) Duration.between(start, occurredAt).getSeconds());
                rerouteRequired = offRouteSeconds >= OFF_ROUTE_CONFIRM_SECONDS;
                storedType = rerouteRequired ? "OFF_ROUTE_CONFIRMED" : "OFF_ROUTE_CANDIDATE";
            } else {
                storedType = "ON_ROUTE";
            }
        }
        NavigationHazardAheadResponse hazardAhead = locationUpdate
                && accuracyValid
                && request.lat() != null
                && request.lng() != null
                ? hazardAhead(session.id(), request.lat(), request.lng())
                : null;
        if (hazardAhead != null && Boolean.TRUE.equals(hazardAhead.blocking()) && !rerouteRequired) {
            rerouteRequired = true;
            storedType = "HAZARD_REROUTE_REQUIRED";
        }

        String eventType = storedType;
        NavigationHazardAheadResponse hazard = hazardAhead;
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
            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("sourceEventType", request.eventType());
            payload.put("metadata", request.metadata() == null ? "" : request.metadata());
            if (hazard != null) {
                payload.put("hazardId", hazard.hazardId());
                payload.put("hazardSeverity", hazard.severity());
                payload.put("hazardDistanceMeters", hazard.distanceAlongRouteMeters());
            }
            statement.setString(7, json(payload));
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
                occurredAt,
                hazard
        );
    }

    @Transactional(readOnly = true)
    public NavigationSessionResponse current() {
        Driver driver = currentDriver();
        // A trip start creates a session before any route exists. Restoring that
        // empty shell would blank the planner, so only sessions that actually
        // carry a computed route are offered back to the device.
        List<String> sessions = jdbcTemplate.queryForList("""
                SELECT session_uuid
                FROM navigation_sessions
                WHERE driver_id = ? AND status IN ('ACTIVE', 'PAUSED') AND deleted = FALSE
                  AND selected_candidate_id IS NOT NULL
                ORDER BY updated_at DESC NULLS LAST, created_at DESC
                LIMIT 1
                """, String.class, driver.getId());
        if (sessions.isEmpty()) {
            throw new NotFoundException("Không có phiên dẫn đường đang hoạt động");
        }
        return loadSession(sessions.get(0), driver.getId());
    }

    @Transactional(readOnly = true)
    public NavigationSessionResponse activeForVehicle(Long vehicleId) {
        List<Map<String, Object>> sessions = jdbcTemplate.queryForList("""
                SELECT session_uuid, driver_id
                FROM navigation_sessions
                WHERE vehicle_id = ? AND status IN ('ACTIVE', 'PAUSED') AND deleted = FALSE
                ORDER BY updated_at DESC NULLS LAST, created_at DESC
                LIMIT 1
                """, vehicleId);
        if (sessions.isEmpty()) {
            throw new NotFoundException("Xe chưa có phiên dẫn đường đang hoạt động");
        }
        Map<String, Object> session = sessions.get(0);
        return loadSession(
                session.get("session_uuid").toString(),
                ((Number) session.get("driver_id")).longValue()
        );
    }

    private void computeAndPersist(Long sessionId, Driver driver, NavigationRouteRequest request) {
        computeAndPersist(sessionId, driver, request, routingProfile(driver.getCurrentVehicle()));
    }

    /**
     * Builds, validates and stores the route options for a session.
     *
     * <p>Hazard avoidance runs on three independent layers, because any single
     * one of them can fail in production:</p>
     * <ol>
     *   <li>the road graph itself is asked to exclude the closure, which is the
     *       only layer that can weigh the whole network and pick the genuinely
     *       cheapest way around it;</li>
     *   <li>explicit detour waypoints are requested around every closure that
     *       still sits on a returned route, so a provider that ignores dynamic
     *       exclusions (OSRM) or runs on a graph older than the report still
     *       produces a usable bypass;</li>
     *   <li>every returned geometry is re-tested against the hazards and any
     *       route still crossing a hard closure is dropped rather than ranked.</li>
     * </ol>
     *
     * <p>Direct alternatives and detours are scored against one another, so a
     * short local bypass wins over a long reroute whenever it really is
     * cheaper - which is what a driver expects after reporting a flooded
     * street.</p>
     */
    private void computeAndPersist(Long sessionId,
                                   Driver driver,
                                   NavigationRouteRequest request,
                                   VehicleRoutingProfile profile) {
        GeoPoint origin = new GeoPoint(request.originLat(), request.originLng());
        GeoPoint destination = new GeoPoint(request.destinationLat(), request.destinationLng());
        List<FloodReport> floods = activeFloodReports();
        RoutingExclusions exclusions = routingExclusions(floods);
        List<ScoredRoute> direct = routingProvider.routes(
                        List.of(origin, destination),
                        true,
                        exclusions,
                        profile
                ).stream()
                .map(route -> score(route, floods, driver))
                .toList();
        if (direct.isEmpty()) {
            throw new BadRequestException("Không thể tạo tuyến đường");
        }

        List<ScoredRoute> candidates = new ArrayList<>(direct);
        if (direct.stream().anyMatch(ScoredRoute::blocked)) {
            ScoredRoute blockedReference = direct.stream()
                    .filter(ScoredRoute::blocked)
                    .min(Comparator.comparingDouble(ScoredRoute::totalScore))
                    .orElse(direct.get(0));
            int requests = 0;
            for (List<GeoPoint> waypoints : detourWaypointSets(blockedReference.route(), floods)) {
                if (requests >= MAX_DETOUR_ROUTE_REQUESTS) {
                    break;
                }
                List<GeoPoint> requestPoints = new ArrayList<>();
                requestPoints.add(origin);
                requestPoints.addAll(waypoints);
                requestPoints.add(destination);
                if (requestPoints.size() <= 2) {
                    continue;
                }
                requests++;
                routingProvider.routes(requestPoints, false, exclusions, profile).stream()
                        .map(route -> score(route, floods, driver))
                        .forEach(candidates::add);
            }
        }

        // A route intersecting a hard closure must never be exposed as a usable
        // alternative. This also protects against stale/misconfigured providers
        // that silently ignore dynamic exclusions.
        List<ScoredRoute> safeRoutes = candidates.stream()
                .filter(route -> !route.blocked())
                .distinct()
                .sorted(routeComparator())
                .limit(MAX_ROUTE_CANDIDATES)
                .toList();
        if (safeRoutes.isEmpty()) {
            throw new BadRequestException(
                    "Chưa tìm thấy tuyến an toàn không đi qua vùng ngập hoặc đường bị chặn"
            );
        }

        persistHazardSnapshot(sessionId, floods);
        persistCandidates(sessionId, safeRoutes, 0);
    }

    /**
     * Freezes the hazard set the routes were scored against onto the session so
     * the device can keep warning about the same closures while offline.
     */
    private void persistHazardSnapshot(Long sessionId, List<FloodReport> floods) {
        List<NavigationHazardResponse> snapshot = floods.stream()
                .map(this::toHazard)
                .toList();
        jdbcTemplate.update(
                "UPDATE navigation_sessions SET hazards_json = ? WHERE id = ?",
                json(snapshot),
                sessionId
        );
    }

    private NavigationHazardResponse toHazard(FloodReport flood) {
        FloodGeometryType type = flood.getGeometryType() == null
                ? FloodGeometryType.POINT
                : flood.getGeometryType();
        return new NavigationHazardResponse(
                flood.getId(),
                flood.getHazardType() == null ? RoadHazardType.FLOOD.name() : flood.getHazardType().name(),
                flood.getSeverity().name(),
                flood.getStatus().name(),
                type.name(),
                flood.getLat(),
                flood.getLng(),
                flood.getRadiusMeters() == null ? 120.0 : flood.getRadiusMeters(),
                hazardGeometry(flood).stream()
                        .map(point -> List.of(point.lng(), point.lat()))
                        .toList(),
                isHardClosure(flood),
                flood.getAddress(),
                flood.getExpiredAt()
        );
    }

    private ScoredRoute score(ProviderRoute route, List<FloodReport> floods, Driver driver) {
        double floodPenalty = 0;
        boolean blocked = false;
        int intersections = 0;
        List<String> warnings = new ArrayList<>();
        LocalDateTime now = LocalDateTime.now();
        for (FloodReport flood : floods) {
            double distance = hazardDistanceToRoute(flood, route.geometry());
            double distanceFactor = distanceFactor(distance);
            if (distanceFactor == 0) {
                continue;
            }
            intersections++;
            double freshness = freshnessFactor(flood.getCreatedAt(), now);
            double penalty = severityPenalty(flood.getSeverity()) * distanceFactor * freshness;
            floodPenalty += penalty;
            if (isHardClosure(flood) && distance <= HARD_CLOSURE_BUFFER_METERS) {
                blocked = true;
            }
            warnings.add("%s %s %s cách tuyến %.0f m%s".formatted(
                    hazardLabel(flood),
                    flood.getSeverity().name(),
                    flood.getGeometryType() == null ? "POINT" : flood.getGeometryType().name(),
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
            String label = recommended
                    ? "Đề xuất ít rủi ro nhất"
                    : "Phương án " + (index + 1) + describeTradeOff(scored, routes.get(selectedIndex));
            List<List<Double>> geometry = scored.route().geometry().stream()
                    .map(point -> List.of(point.lng(), point.lat()))
                    .toList();
            List<NavigationStepResponse> steps = scored.route().steps().stream()
                    .map(this::toStep)
                    .toList();
            List<List<Double>> navigationWaypoints = scored.route().navigationWaypoints().stream()
                    .map(point -> List.of(point.lng(), point.lat()))
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
                            geometry_json, steps_json, warnings_json, provider,
                            provider_fallback, navigation_waypoints_json, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP(6))
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
                statement.setBoolean(19, scored.route().fallback());
                statement.setString(20, json(navigationWaypoints));
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
                       geometry_json, steps_json, warnings_json, provider,
                       provider_fallback, navigation_waypoints_json
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
                rs.getBoolean("provider_fallback"),
                readJson(rs.getString("navigation_waypoints_json"), new TypeReference<>() {
                }),
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
                sessionHazards(session.id()),
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

    /**
     * Finds the session a new routing request should overwrite.
     *
     * <p>A trip has exactly one navigation session. Ad-hoc navigation used to
     * create a row per search, which left {@code ACTIVE} sessions behind
     * forever and made {@code /navigation/current} resurrect finished routes.
     * Re-planning towards the same destination now reuses the open session, and
     * a genuinely new destination closes the previous one first.</p>
     */
    private Long findReusableSession(Long driverId, Long tripId, NavigationRouteRequest request) {
        if (tripId != null) {
            List<Long> ids = jdbcTemplate.queryForList("""
                    SELECT id
                    FROM navigation_sessions
                    WHERE driver_id = ? AND trip_id = ? AND status IN ('ACTIVE', 'PAUSED') AND deleted = FALSE
                    ORDER BY created_at DESC
                    LIMIT 1
                    """, Long.class, driverId, tripId);
            return ids.isEmpty() ? null : ids.get(0);
        }
        List<Map<String, Object>> open = jdbcTemplate.queryForList("""
                SELECT id, destination_lat, destination_lng
                FROM navigation_sessions
                WHERE driver_id = ? AND trip_id IS NULL
                  AND status IN ('ACTIVE', 'PAUSED') AND deleted = FALSE
                ORDER BY updated_at DESC NULLS LAST, created_at DESC
                """, driverId);
        if (open.isEmpty()) {
            return null;
        }
        GeoPoint destination = new GeoPoint(request.destinationLat(), request.destinationLng());
        Long reusable = null;
        for (Map<String, Object> row : open) {
            Long id = ((Number) row.get("id")).longValue();
            GeoPoint previous = new GeoPoint(
                    ((Number) row.get("destination_lat")).doubleValue(),
                    ((Number) row.get("destination_lng")).doubleValue()
            );
            if (reusable == null
                    && haversineMeters(previous, destination) <= DESTINATION_REUSE_RADIUS_METERS) {
                reusable = id;
            } else {
                closeSession(id, "SUPERSEDED");
            }
        }
        return reusable;
    }

    private void closeSession(Long sessionId, String reason) {
        jdbcTemplate.update("""
                UPDATE navigation_sessions
                SET status = ?, completion_reason = ?,
                    ended_at = COALESCE(ended_at, CURRENT_TIMESTAMP(6)),
                    updated_at = CURRENT_TIMESTAMP(6)
                WHERE id = ?
                """, "SUPERSEDED".equals(reason) ? "CANCELLED" : "COMPLETED", reason, sessionId);
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

    private List<NavigationHazardResponse> sessionHazards(Long sessionId) {
        List<String> rows = jdbcTemplate.queryForList(
                "SELECT hazards_json FROM navigation_sessions WHERE id = ?",
                String.class,
                sessionId
        );
        if (rows.isEmpty() || rows.getFirst() == null) {
            return List.of();
        }
        List<NavigationHazardResponse> hazards = readJson(rows.getFirst(), new TypeReference<>() {
        });
        return hazards == null ? List.of() : hazards;
    }

    /**
     * Ends a session the driver has finished with.
     *
     * <p>Without this the planner kept resurrecting a completed route from
     * {@code /navigation/current}, and {@code ACTIVE} rows grew without bound.
     * Arrival is reported by the device because only it knows when the vehicle
     * actually stopped at the destination.</p>
     */
    @Transactional
    public NavigationSessionResponse complete(String sessionId, String reason) {
        Driver driver = currentDriver();
        SessionRow session = ownedSession(sessionId, driver.getId());
        String completion = reason == null || reason.isBlank()
                ? "ARRIVED"
                : reason.trim().toUpperCase(Locale.ROOT);
        jdbcTemplate.update("""
                UPDATE navigation_sessions
                SET status = ?, completion_reason = ?,
                    ended_at = COALESCE(ended_at, CURRENT_TIMESTAMP(6)),
                    updated_at = CURRENT_TIMESTAMP(6)
                WHERE id = ?
                """, "CANCELLED".equals(completion) ? "CANCELLED" : "COMPLETED", completion, session.id());
        jdbcTemplate.update("""
                INSERT INTO navigation_events (
                    navigation_session_id, event_type, payload_json, occurred_at, created_at
                ) VALUES (?, ?, ?, CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6))
                """, session.id(), "SESSION_" + completion, json(Map.of("reason", completion)));
        return loadSession(sessionId, driver.getId());
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

    /**
     * Finds the nearest hazard on the part of the selected route the driver has
     * not covered yet.
     *
     * <p>The distance is measured forward along the route geometry, not as a
     * straight line, so the app can announce a distance the vehicle will
     * actually travel. Hazards behind the driver and hazards further away than
     * {@link #HAZARD_LOOKAHEAD_METERS} are ignored: rerouting around something
     * that far ahead usually costs more than the closure will still be there.</p>
     */
    private NavigationHazardAheadResponse hazardAhead(Long sessionId, double lat, double lng) {
        List<String> geometries = jdbcTemplate.queryForList("""
                SELECT candidate.geometry_json
                FROM navigation_sessions session
                JOIN navigation_route_candidates candidate
                  ON candidate.id = session.selected_candidate_id
                WHERE session.id = ?
                  AND session.deleted = FALSE
                """, String.class, sessionId);
        if (geometries.isEmpty()) {
            return null;
        }
        List<List<Double>> raw = readJson(geometries.getFirst(), new TypeReference<>() {
        });
        if (raw == null) {
            return null;
        }
        List<GeoPoint> route = raw.stream()
                .filter(point -> point != null && point.size() >= 2)
                .map(point -> new GeoPoint(point.get(1), point.get(0)))
                .toList();
        if (route.size() < 2) {
            return null;
        }
        GeoPoint current = new GeoPoint(lat, lng);
        int nearest = 0;
        double nearestDistance = Double.MAX_VALUE;
        for (int index = 1; index < route.size(); index++) {
            double distance = distanceToSegmentMeters(current, route.get(index - 1), route.get(index));
            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearest = index - 1;
            }
        }
        List<GeoPoint> remainingRoute = route.subList(nearest, route.size());

        NavigationHazardAheadResponse best = null;
        double bestDistance = Double.MAX_VALUE;
        for (FloodReport flood : activeFloodReports()) {
            double clearance = hazardDistanceToRoute(flood, remainingRoute);
            boolean blocking = isHardClosure(flood) && clearance <= HARD_CLOSURE_BUFFER_METERS;
            if (!blocking && clearance > SEGMENT_EXCLUSION_BUFFER_METERS) {
                continue;
            }
            double alongRoute = distanceAlongRouteMeters(remainingRoute, hazardCenter(flood));
            if (alongRoute > HAZARD_LOOKAHEAD_METERS) {
                continue;
            }
            // A blocking hazard always outranks an advisory one, then proximity.
            boolean better = best == null
                    || (blocking && !Boolean.TRUE.equals(best.blocking()))
                    || (blocking == Boolean.TRUE.equals(best.blocking()) && alongRoute < bestDistance);
            if (better) {
                bestDistance = alongRoute;
                best = new NavigationHazardAheadResponse(
                        flood.getId(),
                        flood.getHazardType() == null
                                ? RoadHazardType.FLOOD.name()
                                : flood.getHazardType().name(),
                        flood.getSeverity().name(),
                        roundThree(alongRoute),
                        blocking,
                        flood.getAddress()
                );
            }
        }
        return best;
    }

    /** Distance travelled along {@code route} before reaching {@code target}. */
    private double distanceAlongRouteMeters(List<GeoPoint> route, GeoPoint target) {
        double cumulative = 0;
        double bestAlong = 0;
        double bestLateral = Double.MAX_VALUE;
        for (int index = 1; index < route.size(); index++) {
            GeoPoint start = route.get(index - 1);
            GeoPoint end = route.get(index);
            double segment = haversineMeters(start, end);
            double lateral = distanceToSegmentMeters(target, start, end);
            if (lateral < bestLateral) {
                bestLateral = lateral;
                bestAlong = cumulative + segment * projectionRatio(target, start, end);
            }
            cumulative += segment;
        }
        return bestAlong;
    }

    private double projectionRatio(GeoPoint point, GeoPoint start, GeoPoint end) {
        double metersPerLat = 111_320.0;
        double metersPerLng = 111_320.0 * Math.cos(Math.toRadians(point.lat()));
        double dx = (end.lng() - start.lng()) * metersPerLng;
        double dy = (end.lat() - start.lat()) * metersPerLat;
        double lengthSquared = dx * dx + dy * dy;
        if (lengthSquared == 0) {
            return 0;
        }
        double px = (point.lng() - start.lng()) * metersPerLng;
        double py = (point.lat() - start.lat()) * metersPerLat;
        return Math.max(0, Math.min(1, (px * dx + py * dy) / lengthSquared));
    }

    private String describeTradeOff(ScoredRoute candidate, ScoredRoute recommended) {
        double extraMinutes = (candidate.route().durationSeconds()
                - recommended.route().durationSeconds()) / 60.0;
        double extraKm = (candidate.route().distanceMeters()
                - recommended.route().distanceMeters()) / 1000.0;
        if (Math.abs(extraMinutes) < 1 && Math.abs(extraKm) < 0.3) {
            return "";
        }
        return " (%+.0f phút, %+.1f km)".formatted(extraMinutes, extraKm);
    }

    /**
     * Turns trusted closures into the strongest exclusion each geometry
     * supports.
     *
     * <p>A reported point becomes an {@code exclude_locations} entry, which the
     * router snaps to a single edge - surgical enough that a closure at a
     * junction does not remove every approach to it. A reported stretch of road
     * becomes a narrow corridor polygon instead, because sampling it as points
     * only removes the edges nearest the samples and leaves the rest of the
     * flooded street routable. The corridor is kept deliberately tight so the
     * parallel street that is the natural bypass survives.</p>
     */
    private RoutingExclusions routingExclusions(List<FloodReport> floods) {
        List<FloodReport> trusted = floods.stream()
                .filter(this::isHardClosure)
                .sorted(Comparator
                        .comparingInt((FloodReport report) -> report.getSeverity().ordinal())
                        .reversed()
                        .thenComparing(
                                report -> report.getConfidence() == null ? 0.0 : report.getConfidence(),
                                Comparator.reverseOrder()
                        ))
                .toList();

        List<GeoPoint> locations = new ArrayList<>();
        List<List<GeoPoint>> polygons = new ArrayList<>();
        for (FloodReport report : trusted) {
            FloodGeometryType type = report.getGeometryType() == null
                    ? FloodGeometryType.POINT
                    : report.getGeometryType();
            if (type == FloodGeometryType.POLYGON) {
                List<GeoPoint> ring = closedRing(hazardGeometry(report));
                if (ring.size() >= 4) {
                    polygons.add(ring);
                }
            } else if (type == FloodGeometryType.SEGMENT) {
                List<GeoPoint> corridor = corridorPolygon(
                        hazardGeometry(report),
                        exclusionBufferMeters(report)
                );
                if (corridor.size() >= 4) {
                    polygons.add(corridor);
                }
            }
            locations.addAll(routingAvoidancePoints(report));
        }

        return new RoutingExclusions(
                locations.stream().distinct().limit(MAX_ROUTING_AVOID_LOCATIONS).toList(),
                polygons.stream().limit(MAX_ROUTING_AVOID_POLYGONS).toList()
        );
    }

    private double exclusionBufferMeters(FloodReport report) {
        double radius = report.getRadiusMeters() == null
                ? SEGMENT_EXCLUSION_BUFFER_METERS
                : report.getRadiusMeters();
        return Math.max(10.0, Math.min(40.0, radius));
    }

    /**
     * Builds a closed corridor around a reported stretch of road by offsetting
     * every vertex to both sides along the local segment normal.
     */
    private List<GeoPoint> corridorPolygon(List<GeoPoint> line, double bufferMeters) {
        if (line.size() < 2) {
            return List.of();
        }
        List<GeoPoint> left = new ArrayList<>();
        List<GeoPoint> right = new ArrayList<>();
        for (int index = 0; index < line.size(); index++) {
            GeoPoint start = line.get(Math.max(0, index - 1));
            GeoPoint end = line.get(Math.min(line.size() - 1, index + 1));
            GeoPoint vertex = line.get(index);
            double metersPerLng = 111_320.0 * Math.max(0.2, Math.cos(Math.toRadians(vertex.lat())));
            double dx = (end.lng() - start.lng()) * metersPerLng;
            double dy = (end.lat() - start.lat()) * 111_320.0;
            double norm = Math.sqrt(dx * dx + dy * dy);
            if (norm < 1e-6) {
                continue;
            }
            double offsetLat = (-dx / norm) * bufferMeters / 111_320.0;
            double offsetLng = (dy / norm) * bufferMeters / metersPerLng;
            left.add(new GeoPoint(vertex.lat() + offsetLat, vertex.lng() + offsetLng));
            right.add(new GeoPoint(vertex.lat() - offsetLat, vertex.lng() - offsetLng));
        }
        if (left.size() < 2) {
            return List.of();
        }
        List<GeoPoint> ring = new ArrayList<>(left);
        for (int index = right.size() - 1; index >= 0; index--) {
            ring.add(right.get(index));
        }
        ring.add(left.get(0));
        return List.copyOf(ring);
    }

    private List<GeoPoint> closedRing(List<GeoPoint> points) {
        if (points.size() < 3) {
            return List.of();
        }
        if (points.getFirst().equals(points.getLast())) {
            return List.copyOf(points);
        }
        List<GeoPoint> ring = new ArrayList<>(points);
        ring.add(points.getFirst());
        return List.copyOf(ring);
    }

    private boolean isHardClosure(FloodReport report) {
        if (report.getSeverity() == FloodSeverity.BLOCKED) {
            boolean trusted = report.getStatus() == FloodStatus.VERIFIED
                    || (report.getConfidence() != null && report.getConfidence() >= 0.65);
            boolean recent = report.getCreatedAt() != null
                    && report.getCreatedAt().isAfter(
                    LocalDateTime.now().minusMinutes(UNVERIFIED_BLOCKED_CLOSURE_MINUTES)
            );
            // A fresh report blocks immediately for safety. If nobody verifies
            // it, the hard closure expires quickly and remains only a soft risk
            // penalty until the report itself expires.
            return trusted || recent;
        }
        if (report.getHazardType() == RoadHazardType.TRAFFIC_JAM) {
            return false;
        }
        return report.getSeverity() == FloodSeverity.HIGH
                && (report.getStatus() == FloodStatus.VERIFIED
                || (report.getConfidence() != null && report.getConfidence() >= 0.65));
    }

    private VehicleRoutingProfile routingProfile(Vehicle vehicle) {
        if (vehicle == null) return VehicleRoutingProfile.conservativeTruck();
        String costing = switch (vehicle.getVehicleType()) {
            case CAR, PICKUP, VAN -> "auto";
            case BUS -> "bus";
            case MOTORBIKE -> "motorcycle";
            case TRUCK -> "truck";
        };
        double[] conservative = switch (vehicle.getVehicleType()) {
            // Conservative fleet defaults prevent an incompletely configured
            // vehicle from being sent under a low bridge. Exact admin-entered
            // values always replace these defaults and unlock suitable roads.
            case TRUCK -> new double[]{4.2, 2.6, 20.0, 40.0, 10.0, 5, 80.0};
            case BUS -> new double[]{4.2, 2.6, 15.0, 25.0, 0.0, 0, 80.0};
            case VAN -> new double[]{3.2, 2.2, 7.0, 5.0, 0.0, 0, 100.0};
            case PICKUP -> new double[]{2.2, 2.2, 6.0, 4.0, 0.0, 0, 100.0};
            case CAR -> new double[]{2.0, 2.0, 6.0, 3.0, 0.0, 0, 120.0};
            case MOTORBIKE -> new double[]{0.0, 0.0, 0.0, 0.0, 0.0, 0, 100.0};
        };
        return new VehicleRoutingProfile(
                costing,
                decimalOr(vehicle.getHeightMeters(), conservative[0]),
                decimalOr(vehicle.getWidthMeters(), conservative[1]),
                decimalOr(vehicle.getLengthMeters(), conservative[2]),
                decimalOr(vehicle.getGrossWeightTons(), conservative[3]),
                decimalOr(vehicle.getAxleLoadTons(), conservative[4]),
                integerOr(vehicle.getAxleCount(), (int) conservative[5]),
                decimalOr(vehicle.getTopSpeedKph(), conservative[6]),
                vehicle.isHazardousGoods()
        );
    }

    private Double decimalOr(BigDecimal value, double fallback) {
        if (value != null) return value.doubleValue();
        return fallback > 0 ? fallback : null;
    }

    private Integer integerOr(Integer value, int fallback) {
        if (value != null) return value;
        return fallback > 0 ? fallback : null;
    }

    private String hazardLabel(FloodReport report) {
        return report.getHazardType() == RoadHazardType.TRAFFIC_JAM ? "KẸT_XE" : "NGẬP";
    }

    private List<GeoPoint> routingAvoidancePoints(FloodReport flood) {
        FloodGeometryType type = flood.getGeometryType() == null
                ? FloodGeometryType.POINT
                : flood.getGeometryType();
        List<GeoPoint> geometry = hazardGeometry(flood);
        if (type == FloodGeometryType.SEGMENT) {
            return sampledHazardPoints(flood, 75);
        }
        if (type == FloodGeometryType.POLYGON) {
            List<GeoPoint> points = new ArrayList<>(sampledHazardPoints(flood, 80));
            double latitude = geometry.stream().mapToDouble(GeoPoint::lat).average().orElse(flood.getLat());
            double longitude = geometry.stream().mapToDouble(GeoPoint::lng).average().orElse(flood.getLng());
            points.add(new GeoPoint(latitude, longitude));
            return points;
        }

        GeoPoint center = geometry.getFirst();
        double radius = Math.max(30.0, Math.min(200.0,
                flood.getRadiusMeters() == null ? 120.0 : flood.getRadiusMeters()));
        double latitudeOffset = radius * 0.7 / 111_320.0;
        double longitudeOffset = radius * 0.7
                / (111_320.0 * Math.max(0.2, Math.cos(Math.toRadians(center.lat()))));
        return List.of(
                center,
                new GeoPoint(center.lat() + latitudeOffset, center.lng()),
                new GeoPoint(center.lat() - latitudeOffset, center.lng()),
                new GeoPoint(center.lat(), center.lng() + longitudeOffset),
                new GeoPoint(center.lat(), center.lng() - longitudeOffset)
        );
    }

    private List<List<GeoPoint>> detourWaypointSets(ProviderRoute route, List<FloodReport> floods) {
        List<FloodReport> blockers = floods.stream()
                .filter(this::isHardClosure)
                .filter(flood -> hazardDistanceToRoute(flood, route.geometry()) <= HARD_CLOSURE_BUFFER_METERS)
                .sorted(Comparator.comparingInt(flood -> nearestRouteSegment(flood, route.geometry())))
                .limit(MAX_DETOUR_HAZARDS)
                .toList();
        if (blockers.isEmpty()) {
            return List.of();
        }

        List<List<GeoPoint>> pairs = blockers.stream()
                .map(flood -> detourWaypoints(route, flood))
                .filter(points -> points.size() == 2)
                .toList();
        if (pairs.isEmpty()) {
            return List.of();
        }

        List<List<GeoPoint>> result = new ArrayList<>();
        // Try going consistently along either side of all successive closures.
        result.add(pairs.stream().map(points -> points.get(0)).toList());
        result.add(pairs.stream().map(points -> points.get(1)).toList());
        // Also try a local detour around each closure; useful when the provider
        // cannot accept several intermediate waypoints as one route.
        for (List<GeoPoint> pair : pairs) {
            result.add(List.of(pair.get(0)));
            result.add(List.of(pair.get(1)));
        }
        return result.stream().distinct().toList();
    }

    private int nearestRouteSegment(FloodReport danger, List<GeoPoint> route) {
        GeoPoint center = hazardCenter(danger);
        int nearestIndex = 0;
        double nearestDistance = Double.MAX_VALUE;
        for (int index = 1; index < route.size(); index++) {
            double distance = distanceToSegmentMeters(center, route.get(index - 1), route.get(index));
            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearestIndex = index - 1;
            }
        }
        return nearestIndex;
    }

    private List<GeoPoint> detourWaypoints(ProviderRoute route, FloodReport danger) {
        List<GeoPoint> geometry = route.geometry();
        if (geometry.size() < 2) {
            return List.of();
        }
        GeoPoint flood = hazardCenter(danger);
        int nearestIndex = nearestRouteSegment(danger, geometry);
        GeoPoint first = geometry.get(nearestIndex);
        GeoPoint second = geometry.get(nearestIndex + 1);
        double dLat = second.lat() - first.lat();
        double dLng = second.lng() - first.lng();
        double norm = Math.max(0.000001, Math.sqrt(dLat * dLat + dLng * dLng));
        double hazardRadius = danger.getRadiusMeters() == null ? 120.0 : danger.getRadiusMeters();
        double offsetMeters = Math.max(500.0, Math.min(1_500.0, hazardRadius + 350.0));
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

    private double hazardDistanceToRoute(FloodReport flood, List<GeoPoint> route) {
        if (route == null || route.size() < 2) {
            return Double.MAX_VALUE;
        }
        FloodGeometryType type = flood.getGeometryType() == null
                ? FloodGeometryType.POINT
                : flood.getGeometryType();
        List<GeoPoint> geometry = hazardGeometry(flood);
        double distance;
        if (type == FloodGeometryType.POINT || geometry.size() == 1) {
            distance = distanceToPolylineMeters(geometry.getFirst(), route);
        } else {
            if (type == FloodGeometryType.POLYGON
                    && route.stream().anyMatch(point -> pointInPolygon(point, geometry))) {
                distance = 0;
            } else {
                distance = distanceBetweenPolylinesMeters(route, geometry);
            }
        }
        double radius = flood.getRadiusMeters() == null ? 120.0 : flood.getRadiusMeters();
        return Math.max(0, distance - radius);
    }

    private GeoPoint hazardCenter(FloodReport flood) {
        List<GeoPoint> geometry = hazardGeometry(flood);
        return new GeoPoint(
                geometry.stream().mapToDouble(GeoPoint::lat).average().orElse(flood.getLat()),
                geometry.stream().mapToDouble(GeoPoint::lng).average().orElse(flood.getLng())
        );
    }

    private List<GeoPoint> sampledHazardPoints(FloodReport flood, double spacingMeters) {
        List<GeoPoint> geometry = hazardGeometry(flood);
        if (geometry.size() < 2) return geometry;
        List<GeoPoint> sampled = new ArrayList<>();
        sampled.add(geometry.getFirst());
        for (int index = 1; index < geometry.size(); index++) {
            GeoPoint start = geometry.get(index - 1);
            GeoPoint end = geometry.get(index);
            double length = haversineMeters(start, end);
            int segments = Math.max(1, (int) Math.ceil(length / spacingMeters));
            for (int step = 1; step <= segments; step++) {
                double ratio = step / (double) segments;
                sampled.add(new GeoPoint(
                        start.lat() + (end.lat() - start.lat()) * ratio,
                        start.lng() + (end.lng() - start.lng()) * ratio
                ));
            }
        }
        return sampled;
    }

    private List<GeoPoint> hazardGeometry(FloodReport flood) {
        if (flood.getGeometryType() == null
                || flood.getGeometryType() == FloodGeometryType.POINT
                || flood.getGeometryJson() == null
                || flood.getGeometryJson().isBlank()) {
            return List.of(new GeoPoint(flood.getLat(), flood.getLng()));
        }
        try {
            List<GeoPoint> points = objectMapper.readValue(
                    flood.getGeometryJson(),
                    new TypeReference<List<GeoPoint>>() {
                    }
            );
            return points == null || points.isEmpty()
                    ? List.of(new GeoPoint(flood.getLat(), flood.getLng()))
                    : points;
        } catch (JsonProcessingException exception) {
            return List.of(new GeoPoint(flood.getLat(), flood.getLng()));
        }
    }

    private boolean pointInPolygon(GeoPoint point, List<GeoPoint> polygon) {
        if (polygon.size() < 3) return false;
        boolean inside = false;
        for (int current = 0, previous = polygon.size() - 1;
             current < polygon.size();
             previous = current++) {
            GeoPoint first = polygon.get(current);
            GeoPoint second = polygon.get(previous);
            boolean crosses = (first.lat() > point.lat()) != (second.lat() > point.lat())
                    && point.lng() < (second.lng() - first.lng())
                    * (point.lat() - first.lat())
                    / (second.lat() - first.lat() + 1e-12)
                    + first.lng();
            if (crosses) inside = !inside;
        }
        return inside;
    }

    private double haversineMeters(GeoPoint first, GeoPoint second) {
        double dLat = Math.toRadians(second.lat() - first.lat());
        double dLng = Math.toRadians(second.lng() - first.lng());
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(first.lat())) * Math.cos(Math.toRadians(second.lat()))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 6_371_000.0 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
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

    private double distanceBetweenPolylinesMeters(List<GeoPoint> first, List<GeoPoint> second) {
        if (first == null || second == null || first.size() < 2 || second.size() < 2) {
            return Double.MAX_VALUE;
        }
        double distance = Double.MAX_VALUE;
        for (int firstIndex = 1; firstIndex < first.size(); firstIndex++) {
            GeoPoint firstStart = first.get(firstIndex - 1);
            GeoPoint firstEnd = first.get(firstIndex);
            for (int secondIndex = 1; secondIndex < second.size(); secondIndex++) {
                GeoPoint secondStart = second.get(secondIndex - 1);
                GeoPoint secondEnd = second.get(secondIndex);
                if (segmentsIntersect(firstStart, firstEnd, secondStart, secondEnd)) {
                    return 0;
                }
                distance = Math.min(distance, distanceToSegmentMeters(firstStart, secondStart, secondEnd));
                distance = Math.min(distance, distanceToSegmentMeters(firstEnd, secondStart, secondEnd));
                distance = Math.min(distance, distanceToSegmentMeters(secondStart, firstStart, firstEnd));
                distance = Math.min(distance, distanceToSegmentMeters(secondEnd, firstStart, firstEnd));
            }
        }
        return distance;
    }

    private boolean segmentsIntersect(GeoPoint firstStart,
                                      GeoPoint firstEnd,
                                      GeoPoint secondStart,
                                      GeoPoint secondEnd) {
        double firstOrientation = orientation(firstStart, firstEnd, secondStart);
        double secondOrientation = orientation(firstStart, firstEnd, secondEnd);
        double thirdOrientation = orientation(secondStart, secondEnd, firstStart);
        double fourthOrientation = orientation(secondStart, secondEnd, firstEnd);
        double epsilon = 1e-12;
        if (((firstOrientation > epsilon && secondOrientation < -epsilon)
                || (firstOrientation < -epsilon && secondOrientation > epsilon))
                && ((thirdOrientation > epsilon && fourthOrientation < -epsilon)
                || (thirdOrientation < -epsilon && fourthOrientation > epsilon))) {
            return true;
        }
        return Math.abs(firstOrientation) <= epsilon && onSegment(firstStart, secondStart, firstEnd)
                || Math.abs(secondOrientation) <= epsilon && onSegment(firstStart, secondEnd, firstEnd)
                || Math.abs(thirdOrientation) <= epsilon && onSegment(secondStart, firstStart, secondEnd)
                || Math.abs(fourthOrientation) <= epsilon && onSegment(secondStart, firstEnd, secondEnd);
    }

    private double orientation(GeoPoint start, GeoPoint end, GeoPoint point) {
        return (end.lng() - start.lng()) * (point.lat() - start.lat())
                - (end.lat() - start.lat()) * (point.lng() - start.lng());
    }

    private boolean onSegment(GeoPoint start, GeoPoint point, GeoPoint end) {
        double epsilon = 1e-12;
        return point.lat() >= Math.min(start.lat(), end.lat()) - epsilon
                && point.lat() <= Math.max(start.lat(), end.lat()) + epsilon
                && point.lng() >= Math.min(start.lng(), end.lng()) - epsilon
                && point.lng() <= Math.max(start.lng(), end.lng()) + epsilon;
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
                step.maneuver().name(),
                step.maneuverType(),
                step.modifier(),
                step.beginShapeIndex(),
                step.roundaboutExitCount(),
                step.exitNumber(),
                step.toward(),
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
