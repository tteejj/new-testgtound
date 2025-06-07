# Test Command Palette Debug Script

Write-Host "Testing Command Palette..." -ForegroundColor Yellow

# Load the modules first
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    $scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

# Load required modules
. "$scriptRoot\helper.ps1"
. "$scriptRoot\fuzzy.ps1"  
. "$scriptRoot\core-data.ps1"
. "$scriptRoot\theme.ps1"
. "$scriptRoot\command-palette.ps1"

Write-Host "`n1. Testing fuzzy similarity function..." -ForegroundColor Green
$sim1 = Get-FuzzySimilarity -String1 "Add Task" -String2 "add"
$sim2 = Get-FuzzySimilarity -String1 "Add Manual Time Entry" -String2 "add"
Write-Host "   'Add Task' vs 'add': $sim1%" -ForegroundColor Cyan
Write-Host "   'Add Manual Time Entry' vs 'add': $sim2%" -ForegroundColor Cyan

Write-Host "`n2. Testing command registry initialization..." -ForegroundColor Green
Initialize-CommandRegistry
Write-Host "   Commands registered: $($script:CommandRegistry.Count)" -ForegroundColor Cyan

if ($script:CommandRegistry.Count -gt 0) {
    Write-Host "`n3. First few registered commands:" -ForegroundColor Green
    $script:CommandRegistry | Select-Object -First 5 | ForEach-Object {
        Write-Host "   - $($_.Name): $($_.SearchText)" -ForegroundColor Gray
    }
    
    Write-Host "`n4. Testing search for 'add'..." -ForegroundColor Green
    $filtered = @()
    foreach ($command in $script:CommandRegistry) {
        $maxSimilarity = Get-FuzzySimilarity -String1 $command.SearchText -String2 "add"
        if ($maxSimilarity -ge 40) { 
            Write-Host "   Found: $($command.Name) - Score: $maxSimilarity%" -ForegroundColor Cyan
            $filtered += $command 
        }
    }
    
    if ($filtered.Count -eq 0) {
        Write-Host "   No commands found with 40% threshold" -ForegroundColor Red
        Write-Host "`n5. Testing with lower threshold (20%)..." -ForegroundColor Green
        foreach ($command in $script:CommandRegistry) {
            $maxSimilarity = Get-FuzzySimilarity -String1 $command.SearchText -String2 "add"
            if ($maxSimilarity -ge 20) { 
                Write-Host "   Found: $($command.Name) - Score: $maxSimilarity%" -ForegroundColor Yellow
            }
        }
    }
} else {
    Write-Host "   ERROR: No commands were registered!" -ForegroundColor Red
}
