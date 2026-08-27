# Hệ thống dẫn đường SafeFleet

Dẫn đường turn-by-turn cho tài xế, chạy hoàn toàn trên hạ tầng tự chủ: dữ liệu
đường OpenStreetMap, road graph Valhalla tự host, bản đồ MapLibre. **Không dùng
Google Maps / Google Navigation SDK.**

Điểm khác biệt so với một ứng dụng dẫn đường thông thường: vùng ngập và đoạn
đường bị chặn do chính tài xế báo sẽ được loại khỏi đồ thị đường trước khi tính
tuyến, và tuyến trả về còn bị kiểm tra lại một lần nữa trước khi đưa cho tài xế.

---

## 1. Kiến trúc

```
App (Flutter)                        Backend (Spring)                Hạ tầng
─────────────────────────────        ─────────────────────────       ──────────────
RoutePlannerScreen                   MobileNavigationController      Valhalla  (route)
  └─ chọn điểm đến, xem              NavigationService               Photon    (địa danh)
     các phương án                     ├─ activeFloodReports()       PostgreSQL
TurnByTurnScreen                       ├─ routingExclusions()        MinIO
  └─ engine/ (thuần Dart)              ├─ score() + kiểm tra lại
       NavRoute                        ├─ detourWaypointSets()
       RouteMatcher                    ├─ hazardAhead()
       NavigationEngine                └─ complete()
       GuidancePlanner
       VoiceGuidance
```

Toàn bộ logic quyết định “tài xế nhìn thấy gì, nghe thấy gì” nằm trong
`safe_fleet_driver_ui/lib/features/navigation/engine/` và **không phụ thuộc
widget, plugin hay timer** — nhờ đó có thể phát lại nguyên một hành trình trong
unit test.

---

## 2. Cơ chế tránh ngập — ba lớp độc lập

Mỗi lớp có thể hỏng riêng, nên cả ba đều phải có.

### Lớp 1 — Loại bỏ ngay trên đồ thị đường

`NavigationService.routingExclusions()` chuyển mỗi báo cáo bị coi là *chặn cứng*
thành dạng loại trừ mạnh nhất mà hình học đó cho phép:

| Kiểu báo cáo | Gửi cho Valhalla | Lý do |
|---|---|---|
| `POINT` | `exclude_locations` | Router bám vào đúng một cạnh đường; không xoá cả nút giao |
| `SEGMENT` | `exclude_polygons` (hành lang đệm 10–40 m) | Lấy mẫu điểm chỉ xoá vài cạnh gần mẫu, phần còn lại của phố ngập vẫn đi được |
| `POLYGON` | `exclude_polygons` (vòng khép kín) | Giữ nguyên vùng quản trị viên khoanh |

Hành lang được giữ **hẹp có chủ đích**: một phố bị chặn không được kéo theo con
ngõ song song vốn chính là lối vòng tự nhiên.

Đây là lớp duy nhất cân nhắc được **toàn mạng lưới**, nên luôn cho lối vòng rẻ
nhất khi nó hoạt động.

### Lớp 2 — Đường vòng tường minh

Khi vẫn còn tuyến trả về cắt qua vùng chặn (Valhalla chết và rơi xuống OSRM —
OSRM không hỗ trợ loại trừ động; hoặc graph cũ hơn báo cáo), hệ thống yêu cầu
tuyến đi qua các điểm vòng hai bên vật cản (`detourWaypointSets`), tối đa 4 lần
gọi.

Các đường vòng này được **chấm điểm chung** với các phương án trực tiếp:

```
totalScore = thời gian (phút) + quãng đường (km) + phạt ngập + phạt giờ lái
```

Nhờ vậy “đường vòng qua nếu gần hơn” xảy ra tự nhiên: lối vòng ngắn thắng tuyến
thay thế dài, còn tuyến thay thế thắng khi lối vòng quá xa.

### Lớp 3 — Kiểm tra lại hình học trước khi công bố

Mọi tuyến trả về đều được đo lại với từng hazard
(`hazardDistanceToRoute`: điểm–polyline, polyline–polyline, point-in-polygon,
cắt đoạn). Tuyến còn cắt vùng chặn cứng bị **loại**, không phải bị xếp hạng thấp.
Nếu không còn tuyến nào an toàn, API trả lỗi rõ ràng thay vì đưa ra tuyến nguy
hiểm.

### Trong lúc đang chạy

- Backend tính `hazardAhead`: hazard gần nhất **trên phần tuyến chưa đi**, đo
  theo chiều dài dọc tuyến, trong tầm nhìn 2,5 km.
- Hazard chặn cứng ⇒ `rerouteRequired = true` ⇒ app tính lại tuyến.
- Hazard mức cảnh báo ⇒ chỉ đọc cảnh báo bằng giọng nói, không đổi tuyến.
- Tài xế bấm **“Đoạn đang đi bị ngập”** ⇒ gửi đoạn tuyến ±120 m quanh xe dưới
  dạng `SEGMENT` ⇒ tính lại tuyến ngay (bỏ qua cooldown).
- Tập hazard được **đóng băng vào phiên** (`hazards_json`), nên khi mất mạng app
  vẫn cảnh báo đúng những vùng mà tuyến đã được chấm điểm với chúng.

---

## 3. Dẫn đường trên máy

| Thành phần | Vai trò |
|---|---|
| `NavRoute` | Tuyến đã phân tích: hình học, mảng khoảng cách luỹ kế, các bước gắn với `beginShapeIndex`, hazard đã chiếu lên tuyến |
| `RouteMatcher` | Bám GPS vào tuyến bằng **cửa sổ trượt** quanh vị trí trước đó, có phạt theo hướng đi |
| `NavigationEngine` | Máy trạng thái: tiến độ, bước kế tiếp, khoảng cách tới khúc rẽ, lệch tuyến, ETA, tới nơi |
| `GuidancePlanner` | Quyết định câu nào nói, lúc nào |
| `VoiceGuidance` | Hàng đợi TTS có ưu tiên, cảnh báo an toàn cắt ngang |
| `RouteSimulator` | Sinh vệt GPS để kiểm thử và để chạy thử tuyến trên máy |

**Vì sao dùng cửa sổ trượt.** Tìm điểm gần nhất trên toàn polyline sẽ nhảy sang
lượt đi khác khi tuyến quay lại gần chính nó (vòng lặp, đường hai chiều, hai làn
song song). Cửa sổ giữ tiến độ đơn điệu và giảm chi phí mỗi nhịp GPS từ toàn bộ
polyline xuống vài chục đoạn. Khoảng cách *lệch tuyến* vẫn lấy cực tiểu toàn cục
để phát hiện đi sai, còn *tiến độ* luôn lấy trong cửa sổ.

**Xác nhận lệch tuyến** cần đủ **cả ba**: số nhịp GPS liên tiếp, thời gian trôi
qua, và quãng đường thực sự đã đi. Xe đỗ ở chỗ GPS nhiễu thoả hai điều đầu nhưng
không bao giờ thoả điều thứ ba. Ngưỡng lệch giãn theo sai số GPS báo về
(40–90 m).

**Phát thoại theo bậc**, ngưỡng giãn theo tốc độ:

| Bậc | Thời điểm | Ví dụ |
|---|---|---|
| Chuẩn bị | ~45 giây trước (400–1500 m) | “Sau 700 mét, rẽ phải vào Phố Huế” |
| Xác nhận | ~18 giây trước (150–500 m) | “Sau 200 mét, rẽ phải vào Phố Huế” |
| Thực hiện | ~5 giây trước (30–120 m) | “Rẽ phải, sau đó rẽ trái” |

Bậc “chuẩn bị” bị bỏ nếu chặng quá ngắn (nếu không nó sẽ đè lên chỉ dẫn trước).
Hai khúc rẽ sát nhau được **ghép** vào một câu thay vì bị bỏ sót. Khi đang lệch
tuyến, hệ thống **im lặng** về khúc rẽ kế tiếp vì nó thuộc con đường xe đã rời.

---

## 4. Vận hành

### Bật road graph

```bash
docker compose -f docker-compose.yml -f docker-compose.routing.yml up -d
```

Lần đầu Valhalla dựng graph Việt Nam mất khoảng 30–60 phút (`start_period: 30m`).
Kiểm tra `GET /status` và `tileset_last_modified` hằng ngày.

### Khi Valhalla chết

Hệ thống rơi xuống OSRM — **profile xe con, không áp được vùng cấm động và không
áp được giới hạn cao/rộng/tải**. Backend vẫn tự loại tuyến cắt vùng chặn cứng,
nhưng chất lượng giảm rõ rệt. Tuyến được đánh dấu `providerFallback = true` và
app hiển thị nhãn **“TUYẾN SUY GIẢM”** để tài xế không hiểu nhầm là đã né ngập
đầy đủ.

Không bao giờ bật `ALLOW_DETERMINISTIC_ROUTING_FALLBACK` ngoài test cô lập —
nó sinh tuyến đường thẳng, vô nghĩa trên đường thật.

### Vòng đời phiên

`ACTIVE → COMPLETED/CANCELLED`. App gọi `/mobile/navigation/complete` khi tới nơi
hoặc khi tài xế dừng. Tìm đường lại cùng một điểm đến sẽ **dùng lại** phiên đang
mở; điểm đến khác sẽ đóng phiên cũ. Trước đây mỗi lần tìm đường tạo một phiên
mới không bao giờ đóng.

---

## 5. Kiểm thử

```bash
# Backend (bỏ test cần Docker)
cd web_quan_ly/backend && mvn -o test -Dtest='!RealPostgreSqlApiIntegrationTest'

# App: phân tích tĩnh + toàn bộ test
cd safe_fleet_driver_ui && flutter analyze && flutter test

# Dựng ảnh xem trước giao diện dẫn đường
SF_RENDER_PREVIEW=1 flutter test test/navigation_preview_test.dart --update-goldens
```

Bộ test dẫn đường phát lại nguyên hành trình mô phỏng và kiểm chứng:

- mốc bước rẽ bám đúng polyline, không lệch theo tổng độ dài các bước;
- tiến độ đơn điệu trên tuyến quay lại gần chính nó;
- nhiễu GPS ngang 22 m không tạo lệch tuyến giả;
- xe đỗ ở chỗ GPS trôi không bị tính lại tuyến;
- mỗi khúc rẽ được đọc đúng một lần, đúng thứ tự chuẩn bị → xác nhận → thực hiện;
- im lặng về khúc rẽ khi đang lệch tuyến;
- cảnh báo đoạn ngập ở xa rồi lại ở gần;
- ETA siết lại khi xe chạy nhanh hơn kế hoạch;
- tính lại tuyến giữ nguyên vị trí hiện tại, không quay về điểm xuất phát.

### Chạy thử trên máy, không cần lái

Ở bản debug, màn dẫn đường có nút ▶ phát lại tuyến qua đúng engine mà GPS thật
dùng — dùng để duyệt lại chỉ dẫn và giọng đọc của một tuyến ngay tại bãi xe.

---

## 6. Giới hạn cần nói rõ

- Chất lượng cuối cùng phụ thuộc độ đầy đủ của tag OSM (cấm tải, chiều cao cầu,
  tải trọng cầu). Nếu dữ liệu đường không có tag an toàn thì không thuật toán
  nào suy ra được.
- ETA chưa có nguồn giao thông thời gian thực; hệ thống hiệu chỉnh theo tốc độ
  quan sát được của chính xe đó, không phải theo dòng xe.
- Báo cáo của tài xế là nguồn crowd-sourced: báo `BLOCKED` chưa xác minh chặn
  ngay trong 30 phút, sau đó cần `VERIFIED` hoặc confidence ≥ 0,65 mới tiếp tục
  chặn cứng. Cần người trực xác minh và quy trình gỡ báo sai.
- Tile nền công cộng chỉ dùng cho thử nghiệm; production cần tự dựng vector tile
  (Planetiler + Martin) kèm attribution OSM/ODbL.
