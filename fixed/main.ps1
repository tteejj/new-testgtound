# PMC Terminal TUI - Main Entry Point
# Clean modular structure - no business logic here

#Requires -Version 5.0

# Set script root
$script:ModuleRoot = Join-Path $PSScriptRoot "modules"

# Load configuration
Write-Host "Loading PMC Terminal TUI..." -ForegroundColor Cyan

# Core TUI Engine and Systems
. "$script:ModuleRoot\tui-engine-v2.ps1"
. "$script:ModuleRoot\event-system.ps1"
. "$script:ModuleRoot\form-components.ps1"

# Business Logic Modules
. "$script:ModuleRoot\data-manager.ps1"
. "$script:ModuleRoot\time-management.ps1"
. "$script:ModuleRoot\task-management.ps1"
. "$script:ModuleRoot\project-management.ps1"
. "$script:ModuleRoot\report-generator.ps1"

# Screen Modules
. "$script:ModuleRoot\screens\dashboard-screen.ps1"
. "$script:ModuleRoot\screens\time-entry-screen.ps1"
. "$script:ModuleRoot\screens\task-list-screen.ps1"
. "$script:ModuleRoot\screens\timer-screen.ps1"
. "$script:ModuleRoot\screens\project-screen.ps1"
. "$script:ModuleRoot\screens\reports-screen.ps1"
. "$script:ModuleRoot\screens\settings-screen.ps1"

# Initialize application
function Start-PMCTerminal {
    try {
        # Initialize systems
        Initialize-TuiEngine
        Initialize-EventSystem
        Initialize-DataManager
        
        # Subscribe to global events
        Subscribe-Event -EventName "App.Exit" -Handler {
            Save-UnifiedData
            Write-TuiLog "Application shutting down gracefully" -Level Info
        }
        
        # Start with dashboard
        Start-TuiLoop -InitialScreen $script:DashboardScreen
    }
    catch {
        Write-Error "Fatal error: $_"
        Write-Error $_.ScriptStackTrace
        
        # Show error report if available
        $errorReport = Get-TuiErrorReport
        if ($errorReport) {
            Write-Host "`nError Report:`n$errorReport" -ForegroundColor Red
        }
    }
    finally {
        # Ensure cleanup
        if ($script:TuiState.Initialized) {
            Stop-TuiEngine
        }
        
        # Reset console
        [Console]::CursorVisible = $true
        Clear-Host
    }
}

# Auto-start if run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-PMCTerminal
}
