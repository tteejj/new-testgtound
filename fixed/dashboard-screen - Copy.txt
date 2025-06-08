# Main Dashboard Screen Module
# Implements the main dashboard using the TUI engine

$script:MainDashboardScreen = @{
    Name = "MainDashboard"
    State = @{
        SelectedMenuItem = 0
        MenuItems = @(
            @{ Key = "1"; Label = "Time Management"; Icon = "⏰" }
            @{ Key = "2"; Label = "Task Management"; Icon = "📋" }
            @{ Key = "3"; Label = "Reports & Analytics"; Icon = "📈" }
            @{ Key = "4"; Label = "Projects & Clients"; Icon = "🏢" }
            @{ Key = "5"; Label = "Tools & Utilities"; Icon = "🔧" }
            @{ Key = "6"; Label = "Settings & Config"; Icon = "⚙️" }
        )
        QuickActions = @(
            @{ Key = "M"; Label = "Manual Entry"; Icon = "📝" }
            @{ Key = "S"; Label = "Start Timer"; Icon = "▶️" }
            @{ Key = "A"; Label = "Add Task"; Icon = "➕" }
            @{ Key = "V"; Label = "View Timers"; Icon = "👁️" }
            @{ Key = "T"; Label = "Today View"; Icon = "📅" }
            @{ Key = "W"; Label = "Week Report"; Icon = "📊" }
        )
    }
    
    Init = {
        Write-StatusLine -Text " Unified Productivity Suite v5.0 | Use ↑↓ to navigate, Enter to select, Q to quit"
    }
    
    Render = {
        $state = $script:MainDashboardScreen.State
        
        # Render header
        Render-DashboardHeader
        
        # Render status cards
        Render-StatusCards -Y 10
        
        # Render activity timeline  
        Render-ActivityTimeline -Y 16
        
        # Render quick actions
        Render-QuickActions -Y 20
        
        # Render main menu
        Render-MainMenu -Y 26 -Selected $state.SelectedMenuItem
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:MainDashboardScreen.State
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                $state.SelectedMenuItem = [Math]::Max(0, $state.SelectedMenuItem - 1)
            }
            ([ConsoleKey]::DownArrow) {
                $state.SelectedMenuItem = [Math]::Min($state.MenuItems.Count - 1, $state.SelectedMenuItem + 1)
            }
            ([ConsoleKey]::Enter) {
                $selected = $state.MenuItems[$state.SelectedMenuItem]
                Handle-MenuSelection -Key $selected.Key
            }
            ([ConsoleKey]::Escape) {
                return "Quit"
            }
            ([ConsoleKey]::Q) {
                if (-not $Key.Modifiers) { return "Quit" }
            }
            default {
                # Handle direct menu selection
                $menuKey = $Key.KeyChar.ToString().ToUpper()
                $menuItem = $state.MenuItems | Where-Object { $_.Key -eq $menuKey } | Select-Object -First 1
                if ($menuItem) {
                    Handle-MenuSelection -Key $menuItem.Key
                }
                
                # Handle quick actions
                $quickAction = $state.QuickActions | Where-Object { $_.Key -eq $menuKey } | Select-Object -First 1
                if ($quickAction) {
                    Handle-QuickAction -Key $quickAction.Key
                }
            }
        }
    }
}

function Render-DashboardHeader {
    $headerLines = @(
        "╔═══════════════════════════════════════════════════════════════════════╗",
        "║  ██╗   ██╗███╗   ██╗██╗███████╗██╗███████╗██████╗     ██╗   ██╗███████╗ ║",
        "║  ██║   ██║████╗  ██║██║██╔════╝██║██╔════╝██╔══██╗    ██║   ██║██╔════╝ ║",
        "║  ██║   ██║██╔██╗ ██║██║█████╗  ██║█████╗  ██║  ██║    ██║   ██║███████╗ ║",
        "║  ██║   ██║██║╚██╗██║██║██╔══╝  ██║██╔══╝  ██║  ██║    ╚██╗ ██╔╝╚════██║ ║",
        "║  ╚██████╔╝██║ ╚████║██║██║     ██║███████╗██████╔╝     ╚████╔╝ ███████║ ║",
        "║   ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝     ╚═╝╚══════╝╚═════╝       ╚═══╝  ╚══════╝ ║",
        "║                  🚀 PRODUCTIVITY SUITE v5.0 TURBO 🚀                     ║",
        "╚═══════════════════════════════════════════════════════════════════════╝"
    )
    
    $colors = @(
        [ConsoleColor]::DarkCyan,
        [ConsoleColor]::Cyan,
        [ConsoleColor]::Cyan,
        [ConsoleColor]::Cyan,
        [ConsoleColor]::Cyan,
        [ConsoleColor]::Cyan,
        [ConsoleColor]::Cyan,
        [ConsoleColor]::Yellow,
        [ConsoleColor]::DarkCyan
    )
    
    $startX = ([Console]::WindowWidth - 75) / 2
    
    for ($i = 0; $i -lt $headerLines.Count; $i++) {
        Write-BufferString -X $startX -Y $i -Text $headerLines[$i] -ForegroundColor $colors[$i]
    }
}

function Render-StatusCards {
    param([int]$Y)
    
    # Get data for cards
    $activeTimers = if ($script:Data.ActiveTimers) { $script:Data.ActiveTimers.Count } else { 0 }
    $activeTasks = if ($script:Data.Tasks) { 
        ($script:Data.Tasks | Where-Object { (-not $_.Completed) -and ($_.IsCommand -ne $true) }).Count 
    } else { 0 }
    $todayHours = 0.0
    if ($script:Data.TimeEntries) {
        $todayHours = ($script:Data.TimeEntries | Where-Object { 
            $_.Date -eq (Get-Date).ToString("yyyy-MM-dd") 
        } | Measure-Object -Property Hours -Sum).Sum
        $todayHours = if ($todayHours) { [Math]::Round($todayHours, 2) } else { 0.0 }
    }
    
    $cards = @(
        @{ Icon = "📅"; Title = "TODAY"; Value = (Get-Date).ToString("MMM dd"); Subtitle = (Get-Date).ToString("dddd") },
        @{ Icon = "⏱️"; Title = "HOURS"; Value = "$todayHours"; Subtitle = "logged today" },
        @{ Icon = "⏰"; Title = "TIMERS"; Value = "$activeTimers"; Subtitle = "active" },
        @{ Icon = "✅"; Title = "TASKS"; Value = "$activeTasks"; Subtitle = "pending" }
    )
    
    $cardWidth = 18
    $totalWidth = ($cardWidth * 4) + 3
    $startX = ([Console]::WindowWidth - $totalWidth) / 2
    
    # Draw cards
    for ($i = 0; $i -lt $cards.Count; $i++) {
        $card = $cards[$i]
        $x = $startX + ($i * ($cardWidth + 1))
        
        # Determine color based on value
        $color = [ConsoleColor]::White
        if ($i -eq 1) { # Hours
            $color = if ($todayHours -ge 6) { [ConsoleColor]::Green } else { [ConsoleColor]::Yellow }
        }
        elseif ($i -eq 2) { # Timers
            $color = if ($activeTimers -gt 0) { [ConsoleColor]::Red } else { [ConsoleColor]::DarkGray }
        }
        elseif ($i -eq 3) { # Tasks
            $color = if ($activeTasks -gt 10) { [ConsoleColor]::Red } 
                     elseif ($activeTasks -gt 5) { [ConsoleColor]::Yellow } 
                     else { [ConsoleColor]::Green }
        }
        
        # Draw card box
        Write-BufferBox -X $x -Y $Y -Width $cardWidth -Height 5 -BorderColor $color
        
        # Draw card content
        Write-BufferString -X ($x + 2) -Y ($Y + 1) -Text "$($card.Icon) $($card.Title)" -ForegroundColor $color
        Write-BufferString -X ($x + 2) -Y ($Y + 2) -Text $card.Value -ForegroundColor $color
        Write-BufferString -X ($x + 2) -Y ($Y + 3) -Text $card.Subtitle -ForegroundColor [ConsoleColor]::DarkGray
    }
}

function Render-ActivityTimeline {
    param([int]$Y)
    
    $title = "📊 ACTIVITY TIMELINE"
    $startX = ([Console]::WindowWidth - 60) / 2
    
    Write-BufferString -X $startX -Y $Y -Text $title -ForegroundColor [ConsoleColor]::Magenta
    
    if (-not $script:Data -or -not $script:Data.TimeEntries) {
        Write-BufferString -X $startX -Y ($Y + 1) -Text "No activity data available" -ForegroundColor [ConsoleColor]::DarkGray
        return
    }
    
    $weekStart = Get-WeekStart
    $sparklineChars = @(" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█")
    $weekData = @()
    
    for ($i = 0; $i -lt 7; $i++) {
        $date = $weekStart.AddDays($i).ToString("yyyy-MM-dd")
        $dayHours = ($script:Data.TimeEntries | Where-Object { $_.Date -eq $date } | Measure-Object -Property Hours -Sum).Sum
        $weekData += if ($dayHours) { [Math]::Min($dayHours, 10) } else { 0 }
    }
    
    $maxHours = ($weekData | Measure-Object -Maximum).Maximum
    if ($maxHours -eq 0) { $maxHours = 1 }
    
    # Draw sparkline
    $sparkX = $startX + 3
    for ($i = 0; $i -lt 7; $i++) {
        $normalized = [Math]::Floor(($weekData[$i] / $maxHours) * ($sparklineChars.Count - 1))
        $char = $sparklineChars[$normalized]
        $isToday = $i -eq [int](Get-Date).DayOfWeek
        
        $color = if ($weekData[$i] -ge 6) { [ConsoleColor]::Green } 
                 elseif ($weekData[$i] -gt 0) { [ConsoleColor]::Yellow } 
                 else { [ConsoleColor]::DarkGray }
        
        if ($isToday) {
            Write-BufferString -X ($sparkX + ($i * 4) - 1) -Y ($Y + 2) -Text "[" -ForegroundColor [ConsoleColor]::Green
            Write-BufferString -X ($sparkX + ($i * 4)) -Y ($Y + 2) -Text $char -ForegroundColor $color
            Write-BufferString -X ($sparkX + ($i * 4) + 1) -Y ($Y + 2) -Text "]" -ForegroundColor [ConsoleColor]::Green
        } else {
            Write-BufferString -X ($sparkX + ($i * 4)) -Y ($Y + 2) -Text $char -ForegroundColor $color
        }
    }
    
    $totalHours = [Math]::Round(($weekData | Measure-Object -Sum).Sum, 1)
    Write-BufferString -X ($sparkX + 30) -Y ($Y + 2) -Text "→ ${totalHours}h this week" -ForegroundColor [ConsoleColor]::White
}

function Render-QuickActions {
    param([int]$Y)
    
    $title = "⚡ QUICK ACTIONS"
    $startX = ([Console]::WindowWidth - 60) / 2
    
    Write-BufferString -X $startX -Y $Y -Text $title -ForegroundColor [ConsoleColor]::Yellow
    
    $quickActions = $script:MainDashboardScreen.State.QuickActions
    $actionsPerRow = 3
    
    for ($i = 0; $i -lt $quickActions.Count; $i += $actionsPerRow) {
        $rowX = $startX + 3
        $rowY = $Y + 2 + ($i / $actionsPerRow)
        
        for ($j = 0; $j -lt $actionsPerRow -and ($i + $j) -lt $quickActions.Count; $j++) {
            $action = $quickActions[$i + $j]
            $actionX = $rowX + ($j * 20)
            
            Write-BufferString -X $actionX -Y $rowY -Text "[" -ForegroundColor [ConsoleColor]::Blue
            Write-BufferString -X ($actionX + 1) -Y $rowY -Text $action.Key -ForegroundColor [ConsoleColor]::Cyan
            Write-BufferString -X ($actionX + 2) -Y $rowY -Text "]" -ForegroundColor [ConsoleColor]::Blue
            Write-BufferString -X ($actionX + 4) -Y $rowY -Text "$($action.Icon) $($action.Label)" -ForegroundColor [ConsoleColor]::White
        }
    }
}

function Render-MainMenu {
    param(
        [int]$Y,
        [int]$Selected
    )
    
    $title = "🎯 MAIN MENU"
    $startX = ([Console]::WindowWidth - 40) / 2
    
    Write-BufferString -X $startX -Y $Y -Text $title -ForegroundColor [ConsoleColor]::Magenta
    
    $menuItems = $script:MainDashboardScreen.State.MenuItems
    
    for ($i = 0; $i -lt $menuItems.Count; $i++) {
        $item = $menuItems[$i]
        $itemY = $Y + 2 + $i
        
        if ($i -eq $Selected) {
            # Highlight selected item
            Write-BufferString -X ($startX - 2) -Y $itemY -Text "►" -ForegroundColor [ConsoleColor]::Yellow
            $bgColor = [ConsoleColor]::DarkBlue
        } else {
            $bgColor = [ConsoleColor]::Black
        }
        
        Write-BufferString -X $startX -Y $itemY -Text "[" -ForegroundColor [ConsoleColor]::DarkGray -BackgroundColor $bgColor
        Write-BufferString -X ($startX + 1) -Y $itemY -Text $item.Key -ForegroundColor [ConsoleColor]::Cyan -BackgroundColor $bgColor
        Write-BufferString -X ($startX + 2) -Y $itemY -Text "]" -ForegroundColor [ConsoleColor]::DarkGray -BackgroundColor $bgColor
        Write-BufferString -X ($startX + 4) -Y $itemY -Text "$($item.Icon) $($item.Label)".PadRight(25) -ForegroundColor [ConsoleColor]::White -BackgroundColor $bgColor
    }
    
    # Quit option
    $quitY = $Y + 2 + $menuItems.Count + 1
    Write-BufferString -X $startX -Y $quitY -Text "[Q] 🚪 Quit" -ForegroundColor [ConsoleColor]::Red
}

function Handle-MenuSelection {
    param([string]$Key)
    
    # Here you would push the appropriate screen based on the selection
    # For now, just show a message
    Write-StatusLine -Text " Selected: Menu option $Key (Not implemented yet)"
}

function Handle-QuickAction {
    param([string]$Key)
    
    # Here you would execute the quick action
    # For now, just show a message
    Write-StatusLine -Text " Executing: Quick action $Key (Not implemented yet)"
}

# Helper function
function Get-WeekStart {
    $today = Get-Date
    $dayOfWeek = [int]$today.DayOfWeek
    if ($dayOfWeek -eq 0) { $dayOfWeek = 7 } # Sunday = 7
    return $today.AddDays(1 - $dayOfWeek).Date
}
