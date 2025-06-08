#
# PMC Terminal - TUI Main Entry Point
# Version: Final Skeleton
#
# This is the primary application shell. It loads all modules,
# defines the main loop, and handles top-level navigation.
# This file is considered complete and should not be modified in later steps.
#

#region Module Loading & Configuration

# Get script directory and set global paths
$script:ModuleRoot = $PSScriptRoot
if (-not $script:ModuleRoot) {
    try { $script:ModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
    catch { Write-Error "Could not determine script root. Please run as a .ps1 file."; exit 1 }
}

# Initialize data structure first
$script:Data = $null

# Load foundational modules
. "$script:ModuleRoot\helper.ps1"
. "$script:ModuleRoot\core-data.ps1"
. "$script:ModuleRoot\tui-engine.ps1"

# Load feature modules (These will be created in subsequent steps)
. "$script:ModuleRoot\dashboard-screen.ps1"
. "$script:ModuleRoot\time-management.ps1"
. "$script:ModuleRoot\task-management.ps1"
. "$script:ModuleRoot\project-management.ps1"
. "$script:ModuleRoot\command-palette.ps1"
. "$script:ModuleRoot\settings.ps1"
. "$script:ModuleRoot\help.ps1"

# Initialize data from disk
Load-UnifiedData

#endregion

#region Screen Navigation Handler (Final Implementation)

# This function handles menu selections from the main dashboard.
function global:Handle-MenuSelection {
    param([string]$Key)
    
    switch ($Key) {
        "1" { Push-Screen -Screen $script:TimeManagementMenuScreen } # Placeholder, will be defined in time-management.ps1
        "2" { Push-Screen -Screen $script:EnhancedTaskListScreen }
        "3" { Push-Screen -Screen $script:ReportsMenuScreen } # Placeholder, will be defined in time-management.ps1
        "4" { Push-Screen -Screen $script:ProjectListScreen }
        "5" { Push-Screen -Screen $script:ToolsMenuScreen } # Placeholder, will be defined in command-palette.ps1
        "6" { Push-Screen -Screen $script:SettingsScreen }
        default {
            Write-StatusLine -Text " Feature for key '$Key' is not yet implemented in a loaded module." -BackgroundColor [ConsoleColor]::DarkRed
        }
    }
}

# This function handles quick action key presses from the main dashboard.
function global:Handle-QuickAction {
    param([string]$Key)
    
    switch ($Key) {
        "M" { Push-Screen -Screen $script:TimeEntryFormScreen }
        "S" { Push-Screen -Screen $script:TimerStartScreen } # Placeholder, will be defined in time-management.ps1
        "A" { Push-Screen -Screen $script:QuickTaskAdd }
        "V" { Push-Screen -Screen $script:ActiveTimersScreen }
        "T" { Push-Screen -Screen $script:TodayViewScreen } # Placeholder, will be defined in time-management.ps1
        "W" { Push-Screen -Screen $script:WeekReportScreen }
        default {
            Write-StatusLine -Text " Quick action '$Key' is not yet implemented in a loaded module." -BackgroundColor [ConsoleColor]::DarkRed
        }
    }
}

#endregion

#region Main TUI Loop (Final Implementation)

# This is the enhanced TUI loop that supports live updates for components.
function Start-EnhancedTuiLoop {
    param(
        [hashtable]$InitialScreen
    )
    
    try {
        Initialize-TuiEngine
        Push-Screen -Screen $InitialScreen
        
        $script:TuiState.Running = $true
        $lastUpdate = [DateTime]::Now
        
        while ($script:TuiState.Running) {
            # Process any pending keyboard input
            $key = Process-Input
            if ($key) {
                Handle-ScreenInput -Key $key
            }
            
            # Trigger a live update for components every second
            if (([DateTime]::Now - $lastUpdate).TotalSeconds -ge 1) {
                # This is a generic hook. The dashboard screen's Render function
                # will contain the specific logic to update its components.
                $lastUpdate = [DateTime]::Now
            }
            
            # Render the current screen to the buffer and draw it
            Update-CurrentScreen
            
            # Sleep briefly to prevent 100% CPU usage
            Start-Sleep -Milliseconds 16
        }
    }
    finally {
        # Ensure the console is restored on exit
        Stop-InputHandler
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::ResetColor()
        
        # Save data on exit
        Save-UnifiedData
    }
}

#endregion

#region Entry Point

function Start-PMCTerminalTUI {
    Write-Host @"
╔════════════════════════════════════════════════════════════════════╗
║                  PMC Terminal - TUI Mode v5.0                      ║
║                                                                    ║
║  This is the enhanced non-blocking TUI version.                    ║
║  Loading modules...                                                ║
╚════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Start-Sleep -Seconds 1
    
    try {
        Start-EnhancedTuiLoop -InitialScreen $script:MainDashboardScreen
    }
    catch {
        Write-Error "A critical TUI error occurred: $_"
        Write-Error $_.ScriptStackTrace
    }
    finally {
        Write-Host "`n✨ Thank you for using PMC Terminal TUI!" -ForegroundColor Cyan
        Write-Host "Your productivity data has been saved." -ForegroundColor Gray
    }
}

# Check PowerShell version compatibility
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "This application requires PowerShell 5.0 or higher."
    exit 1
}

# Start the application
Start-PMCTerminalTUI

#endregion