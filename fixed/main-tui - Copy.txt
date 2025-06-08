# Non-Blocking TUI Main Entry Point
# Demonstrates proper integration of all components

#region Module Loading

# Get script directory
$script:ModuleRoot = $PSScriptRoot
if (-not $script:ModuleRoot) {
    try { $script:ModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
    catch { Write-Error "Could not determine script root. Please run as a .ps1 file."; exit 1 }
}

# Initialize data structure first
$script:Data = $null

# Load original modules that we still need
$parentDir = Split-Path $script:ModuleRoot -Parent
if (Test-Path "$parentDir\helper.ps1") { . "$parentDir\helper.ps1" }
if (Test-Path "$parentDir\core-data.ps1") { . "$parentDir\core-data.ps1" }
if (Test-Path "$parentDir\core-time.ps1") { . "$parentDir\core-time.ps1" }

# Load fixed TUI modules
. "$script:ModuleRoot\tui-engine.ps1"
. "$script:ModuleRoot\dashboard-screen.ps1"

# Initialize data
if (Get-Command Load-UnifiedData -ErrorAction SilentlyContinue) {
    Load-UnifiedData
} else {
    # Create minimal data structure if helper not available
    $script:Data = @{
        Projects = @{}
        Tasks = @()
        TimeEntries = @()
        ActiveTimers = @{}
        ArchivedTasks = @()
        Settings = @{
            DefaultRate = 100.0
            Currency = "USD"
            HoursPerDay = 8.0
            DaysPerWeek = 5
            DefaultPriority = "Medium"
            DefaultCategory = "General"
            CurrentTheme = "Cyberpunk"
        }
    }
}

#endregion

#region Additional Screens (Examples)

$script:TimeManagementScreen = @{
    Name = "TimeManagement"
    State = @{
        SelectedOption = 0
        Options = @(
            "Manual Time Entry",
            "Start Timer",
            "Stop Timer",
            "View Active Timers",
            "Edit Time Entry",
            "Back to Dashboard"
        )
    }
    
    Render = {
        $state = $script:TimeManagementScreen.State
        
        # Header
        Write-BufferBox -X 10 -Y 5 -Width 60 -Height 3 -Title "Time Management" -BorderColor [ConsoleColor]::Cyan
        
        # Menu options
        for ($i = 0; $i -lt $state.Options.Count; $i++) {
            $y = 10 + ($i * 2)
            $fg = if ($i -eq $state.SelectedOption) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White }
            $prefix = if ($i -eq $state.SelectedOption) { "► " } else { "  " }
            
            Write-BufferString -X 15 -Y $y -Text "$prefix$($state.Options[$i])" -ForegroundColor $fg
        }
        
        # Instructions
        Write-BufferString -X 10 -Y 25 -Text "Use ↑↓ to navigate, Enter to select, Esc to go back" -ForegroundColor [ConsoleColor]::DarkGray
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:TimeManagementScreen.State
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                $state.SelectedOption = [Math]::Max(0, $state.SelectedOption - 1)
            }
            ([ConsoleKey]::DownArrow) {
                $state.SelectedOption = [Math]::Min($state.Options.Count - 1, $state.SelectedOption + 1)
            }
            ([ConsoleKey]::Enter) {
                if ($state.SelectedOption -eq ($state.Options.Count - 1)) {
                    return "Back"
                }
                # Handle other options...
                Write-StatusLine -Text " Selected: $($state.Options[$state.SelectedOption])"
            }
            ([ConsoleKey]::Escape) {
                return "Back"
            }
        }
    }
}

$script:TaskListScreen = @{
    Name = "TaskList"
    State = @{
        Tasks = @()
        SelectedIndex = 0
        ScrollOffset = 0
        PageSize = 15
    }
    
    Init = {
        # Load tasks
        $state = $script:TaskListScreen.State
        $state.Tasks = $script:Data.Tasks | Where-Object { 
            (-not $_.Completed) -and ($_.IsCommand -ne $true) 
        } | Sort-Object Priority, DueDate
    }
    
    Render = {
        $state = $script:TaskListScreen.State
        
        # Header
        Write-BufferBox -X 5 -Y 2 -Width 70 -Height 3 -Title "Task List" -BorderColor [ConsoleColor]::Green
        
        # Column headers
        Write-BufferString -X 7 -Y 6 -Text "ID      Priority  Task                                    Due Date" -ForegroundColor [ConsoleColor]::Cyan
        Write-BufferString -X 7 -Y 7 -Text "──────  ────────  ──────────────────────────────────────  ──────────" -ForegroundColor [ConsoleColor]::DarkGray
        
        # Task list
        $visibleTasks = $state.Tasks | Select-Object -Skip $state.ScrollOffset -First $state.PageSize
        $i = 0
        
        foreach ($task in $visibleTasks) {
            $y = 8 + $i
            $isSelected = ($state.ScrollOffset + $i) -eq $state.SelectedIndex
            
            $fg = if ($isSelected) { [ConsoleColor]::Black } else { [ConsoleColor]::White }
            $bg = if ($isSelected) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Black }
            
            $id = $task.Id.Substring(0, 6)
            $priority = $task.Priority.PadRight(8).Substring(0, 8)
            $desc = if ($task.Description.Length -gt 38) { 
                $task.Description.Substring(0, 35) + "..." 
            } else { 
                $task.Description.PadRight(38) 
            }
            $due = if ($task.DueDate) { 
                [DateTime]::Parse($task.DueDate).ToString("MM/dd/yyyy") 
            } else { 
                "          " 
            }
            
            $line = "$id  $priority  $desc  $due"
            Write-BufferString -X 7 -Y $y -Text $line -ForegroundColor $fg -BackgroundColor $bg
            
            $i++
        }
        
        # Scroll indicator
        if ($state.Tasks.Count -gt $state.PageSize) {
            $scrollPercent = if ($state.Tasks.Count -gt 1) { 
                $state.SelectedIndex / ($state.Tasks.Count - 1) 
            } else { 0 }
            $scrollY = 8 + [Math]::Floor($scrollPercent * ($state.PageSize - 1))
            Write-BufferString -X 78 -Y $scrollY -Text "█" -ForegroundColor [ConsoleColor]::Yellow
        }
        
        # Status
        $status = "Task $($state.SelectedIndex + 1) of $($state.Tasks.Count) | Press Enter to view, N for new task"
        Write-BufferString -X 5 -Y 25 -Text $status -ForegroundColor [ConsoleColor]::DarkGray
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:TaskListScreen.State
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($state.SelectedIndex -gt 0) {
                    $state.SelectedIndex--
                    if ($state.SelectedIndex -lt $state.ScrollOffset) {
                        $state.ScrollOffset = $state.SelectedIndex
                    }
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($state.SelectedIndex -lt ($state.Tasks.Count - 1)) {
                    $state.SelectedIndex++
                    if ($state.SelectedIndex -ge ($state.ScrollOffset + $state.PageSize)) {
                        $state.ScrollOffset = $state.SelectedIndex - $state.PageSize + 1
                    }
                }
            }
            ([ConsoleKey]::PageUp) {
                $state.SelectedIndex = [Math]::Max(0, $state.SelectedIndex - $state.PageSize)
                $state.ScrollOffset = [Math]::Max(0, $state.ScrollOffset - $state.PageSize)
            }
            ([ConsoleKey]::PageDown) {
                $maxIndex = $state.Tasks.Count - 1
                $state.SelectedIndex = [Math]::Min($maxIndex, $state.SelectedIndex + $state.PageSize)
                $maxScroll = [Math]::Max(0, $state.Tasks.Count - $state.PageSize)
                $state.ScrollOffset = [Math]::Min($maxScroll, $state.ScrollOffset + $state.PageSize)
            }
            ([ConsoleKey]::Enter) {
                if ($state.Tasks.Count -gt 0) {
                    Write-StatusLine -Text " Viewing task: $($state.Tasks[$state.SelectedIndex].Description)"
                }
            }
            ([ConsoleKey]::N) {
                Write-StatusLine -Text " Add new task (not implemented in demo)"
            }
            ([ConsoleKey]::Escape) {
                return "Back"
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
        "2" { Push-Screen -Screen $script:TaskListScreen }
        default {
            Write-StatusLine -Text " Menu option $Key not implemented in this demo"
        }
    }
}

#endregion

#region Main Entry Point

function Start-NonBlockingTUI {
    Write-Host "Starting Non-Blocking TUI Demo..." -ForegroundColor Cyan
    Write-Host "This demonstrates a proper non-blocking terminal UI with:" -ForegroundColor Gray
    Write-Host "  • Double buffering for flicker-free rendering" -ForegroundColor Gray
    Write-Host "  • Non-blocking keyboard input" -ForegroundColor Gray
    Write-Host "  • Screen management with navigation stack" -ForegroundColor Gray
    Write-Host "  • Smooth animations and updates" -ForegroundColor Gray
    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
    $null = [Console]::ReadKey($true)
    
    try {
        # Start the TUI with the main dashboard
        Start-TuiLoop -InitialScreen $script:MainDashboardScreen
    }
    catch {
        Write-Error "TUI Error: $_"
        Write-Error $_.ScriptStackTrace
    }
    finally {
        Write-Host "`nTUI terminated. Thank you for using the Unified Productivity Suite!" -ForegroundColor Cyan
    }
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "This application requires PowerShell 5.0 or higher."
    exit 1
}

# Start the application
Start-NonBlockingTUI

#endregion
