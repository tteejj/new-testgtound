# PMC Terminal - Main Entry Point
# Uses proper module loading with Import-Module

#region Module Loading
$script:ModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

# Define module load order (dependencies first)
$moduleLoadOrder = @(
    'event-system.psm1',
    'tui-engine-v2.psm1',
    'tui-components.psm1',
    'tui-components-extended.psm1',
    'data-manager.psm1'
)

# Load core modules in order
foreach ($moduleName in $moduleLoadOrder) {
    $modulePath = Join-Path $script:ModuleRoot $moduleName
    if (Test-Path $modulePath) {
        Write-Host "Loading module: $moduleName" -ForegroundColor DarkGray
        Import-Module $modulePath -Force -Global
    } else {
        Write-Warning "Module not found: $modulePath"
    }
}

# Load all screen modules from screens directory
$screensPath = Join-Path $script:ModuleRoot "screens"
if (Test-Path $screensPath) {
    Get-ChildItem -Path $screensPath -Filter *.psm1 | ForEach-Object {
        Write-Host "Loading screen: $($_.Name)" -ForegroundColor DarkGray
        Import-Module $_.FullName -Force -Global
    }
}

#endregion

#region Navigation Event Handlers

function Initialize-NavigationHandlers {
    # Handle generic navigation events
    Subscribe-Event -EventName "Navigation.PopScreen" -Handler {
        Pop-Screen
    }
    
    Subscribe-Event -EventName "Navigation.PushScreen" -Handler {
        param($EventData)
        if ($EventData.Data.Screen) {
            Push-Screen -Screen $EventData.Data.Screen
        }
    }
    
    Subscribe-Event -EventName "Navigation.GoHome" -Handler {
        # Clear the stack and go to dashboard
        while (Pop-Screen) { }
        Push-Screen -Screen (Get-DashboardScreen)
    }
}

#endregion

#region Dashboard Screen Definition

function Get-DashboardScreen {
    $dashboard = @{
        Name = "DashboardScreen"
        State = @{
            SelectedMenuIndex = 0
            MenuItems = @(
                @{ Text = "Add Time Entry"; Action = { 
                    Push-Screen -Screen (Get-TimeEntryFormScreen) 
                }}
                @{ Text = "View Time Entries"; Action = { 
                    Push-Screen -Screen (Get-TimeEntriesListScreen) 
                }}
                @{ Text = "Manage Timers"; Action = { 
                    Push-Screen -Screen (Get-TimerManagementScreen) 
                }}
                @{ Text = "Manage Tasks"; Action = { 
                    Push-Screen -Screen (Get-TaskManagementScreen) 
                }}
                @{ Text = "Manage Projects"; Action = { 
                    # Push-Screen -Screen (Get-ProjectsScreen) 
                    Publish-Event -EventName "Notification.Show" -Data @{ 
                        Text = "Projects Screen not implemented yet"
                        Type = "Info" 
                    }
                }}
                @{ Text = "Reports"; Action = { 
                    # Push-Screen -Screen (Get-ReportsScreen) 
                    Publish-Event -EventName "Notification.Show" -Data @{ 
                        Text = "Reports Screen not implemented yet"
                        Type = "Info" 
                    }
                }}
                @{ Text = "Settings"; Action = { 
                    # Push-Screen -Screen (Get-SettingsScreen) 
                    Publish-Event -EventName "Notification.Show" -Data @{ 
                        Text = "Settings Screen not implemented yet"
                        Type = "Info" 
                    }
                }}
                @{ Text = "Exit"; Action = { 
                    Publish-Event -EventName "App.Exit" 
                }}
            )
        }
        
        Render = {
            param($self)
            
            # Title
            $title = " PMC Terminal - Project Management Console "
            $titleX = [Math]::Floor(($script:TuiState.BufferWidth - $title.Length) / 2)
            Write-BufferString -X $titleX -Y 2 -Text $title -ForegroundColor (Get-ThemeColor "Header")
            
            # Menu box
            $menuWidth = 40
            $menuHeight = $self.State.MenuItems.Count + 4
            $menuX = [Math]::Floor(($script:TuiState.BufferWidth - $menuWidth) / 2)
            $menuY = 5
            
            Write-BufferBox -X $menuX -Y $menuY -Width $menuWidth -Height $menuHeight `
                -Title " Main Menu " -BorderColor (Get-ThemeColor "Primary")
            
            # Menu items
            for ($i = 0; $i -lt $self.State.MenuItems.Count; $i++) {
                $item = $self.State.MenuItems[$i]
                $itemY = $menuY + 2 + $i
                
                if ($i -eq $self.State.SelectedMenuIndex) {
                    # Highlight selected item
                    Write-BufferString -X ($menuX + 1) -Y $itemY `
                        -Text (" " * ($menuWidth - 2)) -BackgroundColor (Get-ThemeColor "Accent")
                    Write-BufferString -X ($menuX + 2) -Y $itemY -Text "▶ $($item.Text)" `
                        -ForegroundColor (Get-ThemeColor "Background") -BackgroundColor (Get-ThemeColor "Accent")
                } else {
                    Write-BufferString -X ($menuX + 4) -Y $itemY -Text $item.Text `
                        -ForegroundColor (Get-ThemeColor "Primary")
                }
            }
            
            # Instructions
            $instructions = "Use ↑↓ to navigate, Enter to select, Esc to exit"
            $instrX = [Math]::Floor(($script:TuiState.BufferWidth - $instructions.Length) / 2)
            Write-BufferString -X $instrX -Y ($menuY + $menuHeight + 2) -Text $instructions `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.SelectedMenuIndex -gt 0) {
                        $self.State.SelectedMenuIndex--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.State.SelectedMenuIndex -lt $self.State.MenuItems.Count - 1) {
                        $self.State.SelectedMenuIndex++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    $selectedItem = $self.State.MenuItems[$self.State.SelectedMenuIndex]
                    if ($selectedItem.Action) {
                        & $selectedItem.Action
                    }
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    return "Quit"
                }
            }
            return $false
        }
    }
    
    return $dashboard
}

#endregion

#region Notification System

function Initialize-NotificationSystem {
    $script:NotificationState = @{
        Current = $null
        Timer = $null
    }
    
    Subscribe-Event -EventName "Notification.Show" -Handler {
        param($EventData)
        $notification = $EventData.Data
        
        $script:NotificationState.Current = @{
            Text = $notification.Text ?? "Notification"
            Type = $notification.Type ?? "Info"
            StartTime = [DateTime]::Now
        }
        
        Request-TuiRefresh
        
        # Auto-hide after 3 seconds
        if ($script:NotificationState.Timer) {
            $script:NotificationState.Timer.Stop()
            $script:NotificationState.Timer.Dispose()
        }
        
        $script:NotificationState.Timer = New-Object System.Timers.Timer
        $script:NotificationState.Timer.Interval = 3000
        $script:NotificationState.Timer.AutoReset = $false
        Register-ObjectEvent -InputObject $script:NotificationState.Timer -EventName Elapsed -Action {
            $script:NotificationState.Current = $null
            Request-TuiRefresh
        } | Out-Null
        $script:NotificationState.Timer.Start()
    }
    
    # Hook into the render pipeline
    Subscribe-Event -EventName "Screen.Pushed" -Handler {
        # Inject notification rendering
        $originalRender = $script:TuiState.CurrentScreen.Render
        $script:TuiState.CurrentScreen.Render = {
            param($self)
            
            # Call original render
            & $originalRender -self $self
            
            # Overlay notification if present
            if ($script:NotificationState.Current) {
                $notif = $script:NotificationState.Current
                $text = " $($notif.Text) "
                $width = [Math]::Max($text.Length + 4, 30)
                $height = 5
                $x = [Math]::Floor(($script:TuiState.BufferWidth - $width) / 2)
                $y = [Math]::Floor(($script:TuiState.BufferHeight - $height) / 2)
                
                $bgColor = switch ($notif.Type) {
                    "Success" { [ConsoleColor]::DarkGreen }
                    "Error" { [ConsoleColor]::DarkRed }
                    "Warning" { [ConsoleColor]::DarkYellow }
                    default { [ConsoleColor]::DarkBlue }
                }
                
                # Shadow
                for ($sy = 1; $sy -lt $height; $sy++) {
                    for ($sx = 1; $sx -lt $width; $sx++) {
                        Write-BufferString -X ($x + $sx + 1) -Y ($y + $sy + 1) -Text " " `
                            -BackgroundColor [ConsoleColor]::Black
                    }
                }
                
                # Notification box
                Write-BufferBox -X $x -Y $y -Width $width -Height $height `
                    -BorderStyle "Double" -BorderColor [ConsoleColor]::White -BackgroundColor $bgColor
                    
                # Text
                $textX = $x + [Math]::Floor(($width - $text.Length) / 2)
                Write-BufferString -X $textX -Y ($y + 2) -Text $text `
                    -ForegroundColor [ConsoleColor]::White -BackgroundColor $bgColor
            }
        }.GetNewClosure()
    }
}

#endregion

#region Main Application Entry

function Start-PMCTerminal {
    try {
        # Initialize all systems
        Initialize-NavigationHandlers
        Initialize-NotificationSystem
        Initialize-DataEventHandlers
        
        # Load application data
        Load-UnifiedData
        
        # Handle app exit
        Subscribe-Event -EventName "App.Exit" -Handler {
            $script:TuiState.Running = $false
        }
        
        # Create and start with dashboard
        $dashboardScreen = Get-DashboardScreen
        
        # Start the TUI loop
        Start-TuiLoop -InitialScreen $dashboardScreen
        
        Write-Host "`nThank you for using PMC Terminal!" -ForegroundColor Green
    }
    catch {
        Write-Error "Fatal error: $_"
        Write-Error $_.ScriptStackTrace
    }
    finally {
        # Cleanup
        if ($script:NotificationState.Timer) {
            $script:NotificationState.Timer.Stop()
            $script:NotificationState.Timer.Dispose()
        }
    }
}

# Display startup banner
Clear-Host
Write-Host @"
╔═══════════════════════════════════════════════════════════╗
║                     PMC Terminal v3.0                     ║
║                Project Management Console                 ║
║                                                          ║
║              Built with TUI Framework v2.2               ║
╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "`nInitializing..." -ForegroundColor Gray

# Start the application
Start-PMCTerminal

#endregion
