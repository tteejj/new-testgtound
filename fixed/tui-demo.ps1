# TUI Engine v2 Enhanced - Demo Application
# Demonstrates the capabilities of the rock-solid TUI engine

# Import the enhanced modules
Import-Module "$PSScriptRoot\tui-engine-v2-enhanced.psm1" -Force
Import-Module "$PSScriptRoot\core-components.psm1" -Force

# Demo data
$script:DemoData = @{
    Tasks = @(
        @{ Id = 1; Title = "Implement deep cloning"; Status = "Complete"; Progress = 100 }
        @{ Id = 2; Title = "Optimize ANSI rendering"; Status = "Complete"; Progress = 100 }
        @{ Id = 3; Title = "Build component library"; Status = "In Progress"; Progress = 75 }
        @{ Id = 4; Title = "Create demo application"; Status = "In Progress"; Progress = 50 }
        @{ Id = 5; Title = "Write documentation"; Status = "Pending"; Progress = 0 }
    )
    Settings = @{
        Theme = "Default"
        AutoSave = $true
        RefreshRate = 60
    }
}

#region Main Dashboard Screen

$script:MainDashboardScreen = @{
    Name = "Dashboard"
    State = @{
        SelectedMenuIndex = 0
        StatusMessage = "Welcome to TUI Engine v2 Enhanced Demo"
    }
    
    Init = {
        Write-TuiLog "Dashboard initialized" -Level Info
        
        # Subscribe to events
        $script:DashboardEventHandler = Subscribe-TuiEvent -EventName "Component.ButtonClick" -Handler {
            param($EventData)
            $script:MainDashboardScreen.State.StatusMessage = "Button clicked: $($EventData.Component.Text)"
        }
    }
    
    OnExit = {
        # Cleanup
        if ($script:DashboardEventHandler) {
            Unsubscribe-TuiEvent -EventName "Component.ButtonClick" -HandlerId $script:DashboardEventHandler
        }
    }
    
    Render = {
        # Header
        Write-BufferBox -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height 3 `
            -BorderStyle "Double" -BorderColor (Get-ThemeColor "Header")
        
        $title = "TUI Engine v2 Enhanced Demo"
        $titleX = [Math]::Floor(($script:TuiState.BufferWidth - $title.Length) / 2)
        Write-BufferString -X $titleX -Y 1 -Text $title `
            -ForegroundColor (Get-ThemeColor "Header")
        
        # Menu
        $menuItems = @(
            "Component Gallery",
            "Performance Test",
            "Theme Selector",
            "Event System Demo",
            "Layout Demo",
            "Settings",
            "Exit"
        )
        
        Write-BufferBox -X 2 -Y 4 -Width 30 -Height ($menuItems.Count + 4) `
            -Title "Main Menu" -BorderColor (Get-ThemeColor "Accent")
        
        for ($i = 0; $i -lt $menuItems.Count; $i++) {
            $prefix = if ($i -eq $script:MainDashboardScreen.State.SelectedMenuIndex) { "► " } else { "  " }
            $color = if ($i -eq $script:MainDashboardScreen.State.SelectedMenuIndex) { 
                Get-ThemeColor "Accent" 
            } else { 
                Get-ThemeColor "Primary" 
            }
            
            Write-BufferString -X 4 -Y (6 + $i) -Text "$prefix$($menuItems[$i])" `
                -ForegroundColor $color
        }
        
        # Info panel
        Write-BufferBox -X 35 -Y 4 -Width 50 -Height 20 `
            -Title "Information" -BorderColor (Get-ThemeColor "Secondary")
        
        $info = @(
            "Engine Version: 2.1 Enhanced",
            "Render FPS: $([Math]::Round(1000 / [Math]::Max(1, $script:TuiState.RenderStats.LastFrameTime)))",
            "Frame Count: $($script:TuiState.RenderStats.FrameCount)",
            "Input Queue: $($script:TuiState.InputQueue.Count)",
            "Theme: $($script:TuiState.CurrentTheme)",
            "",
            "Features:",
            "• Deep cloning for components",
            "• Optimized ANSI rendering",
            "• Event-driven architecture",
            "• Reusable component library",
            "• Layout managers",
            "• Theme system"
        )
        
        $y = 6
        foreach ($line in $info) {
            Write-BufferString -X 37 -Y $y -Text $line -ForegroundColor (Get-ThemeColor "Primary")
            $y++
        }
        
        # Status bar
        Write-StatusLine -Text " $($script:MainDashboardScreen.State.StatusMessage)" `
            -BackgroundColor (Get-ThemeColor "Info")
    }
    
    HandleInput = {
        param($Key)
        
        $menuCount = 7
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                $script:MainDashboardScreen.State.SelectedMenuIndex = `
                    ($script:MainDashboardScreen.State.SelectedMenuIndex - 1 + $menuCount) % $menuCount
            }
            ([ConsoleKey]::DownArrow) {
                $script:MainDashboardScreen.State.SelectedMenuIndex = `
                    ($script:MainDashboardScreen.State.SelectedMenuIndex + 1) % $menuCount
            }
            ([ConsoleKey]::Enter) {
                switch ($script:MainDashboardScreen.State.SelectedMenuIndex) {
                    0 { Push-Screen -Screen $script:ComponentGalleryScreen }
                    1 { Push-Screen -Screen $script:PerformanceTestScreen }
                    2 { Push-Screen -Screen $script:ThemeSelectorScreen }
                    3 { Push-Screen -Screen $script:EventDemoScreen }
                    4 { Push-Screen -Screen $script:LayoutDemoScreen }
                    5 { Push-Screen -Screen $script:SettingsScreen }
                    6 { return "Quit" }
                }
            }
            ([ConsoleKey]::Escape) {
                return "Quit"
            }
        }
    }
}

#endregion

#region Component Gallery Screen

$script:ComponentGalleryScreen = @{
    Name = "ComponentGallery"
    State = @{
        Container = $null
        Components = @()
    }
    
    Init = {
        # Create main container
        $container = New-TuiContainer -Properties @{
            X = 2
            Y = 4
            Width = $script:TuiState.BufferWidth - 4
            Height = $script:TuiState.BufferHeight - 6
        }
        
        # Add various components to demonstrate
        
        # Label
        $label = New-TuiLabel -Props @{
            X = 2
            Y = 2
            Width = 30
            Text = "Sample Label Component"
            ForegroundColor = [ConsoleColor]::Cyan
        }
        & $container.AddChild -self $container -child $label
        
        # Button
        $button1 = New-TuiButton -Props @{
            X = 2
            Y = 5
            Width = 20
            Text = "Click Me!"
            OnClick = {
                Write-TuiLog "Button clicked!" -Level Info
                Publish-TuiEvent -EventName "Demo.ButtonClicked" -Data @{ Message = "Hello from button!" }
            }
        }
        & $container.AddChild -self $container -child $button1
        
        # TextBox
        $textBox = New-TuiTextBox -Props @{
            X = 2
            Y = 9
            Width = 40
            PlaceHolder = "Enter some text..."
            OnChange = {
                param($Component, $OldValue, $NewValue)
                Write-TuiLog "TextBox changed: '$OldValue' -> '$NewValue'" -Level Info
            }
        }
        & $container.AddChild -self $container -child $textBox
        
        # CheckBox
        $checkBox = New-TuiCheckBox -Props @{
            X = 2
            Y = 13
            Label = "Enable feature"
            Checked = $true
            OnChange = {
                param($Component, $OldValue, $NewValue)
                Write-TuiLog "CheckBox changed: $OldValue -> $NewValue" -Level Info
            }
        }
        & $container.AddChild -self $container -child $checkBox
        
        # ProgressBar
        $progressBar = New-TuiProgressBar -Props @{
            X = 2
            Y = 15
            Width = 40
            Value = 65
        }
        & $container.AddChild -self $container -child $progressBar
        
        # ListBox
        $listBox = New-TuiListBox -Props @{
            X = 45
            Y = 2
            Width = 35
            Height = 10
            Items = $script:DemoData.Tasks
            ItemRenderer = { param($item) "$($item.Title) ($($item.Status))" }
            OnSelectionChange = {
                param($Component, $OldIndex, $NewIndex)
                Write-TuiLog "ListBox selection: $OldIndex -> $NewIndex" -Level Info
            }
        }
        & $container.AddChild -self $container -child $listBox
        
        # Menu
        $menu = New-TuiMenu -Props @{
            X = 45
            Y = 14
            Width = 35
            Items = @(
                @{ Text = "Option 1"; Action = { Write-TuiLog "Option 1 selected" } }
                @{ Text = "Option 2"; Action = { Write-TuiLog "Option 2 selected" } }
                @{ Text = "Option 3"; Action = { Write-TuiLog "Option 3 selected" } }
            )
        }
        & $container.AddChild -self $container -child $menu
        
        # Store references
        $script:ComponentGalleryScreen.State.Container = $container
        $script:ComponentGalleryScreen.State.Components = @{
            Label = $label
            Button = $button1
            TextBox = $textBox
            CheckBox = $checkBox
            ProgressBar = $progressBar
            ListBox = $listBox
            Menu = $menu
        }
        
        # Focus first component
        & $container.OnFocus -self $container
    }
    
    Render = {
        # Header
        Write-BufferBox -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height 3 `
            -BorderStyle "Double" -BorderColor (Get-ThemeColor "Header")
        
        $title = "Component Gallery - Tab to navigate, Enter to interact"
        $titleX = [Math]::Floor(($script:TuiState.BufferWidth - $title.Length) / 2)
        Write-BufferString -X $titleX -Y 1 -Text $title `
            -ForegroundColor (Get-ThemeColor "Header")
        
        # Container border
        Write-BufferBox -X 1 -Y 3 -Width ($script:TuiState.BufferWidth - 2) -Height ($script:TuiState.BufferHeight - 5) `
            -Title "Components" -BorderColor (Get-ThemeColor "Secondary")
        
        # Render container and all its children
        if ($script:ComponentGalleryScreen.State.Container) {
            & $script:ComponentGalleryScreen.State.Container.Render -self $script:ComponentGalleryScreen.State.Container
        }
        
        # Instructions
        Write-StatusLine -Text " Tab: Next | Shift+Tab: Previous | Esc: Back | Space/Enter: Interact"
    }
    
    HandleInput = {
        param($Key)
        
        if ($Key.Key -eq [ConsoleKey]::Escape) {
            return "Back"
        }
        
        # Pass input to container
        if ($script:ComponentGalleryScreen.State.Container) {
            $handled = & $script:ComponentGalleryScreen.State.Container.HandleInput `
                -self $script:ComponentGalleryScreen.State.Container -Key $Key
        }
        
        # Demo: Animate progress bar with + and -
        if ($Key.KeyChar -eq '+') {
            $pb = $script:ComponentGalleryScreen.State.Components.ProgressBar
            $newValue = [Math]::Min(100, $pb.Value + 5)
            & $pb.SetValue -self $pb -value $newValue
        }
        elseif ($Key.KeyChar -eq '-') {
            $pb = $script:ComponentGalleryScreen.State.Components.ProgressBar
            $newValue = [Math]::Max(0, $pb.Value - 5)
            & $pb.SetValue -self $pb -value $newValue
        }
    }
}

#endregion

#region Performance Test Screen

$script:PerformanceTestScreen = @{
    Name = "PerformanceTest"
    State = @{
        TestRunning = $false
        FrameCount = 0
        StartTime = $null
        Results = @()
        TestType = "Rendering"  # Rendering, Components, Events
    }
    
    Render = {
        # Header
        Write-BufferBox -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height 3 `
            -BorderStyle "Double" -BorderColor (Get-ThemeColor "Header")
        
        $title = "Performance Test"
        $titleX = [Math]::Floor(($script:TuiState.BufferWidth - $title.Length) / 2)
        Write-BufferString -X $titleX -Y 1 -Text $title `
            -ForegroundColor (Get-ThemeColor "Header")
        
        # Test controls
        Write-BufferBox -X 2 -Y 4 -Width 40 -Height 10 `
            -Title "Test Controls" -BorderColor (Get-ThemeColor "Accent")
        
        $y = 6
        Write-BufferString -X 4 -Y $y -Text "Test Type: $($script:PerformanceTestScreen.State.TestType)" `
            -ForegroundColor (Get-ThemeColor "Primary")
        $y += 2
        
        if ($script:PerformanceTestScreen.State.TestRunning) {
            Write-BufferString -X 4 -Y $y -Text "Test Running..." `
                -ForegroundColor (Get-ThemeColor "Warning")
            $y++
            Write-BufferString -X 4 -Y $y -Text "Frames: $($script:PerformanceTestScreen.State.FrameCount)" `
                -ForegroundColor (Get-ThemeColor "Info")
        } else {
            Write-BufferString -X 4 -Y $y -Text "[S] Start Test" `
                -ForegroundColor (Get-ThemeColor "Success")
            $y++
            Write-BufferString -X 4 -Y $y -Text "[T] Toggle Test Type" `
                -ForegroundColor (Get-ThemeColor "Primary")
        }
        
        # Results
        Write-BufferBox -X 45 -Y 4 -Width 40 -Height 20 `
            -Title "Results" -BorderColor (Get-ThemeColor "Secondary")
        
        $y = 6
        foreach ($result in $script:PerformanceTestScreen.State.Results | Select-Object -Last 10) {
            Write-BufferString -X 47 -Y $y -Text $result -ForegroundColor (Get-ThemeColor "Primary")
            $y++
        }
        
        # Render stress test if running
        if ($script:PerformanceTestScreen.State.TestRunning -and 
            $script:PerformanceTestScreen.State.TestType -eq "Rendering") {
            
            # Draw random characters to stress test rendering
            for ($i = 0; $i -lt 100; $i++) {
                $x = Get-Random -Minimum 2 -Maximum ($script:TuiState.BufferWidth - 2)
                $y = Get-Random -Minimum 15 -Maximum ($script:TuiState.BufferHeight - 2)
                $char = [char](Get-Random -Minimum 33 -Maximum 126)
                $color = Get-Random -Minimum 0 -Maximum 15
                
                Write-BufferString -X $x -Y $y -Text $char `
                    -ForegroundColor ([ConsoleColor]$color)
            }
        }
        
        Write-StatusLine -Text " [S] Start | [T] Toggle Type | [Esc] Back"
    }
    
    HandleInput = {
        param($Key)
        
        switch ($Key.Key) {
            ([ConsoleKey]::Escape) { return "Back" }
            ([ConsoleKey]::S) {
                if (-not $script:PerformanceTestScreen.State.TestRunning) {
                    $script:PerformanceTestScreen.State.TestRunning = $true
                    $script:PerformanceTestScreen.State.FrameCount = 0
                    $script:PerformanceTestScreen.State.StartTime = [DateTime]::Now
                    
                    # Run test for 5 seconds
                    $script:TestTimer = Subscribe-TuiEvent -EventName "TestComplete" -Handler {
                        $duration = ([DateTime]::Now - $script:PerformanceTestScreen.State.StartTime).TotalSeconds
                        $fps = $script:PerformanceTestScreen.State.FrameCount / $duration
                        
                        $result = "Test: $($script:PerformanceTestScreen.State.TestType) | " +
                                 "FPS: $([Math]::Round($fps, 2)) | " +
                                 "Frames: $($script:PerformanceTestScreen.State.FrameCount)"
                        
                        $script:PerformanceTestScreen.State.Results += $result
                        $script:PerformanceTestScreen.State.TestRunning = $false
                        
                        Unsubscribe-TuiEvent -EventName "TestComplete" -HandlerId $script:TestTimer
                    }
                    
                    # Schedule test completion
                    Start-Job -ScriptBlock {
                        Start-Sleep -Seconds 5
                    } | Wait-Job | Remove-Job
                    
                    Publish-TuiEvent -EventName "TestComplete"
                }
            }
            ([ConsoleKey]::T) {
                if (-not $script:PerformanceTestScreen.State.TestRunning) {
                    $types = @("Rendering", "Components", "Events")
                    $current = [array]::IndexOf($types, $script:PerformanceTestScreen.State.TestType)
                    $script:PerformanceTestScreen.State.TestType = $types[($current + 1) % $types.Count]
                }
            }
        }
        
        # Count frames during test
        if ($script:PerformanceTestScreen.State.TestRunning) {
            $script:PerformanceTestScreen.State.FrameCount++
        }
    }
}

#endregion

#region Theme Selector Screen

$script:ThemeSelectorScreen = @{
    Name = "ThemeSelector"
    State = @{
        SelectedTheme = 0
        Themes = @("Default", "Dark", "Light")
    }
    
    Render = {
        # Header
        Write-BufferBox -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height 3 `
            -BorderStyle "Double" -BorderColor (Get-ThemeColor "Header")
        
        $title = "Theme Selector"
        $titleX = [Math]::Floor(($script:TuiState.BufferWidth - $title.Length) / 2)
        Write-BufferString -X $titleX -Y 1 -Text $title `
            -ForegroundColor (Get-ThemeColor "Header")
        
        # Theme list
        Write-BufferBox -X 2 -Y 4 -Width 30 -Height 10 `
            -Title "Available Themes" -BorderColor (Get-ThemeColor "Accent")
        
        for ($i = 0; $i -lt $script:ThemeSelectorScreen.State.Themes.Count; $i++) {
            $theme = $script:ThemeSelectorScreen.State.Themes[$i]
            $prefix = if ($i -eq $script:ThemeSelectorScreen.State.SelectedTheme) { "► " } else { "  " }
            $suffix = if ($theme -eq $script:TuiState.CurrentTheme) { " (Current)" } else { "" }
            
            $color = if ($i -eq $script:ThemeSelectorScreen.State.SelectedTheme) { 
                Get-ThemeColor "Accent" 
            } else { 
                Get-ThemeColor "Primary" 
            }
            
            Write-BufferString -X 4 -Y (6 + $i) -Text "$prefix$theme$suffix" `
                -ForegroundColor $color
        }
        
        # Preview panel
        Write-BufferBox -X 35 -Y 4 -Width 50 -Height 20 `
            -Title "Theme Preview" -BorderColor (Get-ThemeColor "Secondary")
        
        $y = 6
        $colors = @("Primary", "Secondary", "Accent", "Success", "Warning", "Error", "Info", "Header", "Subtle")
        
        foreach ($colorName in $colors) {
            Write-BufferString -X 37 -Y $y -Text "$colorName :" -ForegroundColor (Get-ThemeColor "Primary")
            Write-BufferString -X 50 -Y $y -Text "████████" -ForegroundColor (Get-ThemeColor $colorName)
            $y += 2
        }
        
        Write-StatusLine -Text " ↑↓ Select | Enter: Apply | Esc: Back"
    }
    
    HandleInput = {
        param($Key)
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                $count = $script:ThemeSelectorScreen.State.Themes.Count
                $script:ThemeSelectorScreen.State.SelectedTheme = `
                    ($script:ThemeSelectorScreen.State.SelectedTheme - 1 + $count) % $count
            }
            ([ConsoleKey]::DownArrow) {
                $count = $script:ThemeSelectorScreen.State.Themes.Count
                $script:ThemeSelectorScreen.State.SelectedTheme = `
                    ($script:ThemeSelectorScreen.State.SelectedTheme + 1) % $count
            }
            ([ConsoleKey]::Enter) {
                $selectedTheme = $script:ThemeSelectorScreen.State.Themes[$script:ThemeSelectorScreen.State.SelectedTheme]
                Set-TuiTheme -ThemeName $selectedTheme
                Write-TuiLog "Theme changed to: $selectedTheme" -Level Info
            }
            ([ConsoleKey]::Escape) {
                return "Back"
            }
        }
    }
}

#endregion

#region Event Demo Screen

$script:EventDemoScreen = @{
    Name = "EventDemo"
    State = @{
        EventLog = [System.Collections.Generic.List[string]]::new()
        PublishCount = 0
        SubscriberCount = 0
        Subscriptions = @()
    }
    
    Init = {
        # Create multiple event subscriptions to demonstrate
        $events = @("Demo.Event1", "Demo.Event2", "Demo.Event3")
        
        foreach ($eventName in $events) {
            $handlerId = Subscribe-TuiEvent -EventName $eventName -Handler {
                param($EventData)
                $message = "[$(Get-Date -Format 'HH:mm:ss')] $($EventData.EventName): $($EventData.Message)"
                $script:EventDemoScreen.State.EventLog.Add($message)
                
                # Keep only last 20 entries
                if ($script:EventDemoScreen.State.EventLog.Count -gt 20) {
                    $script:EventDemoScreen.State.EventLog.RemoveAt(0)
                }
            }
            
            $script:EventDemoScreen.State.Subscriptions += @{
                EventName = $eventName
                HandlerId = $handlerId
            }
        }
        
        $script:EventDemoScreen.State.SubscriberCount = $script:EventDemoScreen.State.Subscriptions.Count
    }
    
    OnExit = {
        # Cleanup subscriptions
        foreach ($sub in $script:EventDemoScreen.State.Subscriptions) {
            Unsubscribe-TuiEvent -EventName $sub.EventName -HandlerId $sub.HandlerId
        }
    }
    
    Render = {
        # Header
        Write-BufferBox -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height 3 `
            -BorderStyle "Double" -BorderColor (Get-ThemeColor "Header")
        
        $title = "Event System Demo"
        $titleX = [Math]::Floor(($script:TuiState.BufferWidth - $title.Length) / 2)
        Write-BufferString -X $titleX -Y 1 -Text $title `
            -ForegroundColor (Get-ThemeColor "Header")
        
        # Controls
        Write-BufferBox -X 2 -Y 4 -Width 40 -Height 12 `
            -Title "Event Controls" -BorderColor (Get-ThemeColor "Accent")
        
        Write-BufferString -X 4 -Y 6 -Text "Press keys to publish events:" `
            -ForegroundColor (Get-ThemeColor "Primary")
        
        Write-BufferString -X 4 -Y 8 -Text "[1] Publish Event1" -ForegroundColor (Get-ThemeColor "Success")
        Write-BufferString -X 4 -Y 9 -Text "[2] Publish Event2" -ForegroundColor (Get-ThemeColor "Warning")
        Write-BufferString -X 4 -Y 10 -Text "[3] Publish Event3" -ForegroundColor (Get-ThemeColor "Error")
        Write-BufferString -X 4 -Y 11 -Text "[A] Publish All" -ForegroundColor (Get-ThemeColor "Info")
        
        Write-BufferString -X 4 -Y 13 -Text "Published: $($script:EventDemoScreen.State.PublishCount)" `
            -ForegroundColor (Get-ThemeColor "Primary")
        Write-BufferString -X 4 -Y 14 -Text "Subscribers: $($script:EventDemoScreen.State.SubscriberCount)" `
            -ForegroundColor (Get-ThemeColor "Primary")
        
        # Event log
        Write-BufferBox -X 45 -Y 4 -Width 40 -Height 22 `
            -Title "Event Log" -BorderColor (Get-ThemeColor "Secondary")
        
        $y = 6
        foreach ($entry in $script:EventDemoScreen.State.EventLog) {
            if ($entry.Length -gt 36) {
                $entry = $entry.Substring(0, 33) + "..."
            }
            Write-BufferString -X 47 -Y $y -Text $entry -ForegroundColor (Get-ThemeColor "Primary")
            $y++
        }
        
        Write-StatusLine -Text " [1-3] Publish Event | [A] All | [Esc] Back"
    }
    
    HandleInput = {
        param($Key)
        
        switch ($Key.Key) {
            ([ConsoleKey]::D1) {
                Publish-TuiEvent -EventName "Demo.Event1" -Data @{
                    EventName = "Demo.Event1"
                    Message = "Event 1 triggered"
                }
                $script:EventDemoScreen.State.PublishCount++
            }
            ([ConsoleKey]::D2) {
                Publish-TuiEvent -EventName "Demo.Event2" -Data @{
                    EventName = "Demo.Event2"
                    Message = "Event 2 triggered"
                }
                $script:EventDemoScreen.State.PublishCount++
            }
            ([ConsoleKey]::D3) {
                Publish-TuiEvent -EventName "Demo.Event3" -Data @{
                    EventName = "Demo.Event3"
                    Message = "Event 3 triggered"
                }
                $script:EventDemoScreen.State.PublishCount++
            }
            ([ConsoleKey]::A) {
                for ($i = 1; $i -le 3; $i++) {
                    Publish-TuiEvent -EventName "Demo.Event$i" -Data @{
                        EventName = "Demo.Event$i"
                        Message = "Batch event $i"
                    }
                    $script:EventDemoScreen.State.PublishCount++
                }
            }
            ([ConsoleKey]::Escape) {
                return "Back"
            }
        }
    }
}

#endregion

#region Layout Demo Screen

$script:LayoutDemoScreen = @{
    Name = "LayoutDemo"
    State = @{
        CurrentLayout = "Stack"
        Layouts = @("Stack", "Grid", "Dock", "Flow")
        Container = $null
    }
    
    Init = {
        # Create demo container with sample components
        $script:LayoutDemoScreen.State.Container = New-TuiContainer -Properties @{
            X = 35
            Y = 6
            Width = 45
            Height = 18
            Layout = "Stack"
            LayoutProps = @{ Orientation = "Vertical"; Spacing = 1 }
        }
        
        # Add sample components
        for ($i = 1; $i -le 5; $i++) {
            $panel = New-TuiPanel -Properties @{
                Width = 20
                Height = 3
                Title = "Panel $i"
            }
            
            if ($script:LayoutDemoScreen.State.CurrentLayout -eq "Dock") {
                $panel.Dock = @("Top", "Bottom", "Left", "Right", "Fill")[$i - 1]
            }
            
            & $script:LayoutDemoScreen.State.Container.AddChild `
                -self $script:LayoutDemoScreen.State.Container -child $panel
        }
    }
    
    UpdateLayout = {
        param($LayoutName)
        
        $container = $script:LayoutDemoScreen.State.Container
        $container.Layout = $LayoutName
        
        switch ($LayoutName) {
            "Stack" {
                $container.LayoutProps = @{ Orientation = "Vertical"; Spacing = 1 }
            }
            "Grid" {
                $container.LayoutProps = @{ Columns = 2; Rows = 3; Spacing = 1 }
            }
            "Dock" {
                # Set dock properties on children
                $dockPositions = @("Top", "Bottom", "Left", "Right", "Fill")
                for ($i = 0; $i -lt $container.Children.Count; $i++) {
                    $container.Children[$i].Dock = $dockPositions[$i % $dockPositions.Count]
                    
                    # Adjust sizes for dock layout
                    switch ($container.Children[$i].Dock) {
                        "Top" { $container.Children[$i].Height = 3 }
                        "Bottom" { $container.Children[$i].Height = 3 }
                        "Left" { $container.Children[$i].Width = 10 }
                        "Right" { $container.Children[$i].Width = 10 }
                    }
                }
            }
            "Flow" {
                $container.LayoutProps = @{ Spacing = 1 }
                # Make components smaller for flow layout
                foreach ($child in $container.Children) {
                    $child.Width = 12
                    $child.Height = 3
                }
            }
        }
    }
    
    Render = {
        # Header
        Write-BufferBox -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height 3 `
            -BorderStyle "Double" -BorderColor (Get-ThemeColor "Header")
        
        $title = "Layout Manager Demo"
        $titleX = [Math]::Floor(($script:TuiState.BufferWidth - $title.Length) / 2)
        Write-BufferString -X $titleX -Y 1 -Text $title `
            -ForegroundColor (Get-ThemeColor "Header")
        
        # Layout selector
        Write-BufferBox -X 2 -Y 4 -Width 30 -Height 12 `
            -Title "Layout Types" -BorderColor (Get-ThemeColor "Accent")
        
        for ($i = 0; $i -lt $script:LayoutDemoScreen.State.Layouts.Count; $i++) {
            $layout = $script:LayoutDemoScreen.State.Layouts[$i]
            $isCurrent = $layout -eq $script:LayoutDemoScreen.State.CurrentLayout
            
            $prefix = if ($isCurrent) { "► " } else { "  " }
            $color = if ($isCurrent) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
            
            Write-BufferString -X 4 -Y (6 + $i * 2) -Text "$prefix$layout" -ForegroundColor $color
        }
        
        Write-BufferString -X 4 -Y 14 -Text "Press 1-4 to change layout" `
            -ForegroundColor (Get-ThemeColor "Info")
        
        # Demo area
        Write-BufferBox -X 34 -Y 4 -Width 48 -Height 22 `
            -Title "Layout Demo - $($script:LayoutDemoScreen.State.CurrentLayout)" `
            -BorderColor (Get-ThemeColor "Secondary")
        
        # Render container
        if ($script:LayoutDemoScreen.State.Container) {
            & $script:LayoutDemoScreen.State.Container.Render -self $script:LayoutDemoScreen.State.Container
        }
        
        Write-StatusLine -Text " [1-4] Change Layout | [Esc] Back"
    }
    
    HandleInput = {
        param($Key)
        
        switch ($Key.Key) {
            ([ConsoleKey]::D1) {
                $script:LayoutDemoScreen.State.CurrentLayout = "Stack"
                & $script:LayoutDemoScreen.UpdateLayout -LayoutName "Stack"
            }
            ([ConsoleKey]::D2) {
                $script:LayoutDemoScreen.State.CurrentLayout = "Grid"
                & $script:LayoutDemoScreen.UpdateLayout -LayoutName "Grid"
            }
            ([ConsoleKey]::D3) {
                $script:LayoutDemoScreen.State.CurrentLayout = "Dock"
                & $script:LayoutDemoScreen.UpdateLayout -LayoutName "Dock"
            }
            ([ConsoleKey]::D4) {
                $script:LayoutDemoScreen.State.CurrentLayout = "Flow"
                & $script:LayoutDemoScreen.UpdateLayout -LayoutName "Flow"
            }
            ([ConsoleKey]::Escape) {
                return "Back"
            }
        }
    }
}

#endregion

#region Settings Screen

$script:SettingsScreen = @{
    Name = "Settings"
    State = @{
        Container = $null
    }
    
    Init = {
        # Create settings form
        $container = New-TuiContainer -Properties @{
            X = 20
            Y = 6
            Width = 40
            Height = 15
            Layout = "Stack"
            LayoutProps = @{ Orientation = "Vertical"; Spacing = 2 }
        }
        
        # Theme dropdown (simulated with menu)
        $themeLabel = New-TuiLabel -Props @{
            Text = "Theme:"
            Width = 10
        }
        & $container.AddChild -self $container -child $themeLabel
        
        # Auto-save checkbox
        $autoSaveCheck = New-TuiCheckBox -Props @{
            Label = "Auto-save enabled"
            Checked = $script:DemoData.Settings.AutoSave
            OnChange = {
                param($Component, $OldValue, $NewValue)
                $script:DemoData.Settings.AutoSave = $NewValue
                Write-TuiLog "Auto-save changed to: $NewValue" -Level Info
            }
        }
        & $container.AddChild -self $container -child $autoSaveCheck
        
        # Refresh rate input
        $refreshLabel = New-TuiLabel -Props @{
            Text = "Refresh Rate (FPS):"
            Width = 20
        }
        & $container.AddChild -self $container -child $refreshLabel
        
        $refreshInput = New-TuiTextBox -Props @{
            Width = 10
            Text = $script:DemoData.Settings.RefreshRate.ToString()
            MaxLength = 3
            OnChange = {
                param($Component, $OldValue, $NewValue)
                if ([int]::TryParse($NewValue, [ref]$null)) {
                    $script:DemoData.Settings.RefreshRate = [int]$NewValue
                }
            }
        }
        & $container.AddChild -self $container -child $refreshInput
        
        # Save button
        $saveButton = New-TuiButton -Props @{
            Text = "Save Settings"
            Width = 20
            OnClick = {
                Write-TuiLog "Settings saved!" -Level Info
                
                # Show confirmation dialog
                $dialog = New-TuiDialog -Props @{
                    Title = "Success"
                    Message = "Settings have been saved successfully!"
                    Buttons = @("OK")
                }
                
                # Note: In a real app, you'd manage dialog display properly
                Write-StatusLine -Text " Settings saved!" -BackgroundColor (Get-ThemeColor "Success")
            }
        }
        & $container.AddChild -self $container -child $saveButton
        
        $script:SettingsScreen.State.Container = $container
        
        # Focus container
        & $container.OnFocus -self $container
    }
    
    Render = {
        # Header
        Write-BufferBox -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height 3 `
            -BorderStyle "Double" -BorderColor (Get-ThemeColor "Header")
        
        $title = "Settings"
        $titleX = [Math]::Floor(($script:TuiState.BufferWidth - $title.Length) / 2)
        Write-BufferString -X $titleX -Y 1 -Text $title `
            -ForegroundColor (Get-ThemeColor "Header")
        
        # Settings panel
        Write-BufferBox -X 15 -Y 4 -Width 50 -Height 20 `
            -Title "Application Settings" -BorderColor (Get-ThemeColor "Accent")
        
        # Render container
        if ($script:SettingsScreen.State.Container) {
            & $script:SettingsScreen.State.Container.Render -self $script:SettingsScreen.State.Container
        }
        
        Write-StatusLine -Text " Tab: Navigate | Space/Enter: Toggle/Click | Esc: Back"
    }
    
    HandleInput = {
        param($Key)
        
        if ($Key.Key -eq [ConsoleKey]::Escape) {
            return "Back"
        }
        
        # Pass to container
        if ($script:SettingsScreen.State.Container) {
            & $script:SettingsScreen.State.Container.HandleInput `
                -self $script:SettingsScreen.State.Container -Key $Key
        }
    }
}

#endregion

# Main entry point
function Start-TuiEngineDemo {
    try {
        Write-Host "Starting TUI Engine v2 Enhanced Demo..." -ForegroundColor Cyan
        Write-Host "This demo showcases:" -ForegroundColor Yellow
        Write-Host "  • Deep cloning for component independence" -ForegroundColor Green
        Write-Host "  • Optimized ANSI rendering for performance" -ForegroundColor Green
        Write-Host "  • Rich component library" -ForegroundColor Green
        Write-Host "  • Event-driven architecture" -ForegroundColor Green
        Write-Host "  • Layout managers" -ForegroundColor Green
        Write-Host "  • Theme system" -ForegroundColor Green
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Start the TUI loop
        Start-TuiLoop -InitialScreen $script:MainDashboardScreen
        
        Write-Host "`nDemo completed successfully!" -ForegroundColor Green
        
        # Show performance summary
        if ($script:TuiState.RenderStats.FrameCount -gt 0) {
            $avgFrameTime = $script:TuiState.RenderStats.TotalTime / $script:TuiState.RenderStats.FrameCount
            Write-Host "`nPerformance Summary:" -ForegroundColor Cyan
            Write-Host "  Total Frames: $($script:TuiState.RenderStats.FrameCount)" -ForegroundColor Yellow
            Write-Host "  Average Frame Time: $([Math]::Round($avgFrameTime, 2))ms" -ForegroundColor Yellow
            Write-Host "  Average FPS: $([Math]::Round(1000 / [Math]::Max(1, $avgFrameTime)))" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "`nError: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        
        # Show error report
        $errorReport = Get-TuiErrorReport
        if ($errorReport) {
            Write-Host "`nError Report:" -ForegroundColor Yellow
            Write-Host $errorReport
        }
    }
}

# Export the main function
Export-ModuleMember -Function Start-TuiEngineDemo