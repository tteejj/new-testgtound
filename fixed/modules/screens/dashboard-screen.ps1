# Dashboard Screen - Main entry screen with overview

$script:DashboardScreen = @{
    Name = "Dashboard"
    State = @{
        LastUpdate = Get-Date
        RefreshTimer = $null
    }
    
    Init = {
        Write-TuiLog "Dashboard screen initialized" -Level Info
        
        # Subscribe to timer updates for live display
        $script:DashboardScreen.State.RefreshTimer = Subscribe-Event -EventName "Timer.Tick" -Handler {
            if ($script:TuiState.CurrentScreen.Name -eq "Dashboard") {
                Request-TuiRefresh
            }
        }
        
        # Subscribe to data changes
        Subscribe-Event -EventName "Task.Created" -Handler {
            if ($script:TuiState.CurrentScreen.Name -eq "Dashboard") {
                Request-TuiRefresh
            }
        }
        
        Subscribe-Event -EventName "TimeEntry.Created" -Handler {
            if ($script:TuiState.CurrentScreen.Name -eq "Dashboard") {
                Request-TuiRefresh
            }
        }
    }
    
    OnExit = {
        # Clean up subscriptions
        if ($script:DashboardScreen.State.RefreshTimer) {
            Unsubscribe-Event -EventName "Timer.Tick" -SubscriberId $script:DashboardScreen.State.RefreshTimer
            $script:DashboardScreen.State.RefreshTimer = $null
        }
        Clear-EventSubscriptions -EventName "Task.Created"
        Clear-EventSubscriptions -EventName "TimeEntry.Created"
    }
    
    Render = {
        $width = $script:TuiState.Width
        $height = $script:TuiState.Height
        
        # Header
        Write-BufferBox -X 0 -Y 0 -Width $width -Height 3 `
            -Title " PMC Terminal - Productivity Suite " `
            -BorderColor (Get-ThemeColor "Primary")
        
        # Date and time
        $dateStr = (Get-Date).ToString('dddd, MMMM dd, yyyy - HH:mm:ss')
        $dateX = $width - $dateStr.Length - 2
        Write-BufferString -X $dateX -Y 1 -Text $dateStr `
            -ForegroundColor (Get-ThemeColor "Subtle")
        
        # Main content area
        $contentY = 4
        
        # Today's overview section
        Render-TodayOverview -X 2 -Y $contentY -Width ($width - 4)
        
        # Active timers section
        $timersY = $contentY + 10
        Render-ActiveTimers -X 2 -Y $timersY -Width ($width - 4)
        
        # Menu at bottom
        $menuY = $height - 8
        Render-MainMenu -X 2 -Y $menuY -Width ($width - 4)
        
        # Status line
        Write-StatusLine -Text " Navigate: ↑↓ Select | Enter: Choose | /: Command Palette | +: Quick Actions | Q: Quit " `
            -ForegroundColor (Get-ThemeColor "Primary")
    }
    
    HandleInput = {
        param($Key)
        
        # Handle quick actions
        if ($Key.KeyChar -eq '+') {
            Push-Screen -Screen $script:QuickActionScreen
            return
        }
        
        # Handle command palette
        if ($Key.KeyChar -eq '/') {
            Push-Screen -Screen $script:CommandPaletteScreen
            return
        }
        
        # Direct shortcuts
        switch ($Key.Key) {
            ([ConsoleKey]::M) { Push-Screen -Screen $script:TimeEntryScreen }
            ([ConsoleKey]::S) { Push-Screen -Screen $script:TimerStartScreen }
            ([ConsoleKey]::A) { Push-Screen -Screen $script:TaskAddScreen }
            ([ConsoleKey]::V) { Push-Screen -Screen $script:ActiveTimersScreen }
            ([ConsoleKey]::T) { Push-Screen -Screen $script:TodayViewScreen }
            ([ConsoleKey]::W) { Push-Screen -Screen $script:WeekReportScreen }
            ([ConsoleKey]::P) { Push-Screen -Screen $script:ProjectDetailScreen }
            ([ConsoleKey]::H) { Push-Screen -Screen $script:HelpScreen }
            ([ConsoleKey]::Q) { Handle-Quit }
            
            # Menu navigation
            ([ConsoleKey]::D1) { Push-Screen -Screen $script:TimeManagementScreen }
            ([ConsoleKey]::D2) { Push-Screen -Screen $script:TaskManagementScreen }
            ([ConsoleKey]::D3) { Push-Screen -Screen $script:ReportsScreen }
            ([ConsoleKey]::D4) { Push-Screen -Screen $script:ProjectsScreen }
            ([ConsoleKey]::D5) { Push-Screen -Screen $script:ToolsScreen }
            ([ConsoleKey]::D6) { Push-Screen -Screen $script:SettingsScreen }
        }
        
        # Handle numeric keys without modifiers
        if ($Key.KeyChar -match '[1-6]') {
            $screens = @(
                $script:TimeManagementScreen,
                $script:TaskManagementScreen,
                $script:ReportsScreen,
                $script:ProjectsScreen,
                $script:ToolsScreen,
                $script:SettingsScreen
            )
            $index = [int]$Key.KeyChar.ToString() - 1
            if ($index -ge 0 -and $index -lt $screens.Count) {
                Push-Screen -Screen $screens[$index]
            }
        }
    }
}

# Helper functions for rendering sections
function Render-TodayOverview {
    param($X, $Y, $Width)
    
    Write-BufferBox -X $X -Y $Y -Width $Width -Height 8 `
        -Title " Today's Overview " `
        -BorderColor (Get-ThemeColor "Info")
    
    $innerY = $Y + 1
    
    # Time logged today
    $todayHours = Get-TotalHoursToday
    $targetHours = $script:Data.Settings.HoursPerDay
    $percent = if ($targetHours -gt 0) { 
        [Math]::Round(($todayHours / $targetHours) * 100, 0) 
    } else { 0 }
    
    Write-BufferString -X ($X + 2) -Y $innerY `
        -Text "⏱️  TIME LOGGED: " `
        -ForegroundColor (Get-ThemeColor "Warning")
    
    Write-BufferString -X ($X + 18) -Y $innerY `
        -Text "$todayHours hours ($percent% of $targetHours hour target)"
    
    # Tasks summary
    $innerY += 2
    $overdueTasks = Get-OverdueTasks
    $todayTasks = Get-TasksDueToday
    $activeTasks = Get-ActiveTasks
    
    if ($overdueTasks.Count -gt 0) {
        Write-BufferString -X ($X + 2) -Y $innerY `
            -Text "⚠️  OVERDUE: $($overdueTasks.Count) task(s)" `
            -ForegroundColor (Get-ThemeColor "Error")
        $innerY++
    }
    
    if ($todayTasks.Count -gt 0) {
        Write-BufferString -X ($X + 2) -Y $innerY `
            -Text "📋 DUE TODAY: $($todayTasks.Count) task(s)" `
            -ForegroundColor (Get-ThemeColor "Warning")
        $innerY++
    }
    
    Write-BufferString -X ($X + 2) -Y $innerY `
        -Text "✓ ACTIVE: $($activeTasks.Count) total task(s)" `
        -ForegroundColor (Get-ThemeColor "Success")
}

function Render-ActiveTimers {
    param($X, $Y, $Width)
    
    $timers = $script:Data.ActiveTimers
    $height = if ($timers.Count -gt 0) { [Math]::Min($timers.Count + 3, 8) } else { 4 }
    
    Write-BufferBox -X $X -Y $Y -Width $Width -Height $height `
        -Title " Active Timers " `
        -BorderColor (Get-ThemeColor "Warning")
    
    if ($timers.Count -eq 0) {
        Write-BufferString -X ($X + 2) -Y ($Y + 1) `
            -Text "No active timers" `
            -ForegroundColor (Get-ThemeColor "Subtle")
    }
    else {
        $innerY = $Y + 1
        foreach ($timer in $timers.GetEnumerator() | Select-Object -First 5) {
            $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
            $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
            $projectName = if ($project) { $project.Name } else { "Unknown" }
            
            $hours = [Math]::Floor($elapsed.TotalHours)
            $minutes = $elapsed.Minutes.ToString("00")
            $seconds = $elapsed.Seconds.ToString("00")
            
            Write-BufferString -X ($X + 2) -Y $innerY `
                -Text "→ $projectName " `
                -ForegroundColor (Get-ThemeColor "Info")
            
            Write-BufferString -X ($X + 25) -Y $innerY `
                -Text "${hours}:${minutes}:${seconds}" `
                -ForegroundColor (Get-ThemeColor "Success")
            
            $innerY++
        }
    }
}

function Render-MainMenu {
    param($X, $Y, $Width)
    
    # Quick actions
    Write-BufferString -X $X -Y $Y `
        -Text "QUICK ACTIONS: " `
        -ForegroundColor (Get-ThemeColor "Primary")
    
    Write-BufferString -X ($X + 15) -Y $Y `
        -Text "[M]anual Entry  [S]tart Timer  [A]dd Task  [V]iew Timers  [W]eek Report"
    
    # Main menu
    $menuY = $Y + 2
    Write-BufferString -X $X -Y $menuY `
        -Text "MAIN MENU:" `
        -ForegroundColor (Get-ThemeColor "Primary")
    
    $menuOptions = @(
        "[1] Time Management",
        "[2] Task Management", 
        "[3] Reports",
        "[4] Projects",
        "[5] Tools",
        "[6] Settings"
    )
    
    $menuY++
    $col1X = $X
    $col2X = $X + 25
    $col3X = $X + 50
    
    Write-BufferString -X $col1X -Y $menuY -Text $menuOptions[0]
    Write-BufferString -X $col2X -Y $menuY -Text $menuOptions[1]
    Write-BufferString -X $col3X -Y $menuY -Text $menuOptions[2]
    
    $menuY++
    Write-BufferString -X $col1X -Y $menuY -Text $menuOptions[3]
    Write-BufferString -X $col2X -Y $menuY -Text $menuOptions[4]
    Write-BufferString -X $col3X -Y $menuY -Text $menuOptions[5]
}

function Handle-Quit {
    # Check for active timers
    if ($script:Data.ActiveTimers -and $script:Data.ActiveTimers.Count -gt 0) {
        Push-Screen -Screen @{
            Name = "QuitConfirm"
            State = @{ }
            
            Render = {
                $width = 60
                $height = 10
                $x = ($script:TuiState.Width - $width) / 2
                $y = ($script:TuiState.Height - $height) / 2
                
                Write-BufferBox -X $x -Y $y -Width $width -Height $height `
                    -Title " Confirm Quit " `
                    -BorderColor (Get-ThemeColor "Warning")
                
                Write-BufferString -X ($x + 2) -Y ($y + 2) `
                    -Text "You have $($script:Data.ActiveTimers.Count) active timer(s) running!" `
                    -ForegroundColor (Get-ThemeColor "Warning")
                
                Write-BufferString -X ($x + 2) -Y ($y + 4) `
                    -Text "Stop all timers before quitting?" `
                    -ForegroundColor (Get-ThemeColor "Primary")
                
                Write-BufferString -X ($x + 2) -Y ($y + 6) `
                    -Text "[Y]es - Stop timers and quit"
                
                Write-BufferString -X ($x + 2) -Y ($y + 7) `
                    -Text "[N]o - Quit without stopping"
                
                Write-BufferString -X ($x + 2) -Y ($y + 8) `
                    -Text "[ESC] Cancel"
            }
            
            HandleInput = {
                param($Key)
                
                switch ($Key.Key) {
                    ([ConsoleKey]::Y) {
                        # Stop all timers
                        foreach ($timerKey in @($script:Data.ActiveTimers.Keys)) {
                            $timer = $script:Data.ActiveTimers[$timerKey]
                            $elapsed = (Get-Date) - [DateTime]$timer.StartTime
                            
                            # Create time entry
                            $entry = @{
                                Id = "TE-" + (Get-Random -Maximum 999999).ToString("D6")
                                ProjectKey = $timer.ProjectKey
                                Date = $timer.StartTime.ToString("yyyy-MM-dd")
                                Hours = [Math]::Round($elapsed.TotalHours, 2)
                                Description = $timer.Description
                                StartTime = $timer.StartTime.ToString("HH:mm")
                                EndTime = (Get-Date).ToString("HH:mm")
                                TimerGenerated = $true
                            }
                            
                            $script:Data.TimeEntries += $entry
                            $script:Data.ActiveTimers.Remove($timerKey)
                            
                            Publish-Event -EventName "Timer.Stopped" -Data @{ Timer = $timer; Entry = $entry }
                        }
                        
                        Save-UnifiedData
                        Exit-TuiLoop
                    }
                    ([ConsoleKey]::N) {
                        Save-UnifiedData
                        Exit-TuiLoop
                    }
                    ([ConsoleKey]::Escape) {
                        Pop-Screen
                    }
                }
            }
        }
    }
    else {
        Save-UnifiedData
        Exit-TuiLoop
    }
}
