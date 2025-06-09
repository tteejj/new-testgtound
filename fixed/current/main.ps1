# PMC Terminal v3.0 - Main Entry Point

#region Module Loading
$script:ModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

# Create screens directory if it doesn't exist
$screensPath = Join-Path $script:ModuleRoot "screens"
if (-not (Test-Path $screensPath)) {
    New-Item -ItemType Directory -Path $screensPath -Force | Out-Null
}

# Define module load order (dependencies first)
$moduleLoadOrder = @(
    "event-system.psm1",
    "tui-engine-v2.psm1", 
    "tui-components.psm1",
    "data-manager.psm1"
)

# Load core modules in order
foreach ($moduleName in $moduleLoadOrder) {
    $modulePath = Join-Path $script:ModuleRoot $moduleName
    if (Test-Path $modulePath) {
        Write-Host "Loading module: $moduleName" -ForegroundColor Gray
        Import-Module $modulePath -Force -Global
    } else {
        Write-Host "WARNING: Module not found: $modulePath" -ForegroundColor Yellow
    }
}

# Load all screen modules
Get-ChildItem -Path $screensPath -Filter "*.psm1" | ForEach-Object {
    Write-Host "Loading screen: $($_.Name)" -ForegroundColor Gray
    Import-Module $_.FullName -Force -Global
}

#endregion

#region Global Error Handler
$ErrorActionPreference = "Stop"
$script:ErrorLogPath = Join-Path $script:ModuleRoot "error.log"

function Write-ErrorLog {
    param($Error)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errorInfo = @"
----------------------------------------------------
Timestamp: $timestamp
Error: $($Error.Exception.Message)
Stack Trace:
$($Error.ScriptStackTrace)
----------------------------------------------------
"@
    Add-Content -Path $script:ErrorLogPath -Value $errorInfo
}

#endregion

#region Console Size Check
function Test-ConsoleSize {
    $width = [Console]::WindowWidth
    $height = [Console]::WindowHeight
    $minWidth = 80
    $minHeight = 24
    
    if ($width -lt $minWidth -or $height -lt $minHeight) {
        Write-Host "`nConsole Window Too Small!" -ForegroundColor Red
        Write-Host "================================" -ForegroundColor Red
        Write-Host "Current size: $width x $height" -ForegroundColor Yellow
        Write-Host "Minimum required: $minWidth x $minHeight" -ForegroundColor Green
        Write-Host "`nPlease resize your console window and try again." -ForegroundColor Yellow
        Write-Host "In Windows Terminal: drag the window edges to resize" -ForegroundColor Gray
        Write-Host "In PowerShell: right-click title bar > Properties > Layout" -ForegroundColor Gray
        return $false
    }
    return $true
}
#endregion

#region Main Application Logic
function Start-PmcTerminal {
    try {
        # Check console size first
        if (-not (Test-ConsoleSize)) {
            Write-Host "`nPress any key to exit..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        
        # Initialize event system first
        Write-Host "Initializing PMC Terminal..." -ForegroundColor Cyan
        
        # Initialize data event handlers
        Initialize-DataEventHandlers
        
        # Load application data
        Load-UnifiedData
        
        # Subscribe to navigation events (suppress output)
        $null = Subscribe-Event -EventName "Navigation.PopScreen" -Handler { 
            Pop-Screen | Out-Null
        }
        
        $null = Subscribe-Event -EventName "Navigation.PushScreen" -Handler { 
            param($EventData)
            if ($EventData.Data.Screen) {
                Push-Screen -Screen $EventData.Data.Screen
            }
        }
        
        # Subscribe to notification events
        $null = Subscribe-Event -EventName "Notification.Show" -Handler {
            param($EventData)
            $notification = $EventData.Data
            $color = switch ($notification.Type) {
                "Success" { "Green" }
                "Error" { "Red" }
                "Warning" { "Yellow" }
                default { "White" }
            }
            Write-StatusLine -Text $notification.Text -ForegroundColor $color
        }
        
        # Subscribe to timer events
        $null = Subscribe-Event -EventName "Timer.Stop" -Handler {
            param($EventData)
            if ($script:Data.ActiveTimer) {
                $elapsed = [DateTime]::Now - [DateTime]::Parse($script:Data.ActiveTimer.StartTime)
                $hours = [Math]::Round($elapsed.TotalHours, 2)
                
                # Create time entry from timer
                $entry = @{
                    Id = "TE-$(Get-Random -Maximum 999999)"
                    ProjectKey = $script:Data.ActiveTimer.ProjectKey
                    Hours = $hours
                    Description = $script:Data.ActiveTimer.Description
                    Date = (Get-Date).ToString("yyyy-MM-dd")
                }
                
                $script:Data.TimeEntries += $entry
                $script:Data.ActiveTimer = $null
                Save-UnifiedData
                
                Publish-Event -EventName "Notification.Show" -Data @{
                    Text = "Timer stopped. $hours hours recorded."
                    Type = "Success"
                }
                Request-TuiRefresh
            }
        }
        
        # Create and start with dashboard
        $dashboardScreen = Get-DashboardScreen
        
        # Start the main TUI loop
        Start-TuiLoop -InitialScreen $dashboardScreen
        
    } catch {
        Write-ErrorLog $_
        
        # Check if it's a console size error
        if ($_.Exception.Message -like "*Console window too small*") {
            Write-Host "`nConsole Window Too Small!" -ForegroundColor Red
            Write-Host "================================" -ForegroundColor Red
            $currentWidth = [Console]::WindowWidth
            $currentHeight = [Console]::WindowHeight
            Write-Host "Current size: $currentWidth x $currentHeight" -ForegroundColor Yellow
            Write-Host "Minimum required: 80 x 24" -ForegroundColor Green
            Write-Host "`nPlease resize your console window to at least 80x24 and try again." -ForegroundColor Yellow
        } else {
            Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Error has been logged to: $script:ErrorLogPath" -ForegroundColor Yellow
        }
        
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# Entry point
if ($MyInvocation.InvocationName -ne '.') {
    Start-PmcTerminal
}

#endregion
