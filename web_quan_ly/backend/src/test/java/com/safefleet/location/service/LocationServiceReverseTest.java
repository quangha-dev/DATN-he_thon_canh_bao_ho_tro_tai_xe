package com.safefleet.location.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.safefleet.location.dto.response.LocationSuggestionResponse;
import com.safefleet.navigation.provider.RoutingProvider;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class LocationServiceReverseTest {

    private HttpServer photon;

    @AfterEach
    void tearDown() {
        if (photon != null) {
            photon.stop(0);
        }
    }

    private LocationService service() {
        LocationService service = new LocationService(
                new ObjectMapper(),
                mock(RoutingProvider.class)
        );
        ReflectionTestUtils.setField(service, "googleMapsApiKey", "");
        return service;
    }

    @Test
    void namesTheSpotADriverPinnedOnTheMap() throws Exception {
        photon = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        photon.createContext("/reverse", exchange -> {
            byte[] body = """
                    {"features":[{"geometry":{"coordinates":[105.75178,21.04397]},
                    "properties":{"name":"Ngõ 18 Phố Kiều Mai","district":"Bắc Từ Liêm",
                    "city":"Hà Nội","country":"Việt Nam","osm_type":"W","osm_id":"1"}}]}
                    """.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, body.length);
            exchange.getResponseBody().write(body);
            exchange.close();
        });
        photon.start();

        LocationService service = service();
        ReflectionTestUtils.setField(service, "photonUrl",
                "http://127.0.0.1:" + photon.getAddress().getPort() + "/api/");
        ReflectionTestUtils.setField(service, "photonReverseUrl", "");

        LocationSuggestionResponse place = service.reverse(21.04397, 105.75178);

        assertThat(place.name()).isEqualTo("Ngõ 18 Phố Kiều Mai");
        assertThat(place.address()).contains("Hà Nội");
        // Toạ độ giữ nguyên chỗ tài xế chấm, không nhảy về tâm con đường khớp được.
        assertThat(place.lat()).isEqualTo(21.04397);
        assertThat(place.lng()).isEqualTo(105.75178);
        assertThat(place.source()).isEqualTo("MAP_PIN");
    }

    @Test
    void withoutAGeocoderThePinIsStillUsable() {
        LocationService service = service();
        // Cổng không có ai nghe: mô phỏng mất mạng hoặc Photon chết.
        ReflectionTestUtils.setField(service, "photonUrl", "http://127.0.0.1:1/api/");
        ReflectionTestUtils.setField(service, "photonReverseUrl", "");

        LocationSuggestionResponse place = service.reverse(21.0285, 105.8542);

        assertThat(place.name()).isEqualTo("Vị trí đã chọn trên bản đồ");
        assertThat(place.address()).isEqualTo("21.02850, 105.85420");
        assertThat(place.lat()).isEqualTo(21.0285);
        assertThat(place.lng()).isEqualTo(105.8542);
    }

    @Test
    void derivesTheReverseEndpointFromTheConfiguredPhotonUrl() {
        LocationService service = service();
        ReflectionTestUtils.setField(service, "photonReverseUrl", "");

        ReflectionTestUtils.setField(service, "photonUrl", "https://photon.komoot.io/api/");
        assertThat((String) ReflectionTestUtils.invokeMethod(service, "reverseUrl"))
                .isEqualTo("https://photon.komoot.io/reverse");

        ReflectionTestUtils.setField(service, "photonUrl", "https://geocode.noi.bo/api");
        assertThat((String) ReflectionTestUtils.invokeMethod(service, "reverseUrl"))
                .isEqualTo("https://geocode.noi.bo/reverse");

        // Cấu hình tường minh luôn thắng suy diễn.
        ReflectionTestUtils.setField(service, "photonReverseUrl", "https://rev.noi.bo/r");
        assertThat((String) ReflectionTestUtils.invokeMethod(service, "reverseUrl"))
                .isEqualTo("https://rev.noi.bo/r");
    }
}
