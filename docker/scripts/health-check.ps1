$ErrorActionPreference = "Stop"
$checks = @(
    @{ Name = "backend"; Url = "http://localhost:8080/actuator/health" },
    @{ Name = "frontend"; Url = "http://localhost:3000" },
    @{ Name = "ai-service"; Url = "http://localhost:8000/health" },
    @{ Name = "minio"; Url = "http://localhost:9000/minio/health/live" }
)

foreach ($check in $checks) {
    $response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Uri $check.Url
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
        throw "$($check.Name) unhealthy: HTTP $($response.StatusCode)"
    }
    Write-Host "PASS $($check.Name) HTTP $($response.StatusCode)"
}
