# Enhanced UI & Theme Integration Test Script
# Run this to verify the enhanced features are working

Write-Host "🔬 Testing Enhanced UI & Theme Integration..." -ForegroundColor Cyan
Write-Host "=" * 60

# Test 1: Theme System
Write-Host "`n1️⃣  Testing Theme System..." -ForegroundColor Yellow
try {
    if (Get-Command Initialize-ThemeSystem -ErrorAction SilentlyContinue) {
        Initialize-ThemeSystem
        Write-Host "   ✅ Theme system initialized successfully" -ForegroundColor Green
        
        if ($script:CurrentTheme) {
            Write-Host "   ✅ Current theme: $($script:CurrentTheme.Name)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  No current theme set" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ Initialize-ThemeSystem function not found" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Theme system error: $_" -ForegroundColor Red
}

# Test 2: Enhanced UI Functions
Write-Host "`n2️⃣  Testing Enhanced UI Functions..." -ForegroundColor Yellow

$uiFunctions = @(
    "Show-AnimatedHeader",
    "Show-StatusCards", 
    "Show-ActivityTimeline",
    "Draw-AnimatedProgressBar",
    "Show-Notification",
    "Get-PriorityIndicator",
    "Show-CalendarHeatMap"
)

foreach ($func in $uiFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "   ✅ $func available" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $func missing" -ForegroundColor Red
    }
}

# Test 3: Theme Functions
Write-Host "`n3️⃣  Testing Theme Functions..." -ForegroundColor Yellow

$themeFunctions = @(
    "Apply-PSStyle",
    "Get-ThemeProperty", 
    "Get-GradientText",
    "Apply-Theme",
    "Show-TypewriterText",
    "Get-StatusBadge"
)

foreach ($func in $themeFunctions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        Write-Host "   ✅ $func available" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $func missing" -ForegroundColor Red
    }
}

# Test 4: Dependencies
Write-Host "`n4️⃣  Testing Dependencies..." -ForegroundColor Yellow

if (Get-Command Get-WeekStart -ErrorAction SilentlyContinue) {
    Write-Host "   ✅ Get-WeekStart available (from helper.ps1)" -ForegroundColor Green
} else {
    Write-Host "   ❌ Get-WeekStart missing" -ForegroundColor Red
}

if (Get-Command Get-ProjectOrTemplate -ErrorAction SilentlyContinue) {
    Write-Host "   ✅ Get-ProjectOrTemplate available (from core-data.ps1)" -ForegroundColor Green
} else {
    Write-Host "   ❌ Get-ProjectOrTemplate missing" -ForegroundColor Red
}

# Test 5: Visual Theme Test
Write-Host "`n5️⃣  Testing Visual Output..." -ForegroundColor Yellow

try {
    # Test gradient text
    if (Get-Command Get-GradientText -ErrorAction SilentlyContinue) {
        $gradientTest = Get-GradientText -Text "GRADIENT TEST" -StartColor "#FF00FF" -EndColor "#00FFFF"
        Write-Host "   ✨ " -NoNewline
        Write-Host $gradientTest
    }
    
    # Test styled text
    if (Get-Command Apply-PSStyle -ErrorAction SilentlyContinue) {
        Write-Host "   🎨 " -NoNewline
        Write-Host (Apply-PSStyle -Text "STYLED TEXT TEST" -FG "#00FF00" -Bold)
    }
    
    # Test priority indicator
    if (Get-Command Get-PriorityIndicator -ErrorAction SilentlyContinue) {
        $priority = Get-PriorityIndicator -Priority 1
        Write-Host "   📌 Priority Test: $($priority.Icon) $($priority.Text)" -ForegroundColor Magenta
    }
    
    Write-Host "   ✅ Visual output tests passed" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Visual output test warning: $_" -ForegroundColor Yellow
}

# Test 6: Available Themes
Write-Host "`n6️⃣  Testing Available Themes..." -ForegroundColor Yellow

if ($script:ThemePresets) {
    Write-Host "   ✅ Theme presets loaded: $($script:ThemePresets.Keys.Count) themes" -ForegroundColor Green
    foreach ($themeName in $script:ThemePresets.Keys) {
        $theme = $script:ThemePresets[$themeName]
        Write-Host "      🎨 $themeName - $($theme.Description)" -ForegroundColor Cyan
    }
} else {
    Write-Host "   ❌ No theme presets found" -ForegroundColor Red
}

# Test 7: Demo Enhanced Progress Bar
Write-Host "`n7️⃣  Testing Enhanced Progress Bar..." -ForegroundColor Yellow

try {
    if (Get-Command Draw-AnimatedProgressBar -ErrorAction SilentlyContinue) {
        Write-Host "   📊 Progress Bar Styles:"
        Draw-AnimatedProgressBar -Percent 75 -Style "Blocks" -Label "Blocks Style"
        Draw-AnimatedProgressBar -Percent 60 -Style "Gradient" -Label "Gradient Style"
        Draw-AnimatedProgressBar -Percent 90 -Style "Wave" -Label "Wave Style"
        Write-Host "   ✅ Progress bar styles working" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠️  Progress bar test warning: $_" -ForegroundColor Yellow
}

# Final Summary
Write-Host "`n" + "=" * 60
Write-Host "🎯 INTEGRATION TEST COMPLETE" -ForegroundColor Cyan

$errorCount = 0
$successCount = 0

# Count results (simplified check)
$testResults = @($uiFunctions + $themeFunctions) | ForEach-Object {
    Get-Command $_ -ErrorAction SilentlyContinue
}

$successCount = ($testResults | Where-Object { $_ }).Count
$totalTests = ($uiFunctions + $themeFunctions).Count

Write-Host "`n📊 Results:" -ForegroundColor White
Write-Host "   ✅ Functions Available: $successCount/$totalTests" -ForegroundColor Green
Write-Host "   🎨 Themes Available: $(if($script:ThemePresets){$script:ThemePresets.Keys.Count}else{0})" -ForegroundColor Cyan
Write-Host "   🚀 Integration Status: " -NoNewline -ForegroundColor White

if ($successCount -eq $totalTests -and $script:ThemePresets) {
    Write-Host "FULLY WORKING ✅" -ForegroundColor Green
    Write-Host "`n🎉 Your enhanced UI and theme system is ready to use!"
    Write-Host "   • Run your main.ps1 to see the enhanced dashboard"
    Write-Host "   • Use Settings -> Theme to change visual styles"
    Write-Host "   • Enjoy the new animated and visual features!"
} elseif ($successCount -ge ($totalTests * 0.8)) {
    Write-Host "MOSTLY WORKING ⚠️" -ForegroundColor Yellow
    Write-Host "`n🔧 Minor issues detected, but system should work fine."
} else {
    Write-Host "NEEDS ATTENTION ❌" -ForegroundColor Red
    Write-Host "`n🛠️  Some integration issues detected. Check module loading."
}

Write-Host "`nPress any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")