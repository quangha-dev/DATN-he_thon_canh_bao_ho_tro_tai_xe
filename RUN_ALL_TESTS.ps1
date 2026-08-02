param(
    [switch]$SkipAndroid,
    [switch]$SkipDatabaseRestore
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$backend = Join-Path $root "web_quan_ly\backend"
$frontend = Join-Path $root "web_quan_ly\frontend"
$ai = Join-Path $root "safefleet_ai"
$mobile = Join-Path $root "safe_fleet_driver_ui"
$composeFiles = @(
    "-f", (Join-Path $root "docker-compose.yml"),
    "-f", (Join-Path $root "docker-compose.dev.yml"),
    "--profile", "dev"
)

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Assert-LastExitCode {
    param([string]$Action)
    if ($LASTEXITCODE -ne 0) {
        throw "$Action thất bại với exit code $LASTEXITCODE."
    }
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Thiếu công cụ '$Name'. Hãy cài đặt rồi chạy lại."
    }
}

function New-LocalSecret {
    param([int]$Bytes = 32)
    $buffer = New-Object byte[] $Bytes
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($buffer)
    } finally {
        $generator.Dispose()
    }
    return ([Convert]::ToBase64String($buffer) -replace '[^a-zA-Z0-9]', '')
}

function Ensure-LocalEnvironment {
    $envPath = Join-Path $root ".env"
    if (Test-Path -LiteralPath $envPath) {
        Write-Host "Giữ nguyên .env hiện có."
        return
    }

    $templatePath = Join-Path $root ".env.example"
    $content = [IO.File]::ReadAllText($templatePath)
    $content = $content.Replace("change_me_app_password", (New-LocalSecret 24))
    $content = $content.Replace("change_me_root_password", (New-LocalSecret 32))
    $content = $content.Replace("change_me_to_at_least_32_random_characters", (New-LocalSecret 48))
    $content = $content.Replace("change_me_minio_user", ("localminio" + (New-LocalSecret 6).ToLowerInvariant()))
    $content = $content.Replace("change_me_minio_password", (New-LocalSecret 32))
    [IO.File]::WriteAllText($envPath, $content, [Text.UTF8Encoding]::new($false))
    Write-Host "Đã tạo .env local với secret ngẫu nhiên; không in secret ra màn hình."
}

function Invoke-PowerShellScript {
    param([string]$Path)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path
    Assert-LastExitCode $Path
}

function Get-AndroidDevice {
    $raw = & flutter.bat devices --machine
    Assert-LastExitCode "flutter devices"
    $devices = @($raw | ConvertFrom-Json)
    return @($devices | Where-Object {
        $_.targetPlatform -like "android*" -and $_.isSupported -ne $false
    } | Select-Object -First 1)
}

function Start-AndroidInterface {
    if ($SkipAndroid) {
        Write-Host "Bỏ qua Android theo tham số -SkipAndroid." -ForegroundColor Yellow
        return
    }

    $android = @(Get-AndroidDevice)
    if ($android.Count -eq 0) {
        Write-Host "Không có Android device đang chạy; thử khởi động emulator đầu tiên..." -ForegroundColor Yellow
        $emulatorExe = Join-Path $env:LOCALAPPDATA "Android\Sdk\emulator\emulator.exe"
        $emulatorIds = @()
        if (Test-Path -LiteralPath $emulatorExe) {
            $emulatorIds = @(
                & $emulatorExe -list-avds |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
        }
        if ($emulatorIds.Count -gt 0) {
            Start-Process `
                -FilePath $emulatorExe `
                -ArgumentList @("-avd", $emulatorIds[0])
            for ($attempt = 1; $attempt -le 18; $attempt++) {
                Start-Sleep -Seconds 5
                $android = @(Get-AndroidDevice)
                if ($android.Count -gt 0) { break }
            }
        }
    }

    if ($android.Count -eq 0) {
        Write-Host "Chưa có Android emulator/điện thoại. Web vẫn đã mở; tạo emulator trong Android Studio Device Manager rồi chạy lại." -ForegroundColor Yellow
        return
    }

    $deviceId = $android[0].id
    $flutterPath = (Get-Command flutter.bat).Source
    Write-Host "Mở Flutter app trên Android device: $deviceId"
    Start-Process `
        -FilePath $flutterPath `
        -ArgumentList @(
            "run",
            "-d", $deviceId,
            "--dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1"
        ) `
        -WorkingDirectory $mobile
}

$startedAt = Get-Date

try {
    Write-Step "1/10 - Kiểm tra công cụ"
    foreach ($command in @("docker", "mvn.cmd", "node.exe", "npm.cmd", "flutter.bat")) {
        Require-Command $command
    }
    docker info | Out-Null
    Assert-LastExitCode "Docker Desktop"
    Ensure-LocalEnvironment

    if (Test-Path -LiteralPath "D:\DEV\Kit\jdk-21") {
        $env:JAVA_HOME = "D:\DEV\Kit\jdk-21"
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"
    }

    Write-Step "2/10 - Build và khởi động full stack Docker"
    Push-Location $root
    try {
        & docker compose @composeFiles up -d --build
        Assert-LastExitCode "docker compose up"
    } finally {
        Pop-Location
    }

    Write-Step "3/10 - Health check và WebSocket"
    Invoke-PowerShellScript (Join-Path $root "docker\scripts\health-check.ps1")
    & node.exe (Join-Path $root "docker\scripts\websocket-smoke.mjs")
    Assert-LastExitCode "WebSocket smoke"

    Write-Step "4/10 - Backend: unit/controller/MySQL integration"
    Push-Location $backend
    try {
        & mvn.cmd -q test
        Assert-LastExitCode "Backend Maven test"
    } finally {
        Pop-Location
    }

    Write-Step "5/10 - Frontend: cài dependency, lint và production build"
    Push-Location $frontend
    try {
        & npm.cmd ci
        Assert-LastExitCode "npm ci"
        & npm.cmd run lint
        Assert-LastExitCode "Frontend lint"
        & npm.cmd run build
        Assert-LastExitCode "Frontend production build"
    } finally {
        Pop-Location
    }

    Write-Step "6/10 - AI service: Docker test stage"
    & docker build --target test -t safefleet-ai-test:local $ai
    Assert-LastExitCode "AI Docker test build"
    & docker run --rm safefleet-ai-test:local
    Assert-LastExitCode "AI pytest"

    Write-Step "7/10 - Flutter: dependency, analyze, test và APK debug"
    Push-Location $mobile
    try {
        & flutter.bat pub get
        Assert-LastExitCode "flutter pub get"
        & flutter.bat analyze
        Assert-LastExitCode "flutter analyze"
        & flutter.bat test
        Assert-LastExitCode "flutter test"
        & flutter.bat build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
        Assert-LastExitCode "Flutter debug APK"
    } finally {
        Pop-Location
    }

    Write-Step "8/10 - Kiểm tra database dump"
    Invoke-PowerShellScript (Join-Path $root "docker\scripts\db-import-lint.ps1")
    if (-not $SkipDatabaseRestore) {
        Invoke-PowerShellScript (Join-Path $root "docker\scripts\db-verify-backup-restore.ps1")
    } else {
        Write-Host "Bỏ qua backup/restore theo tham số -SkipDatabaseRestore." -ForegroundColor Yellow
    }

    Write-Step "9/10 - Sinh lại báo cáo OpenAPI"
    & node.exe (Join-Path $root "docker\scripts\export-api-report.mjs")
    Assert-LastExitCode "Xuất báo cáo OpenAPI"

    Write-Step "10/10 - Mở giao diện thao tác"
    Start-Process "http://localhost:3000/login"
    Start-Process "http://localhost:8080/swagger-ui/index.html"
    Start-Process "http://localhost:9001"
    Start-AndroidInterface

    $elapsed = (Get-Date) - $startedAt
    Write-Host "`nTOÀN BỘ KIỂM TRA ĐÃ PASS." -ForegroundColor Green
    Write-Host ("Thời gian: {0:hh\:mm\:ss}" -f $elapsed)
    Write-Host "Web:     http://localhost:3000/login"
    Write-Host "Swagger: http://localhost:8080/swagger-ui/index.html"
    Write-Host "MinIO:   http://localhost:9001"
    Write-Host "Admin:   admin / 123456"
    Write-Host "Driver:  driver01 / 123456"
    Write-Host "Không dùng 'docker compose down -v' nếu muốn giữ dữ liệu."
} catch {
    Write-Host "`nDỪNG TẠI BƯỚC BỊ LỖI:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
