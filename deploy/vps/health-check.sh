#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="${SAFEEFLEET_APP_ROOT:-/opt/safefleet/app}"
ENV_FILE="${SAFEEFLEET_ENV_FILE:-/opt/safefleet/.env.production}"

compose=(
  docker compose --project-name safefleet --env-file "$ENV_FILE"
  -f "$APP_ROOT/docker-compose.yml"
  -f "$APP_ROOT/docker-compose.production.yml"
  -f "$APP_ROOT/docker-compose.routing.yml"
  -f "$APP_ROOT/deploy/vps/docker-compose.vps.yml"
)

"${compose[@]}" exec -T backend \
  curl --fail --silent --show-error http://127.0.0.1:8080/actuator/health >/dev/null
"${compose[@]}" exec -T ai-service \
  python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=5)" >/dev/null

app_domain="$(sed -n 's/^APP_DOMAIN=//p' "$ENV_FILE" | tail -n 1)"
if [[ -z "$app_domain" ]]; then
  echo "APP_DOMAIN is missing from $ENV_FILE" >&2
  exit 1
fi
curl --fail --silent --show-error --max-time 20 "https://$app_domain/login" >/dev/null

# WebSocket là đường realtime của bản đồ điều hành. Chỉ cần biết nginx có định
# tuyến sang backend hay không: 400/426 nghĩa là đã tới đúng chỗ và backend từ
# chối một handshake giả; 404/502 mới là cấu hình sai.
ws_status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 15 \
  --header 'Connection: Upgrade' --header 'Upgrade: websocket' \
  "https://$app_domain/ws-native" || echo 000)"
if [[ "$ws_status" == "404" || "$ws_status" == "502" || "$ws_status" == "000" ]]; then
  echo "Đường /ws-native không tới được backend (HTTP $ws_status)" >&2
  exit 1
fi

# Cảnh báo sớm nếu certbot không gia hạn được. Chứng chỉ hết hạn làm app tài xế
# mất kết nối hoàn toàn vì Android chặn cleartext.
cert_end="$(echo | openssl s_client -servername "$app_domain" -connect "$app_domain:443" 2>/dev/null \
  | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')"
if [[ -n "$cert_end" ]]; then
  days_left=$(( ( $(date -d "$cert_end" +%s) - $(date +%s) ) / 86400 ))
  echo "Chứng chỉ TLS còn $days_left ngày (hết hạn $cert_end)"
  if (( days_left < 10 )); then
    echo "Chứng chỉ sắp hết hạn mà chưa được gia hạn; kiểm tra container certbot" >&2
    exit 1
  fi
fi

echo "SafeFleet health checks passed for https://$app_domain"
