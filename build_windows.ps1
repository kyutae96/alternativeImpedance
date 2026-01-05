# ===========================================
# Impedance Monitor - Windows Build Script (PowerShell)
# ===========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Impedance Monitor - Windows Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>&1
    Write-Host "[OK] Flutter found" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Flutter SDK not found!" -ForegroundColor Red
    Write-Host "Please install Flutter and add it to PATH." -ForegroundColor Yellow
    Write-Host "Download: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 1: Check environment
Write-Host ""
Write-Host "[1/5] Checking Flutter environment..." -ForegroundColor Yellow
flutter doctor -v | Select-String "Windows"

# Step 2: Clean previous build
Write-Host ""
Write-Host "[2/5] Cleaning previous build..." -ForegroundColor Yellow
flutter clean

# Step 3: Get dependencies
Write-Host ""
Write-Host "[3/5] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to get dependencies!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 4: Build Windows Release
Write-Host ""
Write-Host "[4/5] Building Windows Release..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..." -ForegroundColor Gray
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Step 5: Complete
Write-Host ""
Write-Host "[5/5] Build completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Build Output Location:" -ForegroundColor Cyan
Write-Host " build\windows\x64\runner\Release\" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create portable package
$releaseDir = "build\windows\x64\runner\Release"
$outputZip = "ImpedanceMonitor_Windows_Portable.zip"

Write-Host "Creating portable package..." -ForegroundColor Yellow
if (Test-Path $outputZip) {
    Remove-Item $outputZip
}
Compress-Archive -Path $releaseDir\* -DestinationPath $outputZip -Force
Write-Host "[OK] Created: $outputZip" -ForegroundColor Green

# Open output folder
Start-Process explorer.exe -ArgumentList $releaseDir

Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Gray
Read-Host
