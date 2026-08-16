param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$source = (Resolve-Path (Join-Path $root $InputPath)).Path
if (-not $source.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "File SQL phải nằm trong workspace SafeFleet."
}
$suffix = [guid]::NewGuid().ToString("N").Substring(0, 12)
$temporaryDatabase = "safefleet_import_lint_$suffix"
$temporaryContainerFile = "/tmp/$temporaryDatabase.sql"

Push-Location $root
try {
    docker compose exec -T postgres sh -c "PGPASSWORD=`"`$POSTGRES_PASSWORD`" dropdb --if-exists -U `"`$POSTGRES_USER`" '$temporaryDatabase'"
    docker compose exec -T postgres sh -c "PGPASSWORD=`"`$POSTGRES_PASSWORD`" createdb -U `"`$POSTGRES_USER`" '$temporaryDatabase'"
    docker compose cp $source "postgres:$temporaryContainerFile"
    if ($LASTEXITCODE -ne 0) { throw "Không thể copy SQL vào PostgreSQL container." }
    $output = docker compose exec -T postgres sh -c "PGPASSWORD=`"`$POSTGRES_PASSWORD`" psql -v ON_ERROR_STOP=1 -U `"`$POSTGRES_USER`" -d '$temporaryDatabase' -f '$temporaryContainerFile'" 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($output | ForEach-Object { "$_" }) -join "`n") }
    [pscustomobject]@{ Success=$true; Input=$source; TemporaryDatabase=$temporaryDatabase; OutputLines=@($output).Count }
} finally {
    docker compose exec -T postgres sh -c "PGPASSWORD=`"`$POSTGRES_PASSWORD`" dropdb --if-exists -U `"`$POSTGRES_USER`" '$temporaryDatabase'" 2>$null | Out-Null
    docker compose exec -T postgres rm -f -- $temporaryContainerFile 2>$null | Out-Null
    Pop-Location
}
