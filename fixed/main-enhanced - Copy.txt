# Enhanced Non-Blocking TUI Main Entry Point
# Demonstrates full integration of all PMC Terminal features

#region Module Loading

$script:ModuleRoot = $PSScriptRoot
if (-not $script:ModuleRoot) {
    try { $script:ModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
    catch { Write-Error "Could not determine script root. Please run as a .ps1 file."; exit 1 }
}

# Initialize data structure
$script:Data = $null

# Load original modules we still need
$parentDir = Split-Path $script:ModuleRoot -Parent
if (Test-Path "$parentDir\helper.ps1") { . "$parentDir\helper.ps1" }
if (Test-Path "$parentDir\core-data.ps1") { . "$parentDir\core-data.ps1" }
if (Test-Path "$parentDir\core-time.ps1") { . "$parentDir\core-time.ps1" }

# Load TUI modules
. "$script:ModuleRoot\tui-engine.ps1"
. "$script:ModuleRoot\dashboard-screen.ps1"
. "$script:ModuleRoot\enhanced-components.ps1"

# Initialize data
if (Get-Command Load-UnifiedData -ErrorAction SilentlyContinue) {
    Load-UnifiedData
} else {
    # Create minimal data structure
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
            CurrentTheme = "Cyberpunk"
            TimeTrackerTemplates = @{
                "ADMIN" = @{ Name = "Administrative Tasks"; Id1 = "100"; Id2 = "ADM" }
                "MEETING" = @{ Name = "Meetings & Calls"; Id1 = "101"; Id2 = "MTG" }
                "TRAINING" = @{ Name = "Training & Learning"; Id1 = "102"; Id2 = "TRN" }
                "BREAK" = @{ Name = "Breaks & Personal"; Id1 = "103"; Id2 = "BRK" }
            }
            CommandSnippets = @{
                EnableHotkeys = $true
                AutoCopyToClipboard = $true
                ShowInTaskList = $false
                DefaultCategory = "Commands"
                RecentLimit = 10
            }
        }
    }
}

#endregion

#region Enhanced Dashboard Screen

# Override the basic dashboard with enhanced version
$script:MainDashboardScreen.Render = {
    $state = $script:MainDashboardScreen.State
    
    # Render header
    Render-DashboardHeader
    
    # Render status cards
    Render-StatusCards -Y 10
    
    # Render live timer widget (if any active)
    if ($script:Data.ActiveTimers -and $script:Data.ActiveTimers.Count -gt 0) {
        $script:TimerWidget.Render.Invoke(50, 10)
    }
    
    # Render activity timeline  
    Render-ActivityTimeline -Y 16
    
    # Render quick actions
    Render-QuickActions -Y 20
    
    # Render main menu
    Render-MainMenu -Y 26 -Selected $state.SelectedMenuItem
}

# Enhanced input handling
$originalHandleInput = $script:MainDashboardScreen.HandleInput
$script:MainDashboardScreen.HandleInput = {
    param($Key)
    
    # Global shortcuts
    switch ($Key.Key) {
        ([ConsoleKey]::F1) { 
            Push-Screen -Screen $script:HelpScreen 
            return
        }
        ([ConsoleKey]::F2) { 
            Push-Screen -Screen $script:CommandPaletteScreen 
            return
        }
    }
    
    # Quick action shortcuts (Alt+Letter)
    if ($Key.Modifiers -band [ConsoleModifiers]::Alt) {
        switch ($Key.Key) {
            ([ConsoleKey]::T) { 
                Push-Screen -Screen $script:TimeEntryFormScreen 
                return
            }
            ([ConsoleKey]::S) { 
                Handle-QuickTimerStart
                return
            }
            ([ConsoleKey]::A) { 
                Push-Screen -Screen $script:TaskFormScreen 
                return
            }
        }
    }
    
    # Call original handler
    & $originalHandleInput -Key $Key
}

#endregion

#region Timer Management

function Handle-QuickTimerStart {
    # Quick timer start with project selection
    Push-Screen -Screen @{
        Name = "QuickTimerStart"
        State = @{
            Projects = @()
            SelectedIndex = 0
            SearchText = ""
        }
        
        Init = {
            # Load projects
            $projects = @()
            foreach ($proj in $script:Data.Projects.GetEnumerator()) {
                $projects += @{ 
                    Key = $proj.Key
                    Name = $proj.Value.Name
                    Type = "Project"
                }
            }
            foreach ($tmpl in $script:Data.Settings.TimeTrackerTemplates.GetEnumerator()) {
                $projects += @{ 
                    Key = $tmpl.Key
                    Name = $tmpl.Value.Name
                    Type = "Template"
                }
            }
            $script:QuickTimerStart.State.Projects = $projects | Sort-Object Name
        }
        
        Render = {
            Write-BufferBox -X 20 -Y 8 -Width 40 -Height 15 -Title "Start Timer" -BorderColor [ConsoleColor]::Green
            
            # Search box
            Write-BufferString -X 22 -Y 10 -Text "Project: " -ForegroundColor [ConsoleColor]::White
            Write-BufferBox -X 31 -Y 9 -Width 27 -Height 3 -BorderColor [ConsoleColor]::Yellow
            Write-BufferString -X 33 -Y 10 -Text ($State.SearchText + "_") -ForegroundColor [ConsoleColor]::White
            
            # Project list
            $y = 13
            $filtered = $State.Projects
            if ($State.SearchText) {
                $filtered = $State.Projects | Where-Object { 
                    $_.Name -like "*$($State.SearchText)*" -or 
                    $_.Key -like "*$($State.SearchText)*" 
                }
            }
            
            foreach ($proj in $filtered | Select-Object -First 5) {
                $index = $filtered.IndexOf($proj)
                $isSelected = $index -eq $State.SelectedIndex
                
                if ($isSelected) {
                    Write-BufferString -X 22 -Y $y -Text "►" -ForegroundColor [ConsoleColor]::Yellow
                }
                
                $display = "$($proj.Key) - $($proj.Name)"
                if ($display.Length -gt 35) { $display = $display.Substring(0, 32) + "..." }
                
                Write-BufferString -X 24 -Y $y -Text $display `
                    -ForegroundColor (if ($isSelected) { [ConsoleColor]::Cyan } else { [ConsoleColor]::White })
                
                $y++
            }
            
            Write-BufferString -X 22 -Y 20 -Text "Enter: Start  Esc: Cancel" -ForegroundColor [ConsoleColor]::DarkGray
        }
        
        HandleInput = {
            param($Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::Enter) {
                    if ($State.Projects.Count -gt 0) {
                        $selected = $State.Projects[$State.SelectedIndex]
                        Start-Timer -ProjectKeyParam $selected.Key
                        Write-StatusLine -Text " Timer started for: $($selected.Name)" -BackgroundColor [ConsoleColor]::DarkGreen
                        return "Back"
                    }
                }
                ([ConsoleKey]::Escape) { return "Back" }
                ([ConsoleKey]::UpArrow) {
                    if ($State.SelectedIndex -gt 0) { $State.SelectedIndex-- }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($State.SelectedIndex -lt ($State.Projects.Count - 1)) { $State.SelectedIndex++ }
                }
                ([ConsoleKey]::Backspace) {
                    if ($State.SearchText.Length -gt 0) {
                        $State.SearchText = $State.SearchText.Substring(0, $State.SearchText.Length - 1)
                    }
                }
                default {
                    if ($Key.KeyChar) {
                        $State.SearchText += $Key.KeyChar
                    }
                }
            }
        }
    }
}

#endregion

#region Screen Navigation Handler

function global:Handle-MenuSelection {
    param([string]$Key)
    
    switch ($Key) {
        "1" { Push-Screen -Screen $script:TimeManagementScreen }
        "2" { Push-Screen -Screen $script:EnhancedTaskListScreen }
        "3" { Push-Screen -Screen $script:WeekReportScreen }
        "4" { Push-Screen -Screen $script:ProjectListScreen }
        "5" { Push-Screen -Screen $script:ToolsMenuScreen }
        "6" { Push-Screen -Screen $script:SettingsScreen }
        default {
            Write-StatusLine -Text " Feature not yet implemented in TUI mode" -BackgroundColor [ConsoleColor]::DarkRed
        }
    }
}

function global:Handle-QuickAction {
    param([string]$Key)
    
    switch ($Key) {
        "M" { Push-Screen -Screen $script:TimeEntryFormScreen }
        "S" { Handle-QuickTimerStart }
        "A" { 
            # Quick task add
            Push-Screen -Screen @{
                Name = "QuickTaskAdd"
                State = @{ TaskText = "" }
                Render = {
                    Write-BufferBox -X 15 -Y 10 -Width 50 -Height 5 -Title "Quick Add Task" -BorderColor [ConsoleColor]::Green
                    Write-BufferString -X 17 -Y 12 -Text "Task: " -ForegroundColor [ConsoleColor]::White
                    Write-BufferString -X 23 -Y 12 -Text ($State.TaskText + "_") -ForegroundColor [ConsoleColor]::Yellow
                }
                HandleInput = {
                    param($Key)
                    switch ($Key.Key) {
                        ([ConsoleKey]::Enter) {
                            if ($State.TaskText) {
                                Quick-AddTask -InputString $State.TaskText
                                Write-StatusLine -Text " Task added!" -BackgroundColor [ConsoleColor]::DarkGreen
                                return "Back"
                            }
                        }
                        ([ConsoleKey]::Escape) { return "Back" }
                        ([ConsoleKey]::Backspace) {
                            if ($State.TaskText.Length -gt 0) {
                                $State.TaskText = $State.TaskText.Substring(0, $State.TaskText.Length - 1)
                            }
                        }
                        default {
                            if ($Key.KeyChar) { $State.TaskText += $Key.KeyChar }
                        }
                    }
                }
            }
        }
        "V" { Push-Screen -Screen $script:ActiveTimersScreen }
        "T" { Push-Screen -Screen $script:TodayViewScreen }
        "W" { Push-Screen -Screen $script:WeekReportScreen }
        default {
            Write-StatusLine -Text " Quick action $Key not yet implemented" -BackgroundColor [ConsoleColor]::DarkRed
        }
    }
}

#endregion

#region Additional Screens

$script:ActiveTimersScreen = @{
    Name = "ActiveTimers"
    State = @{ }
    
    Render = {
        Write-BufferBox -X 10 -Y 5 -Width 60 -Height 20 -Title "Active Timers" -BorderColor [ConsoleColor]::Red
        
        if (-not $script:Data.ActiveTimers -or $script:Data.ActiveTimers.Count -eq 0) {
            Write-BufferString -X 25 -Y 12 -Text "No active timers" -ForegroundColor [ConsoleColor]::DarkGray
        } else {
            $y = 7
            foreach ($timer in $script:Data.ActiveTimers.GetEnumerator()) {
                $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
                
                # Timer info
                Write-BufferString -X 12 -Y $y -Text "Project: " -ForegroundColor [ConsoleColor]::DarkGray
                Write-BufferString -X 21 -Y $y -Text $project.Name -ForegroundColor [ConsoleColor]::Yellow
                
                # Elapsed time
                $y++
                $hours = [Math]::Floor($elapsed.TotalHours)
                $timeStr = "{0:D2}:{1:mm}:{1:ss}" -f $hours, $elapsed
                Write-BufferString -X 12 -Y $y -Text "Elapsed: " -ForegroundColor [ConsoleColor]::DarkGray
                Write-BufferString -X 21 -Y $y -Text $timeStr -ForegroundColor [ConsoleColor]::Red
                
                # Stop button hint
                $y++
                Write-BufferString -X 12 -Y $y -Text "[S] Stop this timer" -ForegroundColor [ConsoleColor]::Cyan
                
                $y += 2
            }
        }
        
        Write-BufferString -X 12 -Y 23 -Text "Press Esc to go back" -ForegroundColor [ConsoleColor]::DarkGray
    }
    
    HandleInput = {
        param($Key)
        
        switch ($Key.Key) {
            ([ConsoleKey]::S) {
                if ($script:Data.ActiveTimers.Count -gt 0) {
                    # Stop first timer (in real app, allow selection)
                    $timer = $script:Data.ActiveTimers.GetEnumerator() | Select-Object -First 1
                    Stop-Timer
                    Write-StatusLine -Text " Timer stopped" -BackgroundColor [ConsoleColor]::DarkGreen
                }
            }
            ([ConsoleKey]::Escape) { return "Back" }
        }
    }
}

#endregion

#region Main Loop Override

# Override the TUI loop to add live updates
function Start-EnhancedTuiLoop {
    param(
        [hashtable]$InitialScreen
    )
    
    try {
        # Initialize the engine
        Initialize-TuiEngine
        
        # Set initial screen
        Push-Screen -Screen $InitialScreen
        
        # Start the main loop
        $script:TuiState.Running = $true
        $lastUpdate = [DateTime]::Now
        
        while ($script:TuiState.Running) {
            # Process input
            $key = Process-Input
            if ($key) {
                Handle-ScreenInput -Key $key
            }
            
            # Update live components every second
            if (([DateTime]::Now - $lastUpdate).TotalSeconds -ge 1) {
                Update-DashboardComponents
                $lastUpdate = [DateTime]::Now
            }
            
            # Update current screen
            Update-CurrentScreen
            
            # Small delay to prevent CPU spinning
            Start-Sleep -Milliseconds 10
        }
    }
    finally {
        # Cleanup
        Stop-InputHandler
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::ResetColor()
        
        # Save any pending data
        if (Get-Command Save-UnifiedData -ErrorAction SilentlyContinue) {
            Save-UnifiedData
        }
    }
}

#endregion

#region Entry Point

function Start-PMCTerminalTUI {
    Write-Host @"
╔════════════════════════════════════════════════════════════════════╗
║                  PMC Terminal - TUI Mode v5.0                      ║
║                                                                    ║
║  This is the enhanced non-blocking TUI version featuring:         ║
║    • Live timer updates                                           ║
║    • Smooth keyboard navigation                                   ║
║    • Interactive forms and data entry                            ║
║    • Real-time data visualization                                ║
║                                                                    ║
║  Press F1 for help, F2 for command palette                       ║
╚════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Write-Host "`nInitializing..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
    
    try {
        # Start the enhanced TUI
        Start-EnhancedTuiLoop -InitialScreen $script:MainDashboardScreen
    }
    catch {
        Write-Error "TUI Error: $_"
        Write-Error $_.ScriptStackTrace
    }
    finally {
        Write-Host "`n✨ Thank you for using PMC Terminal TUI!" -ForegroundColor Cyan
        Write-Host "Your productivity data has been saved." -ForegroundColor Gray
    }
}

# Helper function for week calculations
function Get-WeekStart {
    param($Date = (Get-Date))
    $dayOfWeek = [int]$Date.DayOfWeek
    if ($dayOfWeek -eq 0) { $dayOfWeek = 7 }
    return $Date.AddDays(1 - $dayOfWeek).Date
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "This application requires PowerShell 5.0 or higher."
    exit 1
}

# Start the application
Start-PMCTerminalTUI

#endregion
