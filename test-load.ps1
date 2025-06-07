# Test script to check if modules load without parser errors
Write-Host "Testing module loading..." -ForegroundColor Yellow

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    $scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

Write-Host "Loading helper.ps1..." -ForegroundColor Green
try {
    . "$scriptRoot\helper.ps1"
    Write-Host "✓ helper.ps1 loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ helper.ps1 failed: $_" -ForegroundColor Red
}

Write-Host "Loading fuzzy.ps1..." -ForegroundColor Green
try {
    . "$scriptRoot\fuzzy.ps1"
    Write-Host "✓ fuzzy.ps1 loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ fuzzy.ps1 failed: $_" -ForegroundColor Red
}

Write-Host "Loading core-data.ps1..." -ForegroundColor Green
try {
    . "$scriptRoot\core-data.ps1"
    Write-Host "✓ core-data.ps1 loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ core-data.ps1 failed: $_" -ForegroundColor Red
}

Write-Host "Loading fb.ps1..." -ForegroundColor Green
try {
    . "$scriptRoot\fb.ps1"
    Write-Host "✓ fb.ps1 loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ fb.ps1 failed: $_" -ForegroundColor Red
}

# Test if functions are available
Write-Host "`nTesting function availability:" -ForegroundColor Yellow
$functions = @("Get-DefaultSettings", "Add-TodoTask", "Add-Project", "New-TodoId")
foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "✓ $func is available" -ForegroundColor Green
    } else {
        Write-Host "✗ $func is NOT available" -ForegroundColor Red
    }
}
