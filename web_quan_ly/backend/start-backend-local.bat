@echo off
setlocal

set "ROOT=%~dp0"
set "JAVA=D:\DEV\Kit\jdk-21\bin\java.exe"
set "JAR=%ROOT%target\safefleet-backend-0.0.1-SNAPSHOT.jar"
set "LOG_DIR=%ROOT%runtime-logs"
set "DB_URL=jdbc:mysql://localhost:3306/QuanLyCongViecDuAn?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Ho_Chi_Minh"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

"%JAVA%" "-Dspring.datasource.url=%DB_URL%" "-Dspring.datasource.username=admin123@" "-Dspring.datasource.password=admin123@" -jar "%JAR%" >> "%LOG_DIR%\backend-local.log" 2>&1
