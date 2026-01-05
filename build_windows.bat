@echo off
REM ===========================================
REM Impedance Monitor - Windows Build Script
REM ===========================================

echo.
echo ========================================
echo  Impedance Monitor - Windows Build
echo ========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter SDK not found!
    echo Please install Flutter and add it to PATH.
    echo Download: https://flutter.dev/docs/get-started/install/windows
    pause
    exit /b 1
)

echo [1/5] Checking Flutter environment...
flutter doctor -v | findstr "Windows"
echo.

echo [2/5] Cleaning previous build...
flutter clean

echo [3/5] Getting dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to get dependencies!
    pause
    exit /b 1
)

echo [4/5] Building Windows Release...
flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

echo [5/5] Build completed successfully!
echo.
echo ========================================
echo  Build Output Location:
echo  build\windows\x64\runner\Release\
echo ========================================
echo.

REM Open output folder
explorer build\windows\x64\runner\Release

echo.
echo Press any key to exit...
pause >nul
