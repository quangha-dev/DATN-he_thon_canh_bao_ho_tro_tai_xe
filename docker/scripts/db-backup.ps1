param([string]$OutputPath = "")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $backupDir = Join-Path $root "backups"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $OutputPath = Join-Path $backupDir ("safefleet-{0}.dump" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}
$resolvedParent = (Resolve-Path (Split-Path -Parent $OutputPath)).Path
$safeOutput = Join-Path $resolvedParent (Split-Path -Leaf $OutputPath)
$containerBackup = "/tmp/safefleet-backup-$([guid]::NewGuid().ToString('N')).dump"

Push-Location $root
try {
    docker compose exec -T postgres sh -c "PGPASSWORD=`"`$POSTGRES_PASSWORD`" pg_dump --format=custom --no-owner --no-acl -U `"`$POSTGRES_USER`" -d `"`$POSTGRES_DB`" -f '$containerBackup'"
    if ($LASTEXITCODE -ne 0) { throw "pg_dump thất bại với exit code $LASTEXITCODE." }
    docker compose cp "postgres:$containerBackup" $safeOutput
    if ($LASTEXITCODE -ne 0) { throw "Không thể copy backup PostgreSQL ra máy host." }
    if ((Get-Item -LiteralPath $safeOutput).Length -lt 1024) {
        throw "File backup nhỏ bất thường; từ chối sử dụng."
    }
    Write-Host "Backup PostgreSQL: $safeOutput"
} finally {
    docker compose exec -T postgres rm -f -- $containerBackup 2>$null | Out-Null
    Pop-Location
}
