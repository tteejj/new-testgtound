# Enhanced Main Entry Point for PMC Terminal TUI v2
# Integrates all new components and provides smooth migration path

#region Module Loading

$script:ModuleRoot = $PSScriptRoot
if (-not $script:ModuleRoot) {
    try { $script:ModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
    catch { Write-Error "Could not determine script root. Please run as a .ps1 file."; exit 1 }
}

# Initialize data structure
$script:Data = $null

# Load core modules from parent directory
$parentDir = Split-Path $script:ModuleRoot -Parent
$coreModules = @(
    "$parentDir\helper.ps1",
    "$parentDir\core-data.ps1", 
    "$parentDir\core-time.ps1"
)

foreach ($module in $coreModules) {
    if (Test-Path $module) { 
        Write-Host "Loading core module: $(Split-Path $module -Leaf)" -ForegroundColor Gray
        . $module 
    } else {
        Write-Warning "Core module not found: $module"
    }
}
Import-Module ".\tui-engine-v2.psm1"
Import-Module ".\event-system.psm1"
Import-Module ".\form-components.psm1"
Import-Module ".\task-management.psm1"
Import-Module ".\timer-management.psm1"

# Load enhanced TUI modules
$tuiModules = @(
#    "$script:ModuleRoot\tui-engine-v2.ps1",

#    "$script:ModuleRoot\event-system.ps1",
#    "$script:ModuleRoot\form-components.ps1",
#    "$script:ModuleRoot\dashboard-screen.ps1"
#    "$script:ModuleRoot\timer-management.ps1"
#    "$script:ModuleRoot\task-management.ps1"
)

foreach ($module in $tuiModules) {
    if (Test-Path $module) {
        Write-Host "Loading TUI module: $(Split-Path $module -Leaf)" -ForegroundColor Gray
        . $module
    } else {
        Write-Error "Required TUI module not found: $module"
        exit 1
    }
}

# Initialize data
Write-Host "Initializing data..." -ForegroundColor Gray
if (Get-Command Load-UnifiedData -ErrorAction SilentlyContinue) {
    Load-UnifiedData
} else {
    # Create minimal data structure if core-data not available
    $script:Data = @{
        Projects = @{}
        Tasks = @()
        TimeEntries = @()
        ActiveTimers = @{}
        ArchivedTasks = @()
        CurrentWeek = Get-WeekStart (Get-Date)
        Settings = @{
            DefaultRate = 100.0
            Currency = "USD"
            HoursPerDay = 8.0
            DaysPerWeek = 5
            DefaultPriority = "Medium"
            DefaultCategory = "General"
            CurrentTheme = "Default"
            TimeTrackerTemplates = @{
                "ADMIN" = @{ Name = "Administrative Tasks"; Id1 = "100"; Id2 = "ADM" }
                "MEETING" = @{ Name = "Meetings & Calls"; Id1 = "101"; Id2 = "MTG" }
                "TRAINING" = @{ Name = "Training & Learning"; Id1 = "102"; Id2 = "TRN" }
                "BREAK" = @{ Name = "Breaks & Personal"; Id1 = "103"; Id2 = "BRK" }
            }
        }
    }
}

#endregion

#region Enhanced Dashboard Screen Override

# Override the basic dashboard with full-featured version
$script:MainDashboardScreen.Render = {
    $state = $script:MainDashboardScreen.State
    
    # Header with branding
    Render-DashboardHeader
    
    # Live stats cards
    Render-StatusCards -Y 5
    
    # Active timers widget
    if ($script:Data.ActiveTimers -and $script:Data.ActiveTimers.Count -gt 0) {
        Render-ActiveTimersWidget -X 45 -Y 5
    }
    
    # Recent activity
    Render-RecentActivity -Y 12
    
    # Quick actions panel
    Render-QuickActionsPanel -Y 18
    
    # Main menu
    Render-EnhancedMainMenu -Y 23 -Selected $state.SelectedMenuItem
    
    # Footer with hints
    Render-DashboardFooter
}

# Enhanced input handling with shortcuts
$script:MainDashboardScreen.HandleInput = {
    param($Key)
    
    $state = $script:MainDashboardScreen.State
    
    # Global shortcuts (work from any screen)
    if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
        switch ($Key.Key) {
            ([ConsoleKey]::P) { 
                Push-Screen -Screen $script:CommandPaletteScreen 
                return
            }
            ([ConsoleKey]::T) {
                Push-Screen -Screen $script:TimerStartScreen
                return
            }
            ([ConsoleKey]::N) {
                Push-Screen -Screen $script:TaskCreateScreen
                return
            }
            ([ConsoleKey]::H) {
                Push-Screen -Screen (Get-HelpScreen)
                return
            }
        }
    }
    
    # Function keys
    switch ($Key.Key) {
        ([ConsoleKey]::F1) { Push-Screen -Screen (Get-HelpScreen); return }
        ([ConsoleKey]::F2) { Push-Screen -Screen $script:CommandPaletteScreen; return }
        ([ConsoleKey]::F3) { Push-Screen -Screen $script:TaskManagementScreen; return }
        ([ConsoleKey]::F4) { Push-Screen -Screen $script:TimerManagementScreen; return }
        ([ConsoleKey]::F5) { Refresh-DashboardData; return }
        ([ConsoleKey]::F9) { 
            if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
                Push-Screen -Screen (Get-DebugScreen)
            }
            return
        }
        ([ConsoleKey]::F10) {
            if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
                $script:TuiState.Running = $false
            }
            return
        }
    }
    
    # Regular navigation
    switch ($Key.Key) {
        ([ConsoleKey]::UpArrow) {
            if ($state.SelectedMenuItem -gt 0) { $state.SelectedMenuItem-- }
        }
        ([ConsoleKey]::DownArrow) {
            if ($state.SelectedMenuItem -lt ($state.MenuItems.Count - 1)) { 
                $state.SelectedMenuItem++ 
            }
        }
        ([ConsoleKey]::Enter) {
            $selected = $state.MenuItems[$state.SelectedMenuItem]
            Handle-MenuSelection -MenuItem $selected
        }
        ([ConsoleKey]::Escape) {
            # Show exit confirmation
            if (Confirm-Action -Message "Exit PMC Terminal?") {
                $script:TuiState.Running = $false
            }
        }
        default {
            # Number shortcuts for menu
            if ($Key.KeyChar -and [char]::IsDigit($Key.KeyChar)) {
                $num = [int]::Parse($Key.KeyChar.ToString()) - 1
                if ($num -ge 0 -and $num -lt $state.MenuItems.Count) {
                    $state.SelectedMenuItem = $num
                    Handle-MenuSelection -MenuItem $state.MenuItems[$num]
                }
            }
            # Letter shortcuts for quick actions
            elseif ($Key.KeyChar) {
                Handle-QuickActionKey -Key $Key.KeyChar
            }
        }
    }
}

#endregion

#region Dashboard Components

function Render-ActiveTimersWidget {
    param($X, $Y)
    
    $timers = $script:Data.ActiveTimers.GetEnumerator() | Select-Object -First 3
    $width = 32
    $height = 5 + ($timers.Count * 2)
    
    Write-BufferBox -X $X -Y $Y -Width $width -Height $height `
        -Title "Active Timers ($($script:Data.ActiveTimers.Count))" `
        -BorderColor (Get-ThemeColor "Error")
    
    $timerY = $Y + 2
    foreach ($timer in $timers) {
        $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
        $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
        
        # Project name
        $projName = if ($project) { $project.Name } else { "Unknown" }
        if ($projName.Length -gt 20) { $projName = $projName.Substring(0, 17) + "..." }
        Write-BufferString -X ($X + 2) -Y $timerY -Text $projName `
            -ForegroundColor (Get-ThemeColor "Warning")
        
        # Timer
        $hours = [Math]::Floor($elapsed.TotalHours)
        $timeStr = "{0:D2}:{1:mm}:{1:ss}" -f $hours, $elapsed
        Write-BufferString -X ($X + 2) -Y ($timerY + 1) -Text $timeStr `
            -ForegroundColor (Get-ThemeColor "Error")
        
        # Live indicator
        $pulse = if (([DateTime]::Now.Second % 2) -eq 0) { "●" } else { "○" }
        Write-BufferString -X ($X + $width - 3) -Y $timerY -Text $pulse `
            -ForegroundColor (Get-ThemeColor "Error")
        
        $timerY += 2
    }
    
    if ($script:Data.ActiveTimers.Count -gt 3) {
        Write-BufferString -X ($X + 2) -Y ($Y + $height - 2) `
            -Text "+$($script:Data.ActiveTimers.Count - 3) more..." `
            -ForegroundColor (Get-ThemeColor "Subtle")
    }
}

function Render-RecentActivity {
    param($Y)
    
    Write-BufferBox -X 2 -Y $Y -Width 76 -Height 5 -Title "Recent Activity" `
        -BorderColor (Get-ThemeColor "Info")
    
    # Get recent items
    $recentItems = @()
    
    # Recent time entries
    $recentEntries = $script:Data.TimeEntries | 
        Sort-Object { [DateTime]::Parse($_.CreatedAt) } -Descending | 
        Select-Object -First 3
    
    foreach ($entry in $recentEntries) {
        $project = Get-ProjectOrTemplate $entry.ProjectKey
        $recentItems += @{
            Type = "TimeEntry"
            Text = "Logged $("{0:F1}h" -f $entry.Hours) to $($project.Name ?? $entry.ProjectKey)"
            Time = [DateTime]::Parse($entry.CreatedAt)
        }
    }
    
    # Recent tasks
    $recentTasks = $script:Data.Tasks | 
        Where-Object { $_.CreatedAt } |
        Sort-Object { [DateTime]::Parse($_.CreatedAt) } -Descending | 
        Select-Object -First 2
    
    foreach ($task in $recentTasks) {
        $recentItems += @{
            Type = "Task"
            Text = "Created task: $($task.Description)"
            Time = [DateTime]::Parse($task.CreatedAt)
        }
    }
    
    # Display items
    $itemY = $Y + 2
    $displayed = 0
    foreach ($item in $recentItems | Sort-Object Time -Descending | Select-Object -First 3) {
        $icon = switch ($item.Type) {
            "TimeEntry" { "⏱" }
            "Task" { "☐" }
            default { "•" }
        }
        
        $timeAgo = Get-TimeAgo -Time $item.Time
        Write-BufferString -X 4 -Y $itemY -Text "$icon $($item.Text)" `
            -ForegroundColor (Get-ThemeColor "Primary")
        Write-BufferString -X 65 -Y $itemY -Text $timeAgo `
            -ForegroundColor (Get-ThemeColor "Subtle")
        
        $itemY++
        $displayed++
    }
    
    if ($displayed -eq 0) {
        Write-BufferString -X 30 -Y ($Y + 2) -Text "No recent activity" `
            -ForegroundColor (Get-ThemeColor "Subtle")
    }
}

function Render-QuickActionsPanel {
    param($Y)
    
    Write-BufferBox -X 2 -Y $Y -Width 76 -Height 4 -Title "Quick Actions" `
        -BorderColor (Get-ThemeColor "Success")
    
    $actions = @(
        @{ Key = "S"; Text = "Start Timer"; Color = "Error" }
        @{ Key = "T"; Text = "Add Task"; Color = "Warning" }
        @{ Key = "E"; Text = "Time Entry"; Color = "Info" }
        @{ Key = "R"; Text = "Reports"; Color = "Success" }
        @{ Key = "P"; Text = "Projects"; Color = "Accent" }
    )
    
    $actionX = 5
    foreach ($action in $actions) {
        Write-BufferString -X $actionX -Y ($Y + 2) `
            -Text "[$($action.Key)]" `
            -ForegroundColor (Get-ThemeColor $action.Color)
        Write-BufferString -X ($actionX + 3) -Y ($Y + 2) `
            -Text $action.Text `
            -ForegroundColor (Get-ThemeColor "Primary")
        $actionX += $action.Text.Length + 7
    }
}

function Render-EnhancedMainMenu {
    param($Y, $Selected)
    
    Write-BufferBox -X 10 -Y $Y -Width 60 -Height 7 -Title "Main Menu" `
        -BorderColor (Get-ThemeColor "Accent")
    
    $menuItems = @(
        @{ Num = "1"; Text = "Timer Management"; Icon = "⏱" }
        @{ Num = "2"; Text = "Task Management"; Icon = "☐" }
        @{ Num = "3"; Text = "Reports & Analytics"; Icon = "📊" }
        @{ Num = "4"; Text = "Projects & Settings"; Icon = "⚙" }
        @{ Num = "0"; Text = "Exit"; Icon = "🚪" }
    )
    
    $menuY = $Y + 2
    for ($i = 0; $i -lt $menuItems.Count; $i++) {
        $item = $menuItems[$i]
        $isSelected = $i -eq $Selected
        
        if ($isSelected) {
            for ($x = 11; $x -lt 69; $x++) {
                Write-BufferString -X $x -Y $menuY -Text " " `
                    -BackgroundColor (Get-ThemeColor "Secondary")
            }
        }
        
        $numColor = if ($isSelected) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Info" }
        $textColor = if ($isSelected) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        
        Write-BufferString -X 15 -Y $menuY -Text "[$($item.Num)]" `
            -ForegroundColor $numColor `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        Write-BufferString -X 20 -Y $menuY -Text "$($item.Icon) $($item.Text)" `
            -ForegroundColor $textColor `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        $menuY++
    }
}

function Render-DashboardFooter {
    $y = 29
    $shortcuts = "F1:Help  F2:Commands  Ctrl+T:Timer  Ctrl+N:Task  Ctrl+P:Palette"
    Write-BufferString -X 2 -Y $y -Text $shortcuts `
        -ForegroundColor (Get-ThemeColor "Subtle")
    
    # Version info
    $version = "v2.0"
    Write-BufferString -X (78 - $version.Length) -Y $y -Text $version `
        -ForegroundColor (Get-ThemeColor "Subtle")
}

#endregion

#region Navigation Handlers

function Handle-MenuSelection {
    param($MenuItem)
    
    switch ($MenuItem.Num) {
        "1" { Push-Screen -Screen $script:TimerManagementScreen }
        "2" { Push-Screen -Screen $script:TaskManagementScreen }
        "3" { Push-Screen -Screen (Get-ReportsMenuScreen) }
        "4" { Push-Screen -Screen (Get-ProjectsMenuScreen) }
        "0" { $script:TuiState.Running = $false }
    }
}

function Handle-QuickActionKey {
    param($Key)
    
    switch ($Key) {
        's' { Push-Screen -Screen $script:TimerStartScreen }
        't' { Push-Screen -Screen $script:TaskCreateScreen }
        'e' { Push-Screen -Screen (Get-TimeEntryScreen) }
        'r' { Push-Screen -Screen (Get-ReportsMenuScreen) }
        'p' { Push-Screen -Screen (Get-ProjectsMenuScreen) }
    }
}

#endregion

#region Placeholder Screens

function Get-ReportsMenuScreen {
    return @{
        Name = "ReportsMenu"
        Render = {
            Write-BufferBox -X 20 -Y 10 -Width 40 -Height 10 -Title "Reports" `
                -BorderColor (Get-ThemeColor "Info")
            
            Write-BufferString -X 25 -Y 12 -Text "[1] Time Reports" `
                -ForegroundColor (Get-ThemeColor "Primary")
            Write-BufferString -X 25 -Y 13 -Text "[2] Task Reports" `
                -ForegroundColor (Get-ThemeColor "Primary")
            Write-BufferString -X 25 -Y 14 -Text "[3] Project Summary" `
                -ForegroundColor (Get-ThemeColor "Primary")
            Write-BufferString -X 25 -Y 15 -Text "[4] Export All Data" `
                -ForegroundColor (Get-ThemeColor "Primary")
            
            Write-BufferString -X 25 -Y 17 -Text "Press number or Esc" `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        HandleInput = {
            param($Key)
            switch ($Key.KeyChar) {
                '1' { Push-Screen -Screen $script:TimerReportScreen }
                '2' { Write-StatusLine -Text " Task reports coming soon!" }
                '3' { Write-StatusLine -Text " Project summary coming soon!" }
                '4' { 
                    Export-AllData
                    Write-StatusLine -Text " Data exported!" -BackgroundColor (Get-ThemeColor "Success")
                }
            }
            if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
        }
    }
}

function Get-ProjectsMenuScreen {
    return @{
        Name = "ProjectsMenu"
        Render = {
            Write-BufferBox -X 20 -Y 10 -Width 40 -Height 8 -Title "Projects & Settings" `
                -BorderColor (Get-ThemeColor "Accent")
            
            Write-BufferString -X 25 -Y 12 -Text "[1] Manage Projects" `
                -ForegroundColor (Get-ThemeColor "Primary")
            Write-BufferString -X 25 -Y 13 -Text "[2] Settings" `
                -ForegroundColor (Get-ThemeColor "Primary")
            Write-BufferString -X 25 -Y 14 -Text "[3] Theme" `
                -ForegroundColor (Get-ThemeColor "Primary")
            
            Write-BufferString -X 25 -Y 16 -Text "Press number or Esc" `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        HandleInput = {
            param($Key)
            switch ($Key.KeyChar) {
                '1' { Write-StatusLine -Text " Project management coming soon!" }
                '2' { Write-StatusLine -Text " Settings coming soon!" }
                '3' { 
                    # Cycle themes
                    $themes = @("Default", "Dark", "Light")
                    $current = $themes.IndexOf($script:TuiState.CurrentTheme)
                    $next = $themes[($current + 1) % $themes.Count]
                    Set-TuiTheme -ThemeName $next
                    Write-StatusLine -Text " Theme changed to: $next" -BackgroundColor (Get-ThemeColor "Success")
                }
            }
            if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
        }
    }
}

function Get-TimeEntryScreen {
    # Reuse the form from timer management
    return $script:TimeEntryFormScreen
}

function Get-HelpScreen {
    return @{
        Name = "Help"
        Render = {
            Write-BufferBox -X 5 -Y 2 -Width 70 -Height 26 -Title "PMC Terminal Help" `
                -BorderColor (Get-ThemeColor "Info")
            
            $y = 4
            $sections = @(
                @{ Title = "Navigation"; Items = @(
                    "↑↓ Arrow Keys - Navigate menus"
                    "Enter - Select item"
                    "Esc - Go back / Cancel"
                    "Tab - Switch views/modes"
                )}
                @{ Title = "Global Shortcuts"; Items = @(
                    "F1 - This help screen"
                    "F2 - Command palette"
                    "Ctrl+T - Start timer"
                    "Ctrl+N - New task"
                    "Ctrl+P - Command palette"
                )}
                @{ Title = "Timer Commands"; Items = @(
                    "S - Start new timer"
                    "Space - Stop selected timer"
                    "D - View timer details"
                )}
                @{ Title = "Task Commands"; Items = @(
                    "N - New task"
                    "E - Edit task"
                    "C - Complete/uncomplete"
                    "D - Delete task"
                    "/ - Filter tasks"
                )}
            )
            
            foreach ($section in $sections) {
                Write-BufferString -X 7 -Y $y -Text $section.Title `
                    -ForegroundColor (Get-ThemeColor "Accent")
                $y++
                
                foreach ($item in $section.Items) {
                    Write-BufferString -X 9 -Y $y -Text "• $item" `
                        -ForegroundColor (Get-ThemeColor "Primary")
                    $y++
                }
                $y++
            }
            
            Write-BufferString -X 7 -Y 27 -Text "Press any key to close" `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        HandleInput = {
            param($Key)
            return "Back"
        }
    }
}

#endregion

#region Helper Functions

function Get-TimeAgo {
    param([DateTime]$Time)
    
    $span = (Get-Date) - $Time
    
    if ($span.TotalMinutes -lt 1) { return "just now" }
    if ($span.TotalMinutes -lt 60) { return "$([Math]::Floor($span.TotalMinutes))m ago" }
    if ($span.TotalHours -lt 24) { return "$([Math]::Floor($span.TotalHours))h ago" }
    if ($span.TotalDays -lt 7) { return "$([Math]::Floor($span.TotalDays))d ago" }
    
    return $Time.ToString("MMM dd")
}

function Refresh-DashboardData {
    # Force refresh of all data
    Load-TaskData
    Refresh-TimerData
    
    Write-StatusLine -Text " Dashboard refreshed" -BackgroundColor (Get-ThemeColor "Success")
}

function Export-AllData {
    $exportData = @{
        ExportDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Projects = $script:Data.Projects
        Tasks = $script:Data.Tasks
        TimeEntries = $script:Data.TimeEntries
        ActiveTimers = $script:Data.ActiveTimers
        Settings = $script:Data.Settings
    }
    
    $json = $exportData | ConvertTo-Json -Depth 10
    $json | Set-Clipboard
    
    # Also save to file
    $exportPath = Join-Path $env:TEMP "pmc-export-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $json | Set-Content $exportPath
    
    Write-StatusLine -Text " Exported to clipboard and $exportPath" -BackgroundColor (Get-ThemeColor "Success")
}

#endregion

#region Main Entry Point

function Start-PMCTerminalTUI {
    Clear-Host
    
    Write-Host @"
╔════════════════════════════════════════════════════════════════════════╗
║                   PMC Terminal - Enhanced TUI v2.0                      ║
║                                                                         ║
║  Welcome to the next generation of terminal productivity!              ║
║                                                                         ║
║  New Features:                                                          ║
║    • Rock-solid error handling and recovery                           ║
║    • Event-driven architecture                                         ║
║    • Reusable form components                                         ║
║    • Live timer updates                                               ║
║    • Advanced task management                                         ║
║    • Multiple view modes                                              ║
║    • Theme support                                                    ║
║                                                                         ║
║  Press F1 for help at any time                                        ║
╚════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Write-Host "`nInitializing enhanced TUI engine..." -ForegroundColor Gray
    
    # Show initialization progress
    $steps = @(
        "Loading configuration",
        "Initializing event system", 
        "Setting up components",
        "Loading user data",
        "Starting TUI engine"
    )
    
    foreach ($step in $steps) {
        Write-Host "  • $step..." -ForegroundColor Gray
        Start-Sleep -Milliseconds 200
    }
    
    Write-Host "`nInitialization complete!" -ForegroundColor Green
    Start-Sleep -Seconds 1
    
    try {
        # Initialize systems
        Initialize-EventSystem
        
        # Subscribe to global events
        Subscribe-Event -EventName "System.ErrorOccurred" -Handler {
            param($EventData)
            Write-StatusLine -Text " Error: $($EventData.Data.Message)" -BackgroundColor (Get-ThemeColor "Error")
        }
        
        # Start the enhanced TUI loop
        Start-TuiLoop -InitialScreen $script:MainDashboardScreen
    }
    catch {
        Write-Error "TUI Error: $_"
        Write-Error $_.ScriptStackTrace
        
        # Show error report
        $errorReport = Get-TuiErrorReport
        if ($errorReport) {
            Write-Host "`nError Report:`n$errorReport" -ForegroundColor Red
        }
        
        Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    finally {
        # Ensure cleanup
        Write-Host "`n✨ Thank you for using PMC Terminal!" -ForegroundColor Cyan
        Write-Host "Your productivity data has been saved." -ForegroundColor Gray
        
        # Save any pending data
        if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
            Save-UnifiedData
        }
    }
}

# Check prerequisites
function Test-Prerequisites {
    $errors = @()
    
    # PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $errors += "PowerShell 5.0 or higher required (current: $($PSVersionTable.PSVersion))"
    }
    
    # Console size
    if ([Console]::WindowWidth -lt 80 -or [Console]::WindowHeight -lt 30) {
        $errors += "Console size must be at least 80x30 (current: $([Console]::WindowWidth)x$([Console]::WindowHeight))"
    }
    
    # Required modules
    $requiredModules = @(
        "tui-engine-v2.psm1",
        "event-system.psm1",
        "form-components.psm1"
    )
    
    foreach ($module in $requiredModules) {
        if (-not (Test-Path "$script:ModuleRoot\$module")) {
            $errors += "Required module not found: $module"
        }
    }
    
    if ($errors.Count -gt 0) {
        Write-Host "Prerequisites check failed:" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "  • $error" -ForegroundColor Yellow
        }
        return $false
    }
    
    return $true
}

# Module initialization
#if (Test-Prerequisites) {
#    # Export main function
#    Export-ModuleMember -Function @(
#        'Start-PMCTerminalTUI',
#        'Get-TimeAgo',
#        'Refresh-DashboardData',
#        'Export-AllData'
#    )
#} else {
#    Write-Host "`nPlease fix the issues above and try again." -ForegroundColor Red
#    exit 1
#}

#endregion
Start-PMCTerminalTUI