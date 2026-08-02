param(
    [string]$InputPath = "SAFEEFLEET_FULL_DATABASE.sql"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$source = (Resolve-Path (Join-Path $root $InputPath)).Path
$temporaryDatabase = "safefleet_import_lint_20260727"
$temporaryHostFile = Join-Path $root "backups\safefleet-import-lint.sql"
$temporaryContainerFile = "/tmp/safefleet-import-lint.sql"

if ($temporaryDatabase -notmatch '^safefleet_import_lint_[a-z0-9_]+$') {
    throw "Tên database kiểm tra không an toàn."
}
if (-not $source.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "File SQL phải nằm trong workspace SafeFleet."
}

function Invoke-MySqlContainer {
    param([Parameter(Mandatory = $true)][string]$Command)

    $encodedCommand = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes($Command)
    )
    $dockerArguments = @(
        "compose", "exec", "-T", "mysql", "sh", "-c",
        'echo$IFS"$1"|base64$IFS-d|sh',
        "safefleet",
        $encodedCommand
    )
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & docker @dockerArguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw (($output | ForEach-Object { "$_" }) -join "`n")
    }
    return $output
}

Push-Location $root
try {
    $sql = [IO.File]::ReadAllText($source)
    $temporarySql = $sql.Replace('`safefleet`', ('`' + $temporaryDatabase + '`'))
    if ($temporarySql -eq $sql) {
        throw "Không tìm thấy database safefleet trong dump."
    }
    [IO.File]::WriteAllText(
        $temporaryHostFile,
        $temporarySql,
        [Text.UTF8Encoding]::new($false)
    )

    docker compose cp $temporaryHostFile "mysql:$temporaryContainerFile" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Không thể copy dump kiểm tra vào MySQL container."
    }

    $output = Invoke-MySqlContainer -Command (
        'mysql --show-warnings --default-character-set=utf8mb4 ' +
        '-uroot -p"$MYSQL_ROOT_PASSWORD" < "' + $temporaryContainerFile + '"'
    )
    $warnings = @($output | Where-Object { "$_" -match '^(Warning|Note|Error)' })

    [pscustomobject]@{
        Success = $true
        Input = $source
        TemporaryDatabase = $temporaryDatabase
        WarningCount = $warnings.Count
        Warnings = ($warnings -join " | ")
    }
} finally {
    try {
        Invoke-MySqlContainer -Command (
            'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS ' +
            $temporaryDatabase + '"'
        ) | Out-Null
        Invoke-MySqlContainer -Command ('rm -f -- "' + $temporaryContainerFile + '"') | Out-Null
    } finally {
        if (Test-Path -LiteralPath $temporaryHostFile) {
            Remove-Item -Force -LiteralPath $temporaryHostFile
        }
        Pop-Location
    }
}
