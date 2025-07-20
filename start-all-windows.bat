@echo off
echo =====================================
echo Starting Proxy Farm System on Windows
echo =====================================
echo.

echo [1] Starting Flask Webapp...
start /B call start-webapp-windows.bat

echo Waiting for webapp to initialize...
timeout /t 5 /nobreak >nul

echo.
echo [2] Starting 3proxy...
call start-3proxy-windows.bat

echo.
echo =====================================
echo Proxy Farm System Started!
echo =====================================
echo.
echo Dashboard: http://localhost:5000
echo.
echo Default credentials:
echo Username: admin
echo Password: admin123
echo.
echo Proxy endpoints:
echo - HTTP: localhost:3330-3334 (auth required)
echo - SOCKS5: localhost:3335-3337 (auth required)
echo - HTTP: localhost:3338 (no auth)
echo - SOCKS5: localhost:3339 (no auth)
echo.
pause