package com.safefleet.navigation.provider;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class OsrmRoutingProvider implements RoutingProvider {

    private static final double FALLBACK_SPEED_KMH = 32.0;

    private final ObjectMapper objectMapper;

    @Value("${app.location.osrm-url:https://router.project-osrm.org/route/v1/driving}")
    private String osrmUrl;

    @Value("${app.location.allow-deterministic-fallback:false}")
    private boolean allowDeterministicFallback;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();

    @Override
    public List<ProviderRoute> routes(List<GeoPoint> points, boolean alternatives) {
        if (points == null || points.size() < 2) {
            return List.of();
        }
        try {
            String coordinates = points.stream()
                    .map(point -> String.format(Locale.US, "%.7f,%.7f", point.lng(), point.lat()))
                    .collect(Collectors.joining(";"));
            URI uri = UriComponentsBuilder.fromUriString(osrmUrl + "/" + coordinates)
                    .queryParam("alternatives", alternatives ? 3 : "false")
                    .queryParam("steps", true)
                    .queryParam("geometries", "geojson")
                    .queryParam("overview", "full")
                    .build()
                    .encode()
                    .toUri();
            HttpRequest request = HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofSeconds(8))
                    .header("User-Agent", "SafeFleet-DATN/1.0")
                    .GET()
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                List<ProviderRoute> parsed = parseRoutes(response.body());
                if (!parsed.isEmpty()) return parsed;
            }
        } catch (Exception ignored) {
            // The caller decides whether absence of a road-graph route is recoverable.
        }
        return allowDeterministicFallback ? fallbackRoutes(points, alternatives) : List.of();
    }

    private List<ProviderRoute> parseRoutes(String body) throws Exception {
        JsonNode routes = objectMapper.readTree(body).path("routes");
        if (!routes.isArray()) {
            return List.of();
        }
        List<ProviderRoute> result = new ArrayList<>();
        for (JsonNode route : routes) {
            List<GeoPoint> geometry = new ArrayList<>();
            for (JsonNode coordinate : route.path("geometry").path("coordinates")) {
                if (coordinate.isArray() && coordinate.size() >= 2) {
                    geometry.add(new GeoPoint(coordinate.get(1).asDouble(), coordinate.get(0).asDouble()));
                }
            }
            if (geometry.size() < 2) {
                continue;
            }
            List<TurnStep> steps = new ArrayList<>();
            int shapeCursor = 0;
            for (JsonNode leg : route.path("legs")) {
                for (JsonNode step : leg.path("steps")) {
                    JsonNode maneuver = step.path("maneuver");
                    JsonNode location = maneuver.path("location");
                    GeoPoint point = location.isArray() && location.size() >= 2
                            ? new GeoPoint(location.get(1).asDouble(), location.get(0).asDouble())
                            : geometry.get(0);
                    // OSRM does not report a shape index. Maneuvers are ordered
                    // along the route, so a forward-only scan keeps this linear
                    // overall instead of rescanning the whole polyline per step.
                    shapeCursor = nearestVertexFrom(geometry, point, shapeCursor);
                    String roadName = step.path("name").asText("");
                    ManeuverType type = ManeuverType.fromOsrm(
                            maneuver.path("type").asText(""),
                            maneuver.path("modifier").asText("")
                    );
                    Integer roundaboutExit = maneuver.has("exit")
                            ? maneuver.path("exit").asInt()
                            : null;
                    steps.add(new TurnStep(
                            ManeuverNarrator.describe(type, roadName, roundaboutExit, null, null),
                            roadName,
                            step.path("distance").asDouble(),
                            step.path("duration").asDouble(),
                            type,
                            point,
                            shapeCursor,
                            roundaboutExit,
                            null,
                            null
                    ));
                }
            }
            result.add(new ProviderRoute(
                    route.path("distance").asDouble(),
                    route.path("duration").asDouble(),
                    geometry,
                    steps,
                    "OSRM",
                    false,
                    List.of()
            ));
        }
        return result;
    }

    private List<ProviderRoute> fallbackRoutes(List<GeoPoint> points, boolean alternatives) {
        if (points.size() > 2 || !alternatives) {
            return List.of(fallback(points));
        }
        GeoPoint start = points.get(0);
        GeoPoint end = points.get(points.size() - 1);
        double midLat = (start.lat() + end.lat()) / 2.0;
        double midLng = (start.lng() + end.lng()) / 2.0;
        double dLat = end.lat() - start.lat();
        double dLng = end.lng() - start.lng();
        double norm = Math.max(0.000001, Math.sqrt(dLat * dLat + dLng * dLng));
        double offsetLat = -dLng / norm * 0.0045;
        double offsetLng = dLat / norm * 0.0045;
        return List.of(
                fallback(List.of(start, end)),
                fallback(List.of(start, new GeoPoint(midLat + offsetLat, midLng + offsetLng), end)),
                fallback(List.of(start, new GeoPoint(midLat - offsetLat, midLng - offsetLng), end))
        );
    }

    private ProviderRoute fallback(List<GeoPoint> points) {
        double distance = 0;
        List<TurnStep> steps = new ArrayList<>();
        for (int index = 1; index < points.size(); index++) {
            GeoPoint from = points.get(index - 1);
            GeoPoint to = points.get(index);
            double segment = haversineMeters(from, to);
            distance += segment;
            steps.add(new TurnStep(
                    index == points.size() - 1 ? "Đi đến điểm đến" : "Tiếp tục theo tuyến tránh",
                    "",
                    segment,
                    segment / (FALLBACK_SPEED_KMH * 1000 / 3600),
                    index == points.size() - 1 ? ManeuverType.ARRIVE : ManeuverType.CONTINUE,
                    from,
                    index - 1,
                    null,
                    null,
                    null
            ));
        }
        double duration = distance / (FALLBACK_SPEED_KMH * 1000 / 3600);
        List<GeoPoint> navigationWaypoints = points.size() <= 2
                ? List.of()
                : List.copyOf(points.subList(1, points.size() - 1));
        return new ProviderRoute(
                distance,
                duration,
                List.copyOf(points),
                steps,
                "LOCAL_DETERMINISTIC",
                true,
                navigationWaypoints
        );
    }

    private int nearestVertexFrom(List<GeoPoint> geometry, GeoPoint target, int fromIndex) {
        int best = Math.min(fromIndex, geometry.size() - 1);
        double bestDistance = Double.MAX_VALUE;
        for (int index = best; index < geometry.size(); index++) {
            double distance = haversineMeters(geometry.get(index), target);
            if (distance < bestDistance) {
                bestDistance = distance;
                best = index;
            }
            // The polyline is dense; once we are moving away from the maneuver
            // by more than a block it cannot come back closer on this step.
            if (bestDistance < 5 || distance > bestDistance + 300) {
                break;
            }
        }
        return best;
    }

    private double haversineMeters(GeoPoint first, GeoPoint second) {
        double earthRadius = 6_371_000;
        double dLat = Math.toRadians(second.lat() - first.lat());
        double dLng = Math.toRadians(second.lng() - first.lng());
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(first.lat())) * Math.cos(Math.toRadians(second.lat()))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
}
