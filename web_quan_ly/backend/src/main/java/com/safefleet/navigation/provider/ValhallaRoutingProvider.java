package com.safefleet.navigation.provider;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Primary road-graph provider for SafeFleet production routing.
 *
 * <p>Valhalla is self-hosted and receives active flood closures as
 * {@code avoid_locations}. If it is not configured or unavailable, routing
 * falls back to OSRM road geometry. Neither provider is allowed to return the
 * deterministic straight-line geometry used by isolated tests.</p>
 */
@Service
@Primary
@RequiredArgsConstructor
@Slf4j
public class ValhallaRoutingProvider implements RoutingProvider {

    private static final double EXCLUSION_ENDPOINT_GUARD_METERS = 100.0;

    private final ObjectMapper objectMapper;
    private final OsrmRoutingProvider fallbackProvider;

    @Value("${app.location.valhalla-url:}")
    private String valhallaUrl;

    @Value("${app.location.valhalla-costing:truck}")
    private String costing;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();

    @Override
    public List<ProviderRoute> routes(List<GeoPoint> points, boolean alternatives) {
        return routes(points, alternatives, List.of());
    }

    @Override
    public List<ProviderRoute> routes(List<GeoPoint> points,
                                      boolean alternatives,
                                      List<GeoPoint> excludedLocations) {
        return routes(points, alternatives, new RoutingExclusions(excludedLocations, List.of()));
    }

    @Override
    public List<ProviderRoute> routes(List<GeoPoint> points,
                                      boolean alternatives,
                                      RoutingExclusions exclusions) {
        return routes(points, alternatives, exclusions, VehicleRoutingProfile.conservativeTruck());
    }

    @Override
    public List<ProviderRoute> routes(List<GeoPoint> points,
                                      boolean alternatives,
                                      RoutingExclusions exclusions,
                                      VehicleRoutingProfile profile) {
        if (points == null || points.size() < 2) return List.of();
        RoutingExclusions safeExclusions = exclusions == null
                ? RoutingExclusions.empty()
                : exclusions;
        if (valhallaUrl == null || valhallaUrl.isBlank()) {
            return fallbackRoutes(points, alternatives);
        }
        try {
            HttpRequest request = HttpRequest.newBuilder(routeUri())
                    .timeout(Duration.ofSeconds(12))
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json")
                    .header("User-Agent", "SafeFleet/1.0")
                    .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(
                            requestBody(points, alternatives, safeExclusions, profile)
                    )))
                    .build();
            HttpResponse<String> response = httpClient.send(
                    request,
                    HttpResponse.BodyHandlers.ofString()
            );
            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                List<ProviderRoute> parsed = parseRoutes(response.body(), points);
                if (!parsed.isEmpty()) return parsed;
            }
            log.warn("Valhalla returned HTTP {}; using degraded OSRM routing", response.statusCode());
        } catch (Exception exception) {
            log.warn("Valhalla unavailable ({}); using degraded OSRM routing",
                    exception.getClass().getSimpleName());
        }
        return fallbackRoutes(points, alternatives);
    }

    private URI routeUri() {
        String base = valhallaUrl.trim().replaceAll("/+$", "");
        return URI.create(base.endsWith("/route") ? base : base + "/route");
    }

    private Map<String, Object> requestBody(List<GeoPoint> points,
                                            boolean alternatives,
                                            RoutingExclusions routingExclusions,
                                            VehicleRoutingProfile profile) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("locations", points.stream()
                .map(point -> Map.of("lat", point.lat(), "lon", point.lng()))
                .toList());
        String selectedCosting = profile == null || profile.costing() == null
                ? (costing == null || costing.isBlank() ? "truck" : costing.trim())
                : profile.costing();
        body.put("costing", selectedCosting);
        Map<String, Object> vehicleOptions = vehicleCostingOptions(selectedCosting, profile);
        if (!vehicleOptions.isEmpty()) {
            body.put("costing_options", Map.of(selectedCosting, vehicleOptions));
        }
        body.put("units", "kilometers");
        // Valhalla does not currently ship Vietnamese narrative strings. Request a
        // stable supported locale and localize maneuvers from their numeric type.
        body.put("language", "en-US");
        body.put("directions_type", "instructions");
        body.put("shape_format", "polyline6");
        if (alternatives) body.put("alternates", 2);

        GeoPoint origin = points.getFirst();
        GeoPoint destination = points.getLast();
        List<Map<String, Double>> exclusions = routingExclusions.locations().stream()
                .filter(point -> distanceMeters(point, origin) > EXCLUSION_ENDPOINT_GUARD_METERS)
                .filter(point -> distanceMeters(point, destination) > EXCLUSION_ENDPOINT_GUARD_METERS)
                .distinct()
                .map(point -> Map.of("lat", point.lat(), "lon", point.lng()))
                .toList();
        if (!exclusions.isEmpty()) body.put("exclude_locations", exclusions);
        List<List<List<Double>>> polygons = routingExclusions.polygons().stream()
                .filter(polygon -> polygon.size() >= 4)
                .filter(polygon -> !pointInPolygon(origin, polygon))
                .filter(polygon -> !pointInPolygon(destination, polygon))
                .map(polygon -> polygon.stream()
                        // Valhalla follows GeoJSON coordinate order for polygon rings.
                        .map(point -> List.of(point.lng(), point.lat()))
                        .toList())
                .toList();
        if (!polygons.isEmpty()) body.put("exclude_polygons", polygons);
        return body;
    }

    private Map<String, Object> vehicleCostingOptions(String selectedCosting,
                                                       VehicleRoutingProfile profile) {
        if (profile == null) return Map.of();
        Map<String, Object> options = new LinkedHashMap<>();
        boolean dimensionAware = "auto".equalsIgnoreCase(selectedCosting)
                || "bus".equalsIgnoreCase(selectedCosting)
                || "truck".equalsIgnoreCase(selectedCosting);
        if (dimensionAware) {
            putPositive(options, "height", profile.heightMeters());
            putPositive(options, "width", profile.widthMeters());
            putPositive(options, "length", profile.lengthMeters());
            putPositive(options, "weight", profile.grossWeightTons());
        }
        putPositive(options, "top_speed", profile.topSpeedKph());
        if ("truck".equalsIgnoreCase(selectedCosting)) {
            putPositive(options, "axle_load", profile.axleLoadTons());
            if (profile.axleCount() != null && profile.axleCount() > 0) {
                options.put("axle_count", profile.axleCount());
            }
            if (profile.hazardousGoods()) options.put("hazmat", true);
            // Prefer designated HGV roads without making sparse OSM tagging in
            // Vietnam an absolute requirement.
            options.put("use_truck_route", 0.3);
        }
        return options;
    }

    private void putPositive(Map<String, Object> target, String key, Double value) {
        if (value != null && value > 0) target.put(key, value);
    }

    private List<ProviderRoute> fallbackRoutes(List<GeoPoint> points, boolean alternatives) {
        return fallbackProvider.routes(points, alternatives).stream()
                .map(route -> new ProviderRoute(
                        route.distanceMeters(),
                        route.durationSeconds(),
                        route.geometry(),
                        route.steps(),
                        route.provider(),
                        true,
                        route.navigationWaypoints()
                ))
                .toList();
    }

    private boolean pointInPolygon(GeoPoint point, List<GeoPoint> polygon) {
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

    private List<ProviderRoute> parseRoutes(String responseBody,
                                            List<GeoPoint> requestedPoints) throws Exception {
        JsonNode root = objectMapper.readTree(responseBody);
        List<JsonNode> trips = new ArrayList<>();
        if (root.path("trip").isObject()) trips.add(root.path("trip"));
        if (root.path("alternates").isArray()) {
            for (JsonNode alternate : root.path("alternates")) {
                JsonNode trip = alternate.path("trip").isObject()
                        ? alternate.path("trip")
                        : alternate;
                if (trip.isObject()) trips.add(trip);
            }
        }

        List<GeoPoint> navigationWaypoints = requestedPoints.size() <= 2
                ? List.of()
                : List.copyOf(requestedPoints.subList(1, requestedPoints.size() - 1));
        List<ProviderRoute> result = new ArrayList<>();
        for (JsonNode trip : trips) {
            List<GeoPoint> geometry = new ArrayList<>();
            List<TurnStep> steps = new ArrayList<>();
            for (JsonNode leg : trip.path("legs")) {
                List<GeoPoint> legGeometry = decodePolyline6(leg.path("shape").asText(""));
                int offset = geometry.size();
                if (!geometry.isEmpty() && !legGeometry.isEmpty()
                        && geometry.getLast().equals(legGeometry.getFirst())) {
                    geometry.addAll(legGeometry.subList(1, legGeometry.size()));
                    offset -= 1;
                } else {
                    geometry.addAll(legGeometry);
                }
                for (JsonNode maneuver : leg.path("maneuvers")) {
                    int shapeIndex = clampIndex(
                            maneuver.path("begin_shape_index").asInt(0) + offset,
                            geometry.size()
                    );
                    GeoPoint location = geometry.isEmpty()
                            ? requestedPoints.getFirst()
                            : geometry.get(shapeIndex);
                    String streetName = firstStreetName(maneuver);
                    ManeuverType type = ManeuverType.fromValhalla(maneuver.path("type").asInt(-1));
                    Integer roundaboutExit = maneuver.has("roundabout_exit_count")
                            ? maneuver.path("roundabout_exit_count").asInt()
                            : null;
                    String exitNumber = signText(maneuver, "exit_number_elements");
                    String toward = signText(maneuver, "exit_toward_elements");
                    steps.add(new TurnStep(
                            ManeuverNarrator.describe(type, streetName, roundaboutExit, exitNumber, toward),
                            streetName,
                            maneuver.path("length").asDouble(0) * 1_000.0,
                            maneuver.path("time").asDouble(0),
                            type,
                            location,
                            shapeIndex,
                            roundaboutExit,
                            exitNumber,
                            toward
                    ));
                }
            }
            if (geometry.size() < 2) continue;
            JsonNode summary = trip.path("summary");
            result.add(new ProviderRoute(
                    summary.path("length").asDouble(0) * 1_000.0,
                    summary.path("time").asDouble(0),
                    List.copyOf(geometry),
                    List.copyOf(steps),
                    "VALHALLA",
                    false,
                    navigationWaypoints
            ));
        }
        return result;
    }

    private String firstStreetName(JsonNode maneuver) {
        JsonNode names = maneuver.path("street_names");
        if (names.isArray() && !names.isEmpty()) {
            return names.get(0).asText("");
        }
        JsonNode beginNames = maneuver.path("begin_street_names");
        return beginNames.isArray() && !beginNames.isEmpty() ? beginNames.get(0).asText("") : "";
    }

    private String signText(JsonNode maneuver, String elementName) {
        JsonNode elements = maneuver.path("sign").path(elementName);
        if (!elements.isArray() || elements.isEmpty()) {
            return null;
        }
        String text = elements.get(0).path("text").asText("");
        return text.isBlank() ? null : text;
    }

    private int clampIndex(int index, int size) {
        if (size <= 0) {
            return 0;
        }
        return Math.max(0, Math.min(index, size - 1));
    }

    private List<GeoPoint> decodePolyline6(String encoded) {
        List<GeoPoint> points = new ArrayList<>();
        int index = 0;
        long latitude = 0;
        long longitude = 0;
        while (index < encoded.length()) {
            DecodeResult lat = decode(encoded, index);
            if (lat == null) break;
            index = lat.nextIndex();
            DecodeResult lon = decode(encoded, index);
            if (lon == null) break;
            index = lon.nextIndex();
            latitude += lat.value();
            longitude += lon.value();
            points.add(new GeoPoint(latitude / 1_000_000.0, longitude / 1_000_000.0));
        }
        return points;
    }

    private DecodeResult decode(String encoded, int start) {
        long result = 0;
        int shift = 0;
        int index = start;
        int value;
        do {
            if (index >= encoded.length()) return null;
            value = encoded.charAt(index++) - 63;
            result |= (long) (value & 0x1f) << shift;
            shift += 5;
        } while (value >= 0x20);
        long decoded = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
        return new DecodeResult(decoded, index);
    }

    private double distanceMeters(GeoPoint first, GeoPoint second) {
        double dLat = Math.toRadians(second.lat() - first.lat());
        double dLng = Math.toRadians(second.lng() - first.lng());
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(first.lat())) * Math.cos(Math.toRadians(second.lat()))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 6_371_000.0 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private record DecodeResult(long value, int nextIndex) {
    }
}
