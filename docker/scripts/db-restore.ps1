param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$resolvedInput = Resolve-Path -LiteralPath $InputPath
if ((Get-Item -LiteralPath $resolvedInput).Length -lt 1024) {
    throw "File backup nhỏ bất thường; từ chối restore để tránh mất dữ liệu."
}
$answer = Read-Host "Restore sẽ ghi đè dữ liệu logic trong DB hiện tại. Nhập RESTORE-SAFEFLEET để xác nhận"
if ($answer -cne "RESTORE-SAFEFLEET") {
    Write-Host "Đã hủy restore."
    exit 0
}

$containerBackup = "/tmp/safefleet-restore-$([guid]::NewGuid().ToString('N')).sql"
function Invoke-ContainerShell {
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
    & docker @dockerArguments
    return $LASTEXITCODE
}

Push-Location $root
try {
    docker compose cp $resolvedInput "mysql:$containerBackup"
    if ($LASTEXITCODE -ne 0) {
        throw "Không thể copy file backup vào MySQL container."
    }
    $restoreCommand = 'exec mysql --default-character-set=utf8mb4 -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" < "' +
        $containerBackup + '"'
    $restoreExitCode = Invoke-ContainerShell -Command $restoreCommand
    if ($restoreExitCode -ne 0) {
        throw "Restore thất bại với exit code $restoreExitCode."
    }
    Write-Host "Đã restore từ: $resolvedInput"
} finally {
    $cleanupCommand = 'rm -f -- "' + $containerBackup + '"'
    Invoke-ContainerShell -Command $cleanupCommand 2>$null | Out-Null
    Pop-Location
}
