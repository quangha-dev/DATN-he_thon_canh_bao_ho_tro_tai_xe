package com.safefleet.navigation;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.json.JsonMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.safefleet.common.exception.BadRequestException;
import com.safefleet.driver.entity.Driver;
import com.safefleet.driver.repository.DriverRepository;
import com.safefleet.flood.entity.FloodReport;
import com.safefleet.flood.enums.FloodGeometryType;
import com.safefleet.flood.enums.FloodSeverity;
import com.safefleet.flood.enums.FloodSource;
import com.safefleet.flood.enums.FloodStatus;
import com.safefleet.flood.repository.FloodReportRepository;
import com.safefleet.navigation.provider.OsrmRoutingProvider;
import com.safefleet.navigation.provider.ValhallaRoutingProvider;
import com.safefleet.trip.repository.TripRepository;
import com.safefleet.vehicle.entity.Vehicle;
import com.safefleet.vehicle.enums.VehicleType;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.PreparedStatementCreator;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Kiểm thử sẵn sàng vận hành cho phần định tuyến.
 *
 * <p>Chạy {@link NavigationService} thật, với {@link ValhallaRoutingProvider}
 * thật trỏ vào một Valhalla giả lập mà bài test điều khiển được. Nhờ đó kiểm
 * chứng được đúng thứ chỉ xảy ra ngoài thực tế: báo ngập của tài xế có thật sự
 * biến thành vùng cấm gửi xuống router không, và chuyện gì xảy ra khi router
 * phớt lờ vùng cấm đó.</p>
 */
class NavigationFieldReadinessTest {

    private HttpServer valhalla;
    private final List<String> requests = new ArrayList<>();
    private final ObjectMapper objectMapper = JsonMapper.builder()
            .addModule(new JavaTimeModule())
            .build();

    private FloodReportRepository floodReportRepository;
    private JdbcTemplate jdbcTemplate;
    private NavigationService navigationService;
    private ValhallaRoutingProvider provider;

    /**
     * Tuyến "thẳng qua chỗ ngập": chạy dọc vĩ độ 0 từ tây sang đông, cắt ngang
     * điểm ngập đặt tại (0, 0).
     */
    private static final double[][] THROUGH_CLOSURE = {
            {0.0, -0.010}, {0.0, -0.005}, {0.0, 0.0}, {0.0, 0.005}, {0.0, 0.010}
    };

    /** Tuyến vòng lên phía bắc, cách chỗ ngập hơn 1 km. */
    private static final double[][] AROUND_CLOSURE = {
            {0.0, -0.010}, {0.010, -0.005}, {0.010, 0.0}, {0.010, 0.005}, {0.0, 0.010}
    };

    @BeforeEach
    void setUp() throws IOException {
        floodReportRepository = mock(FloodReportRepository.class);
        jdbcTemplate = mock(JdbcTemplate.class);

        // persistCandidates cần khoá sinh ra từ INSERT; giả lập để nhánh "ghi
        // thành công" cũng chạy được, không chỉ nhánh ném lỗi.
        AtomicLong identity = new AtomicLong();
        when(jdbcTemplate.update(any(PreparedStatementCreator.class), any(KeyHolder.class)))
                .thenAnswer(invocation -> {
                    KeyHolder holder = invocation.getArgument(1);
                    holder.getKeyList().add(Map.of("id", identity.incrementAndGet()));
                    return 1;
                });

        provider = new ValhallaRoutingProvider(objectMapper, mock(OsrmRoutingProvider.class));
        navigationService = new NavigationService(
                provider,
                floodReportRepository,
                mock(DriverRepository.class),
                mock(TripRepository.class),
                jdbcTemplate,
                objectMapper
        );

        valhalla = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        valhalla.start();
        ReflectionTestUtils.setField(provider, "valhallaUrl",
                "http://127.0.0.1:" + valhalla.getAddress().getPort());
        ReflectionTestUtils.setField(provider, "costing", "truck");
    }

    @AfterEach
    void tearDown() {
        if (valhalla != null) {
            valhalla.stop(0);
        }
    }

    // -----------------------------------------------------------------------
    // TH-A · Báo ngập của tài xế phải thành vùng cấm gửi xuống router
    // -----------------------------------------------------------------------

    @Test
    void doanNgapDoTaiXeBaoTroThanhHanhLangCamGuiXuongRouter() {
        serveRoutes(request -> AROUND_CLOSURE);
        FloodReport segment = hazard(FloodSeverity.BLOCKED, FloodGeometryType.SEGMENT);
        segment.setGeometryJson("""
                [{"lat":0.0,"lng":-0.001},{"lat":0.0,"lng":0.001}]
                """);
        segment.setRadiusMeters(25.0);
        when(floodReportRepository.findByStatusIn(anyList())).thenReturn(List.of(segment));

        computeRoute();

        JsonNode body = firstRequestBody();
        JsonNode polygons = body.path("exclude_polygons");
        assertThat(polygons.isArray()).isTrue();
        assertThat(polygons).hasSize(1);

        // Hành lang phải bao quanh đoạn đường được báo, và phải hẹp - nếu nó
        // phình ra thì con ngõ song song, tức lối vòng tự nhiên, cũng bị xoá.
        double maxLatitude = 0;
        for (JsonNode point : polygons.get(0)) {
            maxLatitude = Math.max(maxLatitude, Math.abs(point.get(1).asDouble()));
        }
        double halfWidthMeters = maxLatitude * 111_320.0;
        assertThat(halfWidthMeters).isBetween(10.0, 45.0);

        // Điểm mẫu dọc đoạn ngập vẫn được gửi kèm để router chắc chắn bỏ cạnh.
        assertThat(body.path("exclude_locations").isArray()).isTrue();
        assertThat(body.path("exclude_locations")).isNotEmpty();
    }

    @Test
    void diemNgapDonLeChiXoaCanhDuongChuKhongXoaCaNutGiao() {
        serveRoutes(request -> AROUND_CLOSURE);
        when(floodReportRepository.findByStatusIn(anyList()))
                .thenReturn(List.of(hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT)));

        computeRoute();

        JsonNode body = firstRequestBody();
        assertThat(body.path("exclude_locations")).isNotEmpty();
        // Một điểm báo không được biến thành đa giác nuốt cả ngã tư.
        assertThat(body.path("exclude_polygons").isMissingNode()
                || body.path("exclude_polygons").isEmpty()).isTrue();
    }

    @Test
    void hoSoXeTaiDuocGuiKemDeRouterTranhCauThapVaDuongCamTai() {
        serveRoutes(request -> AROUND_CLOSURE);
        when(floodReportRepository.findByStatusIn(anyList())).thenReturn(List.of());

        Vehicle truck = new Vehicle();
        truck.setVehicleType(VehicleType.TRUCK);
        truck.setHeightMeters(new BigDecimal("4.15"));
        truck.setWidthMeters(new BigDecimal("2.50"));
        truck.setGrossWeightTons(new BigDecimal("24.0"));
        truck.setAxleCount(4);
        truck.setHazardousGoods(true);
        Driver driver = new Driver();
        driver.setCurrentVehicle(truck);

        ReflectionTestUtils.invokeMethod(
                navigationService,
                "computeAndPersist",
                1L,
                driver,
                new NavigationRouteRequest(0.0, -0.010, 0.0, 0.010, "Kho kiểm thử", null)
        );

        JsonNode body = firstRequestBody();
        assertThat(body.path("costing").asText()).isEqualTo("truck");
        JsonNode options = body.path("costing_options").path("truck");
        // Số đo thật của xe phải xuống tới router, nếu không nó sẽ chỉ đường
        // qua cầu thấp hoặc đường cấm tải.
        assertThat(options.path("height").asDouble()).isEqualTo(4.15);
        assertThat(options.path("width").asDouble()).isEqualTo(2.50);
        assertThat(options.path("weight").asDouble()).isEqualTo(24.0);
        assertThat(options.path("axle_count").asInt()).isEqualTo(4);
        assertThat(options.path("hazmat").asBoolean()).isTrue();
    }

    @Test
    void xeChuaGanHoSoThiDeRouterTuDungMacDinhBaoThuChoXeTai() {
        serveRoutes(request -> AROUND_CLOSURE);
        when(floodReportRepository.findByStatusIn(anyList())).thenReturn(List.of());

        computeRoute();

        JsonNode body = firstRequestBody();
        // Không đoán số đo từ tải trọng: gửi thiếu còn an toàn hơn gửi sai.
        assertThat(body.path("costing").asText()).isEqualTo("truck");
        assertThat(body.path("costing_options").path("truck").path("height").isMissingNode())
                .isTrue();
        // Vẫn ưu tiên tuyến dành cho xe tải.
        assertThat(body.path("costing_options").path("truck").path("use_truck_route").asDouble())
                .isGreaterThan(0);
    }

    // -----------------------------------------------------------------------
    // TH-B · Router phớt lờ vùng cấm - lớp bảo vệ thứ hai và thứ ba
    // -----------------------------------------------------------------------

    @Test
    void routerBoQuaVungCamThiHeThongTuTimDuongVongVaKhongCongBoTuyenXuyenVungNgap() {
        // Yêu cầu 2 điểm (tuyến trực tiếp) luôn trả tuyến xuyên qua chỗ ngập,
        // đúng như một graph cũ hơn báo cáo sẽ làm. Chỉ khi bị ép đi qua điểm
        // vòng thì mới trả tuyến sạch.
        serveRoutes(request -> request.path("locations").size() > 2
                ? AROUND_CLOSURE
                : THROUGH_CLOSURE);
        when(floodReportRepository.findByStatusIn(anyList()))
                .thenReturn(List.of(hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT)));

        computeRoute();

        long detourRequests = requests.stream()
                .map(this::parse)
                .filter(body -> body.path("locations").size() > 2)
                .count();
        assertThat(detourRequests)
                .as("phải chủ động hỏi đường vòng khi tuyến trả về vẫn cắt vùng ngập")
                .isGreaterThan(0);

        // Có ghi được phương án nghĩa là đã tìm ra tuyến an toàn; nếu tuyến duy
        // nhất còn lại vẫn cắt vùng ngập thì computeAndPersist đã ném lỗi.
        assertThat(requests).hasSizeGreaterThan(1);
    }

    @Test
    void khongConLoiVongAnToanThiTuChoiDanDuongThayViDuaTuyenNguyHiem() {
        // Mọi yêu cầu đều trả về tuyến xuyên qua chỗ ngập.
        serveRoutes(request -> THROUGH_CLOSURE);
        when(floodReportRepository.findByStatusIn(anyList()))
                .thenReturn(List.of(hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT)));

        assertThatThrownBy(this::computeRoute)
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("Chưa tìm thấy tuyến an toàn");
    }

    @Test
    void tuyenDiSatVungNgapNhungKhongChamThiVanDuocDung() {
        // Điểm ngập cách tuyến khoảng 1,1 km: tính điểm rủi ro thì có, chặn thì không.
        serveRoutes(request -> THROUGH_CLOSURE);
        FloodReport nearby = hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT);
        nearby.setLat(0.010);
        nearby.setRadiusMeters(60.0);
        when(floodReportRepository.findByStatusIn(anyList())).thenReturn(List.of(nearby));

        computeRoute();

        // Không cần hỏi đường vòng vì tuyến trực tiếp đã an toàn.
        long detourRequests = requests.stream()
                .map(this::parse)
                .filter(body -> body.path("locations").size() > 2)
                .count();
        assertThat(detourRequests).isZero();
    }

    // -----------------------------------------------------------------------
    // TH-C · Valhalla chết
    // -----------------------------------------------------------------------

    @Test
    void valhallaChetThiRoiXuongOsrmVaDanhDauTuyenSuyGiam() {
        OsrmRoutingProvider osrm = mock(OsrmRoutingProvider.class);
        when(osrm.routes(anyList(), org.mockito.ArgumentMatchers.anyBoolean()))
                .thenReturn(List.of(new com.safefleet.navigation.provider.RoutingProvider.ProviderRoute(
                        2_200,
                        260,
                        List.of(
                                new com.safefleet.navigation.provider.RoutingProvider.GeoPoint(0.010, -0.010),
                                new com.safefleet.navigation.provider.RoutingProvider.GeoPoint(0.010, 0.010)
                        ),
                        List.of(),
                        "OSRM",
                        false
                )));
        ValhallaRoutingProvider degraded = new ValhallaRoutingProvider(objectMapper, osrm);
        // Cổng không có ai nghe: mô phỏng Valhalla ngừng chạy.
        ReflectionTestUtils.setField(degraded, "valhallaUrl", "http://127.0.0.1:1");
        ReflectionTestUtils.setField(degraded, "costing", "truck");

        var routes = degraded.routes(
                List.of(
                        new com.safefleet.navigation.provider.RoutingProvider.GeoPoint(0.010, -0.010),
                        new com.safefleet.navigation.provider.RoutingProvider.GeoPoint(0.010, 0.010)
                ),
                true
        );

        assertThat(routes).hasSize(1);
        // Nhãn này là thứ app dùng để hiện "TUYẾN SUY GIẢM"; thiếu nó thì tài xế
        // tưởng tuyến đã được lọc ngập đầy đủ.
        assertThat(routes.get(0).fallback()).isTrue();
        assertThat(routes.get(0).provider()).isEqualTo("OSRM");
    }

    @Test
    void khongBaoGioTraVeDuongThangGiaKhiCaHaiRouterDeuChet() {
        OsrmRoutingProvider osrm = new OsrmRoutingProvider(objectMapper);
        ReflectionTestUtils.setField(osrm, "osrmUrl", "http://127.0.0.1:1/route/v1/driving");
        ReflectionTestUtils.setField(osrm, "allowDeterministicFallback", false);

        var routes = osrm.routes(
                List.of(
                        new com.safefleet.navigation.provider.RoutingProvider.GeoPoint(0, 0),
                        new com.safefleet.navigation.provider.RoutingProvider.GeoPoint(0, 0.01)
                ),
                true
        );

        assertThat(routes)
                .as("thà không có tuyến còn hơn đưa tài xế một đường thẳng bịa ra")
                .isEmpty();
    }

    // -----------------------------------------------------------------------
    // TH-D · Độ tin cậy của báo cáo crowd-sourced
    // -----------------------------------------------------------------------

    @Test
    void baoBlockedChuaXacMinhChanNgayNhungHetHieuLucSau30Phut() {
        FloodReport fresh = hazard(FloodSeverity.BLOCKED, FloodGeometryType.POINT);
        fresh.setConfidence(null);

        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", fresh))
                .as("báo mới phải chặn ngay, an toàn trước đã")
                .isTrue();

        fresh.setCreatedAt(LocalDateTime.now().minusMinutes(31));
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", fresh))
                .as("không ai xác minh thì báo cũ chỉ còn là điểm phạt rủi ro")
                .isFalse();

        fresh.setStatus(FloodStatus.VERIFIED);
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", fresh))
                .as("có người trực xác minh thì chặn lại vô thời hạn tới khi hết hiệu lực")
                .isTrue();
    }

    @Test
    void baoKetXeKhongBaoGioTuDongChanDuong() {
        FloodReport jam = hazard(FloodSeverity.HIGH, FloodGeometryType.POINT);
        jam.setHazardType(com.safefleet.flood.enums.RoadHazardType.TRAFFIC_JAM);

        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", jam))
                .as("kẹt xe làm chậm chứ không làm đường không đi được")
                .isFalse();

        jam.setSeverity(FloodSeverity.BLOCKED);
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                navigationService, "isHardClosure", jam))
                .as("trừ khi tài xế nói thẳng là tắc cứng không qua được")
                .isTrue();
    }

    // -----------------------------------------------------------------------
    // Hạ tầng cho bài test
    // -----------------------------------------------------------------------

    private interface RouteChooser {
        double[][] shapeFor(JsonNode requestBody);
    }

    private void serveRoutes(RouteChooser chooser) {
        valhalla.createContext("/route", exchange -> {
            String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            requests.add(body);
            byte[] response = tripJson(chooser.shapeFor(parse(body)))
                    .getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length);
            exchange.getResponseBody().write(response);
            exchange.close();
        });
    }

    private void computeRoute() {
        ReflectionTestUtils.invokeMethod(
                navigationService,
                "computeAndPersist",
                1L,
                new Driver(),
                new NavigationRouteRequest(0.0, -0.010, 0.0, 0.010, "Kho kiểm thử", null)
        );
    }

    private JsonNode firstRequestBody() {
        assertThat(requests).isNotEmpty();
        return parse(requests.get(0));
    }

    private JsonNode parse(String body) {
        try {
            return objectMapper.readTree(body);
        } catch (Exception exception) {
            throw new IllegalStateException(exception);
        }
    }

    private FloodReport hazard(FloodSeverity severity, FloodGeometryType geometryType) {
        FloodReport report = new FloodReport();
        report.setLat(0.0);
        report.setLng(0.0);
        report.setSeverity(severity);
        report.setGeometryType(geometryType);
        report.setRadiusMeters(80.0);
        report.setSource(FloodSource.DRIVER_REPORT);
        report.setStatus(FloodStatus.UNVERIFIED);
        report.setConfidence(0.9);
        report.setCreatedAt(LocalDateTime.now());
        report.setExpiredAt(LocalDateTime.now().plusHours(3));
        return report;
    }

    /** Dựng phản hồi đúng hình dạng Valhalla trả về, kể cả shape polyline6. */
    private String tripJson(double[][] shape) {
        return """
                {"trip":{"legs":[{"shape":"%s","maneuvers":[
                  {"type":1,"length":1.1,"time":130,"begin_shape_index":0,"street_names":["Đường kiểm thử"]},
                  {"type":4,"length":0.0,"time":0,"begin_shape_index":%d,"street_names":[]}
                ]}],"summary":{"length":2.2,"time":260}}}
                """.formatted(encodePolyline6(shape), shape.length - 1);
    }

    private static String encodePolyline6(double[][] points) {
        StringBuilder encoded = new StringBuilder();
        long previousLatitude = 0;
        long previousLongitude = 0;
        for (double[] point : points) {
            long latitude = Math.round(point[0] * 1_000_000);
            long longitude = Math.round(point[1] * 1_000_000);
            encodeValue(encoded, latitude - previousLatitude);
            encodeValue(encoded, longitude - previousLongitude);
            previousLatitude = latitude;
            previousLongitude = longitude;
        }
        return encoded.toString();
    }

    private static void encodeValue(StringBuilder target, long value) {
        long shifted = value < 0 ? ~(value << 1) : value << 1;
        while (shifted >= 0x20) {
            target.append((char) ((0x20 | (shifted & 0x1f)) + 63));
            shifted >>= 5;
        }
        target.append((char) (shifted + 63));
    }
}
