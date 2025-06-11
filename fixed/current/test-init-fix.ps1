# Test script to verify initialization fixes
Clear-Host
Write-Host "Testing PMC Terminal v3.0 initialization fixes..." -ForegroundColor Cyan
Write-Host ""

# Set error action preference to see all errors
$ErrorActionPreference = "Stop"

try {
    # Test the initialization order
    Write-Host "Starting PMC Terminal..." -ForegroundColor Green
    & ".\main.ps1"
} catch {
    Write-Host "Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace
    
    # Pause to see the error
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
