@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: OpenCode Server - Headless, Static IP, Auto-Startup
:: Right-click -> Run as Administrator (once), then runs on boot
:: ============================================================

set "LOGFILE=%TEMP%\opencode-server.log"
echo [%date% %time%] ======================================== >> "%LOGFILE%"
echo [%date% %time%] Starting OpenCode Server on port 4098 >> "%LOGFILE%"

:: Add to Windows Startup
set "STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUP_FILE=%STARTUP_DIR%\start-opencode-server.bat"
if not exist "%STARTUP_FILE%" (
    copy /y "%~f0" "%STARTUP_FILE%" >nul 2>&1
    echo [%date% %time%] Added to Windows Startup >> "%LOGFILE%"
)

:: Kill any existing process on port 4098
echo [%date% %time%] Freeing port 4098 >> "%LOGFILE%"
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":4098" ^| findstr LISTENING') do (
    taskkill /PID %%p /F >nul 2>&1
    timeout /t 2 /nobreak >nul
)

:: Set static IP
set "ADAPTER=Wi-Fi"
set "STATIC_IP=192.168.1.7"
set "MASK=255.255.255.0"
set "GATEWAY=192.168.1.1"
set "DNS=8.8.8.8"

echo [%date% %time%] Setting static IP %STATIC_IP% on %ADAPTER% >> "%LOGFILE%"
netsh interface ip set address name="%ADAPTER%" static %STATIC_IP% %MASK% %GATEWAY% 1 >> "%LOGFILE%" 2>&1
netsh interface ip set dns name="%ADAPTER%" static %DNS% primary >> "%LOGFILE%" 2>&1

:: Start OpenCode server headless
echo [%date% %time%] Launching opencode serve on port 4098 >> "%LOGFILE%"
set "OPENCODE_SERVER_PASSWORD=LOL"
start /b "" opencode serve --hostname 0.0.0.0 --port 4098

timeout /t 3 /nobreak >nul

:: Verify
netstat -ano | findstr ":4098" | findstr LISTENING >nul 2>&1
if %errorlevel% == 0 (
    echo [%date% %time%] [OK] Server running on port 4098 >> "%LOGFILE%"
    echo [%date% %time%] Mobile: 192.168.1.7:4098 ^| User: opencode ^| Pass: LOL >> "%LOGFILE%"
) else (
    echo [%date% %time%] [ERROR] Server failed to start >> "%LOGFILE%"
)

echo [%date% %time%] ======================================== >> "%LOGFILE%"
exit /b
