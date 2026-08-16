$ErrorActionPreference = 'Stop'

$java = 'D:\DEV\Kit\jdk-21\bin\java.exe'
$jar = Join-Path $PSScriptRoot 'target\safefleet-backend-0.0.1-SNAPSHOT.jar'
$dbUrl = if ($env:DB_URL) { $env:DB_URL } else { 'jdbc:postgresql://localhost:5432/safefleet' }
$dbUsername = if ($env:DB_USERNAME) { $env:DB_USERNAME } else { 'safefleet' }
if (-not $env:DB_PASSWORD) {
    throw 'DB_PASSWORD is required.'
}

& $java `
    "-Dspring.datasource.url=$dbUrl" `
    "-Dspring.datasource.username=$dbUsername" `
    "-Dspring.datasource.password=$($env:DB_PASSWORD)" `
    '-jar' `
    $jar
