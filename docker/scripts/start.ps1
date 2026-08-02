$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
    if (-not (Test-Path ".env")) {
        Copy-Item ".env.example" ".env"
        Write-Host "Đã tạo .env từ .env.example. Hãy đổi các giá trị change_me rồi chạy lại."
        exit 1
    }
    docker compose config --quiet
    docker compose up -d --build
    docker compose ps
} finally {
    Pop-Location
}
