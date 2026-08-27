package com.safefleet.navigation;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.flood.entity.FloodReport;
import com.safefleet.flood.enums.FloodGeometryType;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.enums.FloodStatus;
import com.safefleet.flood.enums.RoadHazardType;
import com.safefleet.flood.repository.FloodReportRepository;
import com.safefleet.navigation.provider.RoutingProvider;
import com.safefleet.navigation.provider.RoutingProvider.GeoPoint;
import com.safefleet.navigation.provider.RoutingProvider.ProviderRoute;
import com.safefleet.navigation.provider.RoutingProvider.RoutingExclusions;
import com.safefleet.navigation.provider.RoutingProvider.VehicleRoutingProfile;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.VehicleType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class NavigationServiceSafetyTest {

    private RoutingProvider routingProvider;
    private FloodReportRepository floodReportRepository;
    private JdbcTemplate jdbcTemplate;
    private NavigationService navigationService;

    @BeforeEach
    void setUp() {
        routingProvider = mock(RoutingProvider.class);
        floodReportRepository = mock(FloodReportRepository.class);
        jdbcTemplate = mock(JdbcTemplate.class);
        navigationService = new NavigationService(
                routingProvider,
                floodReportRepository,
                mock(DriverRepository.class),
                mock(TripRepository.class),
                jdbcTemplate,
                new ObjectMapper()
        );
    }

    @Test
    void detectsRouteSegmentCrossingPolygonEvenWhenNoRouteVertexIsInside() {
        FloodReport polygon = hazard(FloodSeverity.BLOCKED, FloodGeometryType.POLYGON, 0);
        polygon.setGeometryJson("""
                [
                  {"lat":-0.001,"lng":-0.001},
                  {"lat": 0.001,"lng":-0.001},
                  {"lat": 0.001,"lng": 0.001},
                  {"lat":-0.001,"lng": 0.001},
                  {"lat":-0.001,"lng":-0.001}
                ]
                """);

        Double clearance = ReflectionTestUtils.invokeMethod(
                navigationService,
                "hazardDistanceToRoute",
                polygon,
                List.of(new GeoPoint(0, -0.01), new GeoPoint(0, 0.01))
        );

        assertThat(clearance).isZero();
    }

    @Test
    void nearbyBlockedPointAddsRiskButDoesNotFalselyBlockTheRoute() throws Exception {
        FloodReport nearby = hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT, 0);
        nearby.setLat(0.0015); // about 167 m from the route
        ProviderRoute route = route(List.of(new GeoPoint(0, -0.01), new GeoPoint(0, 0.01)));

        Object scored = ReflectionTestUtils.invokeMethod(
                navigationService,
                "score",
                route,
                List.of(nearby),
                new Driver()
        );
        var blockedAccessor = scored.getClass().getDeclaredMethod("blocked");
        blockedAccessor.setAccessible(true);

        assertThat((Boolean) blockedAccessor.invoke(scored)).isFalse();
    }

    @Test
    void refusesToPersistOrReturnAnyRouteThatStillCrossesAClosure() {
        FloodReport blocked = hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT, 80);
        ProviderRoute crossing = route(List.of(new GeoPoint(0, -0.01), new GeoPoint(0, 0.01)));
        when(floodReportRepository.findByStatusIn(anyList())).thenReturn(List.of(blocked));
        when(routingProvider.routes(anyList(), anyBoolean(), any(RoutingExclusions.class),
                any(VehicleRoutingProfile.class)))
                .thenReturn(List.of(crossing));

        NavigationRouteRequest request = new NavigationRouteRequest(
                0.0, -0.01, 0.0, 0.01, "Đích kiểm thử", null
        );

        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                navigationService,
                "computeAndPersist",
                1L,
                new Driver(),
                request
        ))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("Chưa tìm thấy tuyến an toàn");
    }

    @Test
    void detectsANewHardClosureOnTheRemainingSelectedRoute() {
        FloodReport blockedAhead = hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT, 80);
        when(floodReportRepository.findByStatusIn(anyList())).thenReturn(List.of(blockedAhead));
        when(jdbcTemplate.queryForList(anyString(), eq(String.class), eq(1L)))
                .thenReturn(List.of("[[-0.01,0.0],[0.0,0.0],[0.01,0.0]]"));

        NavigationHazardAheadResponse ahead = ReflectionTestUtils.invokeMethod(
                navigationService,
                "hazardAhead",
                1L,
                0.0,
                -0.005
        );

        assertThat(ahead).isNotNull();
        assertThat(ahead.blocking()).isTrue();
        assertThat(ahead.distanceAlongRouteMeters()).isPositive();
    }

    @Test
    void buildsATightCorridorAroundAReportedFloodedStretch() {
        List<GeoPoint> corridor = ReflectionTestUtils.invokeMethod(
                navigationService,
                "corridorPolygon",
                List.of(new GeoPoint(0, 0), new GeoPoint(0, 0.001)),
                25.0
        );

        assertThat(corridor).isNotNull();
        assertThat(corridor).hasSizeGreaterThanOrEqualTo(4);
        assertThat(corridor.getFirst()).isEqualTo(corridor.getLast());
        // The corridor straddles the reported centre line, so a router that
        // honours exclude_polygons drops the flooded street itself.
        assertThat(corridor.stream().mapToDouble(GeoPoint::lat).max().orElseThrow())
                .isGreaterThan(0);
        assertThat(corridor.stream().mapToDouble(GeoPoint::lat).min().orElseThrow())
                .isLessThan(0);
        // ... while staying narrow enough to leave a parallel street routable.
        assertThat(corridor.stream().mapToDouble(GeoPoint::lat).max().orElseThrow())
                .isLessThan(40.0 / 111_320.0);
    }

    @Test
    void trafficJamOnlyForcesDetourWhenDriverMarksRoadBlocked() {
        FloodReport slowTraffic = hazard(FloodSeverity.HIGH, FloodGeometryType.POINT, 80);
        slowTraffic.setHazardType(RoadHazardType.TRAFFIC_JAM);
        FloodReport blockedTraffic = hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT, 80);
        blockedTraffic.setHazardType(RoadHazardType.TRAFFIC_JAM);

        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", slowTraffic
        )).isFalse();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", blockedTraffic
        )).isTrue();
        assertThat((String) ReflectionTestUtils.invokeMethod(
                navigationService, "hazardLabel", blockedTraffic
        )).isEqualTo("KẸT_XE");
    }

    @Test
    void unverifiedBlockedReportStopsTrafficImmediatelyButNotIndefinitely() {
        FloodReport report = hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT, 80);

        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", report
        )).isTrue();

        report.setCreatedAt(LocalDateTime.now().minusMinutes(31));
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", report
        )).isFalse();

        report.setStatus(FloodStatus.VERIFIED);
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", report
        )).isTrue();
    }

    @Test
    void incompleteBusProfileUsesSafeDefaultsWithoutUnboxingNullAxleCount() {
        Vehicle bus = new Vehicle();
        bus.setVehicleType(VehicleType.BUS);

        VehicleRoutingProfile profile = ReflectionTestUtils.invokeMethod(
                navigationService, "routingProfile", bus
        );

        assertThat(profile).isNotNull();
        assertThat(profile.costing()).isEqualTo("bus");
        assertThat(profile.heightMeters()).isEqualTo(4.2);
        assertThat(profile.axleCount()).isNull();
    }

    private FloodReport hazard(FloodSeverity severity,
                               FloodGeometryType geometryType,
                               double radiusMeters) {
        FloodReport report = new FloodReport();
        report.setLat(0.0);
        report.setLng(0.0);
        report.setHazardType(RoadHazardType.FLOOD);
        report.setSeverity(severity);
        report.setSource(FloodSource.DRIVER_REPORT);
        report.setGeometryType(geometryType);
        report.setRadiusMeters(radiusMeters);
        report.setConfidence(0.45);
        report.setStatus(FloodStatus.UNVERIFIED);
        report.setCreatedAt(LocalDateTime.now());
        report.setExpiredAt(LocalDateTime.now().plusHours(1));
        return report;
    }

    private ProviderRoute route(List<GeoPoint> geometry) {
        return new ProviderRoute(2_000, 240, geometry, List.of(), "TEST", false);
    }
}
