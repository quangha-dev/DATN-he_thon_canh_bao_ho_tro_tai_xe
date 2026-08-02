param(
    [string]$InputPath = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Invoke-MySqlContainer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [switch]$Capture
    )

    # Windows PowerShell 5 splits a dynamic `sh -c` argument on spaces even
    # when it is supplied as one array item. Base64 keeps every argument
    # whitespace-free and lets the container shell reconstruct it byte-for-byte.
    $encodedCommand = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes($Command)
    )
    $dockerArguments = @(
        "compose", "exec", "-T", "mysql", "sh", "-c",
        'echo$IFS"$1"|base64$IFS-d|sh',
        "safefleet",
        $encodedCommand
    )
    $output = & docker @dockerArguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Lệnh MySQL container thất bại với exit code $exitCode."
    }
    if ($Capture) {
        return (($output | ForEach-Object { "$_" }) -join "`n").Trim()
    }
}

Push-Location $root
try {
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        & (Join-Path $PSScriptRoot "db-backup.ps1")
        $backup = Get-ChildItem -LiteralPath (Join-Path $root "backups") -Filter "safefleet-*.sql" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    } else {
        $backup = Get-Item -LiteralPath (Resolve-Path -LiteralPath $InputPath)
    }

    if ($null -eq $backup -or $backup.Length -lt 1024) {
        throw "Không tìm thấy file backup hợp lệ để kiểm tra."
    }

    $suffix = [guid]::NewGuid().ToString("N").Substring(0, 16)
    $temporaryDatabase = "safefleet_restore_verify_$suffix"
    $containerBackup = "/tmp/safefleet-restore-verify-$suffix.sql"
    $copied = $false

    try {
        Invoke-MySqlContainer -Command (
            'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS ' +
            $temporaryDatabase + '"'
        )
        Invoke-MySqlContainer -Command (
            'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE ' +
            $temporaryDatabase +
            ' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"'
        )

        docker compose cp $backup.FullName "mysql:$containerBackup"
        if ($LASTEXITCODE -ne 0) {
            throw "Không thể copy backup vào MySQL container."
        }
        $copied = $true

        Invoke-MySqlContainer -Command (
            'mysql --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD" ' +
            $temporaryDatabase + ' < "' + $containerBackup + '"'
        )

        $signatureSql = @(
            "SELECT COUNT(*) FROM users",
            "SELECT COUNT(*) FROM drivers",
            "SELECT COUNT(*) FROM vehicles",
            "SELECT COUNT(*) FROM trips",
            "SELECT COUNT(*) FROM safety_events",
            "SELECT COUNT(*) FROM incidents",
            "SELECT COUNT(*) FROM flood_reports",
            "SELECT COUNT(*) FROM safety_event_evidence",
            "SELECT COUNT(*) FROM mobile_command_receipts",
            "SELECT MAX(CAST(version AS UNSIGNED)) FROM flyway_schema_history",
            "SELECT COALESCE(MAX(id),0) FROM flood_reports",
            "SELECT COALESCE(MAX(id),0) FROM safety_event_evidence"
        ) -join "; "
        $signatureSql += ";"

        $sourceSignature = Invoke-MySqlContainer -Capture -Command (
            'mysql -N -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "' +
            $signatureSql + '"'
        )
        $restoredSignature = Invoke-MySqlContainer -Capture -Command (
            'mysql -N -uroot -p"$MYSQL_ROOT_PASSWORD" ' +
            $temporaryDatabase + ' -e "' + $signatureSql + '"'
        )

        if ($sourceSignature -cne $restoredSignature) {
            throw "Chữ ký dữ liệu restore không khớp database nguồn."
        }

        [pscustomobject]@{
            Success = $true
            BackupPath = $backup.FullName
            BackupBytes = $backup.Length
            BackupSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $backup.FullName).Hash.ToLowerInvariant()
            SourceSignature = $sourceSignature -replace "`n", "|"
            RestoredSignature = $restoredSignature -replace "`n", "|"
            TemporaryDatabase = $temporaryDatabase
        }
    } finally {
        Invoke-MySqlContainer -Command (
            'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS ' +
            $temporaryDatabase + '"'
        )
        if ($copied) {
            Invoke-MySqlContainer -Command ('rm -f -- "' + $containerBackup + '"')
        }
    }
} finally {
    Pop-Location
}
