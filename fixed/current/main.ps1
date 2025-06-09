# PMC Terminal v3.0 - Main Entry Point
# This file orchestrates module loading and application initialization

# Set strict mode
Set-StrictMode -Version Latest

# Get script root
$script:AppRoot = $PSScriptRoot

# Import modules in correct order
Write-Host "Loading PMC Terminal v3.0..." -ForegroundColor Cyan

# Core engine modules
Import-Module (Join-Path $script:AppRoot "modules\tui-engine-v2.psm1") -Force
Import-Module (Join-Path $script:AppRoot "modules\event-system.psm1") -Force
Import-Module (Join-Path $script:AppRoot "modules\data-manager.psm1") -Force
Import-Module (Join-Path $script:AppRoot "modules\dialog-system.psm1") -Force
Import-Module (Join-Path $script:AppRoot "modules\theme-manager.psm1") -Force

# UI Components
Import-Module (Join-Path $script:AppRoot "components\tui-components.psm1") -Force

# Utility modules
$utilityModules = @(
    "file-browser.psm1",
    "fuzzy-search.psm1", 
    "command-palette.psm1",
    "core-utilities.psm1"
)
foreach ($module in $utilityModules) {
    $modulePath = Join-Path $script:AppRoot "utilities\$module"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
}

# Screen modules
$screenModules = @(
    "dashboard-screen.psm1",
    "time-entry-screen.psm1",
    "task-management-screen.psm1",
    "project-management-screen.psm1",
    "timer-management-screen.psm1",
    "reports-screen.psm1",
    "settings-screen.psm1"
)
foreach ($module in $screenModules) {
    $modulePath = Join-Path $script:AppRoot "screens\$module"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force
    }
}

# Initialize application
function Start-PMCTerminal {
    try {
        # Initialize core systems
        Initialize-TuiEngine
        Initialize-EventSystem
        Initialize-ThemeManager
        Initialize-DialogSystem
        
        # Load application data
        Load-UnifiedData
        
        # Initialize event handlers
        Initialize-DataEventHandlers
        
        # Start with dashboard screen
        $dashboardScreen = Get-DashboardScreen
        Push-Screen -Screen $dashboardScreen
        
        # Run the main loop
        Start-TuiLoop
        
        # Cleanup on exit
        Write-Host "`nThank you for using PMC Terminal!" -ForegroundColor Green
    }
    catch {
        Write-Error "Fatal error: $_"
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    finally {
        # Ensure data is saved
        if ($script:Data) {
            Save-UnifiedData
        }
        
        # Restore console
        if (Get-Command -Name "Restore-TuiState" -ErrorAction SilentlyContinue) {
            Restore-TuiState
        }
    }
}

# Check for command line arguments
if ($args.Count -gt 0) {
    switch ($args[0].ToLower()) {
        "backup" {
            Load-UnifiedData
            Backup-Data
            Write-Host "Backup completed successfully!" -ForegroundColor Green
            exit
        }
        "export" {
            Load-UnifiedData
            # Export functionality to be implemented
            Write-Host "Export functionality coming soon!" -ForegroundColor Yellow
            exit
        }
        "help" {
            Write-Host @"
PMC Terminal v3.0 - Project Management Console

Usage: .\main.ps1 [command]

Commands:
  (none)    Start the interactive TUI
  backup    Create a backup of the data file
  export    Export data (coming soon)
  help      Show this help message

"@ -ForegroundColor Cyan
            exit
        }
    }
}

# Start the application
Start-PMCTerminal