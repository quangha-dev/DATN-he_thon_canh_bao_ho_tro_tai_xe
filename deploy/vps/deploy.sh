#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]] || [[ ! "$1" =~ ^[a-f0-9]{40}$ ]]; then
  echo "Usage: $0 <40-character-git-commit-sha>" >&2
  exit 1
fi

new_tag="$1"
APP_ROOT="${SAFEEFLEET_APP_ROOT:-/opt/safefleet/app}"
ENV_FILE="${SAFEEFLEET_ENV_FILE:-/opt/safefleet/.env.production}"
CURRENT_TAG_FILE="${SAFEEFLEET_CURRENT_TAG_FILE:-/opt/safefleet/.current-image-tag}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing production environment file: $ENV_FILE" >&2
  exit 1
fi

previous_tag=""
if [[ -f "$CURRENT_TAG_FILE" ]]; then
  previous_tag="$(tr -d '[:space:]' < "$CURRENT_TAG_FILE")"
fi

compose=(
  docker compose --project-name safefleet --env-file "$ENV_FILE"
  -f "$APP_ROOT/docker-compose.yml"
  -f "$APP_ROOT/docker-compose.production.yml"
  -f "$APP_ROOT/docker-compose.routing.yml"
  -f "$APP_ROOT/deploy/vps/docker-compose.vps.yml"
)

rollback_application() {
  if [[ ! "$previous_tag" =~ ^[a-f0-9]{40}$ ]]; then
    echo "No valid previous application image tag is available for rollback" >&2
    return 1
  fi
  echo "Rolling application containers back to $previous_tag" >&2
  IMAGE_TAG="$previous_tag" "${compose[@]}" up -d --no-build --wait --wait-timeout 600 \
    backend frontend ai-service
}

if [[ -n "$("${compose[@]}" ps --status running --quiet postgres 2>/dev/null)" ]]; then
  bash "$APP_ROOT/deploy/vps/backup.sh"
else
  echo "Initial deployment: PostgreSQL is not running, so the pre-deploy backup is skipped."
fi

export IMAGE_TAG="$new_tag"
"${compose[@]}" config --quiet
"${compose[@]}" pull backend frontend ai-service caddy

if ! "${compose[@]}" up -d --no-build --remove-orphans --wait --wait-timeout 2400; then
  rollback_application || true
  exit 1
fi

if ! bash "$APP_ROOT/deploy/vps/health-check.sh"; then
  rollback_application || true
  exit 1
fi

printf '%s\n' "$new_tag" > "$CURRENT_TAG_FILE"
echo "SafeFleet deployment completed with image tag $new_tag"
