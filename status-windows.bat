@echo off
echo ===================================
echo Proxy Farm System Status (Windows)
echo ===================================
echo.

echo [1] Checking Flask Webapp...
REM Check if Python webapp is running
netstat -an | findstr :5000 >nul
if %errorlevel%==0 (
    echo [+] Webapp is listening on port 5000
) else (
    echo [-] Webapp is NOT running on port 5000
)

echo.
echo [2] Checking 3proxy...
tasklist /FI "IMAGENAME eq 3proxy.exe" 2>NUL | find /I /N "3proxy.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [+] 3proxy process is running
    
    echo.
    echo [3] Checking proxy ports:
    for %%p in (3330 3331 3332 3333 3334 3335 3336 3337 3338 3339) do (
        netstat -an | findstr :%%p | findstr LISTENING >nul
        if !errorlevel!==0 (
            echo [+] Port %%p is listening
        ) else (
            echo [-] Port %%p is NOT listening
        )
    )
) else (
    echo [-] 3proxy is NOT running!
)

echo.
echo [4] Testing proxy connectivity...
curl --connect-timeout 5 --proxy-user admin:admin123 -x localhost:3330 http://httpbin.org/ip 2>nul
if %errorlevel%==0 (
    echo [+] Proxy test successful!
) else (
    echo [-] Proxy test failed!
)

echo.
echo ===================================
pause