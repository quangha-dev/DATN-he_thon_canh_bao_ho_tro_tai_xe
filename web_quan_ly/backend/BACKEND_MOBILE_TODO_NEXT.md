# Backend Next Tasks

## Việc tiếp theo
1. App mobile có thể tích hợp theo `MOBILE_API_CONTRACT.md`.
2. Nếu cần mở rộng agent thật, bổ sung module xử lý NLP/LLM phía sau `POST /api/v1/mobile/agent/command`.
3. Nếu cần điều hướng bản đồ offline/không key, mobile/front có thể gọi thêm API route/geocoding ngoài backend hiện tại.

## Phần đang làm dở
- Không còn phần backend mobile facade đang làm dở.
- Test backend đã PASS với MySQL thật.

## Lưu ý cho lần chạy Codex tiếp theo
- Không sửa web frontend.
- Không sửa app mobile.
- Không đổi JWT flow, `/api/v1`, `/ws`.
- Không sửa V1/V2 migration.
- V3 đã được áp dụng vào MySQL `QuanLyCongViecDuAn`.
