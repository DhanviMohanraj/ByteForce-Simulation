@echo off
REM NAND Guardian - Quick Setup Script (Windows)
REM This script automates the initial setup of NAND Guardian frontend

echo.
echo 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x
echo NAND Guardian - Frontend Setup
echo 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x 0x
echo.

REM Check Node.js
echo Checking Node.js...
node -v >nul 2>&1
if errorlevel 1 (
    echo.
    echo X Node.js is not installed
    echo Install from: https://nodejs.org/
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('node -v') do set NODE_VERSION=%%i
echo + Node.js %NODE_VERSION%

REM Check npm
echo Checking npm...
for /f "tokens=*" %%i in ('npm -v') do set NPM_VERSION=%%i
echo + npm %NPM_VERSION%

echo.
echo Installing dependencies...
call npm install
if errorlevel 1 (
    echo.
    echo X Failed to install dependencies
    pause
    exit /b 1
)
echo + Dependencies installed

echo.
echo + Setup Complete!
echo.
echo Next Steps:
echo.
echo   1. Start development server:
echo      npm run dev
echo.
echo   2. Open in browser:
echo      http://localhost:5173
echo.
echo   3. To connect to backend API:
echo      - Start your backend on http://localhost:8000
echo      - Click 'Mock Mode' toggle in the header to switch to 'API Mode'
echo.
echo Documentation:
echo   - README.md                  (Project overview and features)
echo   - BACKEND_INTEGRATION.md     (For ML/backend engineers)
echo   - STRUCTURE.md               (Architecture and components)
echo.
echo Tips:
echo   - npm run build              (Production build)
echo   - npm run preview            (Preview production build)
echo   - Check tailwind.config.js   (Customize colors/theme)
echo.
echo Happy coding! 
echo.
pause
