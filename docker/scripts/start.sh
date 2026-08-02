#!/usr/bin/env sh
set -eu
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT_DIR"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env. Replace change_me values, then run again."
  exit 1
fi
docker compose config --quiet
docker compose up -d --build
docker compose ps
