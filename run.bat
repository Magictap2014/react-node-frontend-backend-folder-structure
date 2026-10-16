@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Project Configuration
REM ============================================================
set "PROJECT_DIR=%~dp0"
set "BACKEND_DIR=%PROJECT_DIR%backend"
set "FRONTEND_DIR=%PROJECT_DIR%frontend"

set "BACKEND_PORT=5010"
set "FRONTEND_PORT=5177"

set "BACKEND_HEALTH_PATH=/iocl-cube/api/health"
set "FRONTEND_PATH=/iocl-cube/"

set "BACKEND_URL=http://127.0.0.1:%BACKEND_PORT%%BACKEND_HEALTH_PATH%"
set "FRONTEND_LOCAL_URL=http://127.0.0.1:%FRONTEND_PORT%%FRONTEND_PATH%"

set "BACKEND_PID="
set "FRONTEND_PID="

title RFID Reader System - Startup

echo.
echo ============================================================
echo RFID READER SYSTEM
echo ============================================================
echo.

REM ============================================================
REM Validate Project Directories
REM ============================================================
if not exist "%BACKEND_DIR%\package.json" (
    echo ERROR: Backend package.json not found.
    echo Expected: %BACKEND_DIR%\package.json
    goto :fatal
)

if not exist "%FRONTEND_DIR%\package.json" (
    echo ERROR: Frontend package.json not found.
    echo Expected: %FRONTEND_DIR%\package.json
    goto :fatal
)

where node >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed or not in PATH.
    goto :fatal
)

where npm >nul 2>&1
if errorlevel 1 (
    echo ERROR: npm is not installed or not in PATH.
    goto :fatal
)

where curl >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl is required. Install a recent Windows version.
    goto :fatal
)

REM ============================================================
REM Release Existing Application Ports
REM ============================================================
echo Checking application ports...

call :release_port %BACKEND_PORT%
if errorlevel 1 goto :fatal

call :release_port %FRONTEND_PORT%
if errorlevel 1 goto :fatal

REM ============================================================
REM Backend Dependencies
REM ============================================================
echo.
echo Checking backend dependencies...

pushd "%BACKEND_DIR%" || goto :fatal

if not exist "node_modules" (
    echo Installing backend dependencies...
    call npm install
    if errorlevel 1 (
        popd
        echo ERROR: Backend npm install failed.
        goto :fatal
    )
) else (
    if not exist "package-lock.json" (
        echo package-lock.json not found; checking npm install...
        call npm install
        if errorlevel 1 (
            popd
            echo ERROR: Backend npm install failed.
            goto :fatal
        )
    ) else (
        if not exist "node_modules\.pkg_hash" (
            call npm install
            if errorlevel 1 (
                popd
                echo ERROR: Backend npm install failed.
                goto :fatal
            )
            call :save_hash "%BACKEND_DIR%"
        ) else (
            call :check_hash "%BACKEND_DIR%"
            if errorlevel 1 (
                echo Backend dependencies changed. Installing...
                call npm install
                if errorlevel 1 (
                    popd
                    echo ERROR: Backend npm install failed.
                    goto :fatal
                )
                call :save_hash "%BACKEND_DIR%"
            )
        )
    )
)

if not exist "node_modules\.pkg_hash" call :save_hash "%BACKEND_DIR%"

popd

REM ============================================================
REM Frontend Dependencies
REM ============================================================
echo.
echo Checking frontend dependencies...

pushd "%FRONTEND_DIR%" || goto :fatal

if not exist "node_modules" (
    echo Installing frontend dependencies...
    call npm install
    if errorlevel 1 (
        popd
        echo ERROR: Frontend npm install failed.
        goto :fatal
    )
) else (
    if not exist "package-lock.json" (
        call npm install
        if errorlevel 1 (
            popd
            echo ERROR: Frontend npm install failed.
            goto :fatal
        )
    ) else (
        if not exist "node_modules\.pkg_hash" (
            call npm install
            if errorlevel 1 (
                popd
                echo ERROR: Frontend npm install failed.
                goto :fatal
            )
            call :save_hash "%FRONTEND_DIR%"
        ) else (
            call :check_hash "%FRONTEND_DIR%"
            if errorlevel 1 (
                echo Frontend dependencies changed. Installing...
                call npm install
                if errorlevel 1 (
                    popd
                    echo ERROR: Frontend npm install failed.
                    goto :fatal
                )
                call :save_hash "%FRONTEND_DIR%"
            )
        )
    )
)

if not exist "node_modules\.pkg_hash" call :save_hash "%FRONTEND_DIR%"

popd

REM ============================================================
REM Start Backend
REM ============================================================
echo.
echo Starting backend on port %BACKEND_PORT%...

REM A separate process keeps the backend running independently.
start "RFID Backend" /D "%BACKEND_DIR%" cmd /k "npm run dev -- --host 0.0.0.0"

REM ============================================================
REM Wait for Backend
REM ============================================================
echo Waiting for backend health check...

set "BACKEND_READY=0"

for /L %%I in (1,1,60) do (
    curl -fsS "%BACKEND_URL%" >nul 2>&1
    if not errorlevel 1 (
        set "BACKEND_READY=1"
        goto :backend_ready
    )
    timeout /t 1 /nobreak >nul
)

:backend_ready

if "!BACKEND_READY!"=="0" (
    echo ERROR: Backend did not become ready within 60 seconds.
    echo Health URL: %BACKEND_URL%
    goto :fatal
)

echo Backend is ready.

REM ============================================================
REM Start Frontend
REM ============================================================
echo.
echo Starting Vite frontend on port %FRONTEND_PORT%...

start "RFID Frontend" /D "%FRONTEND_DIR%" cmd /k "npm run dev -- --host 0.0.0.0 --port %FRONTEND_PORT% --strictPort"

REM ============================================================
REM Wait for Frontend
REM ============================================================
echo Waiting for frontend...

set "FRONTEND_READY=0"

for /L %%I in (1,1,60) do (
    curl -fsS "%FRONTEND_LOCAL_URL%" >nul 2>&1
    if not errorlevel 1 (
        set "FRONTEND_READY=1"
        goto :frontend_ready
    )
    timeout /t 1 /nobreak >nul
)

:frontend_ready

if "!FRONTEND_READY!"=="0" (
    echo ERROR: Frontend did not become ready within 60 seconds.
    echo Frontend URL: %FRONTEND_LOCAL_URL%
    goto :fatal
)

echo Frontend is ready.

REM ============================================================
REM Detect LAN IPv4 Address
REM ============================================================
set "NETWORK_IP="

for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /C:"IPv4 Address"') do (
    if not defined NETWORK_IP (
        for /f "tokens=*" %%B in ("%%A") do set "NETWORK_IP=%%B"
    )
)

if not defined NETWORK_IP (
    echo WARNING: Could not detect LAN IP. Using localhost.
    set "NETWORK_IP=127.0.0.1"
)

set "KIOSK_URL=http://!NETWORK_IP!:%FRONTEND_PORT%%FRONTEND_PATH%"

REM ============================================================
REM Display Application URLs
REM ============================================================
echo.
echo ============================================================
echo APPLICATION STARTED SUCCESSFULLY
echo ============================================================
echo Network IP: !NETWORK_IP!
echo.
echo Kiosk URL:  !KIOSK_URL!
echo Frontend:   http://!NETWORK_IP!:%FRONTEND_PORT%%FRONTEND_PATH%
echo Backend:    http://!NETWORK_IP!:%BACKEND_PORT%
echo Health:     http://!NETWORK_IP!:%BACKEND_PORT%%BACKEND_HEALTH_PATH%
echo.
echo ============================================================
echo.

REM ============================================================
REM Open Kiosk Browser
REM ============================================================
echo Opening kiosk browser...

where chrome.exe >nul 2>&1
if not errorlevel 1 (
    start "" chrome.exe --kiosk --noerrdialogs --disable-infobars --no-first-run --start-fullscreen "!KIOSK_URL!"
    goto :browser_opened
)

where msedge.exe >nul 2>&1
if not errorlevel 1 (
    start "" msedge.exe --kiosk --no-first-run "!KIOSK_URL!"
    goto :browser_opened
)

where chromium.exe >nul 2>&1
if not errorlevel 1 (
    start "" chromium.exe --kiosk --noerrdialogs --disable-infobars --no-first-run --start-fullscreen "!KIOSK_URL!"
    goto :browser_opened
)

echo WARNING: Chrome, Edge, or Chromium was not found in PATH.
echo Open this URL manually:
echo !KIOSK_URL!

:browser_opened

REM ============================================================
REM Keep Services Running
REM ============================================================
echo.
echo Backend and frontend are running in separate windows.
echo Their console windows display service logs.
echo.
echo Press Ctrl+C here to exit this launcher.
echo Close the Backend and Frontend windows to stop the services.
echo.

:monitor
curl -fsS "%BACKEND_URL%" >nul 2>&1
if errorlevel 1 (
    echo WARNING: Backend health check failed.
)

curl -fsS "%FRONTEND_LOCAL_URL%" >nul 2>&1
if errorlevel 1 (
    echo WARNING: Frontend health check failed.
)

timeout /t 5 /nobreak >nul
goto :monitor

REM ============================================================
REM Functions
REM ============================================================

:release_port
set "PORT_TO_FREE=%~1"

for /f "tokens=5" %%P in ('netstat -ano -p tcp ^| findstr /R /C:":%PORT_TO_FREE% .*LISTENING"') do (
    if not "%%P"=="0" (
        echo Releasing port %PORT_TO_FREE% ^(PID %%P^)...
        taskkill /PID %%P /T /F >nul 2>&1
    )
)

exit /b 0

:save_hash
set "HASH_DIR=%~1"

if exist "%HASH_DIR%\package-lock.json" (
    certutil -hashfile "%HASH_DIR%\package.json" MD5 > "%HASH_DIR%\node_modules\.pkg_hash.tmp"
    certutil -hashfile "%HASH_DIR%\package-lock.json" MD5 >> "%HASH_DIR%\node_modules\.pkg_hash.tmp"
    findstr /R /C:"^[0-9a-fA-F][0-9a-fA-F]* " "%HASH_DIR%\node_modules\.pkg_hash.tmp" > "%HASH_DIR%\node_modules\.pkg_hash"
    del "%HASH_DIR%\node_modules\.pkg_hash.tmp" >nul 2>&1
)
exit /b 0

:check_hash
set "HASH_DIR=%~1"

if not exist "%HASH_DIR%\node_modules\.pkg_hash" exit /b 1

certutil -hashfile "%HASH_DIR%\package.json" MD5 > "%TEMP%\rfid_pkg_hash.tmp"
certutil -hashfile "%HASH_DIR%\package-lock.json" MD5 >> "%TEMP%\rfid_pkg_hash.tmp"

findstr /R /C:"^[0-9a-fA-F][0-9a-fA-F]* " "%TEMP%\rfid_pkg_hash.tmp" > "%TEMP%\rfid_pkg_hash_actual.tmp"

fc /B "%HASH_DIR%\node_modules\.pkg_hash" "%TEMP%\rfid_pkg_hash_actual.tmp" >nul 2>&1
set "HASH_RESULT=!ERRORLEVEL!"

del "%TEMP%\rfid_pkg_hash.tmp" "%TEMP%\rfid_pkg_hash_actual.tmp" >nul 2>&1

if not "!HASH_RESULT!"=="0" exit /b 1
exit /b 0

:fatal
echo.
echo ============================================================
echo STARTUP FAILED
echo ============================================================
echo Check the error messages above.
echo.
pause
exit /b 1