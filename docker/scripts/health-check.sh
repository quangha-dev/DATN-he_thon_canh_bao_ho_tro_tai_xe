#!/usr/bin/env sh
set -eu
check() {
  name="$1"
  url="$2"
  wget -qO- "$url" >/dev/null
  echo "PASS $name"
}
check backend http://localhost:8080/actuator/health
check frontend http://localhost:3000
check ai-service http://localhost:8000/health
check minio http://localhost:9000/minio/health/live
