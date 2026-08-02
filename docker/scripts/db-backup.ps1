param(
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $backupDir = Join-Path $root "backups"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $OutputPath = Join-Path $backupDir ("safefleet-{0}.sql" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}

$resolvedParent = Resolve-Path (Split-Path -Parent $OutputPath)
$safeOutput = Join-Path $resolvedParent (Split-Path -Leaf $OutputPath)
Push-Location $root
try {
    docker compose exec -T mysql sh -c 'exec mysqldump --no-tablespaces --single-transaction --quick --routines --triggers --events --hex-blob --set-gtid-purged=OFF --default-character-set=utf8mb4 -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' |
        Set-Content -Encoding utf8 -LiteralPath $safeOutput
    $dumpExitCode = $LASTEXITCODE
    if ($dumpExitCode -ne 0) {
        if (Test-Path -LiteralPath $safeOutput) {
            Remove-Item -Force -LiteralPath $safeOutput
        }
        throw "mysqldump thất bại với exit code $dumpExitCode; file backup chưa hoàn chỉnh đã được xóa."
    }
    if ((Get-Item -LiteralPath $safeOutput).Length -lt 1024) {
        Remove-Item -Force -LiteralPath $safeOutput
        throw "File backup nhỏ bất thường; đã xóa để tránh restore nhầm dữ liệu không đầy đủ."
    }
    Write-Host "Backup: $safeOutput"
} finally {
    Pop-Location
}
