param([string]$InputPath = "")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Invoke-Postgres {
    param([Parameter(Mandatory = $true)][string]$Command, [switch]$Capture)
    $output = docker compose exec -T postgres sh -c $Command
    if ($LASTEXITCODE -ne 0) { throw "Lệnh PostgreSQL container thất bại với exit code $LASTEXITCODE." }
    if ($Capture) { return (($output | ForEach-Object { "$_" }) -join "`n").Trim() }
}

Push-Location $root
try {
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        & (Join-Path $PSScriptRoot "db-backup.ps1")
        $backup = Get-ChildItem -LiteralPath (Join-Path $root "backups") -Filter "safefleet-*.dump" |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    } else {
        $backup = Get-Item -LiteralPath (Resolve-Path -LiteralPath $InputPath)
    }
    if ($null -eq $backup -or $backup.Length -lt 1024) { throw "Không tìm thấy backup hợp lệ." }

    $suffix = [guid]::NewGuid().ToString("N").Substring(0, 16)
    $temporaryDatabase = "safefleet_restore_verify_$suffix"
    $containerBackup = "/tmp/$temporaryDatabase.dump"
    try {
        Invoke-Postgres -Command "PGPASSWORD=`"`$POSTGRES_PASSWORD`" dropdb --if-exists -U `"`$POSTGRES_USER`" '$temporaryDatabase'"
        Invoke-Postgres -Command "PGPASSWORD=`"`$POSTGRES_PASSWORD`" createdb -U `"`$POSTGRES_USER`" '$temporaryDatabase'"
        docker compose cp $backup.FullName "postgres:$containerBackup"
        if ($LASTEXITCODE -ne 0) { throw "Không thể copy backup vào PostgreSQL container." }
        Invoke-Postgres -Command "PGPASSWORD=`"`$POSTGRES_PASSWORD`" pg_restore --no-owner --no-acl -U `"`$POSTGRES_USER`" -d '$temporaryDatabase' '$containerBackup'"

        $signatureSql = "SELECT COUNT(*) FROM users; SELECT COUNT(*) FROM drivers; SELECT COUNT(*) FROM vehicles; SELECT COUNT(*) FROM trips; SELECT COUNT(*) FROM safety_events; SELECT COUNT(*) FROM incidents; SELECT COUNT(*) FROM flood_reports; SELECT COALESCE(MAX(version::integer),0) FROM flyway_schema_history;"
        $sourceSignature = Invoke-Postgres -Capture -Command "PGPASSWORD=`"`$POSTGRES_PASSWORD`" psql -At -U `"`$POSTGRES_USER`" -d `"`$POSTGRES_DB`" -c '$signatureSql'"
        $restoredSignature = Invoke-Postgres -Capture -Command "PGPASSWORD=`"`$POSTGRES_PASSWORD`" psql -At -U `"`$POSTGRES_USER`" -d '$temporaryDatabase' -c '$signatureSql'"
        if ($sourceSignature -cne $restoredSignature) { throw "Chữ ký dữ liệu restore không khớp database nguồn." }

        [pscustomobject]@{ Success=$true; BackupPath=$backup.FullName; BackupBytes=$backup.Length; BackupSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $backup.FullName).Hash.ToLowerInvariant(); SourceSignature=$sourceSignature -replace "`n","|"; RestoredSignature=$restoredSignature -replace "`n","|"; TemporaryDatabase=$temporaryDatabase }
    } finally {
        Invoke-Postgres -Command "PGPASSWORD=`"`$POSTGRES_PASSWORD`" dropdb --if-exists -U `"`$POSTGRES_USER`" '$temporaryDatabase'"
        docker compose exec -T postgres rm -f -- $containerBackup 2>$null | Out-Null
    }
} finally { Pop-Location }
