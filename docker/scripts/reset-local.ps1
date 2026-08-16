$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$expectedCompose = Join-Path $root "docker-compose.yml"
if (-not (Test-Path -LiteralPath $expectedCompose)) {
    throw "Không tìm thấy docker-compose.yml tại workspace SafeFleet."
}

$answer = Read-Host "Thao tác này xóa toàn bộ volume PostgreSQL/MinIO/AI local. Nhập RESET-SAFEFLEET để xác nhận"
if ($answer -cne "RESET-SAFEFLEET") {
    Write-Host "Đã hủy reset."
    exit 0
}

Push-Location $root
try {
    docker compose down --volumes --remove-orphans
    Write-Host "Đã xóa container và volume local của project Compose SafeFleet."
} finally {
    Pop-Location
}
