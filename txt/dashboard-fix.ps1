# Dashboard Fix - Replace the Show-Dashboard function to prevent endless clearing
# This replaces the problematic Show-Dashboard function with error handling

function global:Show-Dashboard {
    try {
        Clear-Host
        
        # Simple header fallback
        try {
            if (Get-Command Show-AnimatedHeader -ErrorAction SilentlyContinue) {
                Show-AnimatedHeader
            } else {
                Write-Host "="*80 -ForegroundColor Cyan
                Write-Host "  UNIFIED PRODUCTIVITY SUITE v5.0" -ForegroundColor Yellow
                Write-Host "="*80 -ForegroundColor Cyan
                Write-Host
            }
        } catch {
            Write-Host "="*80 -ForegroundColor Cyan
            Write-Host "  UNIFIED PRODUCTIVITY SUITE v5.0" -ForegroundColor Yellow
            Write-Host "="*80 -ForegroundColor Cyan
            Write-Host
        }
        
        # Simple status display fallback
        try {
            if (Get-Command Show-StatusCards -ErrorAction SilentlyContinue) {
                Show-StatusCards
            } else {
                Show-BasicStatus
            }
        } catch {
            Show-BasicStatus
        }
        
        # Simple timeline fallback
        try {
            if (Get-Command Show-ActivityTimeline -ErrorAction SilentlyContinue) {
                Show-ActivityTimeline
            }
        } catch {
            # Skip timeline if it fails
        }
        
        # Simple quick actions fallback
        try {
            if (Get-Command Show-QuickActions -ErrorAction SilentlyContinue) {
                Show-QuickActions
            } else {
                Show-BasicQuickActions
            }
        } catch {
            Show-BasicQuickActions
        }
        
        # Simple menu fallback
        try {
            if (Get-Command Show-MainMenu -ErrorAction SilentlyContinue) {
                Show-MainMenu
            } else {
                Show-BasicMainMenu
            }
        } catch {
            Show-BasicMainMenu
        }
        
    } catch {
        # Ultimate fallback - basic text menu
        Clear-Host
        Write-Host "UNIFIED PRODUCTIVITY SUITE v5.0" -ForegroundColor Yellow
        Write-Host "-"*50
        Write-Host
        Show-BasicStatus
        Show-BasicQuickActions  
        Show-BasicMainMenu
    }
}

function global:Show-BasicStatus {
    if ($script:Data) {
        $activeTimers = if ($script:Data.ActiveTimers) { $script:Data.ActiveTimers.Count } else { 0 }
        $activeTasks = if ($script:Data.Tasks) { ($script:Data.Tasks | Where-Object { (-not $_.Completed) -and ($_.IsCommand -ne $true) }).Count } else { 0 }
        $todayHours = 0.0
        if ($script:Data.TimeEntries) {
            $todayHours = ($script:Data.TimeEntries | Where-Object { $_.Date -eq (Get-Date).ToString("yyyy-MM-dd") } | Measure-Object -Property Hours -Sum).Sum
            $todayHours = if ($todayHours) { [Math]::Round($todayHours, 2) } else { 0.0 }
        }
        
        Write-Host "Status: Today: $(Get-Date -Format 'MMM dd, yyyy') | Hours: $todayHours | Active Timers: $activeTimers | Pending Tasks: $activeTasks" -ForegroundColor Green
    } else {
        Write-Host "Status: Loading..." -ForegroundColor Yellow
    }
    Write-Host
}

function global:Show-BasicQuickActions {
    Write-Host "Quick Actions:" -ForegroundColor Cyan
    Write-Host "  [M] Manual Entry   [S] Start Timer   [A] Add Task   [V] View Timers"
    Write-Host "  [T] Today View     [W] Week Report   [P] Projects   [H] Help"
    Write-Host
}

function global:Show-BasicMainMenu {
    Write-Host "Main Menu:" -ForegroundColor Cyan
    Write-Host "  [1] Time Management    [2] Task Management    [3] Reports & Analytics"
    Write-Host "  [4] Projects & Clients [5] Tools & Utilities  [6] Settings & Config"
    Write-Host "  [Q] Quit"
    Write-Host
}
