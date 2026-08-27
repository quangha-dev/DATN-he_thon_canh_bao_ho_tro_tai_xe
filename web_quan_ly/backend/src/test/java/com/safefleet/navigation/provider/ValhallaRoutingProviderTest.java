package com.safefleet.navigation.provider;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.safefleet.navigation.provider.RoutingProvider.GeoPoint;
import com.safefleet.navigation.provider.RoutingProvider.ProviderRoute;
import com.safefleet.navigation.provider.RoutingProvider.RoutingExclusions;
import com.safefleet.navigation.provider.RoutingProvider.VehicleRoutingProfile;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ValhallaRoutingProviderTest {

    private HttpServer server;

    @AfterEach
    void stopServer() {
        if (server != null) {
            server.stop(0);
        }
    }

    @Test
    void sendsFloodPointsAndPolygonsAsDynamicAvoidances() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/route", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            exchange.sendResponseHeaders(400, 0);
            exchange.close();
        });
        server.start();

        ObjectMapper objectMapper = new ObjectMapper();
        ValhallaRoutingProvider provider = new ValhallaRoutingProvider(
                objectMapper,
                mock(OsrmRoutingProvider.class)
        );
        ReflectionTestUtils.setField(
                provider,
                "valhallaUrl",
                "http://127.0.0.1:" + server.getAddress().getPort()
        );
        ReflectionTestUtils.setField(provider, "costing", "truck");

        List<GeoPoint> routePoints = List.of(
                new GeoPoint(21.0285, 105.8542),
                new GeoPoint(21.0410, 105.8080)
        );
        RoutingExclusions exclusions = new RoutingExclusions(
                List.of(new GeoPoint(21.0300, 105.8400)),
                List.of(List.of(
                        new GeoPoint(21.0320, 105.8300),
                        new GeoPoint(21.0330, 105.8300),
                        new GeoPoint(21.0330, 105.8310),
                        new GeoPoint(21.0320, 105.8300)
                ))
        );

        provider.routes(routePoints, true, exclusions);

        JsonNode body = objectMapper.readTree(requestBody.get());
        assertThat(body.path("costing").asText()).isEqualTo("truck");
        assertThat(body.path("language").asText()).isEqualTo("en-US");
        assertThat(body.path("alternates").asInt()).isEqualTo(2);
        assertThat(body.path("exclude_locations")).hasSize(1);
        assertThat(body.path("exclude_locations").get(0).path("lat").asDouble()).isEqualTo(21.0300);
        assertThat(body.path("exclude_polygons")).hasSize(1);
        assertThat(body.path("exclude_polygons").get(0)).hasSize(4);
        assertThat(body.path("exclude_polygons").get(0).get(0).get(0).asDouble())
                .as("polygon coordinate order must be longitude, latitude")
                .isEqualTo(105.8300);
        assertThat(body.path("exclude_polygons").get(0).get(0).get(1).asDouble())
                .isEqualTo(21.0320);
    }

    @Test
    void marksOsrmResultAsDegradedWhenValhallaIsUnavailable() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/route", exchange -> {
            exchange.sendResponseHeaders(503, 0);
            exchange.close();
        });
        server.start();

        OsrmRoutingProvider osrm = mock(OsrmRoutingProvider.class);
        List<GeoPoint> points = List.of(
                new GeoPoint(21.0285, 105.8542),
                new GeoPoint(21.0410, 105.8080)
        );
        ProviderRoute osrmRoute = new ProviderRoute(5_000, 600, points, List.of(), "OSRM", false);
        when(osrm.routes(points, true)).thenReturn(List.of(osrmRoute));
        ValhallaRoutingProvider provider = new ValhallaRoutingProvider(new ObjectMapper(), osrm);
        ReflectionTestUtils.setField(
                provider,
                "valhallaUrl",
                "http://127.0.0.1:" + server.getAddress().getPort()
        );

        List<ProviderRoute> routes = provider.routes(points, true, RoutingExclusions.empty());

        assertThat(routes).singleElement().satisfies(route -> {
            assertThat(route.provider()).isEqualTo("OSRM");
            assertThat(route.fallback()).isTrue();
        });
    }

    @Test
    void sendsAssignedTruckDimensionsAndLegalLimitsToValhalla() throws Exception {
        AtomicReference<String> requestBody = new AtomicReference<>();
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/route", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            exchange.sendResponseHeaders(400, 0);
            exchange.close();
        });
        server.start();

        ObjectMapper mapper = new ObjectMapper();
        ValhallaRoutingProvider provider = new ValhallaRoutingProvider(
                mapper, mock(OsrmRoutingProvider.class)
        );
        ReflectionTestUtils.setField(provider, "valhallaUrl",
                "http://127.0.0.1:" + server.getAddress().getPort());
        List<GeoPoint> points = List.of(
                new GeoPoint(21.0285, 105.8542),
                new GeoPoint(21.0410, 105.8080)
        );
        VehicleRoutingProfile profile = new VehicleRoutingProfile(
                "truck", 3.8, 2.5, 12.0, 24.0, 9.0, 4, 80.0, true
        );

        provider.routes(points, false, RoutingExclusions.empty(), profile);

        JsonNode options = mapper.readTree(requestBody.get())
                .path("costing_options").path("truck");
        assertThat(options.path("height").asDouble()).isEqualTo(3.8);
        assertThat(options.path("width").asDouble()).isEqualTo(2.5);
        assertThat(options.path("length").asDouble()).isEqualTo(12.0);
        assertThat(options.path("weight").asDouble()).isEqualTo(24.0);
        assertThat(options.path("axle_load").asDouble()).isEqualTo(9.0);
        assertThat(options.path("axle_count").asInt()).isEqualTo(4);
        assertThat(options.path("top_speed").asDouble()).isEqualTo(80.0);
        assertThat(options.path("hazmat").asBoolean()).isTrue();
    }

    @Test
    void mapsValhallaManeuverCodesOntoTheSharedTurnTaxonomy() {
        assertThat(ManeuverType.fromValhalla(13)).isEqualTo(ManeuverType.UTURN_LEFT);
        assertThat(ManeuverType.fromValhalla(15)).isEqualTo(ManeuverType.TURN_LEFT);
        assertThat(ManeuverType.fromValhalla(16)).isEqualTo(ManeuverType.TURN_SLIGHT_LEFT);
        assertThat(ManeuverType.fromValhalla(10)).isEqualTo(ManeuverType.TURN_RIGHT);
        assertThat(ManeuverType.fromValhalla(26)).isEqualTo(ManeuverType.ROUNDABOUT_ENTER);
        assertThat(ManeuverType.fromValhalla(4)).isEqualTo(ManeuverType.ARRIVE);
        // Unknown and transit codes degrade to a straight-ahead arrow instead of
        // leaking a raw provider code the device cannot render.
        assertThat(ManeuverType.fromValhalla(33)).isEqualTo(ManeuverType.CONTINUE);

        assertThat(ManeuverType.TURN_LEFT.modifier()).isEqualTo("left");
        assertThat(ManeuverType.ROUNDABOUT_ENTER.modifier()).isEqualTo("roundabout");
        assertThat(ManeuverType.CONTINUE.isDirectionChange()).isFalse();
        assertThat(ManeuverType.TURN_RIGHT.isDirectionChange()).isTrue();
    }

    @Test
    void writesVietnameseInstructionsForEveryNormalisedManeuver() {
        assertThat(ManeuverNarrator.describe(ManeuverType.TURN_LEFT, "Phố Huế", null, null, null))
                .isEqualTo("Rẽ trái vào Phố Huế");
        assertThat(ManeuverNarrator.describe(ManeuverType.ROUNDABOUT_EXIT, "", null, null, null))
                .isEqualTo("Ra khỏi vòng xuyến");
        assertThat(ManeuverNarrator.describe(ManeuverType.ROUNDABOUT_ENTER, "", 3, null, null))
                .isEqualTo("Vào vòng xuyến, đi theo lối ra thứ 3");
        assertThat(ManeuverNarrator.describe(ManeuverType.EXIT_RIGHT, "", null, "5", "Hà Nội"))
                .isEqualTo("Đi theo lối ra bên phải số 5 hướng Hà Nội");
        assertThat(ManeuverNarrator.describe(ManeuverType.ARRIVE_LEFT, "", null, null, null))
                .isEqualTo("Điểm đến ở bên trái");
    }

    @Test
    void mapsOsrmTypeAndModifierPairsOntoTheSameTaxonomy() {
        assertThat(ManeuverType.fromOsrm("turn", "left")).isEqualTo(ManeuverType.TURN_LEFT);
        assertThat(ManeuverType.fromOsrm("turn", "slight right"))
                .isEqualTo(ManeuverType.TURN_SLIGHT_RIGHT);
        assertThat(ManeuverType.fromOsrm("end of road", "right")).isEqualTo(ManeuverType.TURN_RIGHT);
        assertThat(ManeuverType.fromOsrm("roundabout", "left"))
                .isEqualTo(ManeuverType.ROUNDABOUT_ENTER);
        assertThat(ManeuverType.fromOsrm("off ramp", "slight right")).isEqualTo(ManeuverType.EXIT_RIGHT);
        assertThat(ManeuverType.fromOsrm("fork", "slight left")).isEqualTo(ManeuverType.KEEP_LEFT);
        assertThat(ManeuverType.fromOsrm("arrive", "left")).isEqualTo(ManeuverType.ARRIVE_LEFT);
        assertThat(ManeuverType.fromOsrm("depart", "straight")).isEqualTo(ManeuverType.DEPART);
        // A plain name change is a straight continuation, not a turn.
        assertThat(ManeuverType.fromOsrm("new name", "straight")).isEqualTo(ManeuverType.CONTINUE);
    }
}
