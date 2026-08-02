# SafeFleet Backend

Backend Spring Boot cho do an "Agentic AI ho tro an toan lai xe".

## Stack

- Java 21
- Spring Boot 3.x
- Maven
- Spring Web, Spring Data JPA, Spring Security + JWT
- MySQL + Flyway
- Swagger/OpenAPI
- WebSocket/STOMP

## Chay local

1. Tao MySQL database hoac de JDBC tu tao database:

```sql
CREATE DATABASE safefleet CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. Cau hinh bien moi truong neu can:

```powershell
$env:DB_URL="jdbc:mysql://localhost:3306/safefleet?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Ho_Chi_Minh"
$env:DB_USERNAME="root"
$env:DB_PASSWORD="root"
$env:JWT_SECRET="SafeFleetJwtSecretKeyForGraduationProjectMustBeLongEnough2026"
```

3. Chay backend:

```powershell
mvn spring-boot:run
```

Swagger UI:

```text
http://localhost:8080/swagger-ui.html
```

WebSocket endpoint:

```text
ws://localhost:8080/ws
```

## Tai khoan seed

Seeder tao cac tai khoan demo voi mat khau mac dinh:

```text
123456
```

Tai khoan mau:

- `admin@safefleet.vn`
- `manager@safefleet.vn`
- `dispatcher@safefleet.vn`
- `safety@safefleet.vn`
- `rescue@safefleet.vn`
- `driver001` hoặc `driver001@safefleet.vn` (tài xế test mã `001`, xe cố định `001`)

## API response format

```json
{
  "success": true,
  "message": "string",
  "data": {},
  "timestamp": "2026-07-08T10:00:00"
}
```

Phan trang:

```json
{
  "success": true,
  "message": "string",
  "data": {
    "items": [],
    "page": 0,
    "size": 10,
    "totalElements": 100,
    "totalPages": 10
  },
  "timestamp": "2026-07-08T10:00:00"
}
```
