$ErrorActionPreference = 'Stop'

$java = 'D:\DEV\Kit\jdk-21\bin\java.exe'
$jar = Join-Path $PSScriptRoot 'target\safefleet-backend-0.0.1-SNAPSHOT.jar'
$dbUrl = 'jdbc:mysql://localhost:3306/QuanLyCongViecDuAn?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Ho_Chi_Minh'

& $java `
    "-Dspring.datasource.url=$dbUrl" `
    '-Dspring.datasource.username=admin123@' `
    '-Dspring.datasource.password=admin123@' `
    '-jar' `
    $jar
