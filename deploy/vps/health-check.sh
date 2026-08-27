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

echo "SafeFleet health checks passed for https://$app_domain"
