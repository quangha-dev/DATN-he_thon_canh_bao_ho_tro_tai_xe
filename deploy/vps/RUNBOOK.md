# Runbook triển khai SafeFleet lên VPS

Áp dụng cho VPS Contabo Ubuntu, lớp edge Nginx + Let's Encrypt.

Người vận hành tự chạy các lệnh dưới đây. Không dán mật khẩu root vào bất kỳ
file nào trong repo.

---

## 0. Điều kiện bắt buộc trước khi bắt đầu

| Việc | Vì sao bắt buộc |
|---|---|
| Bản ghi A của tên miền trỏ đúng IP VPS | Let's Encrypt không cấp chứng chỉ cho IP trần. Không có HTTPS thì app tài xế không kết nối được, vì `AndroidManifest` đặt `usesCleartextTraffic="false"` |
| Cổng 80 và 443 mở | Thử thách ACME đi qua cổng 80; thiếu là không xin được chứng chỉ |
| Đã có Docker Engine + Compose plugin trên VPS | Toàn bộ stack chạy bằng Compose |

Kiểm tra DNS từ máy bất kỳ trước khi làm tiếp:

```bash
dig +short safefleet.duckdns.org
```

Kết quả phải đúng bằng IP VPS. Với DuckDNS, cập nhật bằng:

```bash
curl "https://www.duckdns.org/update?domains=safefleet&token=<duckdns-token>&ip=<ip-vps>"
```

---

## 1. Chuẩn bị VPS

Đăng nhập rồi tạo người dùng triển khai riêng, không dùng root cho việc hằng ngày:

```bash
adduser --disabled-password --gecos "" safefleet
usermod -aG docker safefleet
install -d -m 700 -o safefleet -g safefleet /home/safefleet/.ssh
```

Cài khoá công khai của bạn để bỏ hẳn đăng nhập bằng mật khẩu:

```bash
install -d -m 700 -o safefleet -g safefleet /home/safefleet/.ssh
printf '%s\n' "<noi-dung-id_ed25519.pub-cua-ban>" > /home/safefleet/.ssh/authorized_keys
chown safefleet:safefleet /home/safefleet/.ssh/authorized_keys
chmod 600 /home/safefleet/.ssh/authorized_keys
```

Tắt đăng nhập mật khẩu và đăng nhập root qua SSH:

```bash
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl reload ssh
```

Tường lửa chỉ mở ba cổng:

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
```

---

## 2. Đưa mã nguồn và cấu hình lên VPS

```bash
install -d -o safefleet -g safefleet /opt/safefleet/app /opt/safefleet/secrets
chmod 700 /opt/safefleet/secrets
```

Từ máy phát triển:

```bash
rsync -az --relative \
  docker-compose.yml \
  docker-compose.production.yml \
  docker-compose.routing.yml \
  docker/minio/init-bucket.sh \
  safefleet_ai/models/safefleet_temporal_rules.json \
  deploy/vps/ \
  safefleet@<ip-vps>:/opt/safefleet/app/
```

---

## 3. Tạo file môi trường production

Trên VPS, chép mẫu rồi điền giá trị thật:

```bash
cp /opt/safefleet/app/deploy/vps/.env.production.example /opt/safefleet/.env.production
chmod 600 /opt/safefleet/.env.production
```

Sinh các bí mật bằng lệnh, không tự nghĩ chuỗi:

```bash
openssl rand -base64 48   # JWT_SECRET
openssl rand -base64 36   # POSTGRES_PASSWORD
openssl rand -base64 36   # MINIO_ROOT_PASSWORD
openssl rand -base64 36   # AI_INTERNAL_TOKEN
openssl rand -base64 36   # AGENT_ENCRYPTION_SECRET
```

Các giá trị phải sửa cho đúng môi trường:

```
APP_DOMAIN=safefleet.duckdns.org
LETSENCRYPT_EMAIL=<email-that-cua-ban>
LETSENCRYPT_STAGING=1        # để 1 khi chạy thử lần đầu, xong đổi về 0
CORS_ALLOWED_ORIGINS=https://safefleet.duckdns.org
IMAGE_REGISTRY_PREFIX=ghcr.io/quangha-dev/safefleet
IMAGE_TAG=<git-commit-sha-40-ky-tu>
OPENAI_API_KEY=<khoa-that>
```

`LETSENCRYPT_STAGING=1` cho lần chạy đầu là có chủ đích: Let's Encrypt chỉ cho
5 lần xin thất bại mỗi giờ cho cùng một tên miền. Chứng chỉ staging không được
trình duyệt tin, nhưng cho phép kiểm tra toàn bộ đường đi. Khi đã chắc chắn,
đổi về `0`, xoá volume `letsencrypt_conf` rồi chạy lại `init-tls.sh`.

Nếu bật FCM, đặt service account tại đường dẫn đã khai trong
`FCM_CREDENTIALS_HOST_PATH` với quyền `600`.

---

## 4. Phát hành chứng chỉ TLS lần đầu

```bash
bash /opt/safefleet/app/deploy/vps/init-tls.sh
```

Script tự kiểm tra DNS trước, dựng chứng chỉ tự ký tạm để nginx khởi động được,
xin chứng chỉ thật rồi nạp lại nginx. Chạy đúng một lần; sau đó container
`certbot` tự gia hạn mỗi 12 tiếng và nginx tự nạp lại mỗi 6 tiếng.

---

## 5. Triển khai

```bash
bash /opt/safefleet/app/deploy/vps/deploy.sh <git-commit-sha-40-ky-tu>
```

Script sẽ: sao lưu trước khi đổi (bỏ qua ở lần đầu vì PostgreSQL chưa chạy) →
kiểm tra đã có chứng chỉ chưa → kéo image → dựng stack và chờ healthy → nạp lại
nginx để nhận IP mới của backend → chạy health-check → ghi lại tag để có đường
lùi. Nếu health-check hỏng, script tự quay về tag trước đó.

Lần đầu Valhalla phải dựng đồ thị bản đồ Việt Nam, mất khoảng **30–60 phút**
và ăn nhiều RAM. Đây là lý do `--wait-timeout` đặt 2400 giây.

---

## 6. Nghiệm thu sau triển khai

```bash
bash /opt/safefleet/app/deploy/vps/health-check.sh
```

Kiểm tra thêm từ ngoài:

```bash
curl -I https://safefleet.duckdns.org/login          # phải 200
curl -I http://safefleet.duckdns.org/login           # phải 301 sang https
curl -I https://safefleet.duckdns.org/actuator/health # phải 404, không được lộ
```

Chấm điểm TLS tại `https://www.ssllabs.com/ssltest/` — cấu hình hiện tại nhắm
mức A: chỉ TLS 1.2/1.3, HSTS một năm, session ticket tắt.

---

## 7. Cài app tài xế

Dự án **bắt buộc** ký release: `android/app/build.gradle.kts` ném lỗi nếu
thiếu bốn biến `SAFEEFLEET_ANDROID_*`. Đây là chủ ý, để không ai lỡ phát hành
một bản ký bằng khoá debug.

Vì vậy có hai đường:

**Đường nhanh — bản debug để pilot.** Đã build sẵn, trỏ về
`https://safefleet.duckdns.org/api/v1`, tách theo ABI. Hầu hết điện thoại hiện
nay dùng `arm64-v8a`:

```bash
adb install -r app-arm64-v8a-debug.apk
```

Bản debug chạy chậm hơn và nặng hơn nhiều, nhưng kết nối VPS đầy đủ qua HTTPS.

**Đường chính thức — bản release đã ký.** Tạo keystore rồi build:

```bash
keytool -genkey -v -keystore safefleet-release.jks   -keyalg RSA -keysize 4096 -validity 10000 -alias safefleet

export SAFEEFLEET_ANDROID_STORE_FILE=/duong/dan/safefleet-release.jks
export SAFEEFLEET_ANDROID_STORE_PASSWORD=<mat-khau-kho>
export SAFEEFLEET_ANDROID_KEY_ALIAS=safefleet
export SAFEEFLEET_ANDROID_KEY_PASSWORD=<mat-khau-khoa>

flutter build apk --release --split-per-abi   --dart-define=API_BASE_URL=https://safefleet.duckdns.org/api/v1
```

Giữ file `.jks` ở nơi an toàn và **không bao giờ commit**. Mất keystore là mất
khả năng cập nhật app đã phát hành.

---

## 8. Bật CI/CD tự động

Hiện workflow chưa từng chạy vì `.github/` chưa được đẩy lên GitHub. Sau khi
đẩy, cấu hình trong repo settings:

**Variables:** `APP_DOMAIN`

**Secrets:** `GHCR_USERNAME`, `GHCR_READ_TOKEN`, `VPS_HOST`, `VPS_USER`,
`VPS_SSH_PRIVATE_KEY`, `VPS_KNOWN_HOSTS`, `OCR_MODELS_ARCHIVE_URL`,
`OCR_MODELS_ARCHIVE_SHA`, `OCR_MODELS_DOWNLOAD_TOKEN`

**Tuỳ chọn cho bản ký thật:** `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`

Lấy `VPS_KNOWN_HOSTS` bằng:

```bash
ssh-keyscan -H <ip-vps>
```

Tạo keystore phát hành (chạy trên máy bạn, tự đặt mật khẩu):

```bash
keytool -genkey -v -keystore safefleet-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias safefleet
base64 -w0 safefleet-release.jks    # dán vào secret ANDROID_KEYSTORE_BASE64
```

Giữ file `.jks` ở nơi an toàn và **không bao giờ commit**. Mất keystore là mất
khả năng cập nhật app đã phát hành.

---

## 9. Sao lưu

Bật timer sao lưu đã có sẵn:

```bash
cp /opt/safefleet/app/deploy/vps/systemd/safefleet-backup.* /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now safefleet-backup.timer
systemctl list-timers safefleet-backup.timer
```

Bản sao lưu hiện nằm **trên cùng VPS**. Hỏng ổ là mất cả dữ liệu lẫn bản sao.
Trước khi coi là production, phải thêm bản mã hoá đẩy ra ngoài và diễn tập khôi
phục ít nhất một lần.

---

## 10. Việc còn thiếu để gọi là production

| Hạng mục | Trạng thái |
|---|---|
| Sao lưu off-site + diễn tập khôi phục | Chưa có |
| Prometheus/Grafana/Loki/cảnh báo | Chưa có |
| Cổng quét lỗ hổng trong CI | Chưa có |
| Quy trình xoay secret | Chưa có |
| Keystore phát hành Android | Chưa có |
| Pilot ngủ gật và dẫn đường trên xe thật | Chưa có |
| Giảm thiểu PII trước khi gửi OpenAI | Chưa có |

Triển khai theo runbook này cho ra một hệ thống **chạy được và có HTTPS**, đủ
để nghiệm thu nội bộ. Chưa đủ để gọi là `production-verified`.
