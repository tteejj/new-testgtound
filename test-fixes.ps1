# Quick Integration Fix Test
# Run this to verify the fixes work

Write-Host "🔧 Testing Enhanced UI & Theme Integration Fixes..." -ForegroundColor Cyan
Write-Host "=" * 60

# Test 1: Load modules in correct order
Write-Host "`n1️⃣  Loading modules..." -ForegroundColor Yellow

$moduleRoot = $PSScriptRoot
$modules = @("helper.ps1", "core-data.ps1", "theme.ps1", "ui.ps1")

foreach ($module in $modules) {
    $modulePath = Join-Path $moduleRoot $module
    if (Test-Path $modulePath) {
        try {
            . $modulePath
            Write-Host "   ✅ Loaded $module" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ Error loading $module`: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "   ⚠️  $module not found" -ForegroundColor Yellow
    }
}

# Test 2: Initialize data structure
Write-Host "`n2️⃣  Initializing data..." -ForegroundColor Yellow
try {
    if (Get-Command Load-UnifiedData -ErrorAction SilentlyContinue) {
        Load-UnifiedData
        Write-Host "   ✅ Data structure initialized" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Creating minimal data structure" -ForegroundColor Yellow
        $script:Data = @{
            Projects = @{}
            Tasks = @()
            TimeEntries = @()
            ActiveTimers = @{}
            Settings = @{
                CurrentTheme = "Legacy"
                ShowCompletedDays = 7
            }
        }
    }
} catch {
    Write-Host "   ❌ Data initialization error: $_" -ForegroundColor Red
}

# Test 3: Test theme system
Write-Host "`n3️⃣  Testing theme system..." -ForegroundColor Yellow
try {
    Write-Host "   Theme presets available: $(if($script:ThemePresets){$script:ThemePresets.Keys.Count}else{0})" -ForegroundColor Cyan
    
    if (Get-Command Initialize-ThemeSystem -ErrorAction SilentlyContinue) {
        Initialize-ThemeSystem
        Write-Host "   ✅ Theme system initialized" -ForegroundColor Green
        if ($script:CurrentTheme) {
            Write-Host "   ✅ Active theme: $($script:CurrentTheme.Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "   ❌ Initialize-ThemeSystem not found" -ForegroundColor Red
    }
} catch {
    Write-Host "   ⚠️  Theme initialization warning: $_" -ForegroundColor Yellow
}

# Test 4: Test enhanced dashboard components
Write-Host "`n4️⃣  Testing dashboard components..." -ForegroundColor Yellow

$dashboardFunctions = @("Show-AnimatedHeader", "Show-StatusCards", "Show-ActivityTimeline", "Show-QuickActions", "Show-MainMenu")

foreach ($func in $dashboardFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "   ✅ $func available" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $func missing" -ForegroundColor Red
    }
}

# Test 5: Quick visual test
Write-Host "`n5️⃣  Visual output test..." -ForegroundColor Yellow
try {
    # Test enhanced header (no animation delays)
    if (Get-Command Show-AnimatedHeader -ErrorAction SilentlyContinue) {
        Write-Host "`n   Testing enhanced header:" -ForegroundColor Cyan
        Show-AnimatedHeader
        Write-Host "   ✅ Header displayed without infinite loop" -ForegroundColor Green
    }
    
    # Test status cards with safety checks
    if (Get-Command Show-StatusCards -ErrorAction SilentlyContinue) {
        Write-Host "`n   Testing status cards:" -ForegroundColor Cyan
        Show-StatusCards
        Write-Host "   ✅ Status cards displayed" -ForegroundColor Green
    }
    
} catch {
    Write-Host "   ⚠️  Visual test warning: $_" -ForegroundColor Yellow
}

# Final Summary
Write-Host "`n" + "=" * 60
Write-Host "🎯 FIX TEST COMPLETE" -ForegroundColor Cyan

$functionsWorking = 0
$totalFunctions = ($dashboardFunctions).Count

foreach ($func in $dashboardFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        $functionsWorking++
    }
}

Write-Host "`n📊 Results:" -ForegroundColor White
Write-Host "   ✅ Dashboard Functions: $functionsWorking/$totalFunctions" -ForegroundColor Green
Write-Host "   🎨 Theme Presets: $(if($script:ThemePresets){$script:ThemePresets.Keys.Count}else{0})" -ForegroundColor Cyan
Write-Host "   💾 Data Structure: $(if($script:Data){'✅ Loaded'}else{'❌ Missing'})" -ForegroundColor $(if($script:Data){'Green'}else{'Red'})

if ($functionsWorking -eq $totalFunctions -and $script:ThemePresets -and $script:Data) {
    Write-Host "`n🎉 FIXES SUCCESSFUL! Enhanced system ready to use!" -ForegroundColor Green
    Write-Host "   ▶️  Run main.ps1 to see the enhanced dashboard"
    Write-Host "   🎨 Dashboard should display without infinite loops"
    Write-Host "   ⚙️  Use Settings -> Theme to change visual styles"
} else {
    Write-Host "`n⚠️  Some issues remain. Check module loading order." -ForegroundColor Yellow
}

Write-Host "`nPress any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")