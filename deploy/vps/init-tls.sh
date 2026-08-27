#!/usr/bin/env bash
# Phát hành chứng chỉ TLS lần đầu.
#
# Nginx không khởi động được nếu ssl_certificate trỏ vào file chưa tồn tại, mà
# certbot lại cần nginx đang chạy để trả lời thử thách HTTP-01. Script gỡ vòng
# lặp đó: đặt tạm một chứng chỉ tự ký để nginx lên được, xin chứng chỉ thật,
# rồi nạp lại cấu hình.
#
# Chạy đúng một lần khi dựng VPS. Sau đó container certbot tự gia hạn.
set -Eeuo pipefail

APP_ROOT="${SAFEEFLEET_APP_ROOT:-/opt/safefleet/app}"
ENV_FILE="${SAFEEFLEET_ENV_FILE:-/opt/safefleet/.env.production}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Thiếu file môi trường production: $ENV_FILE" >&2
  exit 1
fi

read_env() {
  sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1 | tr -d '\r'
}

app_domain="$(read_env APP_DOMAIN)"
letsencrypt_email="$(read_env LETSENCRYPT_EMAIL)"
staging="$(read_env LETSENCRYPT_STAGING)"

if [[ -z "$app_domain" ]]; then
  echo "APP_DOMAIN chưa có trong $ENV_FILE" >&2
  exit 1
fi
if [[ -z "$letsencrypt_email" ]]; then
  echo "LETSENCRYPT_EMAIL chưa có trong $ENV_FILE (dùng để nhận cảnh báo hết hạn)" >&2
  exit 1
fi

# Kiểm tra DNS trước khi gọi Let's Encrypt. Xin chứng chỉ cho một tên miền trỏ
# sai sẽ thất bại và ăn hạn mức 5 lần/giờ của cùng một tập tên miền.
resolved="$(getent ahostsv4 "$app_domain" | awk 'NR==1 {print $1}' || true)"
public_ip="$(curl -fsS --max-time 10 https://api.ipify.org || true)"
if [[ -n "$resolved" && -n "$public_ip" && "$resolved" != "$public_ip" ]]; then
  echo "CẢNH BÁO: $app_domain đang trỏ về $resolved nhưng IP công khai của máy này là $public_ip." >&2
  echo "Cập nhật bản ghi DNS rồi chạy lại, nếu không Let's Encrypt sẽ từ chối." >&2
  exit 1
fi

compose=(
  docker compose --project-name safefleet --env-file "$ENV_FILE"
  -f "$APP_ROOT/docker-compose.yml"
  -f "$APP_ROOT/docker-compose.production.yml"
  -f "$APP_ROOT/docker-compose.routing.yml"
  -f "$APP_ROOT/deploy/vps/docker-compose.vps.yml"
)

cert_path="/etc/letsencrypt/live/$app_domain"

if "${compose[@]}" run --rm --entrypoint sh certbot \
     -c "[ -s '$cert_path/fullchain.pem' ] && [ ! -L '$cert_path/fullchain.pem.dummy' ]" 2>/dev/null; then
  if "${compose[@]}" run --rm --entrypoint sh certbot \
       -c "openssl x509 -in '$cert_path/fullchain.pem' -noout -issuer | grep -qv 'SafeFleet bootstrap'"; then
    echo "Chứng chỉ thật cho $app_domain đã có, không cần phát hành lại."
    exit 0
  fi
fi

echo "Đặt chứng chỉ tự ký tạm thời để nginx khởi động được…"
"${compose[@]}" run --rm --entrypoint sh certbot -c "
  mkdir -p '$cert_path' /var/www/certbot
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout '$cert_path/privkey.pem' \
    -out '$cert_path/fullchain.pem' \
    -subj '/CN=$app_domain/O=SafeFleet bootstrap'
"

echo "Khởi động nginx với chứng chỉ tạm…"
"${compose[@]}" up -d --no-build nginx

echo "Xin chứng chỉ thật từ Let's Encrypt…"
staging_flag=()
if [[ "$staging" == "1" || "$staging" == "true" ]]; then
  echo "Dùng môi trường staging của Let's Encrypt (chứng chỉ KHÔNG được trình duyệt tin)."
  staging_flag=(--staging)
fi

"${compose[@]}" run --rm --entrypoint sh certbot -c "
  rm -rf '$cert_path' /etc/letsencrypt/archive/$app_domain /etc/letsencrypt/renewal/$app_domain.conf
  certbot certonly --webroot --webroot-path=/var/www/certbot \
    ${staging_flag[*]} \
    --email '$letsencrypt_email' \
    --agree-tos --no-eff-email --non-interactive \
    --rsa-key-size 4096 \
    -d '$app_domain'
"

echo "Nạp lại nginx với chứng chỉ mới…"
"${compose[@]}" exec -T nginx nginx -s reload

echo "Đã phát hành chứng chỉ TLS cho https://$app_domain"
