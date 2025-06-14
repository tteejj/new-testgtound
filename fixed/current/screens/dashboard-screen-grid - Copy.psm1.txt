# Dashboard Screen - COMPLIANT VERSION
# Using programmatic pattern with component-based architecture

function global:Get-DashboardScreen {
    $screen = @{
        Name = "DashboardScreen"
        
        # 1. State: Central data model for the screen
        State = @{
            ActiveTimers = @()
            TodaysTasks = @()
            RecentEntries = @()
            QuickStats = @{}
            LastRefresh = [DateTime]::MinValue
            AutoRefreshInterval = 5
        }
        
        # 2. Components: Storage for instantiated component objects
        Components = @{}
        
        # 3. Init: One-time setup
        Init = {
            param($self)
            
            # Import advanced components if available
            if (Get-Command New-TuiDataTable -ErrorAction SilentlyContinue) {
                # Quick Actions List (using DataTable as a list)
                $self.Components.quickActions = New-TuiDataTable -Props @{
                    X = 2; Y = 4; Width = 35; Height = 12
                    Columns = @(
                        @{ Name = "Action"; Header = "Quick Actions"; Width = 30 }
                    )
                    Data = @(
                        @{ Action = "1. Add Time Entry" }
                        @{ Action = "2. Start Timer" }
                        @{ Action = "3. Manage Tasks" }
                        @{ Action = "4. Manage Projects" }
                        @{ Action = "5. View Reports" }
                        @{ Action = "6. Settings" }
                    )
                    AllowSort = $false
                    AllowFilter = $false
                    MultiSelect = $false
                    OnRowSelect = {
                        param($Row, $Index)
                        switch ($Index) {
                            0 { if (Get-Command Get-TimeEntryFormScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimeEntryFormScreen) } }
                            1 { if (Get-Command Get-TimerStartScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimerStartScreen) } }
                            2 { if (Get-Command Get-TaskManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TaskManagementScreen) } }
                            3 { if (Get-Command Get-ProjectManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ProjectManagementScreen) } }
                            4 { if (Get-Command Get-ReportsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ReportsScreen) } }
                            5 { if (Get-Command Get-SettingsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-SettingsScreen) } }
                        }
                    }
                }
                
                # Active Timers Table
                $self.Components.activeTimers = New-TuiDataTable -Props @{
                    X = 40; Y = 4; Width = 40; Height = 12
                    Columns = @(
                        @{ Name = "Project"; Header = "Project"; Width = 20 }
                        @{ Name = "Time"; Header = "Time"; Width = 10 }
                    )
                    Data = @()
                    AllowSort = $false
                    AllowFilter = $false
                    MultiSelect = $false
                }
                
                # Today's Tasks Table
                $self.Components.todaysTasks = New-TuiDataTable -Props @{
                    X = 2; Y = 18; Width = 78; Height = 10
                    Columns = @(
                        @{ Name = "Priority"; Header = "Pri"; Width = 8 }
                        @{ Name = "Description"; Header = "Task"; Width = 50 }
                        @{ Name = "Project"; Header = "Project"; Width = 15 }
                    )
                    Data = @()
                    AllowSort = $true
                    AllowFilter = $false
                    MultiSelect = $false
                }
            } else {
                # Fallback to basic components
                $self.Components.quickActionsLabel = New-TuiLabel -Props @{
                    X = 4; Y = 6; Text = "Quick Actions:"
                }
                
                $self.Components.activeTimersLabel = New-TuiLabel -Props @{
                    X = 42; Y = 6; Text = "Active Timers:"
                }
                
                $self.Components.todaysTasksLabel = New-TuiLabel -Props @{
                    X = 4; Y = 20; Text = "Today's Tasks:"
                }
            }
            
            # Quick Stats Labels
            $self.Components.statsLabel = New-TuiLabel -Props @{
                X = 84; Y = 4; Text = "Today's Stats"
            }
            
            $self.Components.todayHoursLabel = New-TuiLabel -Props @{
                X = 84; Y = 6; Text = "Today: 0h"
            }
            
            $self.Components.weekHoursLabel = New-TuiLabel -Props @{
                X = 84; Y = 8; Text = "Week: 0h"
            }
            
            $self.Components.activeTasksLabel = New-TuiLabel -Props @{
                X = 84; Y = 10; Text = "Tasks: 0"
            }
            
            $self.Components.runningTimersLabel = New-TuiLabel -Props @{
                X = 84; Y = 12; Text = "Timers: 0"
            }
            
            # Refresh data
            $self.RefreshData = {
                param($s)
                
                # Refresh Active Timers
                if ($global:Data -and $global:Data.ActiveTimers) {
                    $timerData = @()
                    foreach ($timerEntry in $global:Data.ActiveTimers.GetEnumerator()) {
                        $timer = $timerEntry.Value
                        if ($timer -and $timer.StartTime) {
                            $elapsed = (Get-Date) - [DateTime]$timer.StartTime
                            $project = if ($global:Data.Projects -and $timer.ProjectKey) { 
                                $global:Data.Projects[$timer.ProjectKey].Name 
                            } else { 
                                "Unknown" 
                            }
                            
                            $timerData += @{
                                Project = $project
                                Time = "{0:00}:{1:00}:{2:00}" -f [Math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds
                            }
                        }
                    }
                    if ($s.Components.activeTimers) {
                        $s.Components.activeTimers.Data = $timerData
                    }
                }
                
                # Refresh Today's Tasks
                if ($global:Data -and $global:Data.Tasks) {
                    $today = (Get-Date).ToString("yyyy-MM-dd")
                    $taskData = @()
                    foreach ($task in $global:Data.Tasks) {
                        if ($task -and -not $task.Completed -and ($task.DueDate -eq $today -or [string]::IsNullOrEmpty($task.DueDate))) {
                            $project = if ($global:Data.Projects -and $task.ProjectKey) { 
                                $global:Data.Projects[$task.ProjectKey].Name 
                            } else { 
                                "None" 
                            }
                            
                            $taskData += @{
                                Priority = $task.Priority ?? "Medium"
                                Description = $task.Description
                                Project = $project
                            }
                        }
                    }
                    if ($s.Components.todaysTasks) {
                        $s.Components.todaysTasks.Data = $taskData | Sort-Object Priority, Description
                    }
                }
                
                # Refresh Stats
                $stats = @{ TodayHours = 0; WeekHours = 0; ActiveTasks = 0; RunningTimers = 0 }
                
                if ($global:Data) {
                    $today = (Get-Date).ToString("yyyy-MM-dd")
                    
                    if ($global:Data.TimeEntries) {
                        $todayEntries = @($global:Data.TimeEntries | Where-Object { $_ -and $_.Date -eq $today })
                        $stats.TodayHours = [Math]::Round(($todayEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                        
                        $weekStart = (Get-Date).AddDays(-[int](Get-Date).DayOfWeek).Date
                        $weekEntries = @($global:Data.TimeEntries | Where-Object { 
                            $_ -and $_.Date -and ([DateTime]::Parse($_.Date) -ge $weekStart)
                        })
                        $stats.WeekHours = [Math]::Round(($weekEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                    }
                    
                    if ($global:Data.Tasks) {
                        $stats.ActiveTasks = @($global:Data.Tasks | Where-Object { $_ -and -not $_.Completed }).Count
                    }
                    
                    if ($global:Data.ActiveTimers) {
                        $stats.RunningTimers = $global:Data.ActiveTimers.Count
                    }
                }
                
                $s.State.QuickStats = $stats
                $s.Components.todayHoursLabel.Text = "Today: $($stats.TodayHours)h"
                $s.Components.weekHoursLabel.Text = "Week: $($stats.WeekHours)h"
                $s.Components.activeTasksLabel.Text = "Tasks: $($stats.ActiveTasks)"
                $s.Components.runningTimersLabel.Text = "Timers: $($stats.RunningTimers)"
            }
            
            # Initial refresh
            & $self.RefreshData -s $self
        }
        
        # 4. Render: Draw the screen and its components
        Render = {
            param($self)
            
            # Auto-refresh check
            if (([DateTime]::Now - $self.State.LastRefresh).TotalSeconds -gt $self.State.AutoRefreshInterval) {
                & $self.RefreshData -s $self
                $self.State.LastRefresh = [DateTime]::Now
            }
            
            # Header
            $headerColor = Get-ThemeColor "Header"
            $currentTime = Get-Date -Format 'dddd, MMMM dd, yyyy HH:mm:ss'
            Write-BufferString -X 2 -Y 1 -Text "PMC Terminal Dashboard - $currentTime" -ForegroundColor $headerColor
            
            # Active timer indicator
            if ($self.State.QuickStats.RunningTimers -gt 0) {
                $timerText = "● TIMER ACTIVE"
                $timerX = $global:TuiState.BufferWidth - $timerText.Length - 2
                Write-BufferString -X $timerX -Y 1 -Text $timerText -ForegroundColor Red
            }
            
            # Draw boxes for organization
            Write-BufferBox -X 1 -Y 3 -Width 37 -Height 14 -Title " Quick Actions " -BorderColor (Get-ThemeColor "Accent")
            Write-BufferBox -X 39 -Y 3 -Width 42 -Height 14 -Title " Active Timers " -BorderColor (Get-ThemeColor "Info")
            Write-BufferBox -X 83 -Y 3 -Width 20 -Height 14 -Title " Stats " -BorderColor (Get-ThemeColor "Success")
            Write-BufferBox -X 1 -Y 17 -Width 80 -Height 12 -Title " Today's Tasks " -BorderColor (Get-ThemeColor "Warning")
            
            # Render all components
            foreach ($component in $self.Components.Values) {
                if ($component.Visible -ne $false) {
                    # Set focus state
                    $component.IsFocused = ($self.FocusedComponentName -eq ($self.Components.GetEnumerator() | Where-Object { $_.Value -eq $component } | Select-Object -First 1).Key)
                    & $component.Render -self $component
                }
            }
            
            # Status bar
            $subtleColor = Get-ThemeColor "Subtle"
            $statusY = $global:TuiState.BufferHeight - 2
            Write-BufferString -X 2 -Y $statusY -Text "Tab: Switch Focus • Enter: Select • R: Refresh • Q: Quit" -ForegroundColor $subtleColor
        }
        
        # 5. HandleInput: Global input handling for the screen
        HandleInput = {
            param($self, $Key)
            
            # Screen-level shortcuts
            switch ($Key.Key) {
                ([ConsoleKey]::R) {
                    # Manual refresh
                    & $self.RefreshData -s $self
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Q) { return "Quit" }
                ([ConsoleKey]::Escape) { return "Quit" }
                ([ConsoleKey]::Tab) {
                    # Cycle focus between tables
                    $focusableComponents = @("quickActions", "activeTimers", "todaysTasks") | Where-Object { $self.Components.$_ }
                    if ($focusableComponents.Count -gt 0) {
                        $currentIndex = [array]::IndexOf($focusableComponents, $self.FocusedComponentName)
                        $nextIndex = ($currentIndex + 1) % $focusableComponents.Count
                        $self.FocusedComponentName = $focusableComponents[$nextIndex]
                        Request-TuiRefresh
                    }
                    return $true
                }
            }
            
            # Number keys for quick actions
            if ($Key.KeyChar -ge '1' -and $Key.KeyChar -le '6') {
                $index = [int]$Key.KeyChar.ToString() - 1
                switch ($index) {
                    0 { if (Get-Command Get-TimeEntryFormScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimeEntryFormScreen) } }
                    1 { if (Get-Command Get-TimerStartScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TimerStartScreen) } }
                    2 { if (Get-Command Get-TaskManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-TaskManagementScreen) } }
                    3 { if (Get-Command Get-ProjectManagementScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ProjectManagementScreen) } }
                    4 { if (Get-Command Get-ReportsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-ReportsScreen) } }
                    5 { if (Get-Command Get-SettingsScreen -ErrorAction SilentlyContinue) { Push-Screen -Screen (Get-SettingsScreen) } }
                }
                return $true
            }
            
            # Delegate to focused component
            $focusedComponent = if ($self.FocusedComponentName) { $self.Components[$self.FocusedComponentName] } else { $null }
            if ($focusedComponent -and $focusedComponent.HandleInput) {
                $result = & $focusedComponent.HandleInput -self $focusedComponent -Key $Key
                if ($result) {
                    Request-TuiRefresh
                    return $true
                }
            }
            
            return $false
        }
        
        # 6. Lifecycle Hooks
        OnExit = {
            param($self)
            # Cleanup if needed
        }
        
        OnResume = {
            param($self)
            # Refresh data when returning to dashboard
            & $self.RefreshData -s $self
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DashboardScreen