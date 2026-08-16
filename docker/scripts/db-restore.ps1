param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
if ((Get-Item -LiteralPath $resolvedInput).Length -lt 1024) {
    throw "File backup nhỏ bất thường; từ chối restore."
}
$answer = Read-Host "Restore sẽ ghi đè dữ liệu logic trong PostgreSQL hiện tại. Nhập RESTORE-SAFEFLEET để xác nhận"
if ($answer -cne "RESTORE-SAFEFLEET") { Write-Host "Đã hủy restore."; exit 0 }

$containerBackup = "/tmp/safefleet-restore-$([guid]::NewGuid().ToString('N')).dump"
Push-Location $root
try {
    docker compose cp $resolvedInput "postgres:$containerBackup"
    if ($LASTEXITCODE -ne 0) { throw "Không thể copy backup vào PostgreSQL container." }
    docker compose exec -T postgres sh -c "PGPASSWORD=`"`$POSTGRES_PASSWORD`" pg_restore --clean --if-exists --no-owner --no-acl -U `"`$POSTGRES_USER`" -d `"`$POSTGRES_DB`" '$containerBackup'"
    if ($LASTEXITCODE -ne 0) { throw "pg_restore thất bại với exit code $LASTEXITCODE." }
    Write-Host "Đã restore PostgreSQL từ: $resolvedInput"
} finally {
    docker compose exec -T postgres rm -f -- $containerBackup 2>$null | Out-Null
    Pop-Location
}
