# Quick test script to verify the dashboard fix
# Run this to test if the endless clearing is resolved

Write-Host "Testing dashboard fix..." -ForegroundColor Yellow

# Load the fixed modules
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    $scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

# Source the ui module with the fix
if (Test-Path "$scriptRoot\ui.ps1") {
    . "$scriptRoot\ui.ps1"
    Write-Host "UI module loaded successfully" -ForegroundColor Green
} else {
    Write-Error "ui.ps1 not found in $scriptRoot"
    exit
}

# Initialize minimal data structure for testing
$script:Data = @{
    ActiveTimers = @{}
    Tasks = @()
    TimeEntries = @()
    Settings = @{}
}

Write-Host "Testing Show-Dashboard function..." -ForegroundColor Yellow

try {
    Show-Dashboard
    Write-Host "`nDashboard test completed successfully!" -ForegroundColor Green
    Write-Host "The endless clearing issue should now be resolved." -ForegroundColor Green
} catch {
    Write-Error "Dashboard test failed: $_"
}

Write-Host "`nPress any key to exit test..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
