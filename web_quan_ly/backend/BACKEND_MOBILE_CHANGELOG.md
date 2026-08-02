# Backend Mobile Changelog

## Change 001
- Thời gian: 2026-07-08
- Mục tiêu: Khởi tạo tài liệu triển khai backend cho mobile app.
- File tạo mới:
  - `BACKEND_MOBILE_IMPLEMENTATION_PLAN.md`
  - `BACKEND_MOBILE_PROGRESS.md`
  - `BACKEND_MOBILE_CHANGELOG.md`
  - `BACKEND_MOBILE_TODO_NEXT.md`
  - `MOBILE_API_CONTRACT.md`
- File sửa:
  - Chưa sửa code backend.
- Lý do sửa:
  - Đảm bảo Codex có plan/progress/contract trước khi code, tránh mất tiến độ.
- Ảnh hưởng logic cũ:
  - Không ảnh hưởng.
- Trạng thái: DONE

## Change 002
- Thời gian: 2026-07-08
- Mục tiêu: Bổ sung backend facade cho app mobile tài xế.
- File tạo mới:
  - `src/main/resources/db/migration/V3__add_mobile_driver_app_support.sql`
  - `src/main/java/com/safefleet/mobile/controller/MobileController.java`
  - `src/main/java/com/safefleet/mobile/service/MobileAppService.java`
  - `src/main/java/com/safefleet/mobile/dto/request/*`
  - `src/main/java/com/safefleet/mobile/dto/response/*`
  - `src/main/java/com/safefleet/mobile/entity/*`
  - `src/main/java/com/safefleet/mobile/repository/*`
  - `src/main/java/com/safefleet/mobile/enums/*`
- File sửa:
  - `src/main/java/com/safefleet/trip/repository/TripRepository.java`
  - `src/test/java/com/safefleet/RealMySqlApiIntegrationTest.java`
  - `BACKEND_MOBILE_PROGRESS.md`
  - `BACKEND_MOBILE_TODO_NEXT.md`
  - `MOBILE_API_CONTRACT.md`
- Lý do sửa:
  - Mobile cần một facade ổn định để lấy profile/config/chuyến hiện tại và gửi dữ liệu GPS/AI/SOS/flood mà không phải gọi rời rạc nhiều API web.
- Ảnh hưởng logic cũ:
  - Không đổi `/api/v1` hiện có, không đổi JWT, không đổi WebSocket topic, không sửa V1/V2 migration.
  - Thêm V3 migration mở rộng schema.
- Kiểm thử:
  - `mvn.cmd -q test`: PASS.
  - Có test MySQL thật cho mobile driver scope và phân quyền.
- Trạng thái: DONE
