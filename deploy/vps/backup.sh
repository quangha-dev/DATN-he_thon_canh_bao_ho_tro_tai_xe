#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="${SAFEEFLEET_APP_ROOT:-/opt/safefleet/app}"
ENV_FILE="${SAFEEFLEET_ENV_FILE:-/opt/safefleet/.env.production}"
BACKUP_DIR="${SAFEEFLEET_BACKUP_DIR:-/opt/safefleet/backups}"
RETENTION_DAYS="${SAFEEFLEET_BACKUP_RETENTION_DAYS:-14}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing production environment file: $ENV_FILE" >&2
  exit 1
fi
if [[ "$BACKUP_DIR" != /opt/safefleet/backups* ]]; then
  echo "Refusing backup path outside /opt/safefleet/backups: $BACKUP_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
database_backup="$BACKUP_DIR/postgres-$timestamp.dump"
minio_backup="$BACKUP_DIR/minio-$timestamp.tar.gz"
minio_stage="$(mktemp -d "$BACKUP_DIR/.minio-stage.XXXXXX")"
trap 'rm -rf -- "$minio_stage"' EXIT

compose=(
  docker compose --project-name safefleet --env-file "$ENV_FILE"
  -f "$APP_ROOT/docker-compose.yml"
  -f "$APP_ROOT/docker-compose.production.yml"
  -f "$APP_ROOT/docker-compose.routing.yml"
  -f "$APP_ROOT/deploy/vps/docker-compose.vps.yml"
)

"${compose[@]}" exec -T postgres sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump --format=custom --no-owner --no-acl -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  > "$database_backup"

if [[ ! -s "$database_backup" ]] || [[ "$(stat -c%s "$database_backup")" -lt 1024 ]]; then
  echo "PostgreSQL backup is unexpectedly small" >&2
  exit 1
fi

docker run --rm \
  --network safefleet_safefleet \
  --env-file "$ENV_FILE" \
  -v "$minio_stage:/backup" \
  --entrypoint /bin/sh \
  minio/mc:RELEASE.2025-04-16T18-13-26Z \
  -c 'mc alias set source http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && mc mirror --overwrite "source/$MINIO_BUCKET" /backup'
tar -C "$minio_stage" -czf "$minio_backup" .

sha256sum "$database_backup" "$minio_backup" > "$BACKUP_DIR/checksums-$timestamp.sha256"
find "$BACKUP_DIR" -maxdepth 1 -type f -mtime "+$RETENTION_DAYS" -delete

echo "Backup completed: $database_backup"
echo "Backup completed: $minio_backup"
