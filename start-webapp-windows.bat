@echo off
echo Starting ProxyFarm Webapp on Windows...

REM Navigate to project directory
cd /d D:\Python\proxy-farm-system

REM Check if virtual environment exists
if not exist "webapp\venv" (
    echo Creating Python virtual environment...
    python -m venv webapp\venv
)

REM Activate virtual environment
call webapp\venv\Scripts\activate.bat

REM Install requirements if needed
echo Installing/updating requirements...
pip install flask python-dotenv requests

REM Set environment variables
set FLASK_APP=webapp/app.py
set FLASK_ENV=development

REM Kill any existing Flask process on port 5000
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :5000 ^| findstr LISTENING') do (
    taskkill /F /PID %%a >nul 2>&1
)

REM Start Flask webapp
echo Starting Flask webapp...
cd webapp
start "ProxyFarm Webapp" /B python app.py

echo.
echo Webapp should be starting...
echo Access the dashboard at: http://localhost:5000
echo.
echo Press any key to exit (webapp will continue running in background)
pause >nul