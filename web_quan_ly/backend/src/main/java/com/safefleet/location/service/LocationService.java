package com.safefleet.location.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.safefleet.location.dto.request.RouteRequest;
import com.safefleet.location.dto.response.LocationSuggestionResponse;
import com.safefleet.location.dto.response.RouteResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.text.Normalizer;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class LocationService {

    private static final double HANOI_LAT = 21.0285;
    private static final double HANOI_LNG = 105.8542;
    private static final double FALLBACK_AVERAGE_SPEED_KMH = 35.0;

    private final ObjectMapper objectMapper;

    @Value("${app.location.photon-url:https://photon.komoot.io/api/}")
    private String photonUrl;

    @Value("${app.location.osrm-url:https://router.project-osrm.org/route/v1/driving}")
    private String osrmUrl;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();

    public List<LocationSuggestionResponse> autocomplete(String query, int limit) {
        String normalizedQuery = query == null ? "" : query.trim();
        if (normalizedQuery.length() < 2) {
            return List.of();
        }

        try {
            URI uri = UriComponentsBuilder.fromUriString(photonUrl)
                    .queryParam("q", normalizedQuery)
                    .queryParam("limit", limit)
                    .queryParam("lat", HANOI_LAT)
                    .queryParam("lon", HANOI_LNG)
                    .queryParam("lang", "vi")
                    .build()
                    .encode()
                    .toUri();

            HttpRequest request = HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofSeconds(5))
                    .header("User-Agent", "SafeFleet-DATN/1.0")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                List<LocationSuggestionResponse> suggestions = parsePhoton(response.body(), limit);
                if (!suggestions.isEmpty()) {
                    return suggestions;
                }
            }
        } catch (Exception ignored) {
            // Fallback below keeps dispatch form usable during public API/network failures.
        }

        return fallbackLocations(normalizedQuery, limit);
    }

    public RouteResponse route(RouteRequest request) {
        try {
            String coordinates = "%s,%s;%s,%s".formatted(
                    request.startLng(), request.startLat(), request.endLng(), request.endLat());
            URI uri = UriComponentsBuilder
                    .fromUriString(osrmUrl + "/" + coordinates)
                    .queryParam("overview", "full")
                    .queryParam("geometries", "geojson")
                    .queryParam("steps", "false")
                    .build()
                    .encode()
                    .toUri();

            HttpRequest httpRequest = HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofSeconds(6))
                    .header("User-Agent", "SafeFleet-DATN/1.0")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                RouteResponse route = parseOsrm(response.body());
                if (route != null) {
                    return route;
                }
            }
        } catch (Exception ignored) {
            // Public OSRM can be unavailable or blocked. Use deterministic fallback below.
        }

        return fallbackRoute(request);
    }

    private List<LocationSuggestionResponse> parsePhoton(String body, int limit) throws Exception {
        JsonNode root = objectMapper.readTree(body);
        JsonNode features = root.path("features");
        if (!features.isArray()) {
            return List.of();
        }

        Map<String, LocationSuggestionResponse> unique = new LinkedHashMap<>();
        for (JsonNode feature : features) {
            JsonNode coordinates = feature.path("geometry").path("coordinates");
            if (!coordinates.isArray() || coordinates.size() < 2) {
                continue;
            }

            JsonNode properties = feature.path("properties");
            String name = text(properties, "name");
            String street = text(properties, "street");
            String district = firstNonBlank(text(properties, "district"), text(properties, "city"));
            String city = text(properties, "city");
            String country = text(properties, "country");
            String address = joinAddress(name, street, district, city, country);
            if (address.isBlank()) {
                continue;
            }

            String osmType = text(properties, "osm_type");
            String osmId = text(properties, "osm_id");
            String id = firstNonBlank(osmType + "-" + osmId, address);
            LocationSuggestionResponse item = new LocationSuggestionResponse(
                    id,
                    firstNonBlank(name, street, address),
                    address,
                    coordinates.get(1).asDouble(),
                    coordinates.get(0).asDouble(),
                    "PHOTON"
            );
            unique.putIfAbsent("%s:%s".formatted(round(item.lat()), round(item.lng())), item);
            if (unique.size() >= limit) {
                break;
            }
        }
        return new ArrayList<>(unique.values());
    }

    private RouteResponse parseOsrm(String body) throws Exception {
        JsonNode root = objectMapper.readTree(body);
        JsonNode route = root.path("routes").isArray() && !root.path("routes").isEmpty()
                ? root.path("routes").get(0)
                : null;
        if (route == null) {
            return null;
        }

        double distanceKm = roundOne(route.path("distance").asDouble() / 1000.0);
        long durationMinutes = Math.max(1, Math.round(route.path("duration").asDouble() / 60.0));
        List<List<Double>> coordinates = new ArrayList<>();
        JsonNode routeCoordinates = route.path("geometry").path("coordinates");
        if (routeCoordinates.isArray()) {
            for (JsonNode coordinate : routeCoordinates) {
                if (coordinate.isArray() && coordinate.size() >= 2) {
                    coordinates.add(List.of(coordinate.get(0).asDouble(), coordinate.get(1).asDouble()));
                }
            }
        }

        return new RouteResponse(
                distanceKm,
                durationMinutes,
                coordinates,
                "OSRM",
                false,
                "Tính tuyến thành công"
        );
    }

    private RouteResponse fallbackRoute(RouteRequest request) {
        double distanceKm = roundOne(haversineKm(
                request.startLat(), request.startLng(), request.endLat(), request.endLng()));
        long durationMinutes = Math.max(1, Math.round(distanceKm / FALLBACK_AVERAGE_SPEED_KMH * 60.0));
        List<List<Double>> coordinates = List.of(
                List.of(request.startLng(), request.startLat()),
                List.of(request.endLng(), request.endLat())
        );
        return new RouteResponse(
                distanceKm,
                durationMinutes,
                coordinates,
                "HAVERSINE",
                true,
                "Đang dùng ước tính cục bộ"
        );
    }

    private List<LocationSuggestionResponse> fallbackLocations(String query, int limit) {
        String normalized = normalize(query);
        return hanoiFallbackLocations().stream()
                .filter(item -> {
                    String name = normalize(item.name());
                    String address = normalize(item.address());
                    return name.contains(normalized)
                            || address.contains(normalized)
                            || normalized.contains(name)
                            || normalized.contains(address);
                })
                .limit(limit)
                .toList();
    }

    private List<LocationSuggestionResponse> hanoiFallbackLocations() {
        return List.of(
                local("hanoi-ha-dong", "Hà Đông", "Quận Hà Đông, Hà Nội", 20.9712, 105.7788),
                local("hanoi-cau-giay", "Cầu Giấy", "Quận Cầu Giấy, Hà Nội", 21.0362, 105.7906),
                local("hanoi-my-dinh", "Mỹ Đình", "Mỹ Đình, Nam Từ Liêm, Hà Nội", 21.0280, 105.7780),
                local("hanoi-nguyen-trai", "Nguyễn Trãi", "Nguyễn Trãi, Thanh Xuân, Hà Nội", 20.9969, 105.8064),
                local("hanoi-thang-long", "Đại lộ Thăng Long", "Đại lộ Thăng Long, Hà Nội", 21.0079, 105.7416),
                local("hanoi-kieu-mai", "Kiều Mai", "Kiều Mai, Phú Diễn, Bắc Từ Liêm, Hà Nội", 21.0548, 105.7599),
                local("hanoi-phu-dien", "Phú Diễn", "Phú Diễn, Bắc Từ Liêm, Hà Nội", 21.0508, 105.7645),
                local("hanoi-ho-tung-mau", "Hồ Tùng Mậu", "Hồ Tùng Mậu, Cầu Giấy, Hà Nội", 21.0392, 105.7795),
                local("hanoi-pham-van-dong", "Phạm Văn Đồng", "Phạm Văn Đồng, Bắc Từ Liêm, Hà Nội", 21.0587, 105.7852)
        );
    }

    private LocationSuggestionResponse local(String id, String name, String address, double lat, double lng) {
        return new LocationSuggestionResponse(id, name, address, lat, lng, "LOCAL");
    }

    private String text(JsonNode node, String field) {
        JsonNode value = node.path(field);
        return value.isMissingNode() || value.isNull() ? "" : value.asText("");
    }

    private String joinAddress(String... parts) {
        List<String> values = new ArrayList<>();
        for (String part : parts) {
            if (part != null && !part.isBlank() && values.stream().noneMatch(part::equalsIgnoreCase)) {
                values.add(part);
            }
        }
        return String.join(", ", values);
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return "";
    }

    private String normalize(String value) {
        if (value == null) {
            return "";
        }
        String withoutMarks = Normalizer.normalize(value, Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "");
        return withoutMarks
                .replace('đ', 'd')
                .replace('Đ', 'D')
                .toLowerCase(Locale.ROOT)
                .trim();
    }

    private double round(double value) {
        return Math.round(value * 100000.0) / 100000.0;
    }

    private double roundOne(double value) {
        return Math.round(value * 10.0) / 10.0;
    }

    private double haversineKm(double startLat, double startLng, double endLat, double endLng) {
        double earthRadiusKm = 6371.0;
        double dLat = Math.toRadians(endLat - startLat);
        double dLng = Math.toRadians(endLng - startLng);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(startLat)) * Math.cos(Math.toRadians(endLat))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadiusKm * c;
    }
}
