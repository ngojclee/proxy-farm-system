@echo off
echo Starting 3proxy on Windows...

REM Check if 3proxy.exe exists
if not exist "D:\Python\proxy-farm-system\bin\3proxy.exe" (
    echo ERROR: 3proxy.exe not found in bin directory!
    echo Please download 3proxy for Windows from https://github.com/3proxy/3proxy/releases
    echo Extract 3proxy.exe to D:\Python\proxy-farm-system\bin\
    pause
    exit /b 1
)

REM Create logs directory if not exists
if not exist "D:\Python\proxy-farm-system\logs\3proxy" (
    mkdir "D:\Python\proxy-farm-system\logs\3proxy"
)

REM Kill any existing 3proxy process
taskkill /F /IM 3proxy.exe >nul 2>&1

REM Start 3proxy with Windows config
echo Starting 3proxy with Windows configuration...
cd /d "D:\Python\proxy-farm-system"
start "3proxy" /B bin\3proxy.exe configs\3proxy\3proxy-windows.cfg

REM Wait a moment
timeout /t 3 /nobreak >nul

REM Check if 3proxy is running
tasklist /FI "IMAGENAME eq 3proxy.exe" 2>NUL | find /I /N "3proxy.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo SUCCESS: 3proxy is running!
    echo.
    echo Proxy endpoints:
    echo - HTTP Proxy: localhost:3330-3334 (with auth)
    echo - SOCKS5 Proxy: localhost:3335-3337 (with auth)  
    echo - HTTP Proxy: localhost:3338 (no auth)
    echo - SOCKS5 Proxy: localhost:3339 (no auth)
    echo.
    echo Test with: curl --proxy-user admin:admin123 -x localhost:3330 http://httpbin.org/ip
) else (
    echo ERROR: 3proxy failed to start!
    echo Check logs at D:\Python\proxy-farm-system\logs\3proxy\3proxy.log
)

pause