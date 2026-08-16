@echo off
setlocal

set "ROOT=%~dp0"
set "JAVA=D:\DEV\Kit\jdk-21\bin\java.exe"
set "JAR=%ROOT%target\safefleet-backend-0.0.1-SNAPSHOT.jar"
set "LOG_DIR=%ROOT%runtime-logs"
if not defined DB_URL set "DB_URL=jdbc:postgresql://localhost:5432/safefleet"
if not defined DB_USERNAME set "DB_USERNAME=safefleet"

if not defined DB_PASSWORD (
  echo DB_PASSWORD is required.
  exit /b 1
)

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

"%JAVA%" "-Dspring.datasource.url=%DB_URL%" "-Dspring.datasource.username=%DB_USERNAME%" "-Dspring.datasource.password=%DB_PASSWORD%" -jar "%JAR%" >> "%LOG_DIR%\backend-local.log" 2>&1
