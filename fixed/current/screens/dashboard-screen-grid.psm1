# Dashboard Screen v5.0 - Using Grid Layout System
# Refactored to use the TUI framework's layout managers instead of manual coordinates

function global:Get-DashboardScreen {
    
    $dashboardScreen = Create-TuiScreen -Definition @{
        Name = "DashboardScreen"
        State = @{
            ActiveTimers = @()
            TodaysTasks = @()
            RecentEntries = @()
            QuickStats = @{}
            SelectedQuickAction = 0
            EventHandlers = @()
            LastRefresh = [DateTime]::MinValue
            AutoRefreshInterval = 5
        }
        
        # Grid layout for dashboard
        Layout = "Grid"
        LayoutOptions = @{
            Rows = 3
            Columns = 3
            Spacing = 2
            Padding = 2
            Width = $global:TuiState.BufferWidth
            Height = $global:TuiState.BufferHeight - 4  # Leave room for header and status bar
            Y = 3  # Start below header
        }
        
        Children = @(
            # Top Row - 3 columns
            @{
                Name = "QuickActionsContainer"
                Type = "Container"
                Props = @{
                    ColSpan = 1
                    RowSpan = 1
                }
            }
            @{
                Name = "QuickStatsContainer"
                Type = "Container"
                Props = @{
                    ColSpan = 1
                    RowSpan = 1
                }
            }
            @{
                Name = "ActiveTimersContainer"
                Type = "Container"
                Props = @{
                    ColSpan = 1
                    RowSpan = 1
                }
            }
            # Middle Row - Empty spacer
            @{
                Name = "Spacer1"
                Type = "Container"
                Props = @{
                    ColSpan = 3
                    RowSpan = 1
                    Visible = $false
                }
            }
            # Bottom Row - 2 columns
            @{
                Name = "RecentEntriesContainer"
                Type = "Container"
                Props = @{
                    ColSpan = 1
                    RowSpan = 1
                }
            }
            @{
                Name = "TodaysTasksContainer"
                Type = "Container"
                Props = @{
                    ColSpan = 2
                    RowSpan = 1
                }
            }
        )
        
        Init = {
            param($self)
            try {
                # Set up refresh methods
                $self.RefreshAllData = { param($s) 
                    $s.RefreshActiveTimers.Invoke($s)
                    $s.RefreshTodaysTasks.Invoke($s)
                    $s.RefreshRecentEntries.Invoke($s)
                    $s.RefreshQuickStats.Invoke($s)
                }
                
                $self.RefreshActiveTimers = { param($s)
                    try {
                        if ($global:Data -and $global:Data.ActiveTimers) {
                            $s.State.ActiveTimers = @($global:Data.ActiveTimers.GetEnumerator() | ForEach-Object {
                                $timer = $_.Value
                                if ($timer -and $timer.StartTime) {
                                    $elapsed = (Get-Date) - [DateTime]$timer.StartTime
                                    @{
                                        Key = $_.Key
                                        ProjectKey = $timer.ProjectKey
                                        TaskId = $timer.TaskId
                                        Description = $timer.Description
                                        StartTime = $timer.StartTime
                                        Elapsed = $elapsed
                                        ElapsedDisplay = "{0:00}:{1:00}:{2:00}" -f [Math]::Floor($elapsed.TotalHours), $elapsed.Minutes, $elapsed.Seconds
                                    }
                                }
                            } | Where-Object { $_ } | Select-Object -First 5)
                        } else {
                            $s.State.ActiveTimers = @()
                        }
                    } catch {
                        Write-Warning "Timer refresh error: $_"
                        $s.State.ActiveTimers = @()
                    }
                }
                
                $self.RefreshTodaysTasks = { param($s)
                    try {
                        if ($global:Data -and $global:Data.Tasks) {
                            $today = (Get-Date).ToString("yyyy-MM-dd")
                            $s.State.TodaysTasks = @($global:Data.Tasks | Where-Object { 
                                $_ -and (-not $_.Completed) -and 
                                ($_.DueDate -eq $today -or [string]::IsNullOrEmpty($_.DueDate))
                            } | Sort-Object Priority, DueDate | Select-Object -First 5)
                        } else {
                            $s.State.TodaysTasks = @()
                        }
                    } catch {
                        Write-Warning "Tasks refresh error: $_"
                        $s.State.TodaysTasks = @()
                    }
                }
                
                $self.RefreshRecentEntries = { param($s)
                    try {
                        if ($global:Data -and $global:Data.TimeEntries) {
                            $s.State.RecentEntries = @($global:Data.TimeEntries | 
                                Where-Object { $_ } |
                                Sort-Object Date -Descending | 
                                Select-Object -First 5)
                        } else {
                            $s.State.RecentEntries = @()
                        }
                    } catch {
                        Write-Warning "Entries refresh error: $_"
                        $s.State.RecentEntries = @()
                    }
                }
                
                $self.RefreshQuickStats = { param($s)
                    try {
                        $today = (Get-Date).ToString("yyyy-MM-dd")
                        $stats = @{ TodayHours = 0; ActiveTasks = 0; RunningTimers = 0; WeekHours = 0 }
                        
                        if ($global:Data) {
                            # Today's hours
                            if ($global:Data.TimeEntries) {
                                $todayEntries = @($global:Data.TimeEntries | Where-Object { $_ -and $_.Date -eq $today })
                                $stats.TodayHours = [Math]::Round(($todayEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                                
                                # Week hours
                                $weekStart = (Get-Date).AddDays(-[int](Get-Date).DayOfWeek).Date
                                $weekEntries = @($global:Data.TimeEntries | Where-Object { 
                                    $_ -and $_.Date -and ([DateTime]::Parse($_.Date) -ge $weekStart)
                                })
                                $stats.WeekHours = [Math]::Round(($weekEntries | Measure-Object -Property Hours -Sum).Sum, 2)
                            }
                            
                            # Active tasks
                            if ($global:Data.Tasks) {
                                $stats.ActiveTasks = @($global:Data.Tasks | Where-Object { $_ -and -not $_.Completed }).Count
                            }
                            
                            # Running timers
                            if ($global:Data.ActiveTimers) {
                                $stats.RunningTimers = $global:Data.ActiveTimers.Count
                            }
                        }
                        
                        $s.State.QuickStats = $stats
                    } catch {
                        Write-Warning "Stats refresh error: $_"
                        $s.State.QuickStats = @{ TodayHours = 0; ActiveTasks = 0; RunningTimers = 0; WeekHours = 0 }
                    }
                }
                
                $self.GetQuickActions = { 
                    return @( 
                        @{ 
                            Name = "1. Add Time Entry"
                            Icon = "⏰"
                            Action = { 
                                if (Get-Command Get-TimeEntryFormScreen -ErrorAction SilentlyContinue) { 
                                    Push-Screen -Screen (Get-TimeEntryFormScreen) 
                                } 
                            } 
                        },
                        @{ 
                            Name = "2. Start Timer"
                            Icon = "▶️"
                            Action = { 
                                if (Get-Command Get-TimerStartScreen -ErrorAction SilentlyContinue) { 
                                    Push-Screen -Screen (Get-TimerStartScreen) 
                                } 
                            } 
                        },
                        @{ 
                            Name = "3. Manage Tasks"
                            Icon = "📋"
                            Action = { 
                                if (Get-Command Get-TaskManagementScreen -ErrorAction SilentlyContinue) { 
                                    Push-Screen -Screen (Get-TaskManagementScreen) 
                                } 
                            } 
                        },
                        @{ 
                            Name = "4. Manage Projects"
                            Icon = "📁"
                            Action = { 
                                if (Get-Command Get-ProjectManagementScreen -ErrorAction SilentlyContinue) { 
                                    Push-Screen -Screen (Get-ProjectManagementScreen) 
                                } 
                            } 
                        },
                        @{ 
                            Name = "5. View Reports"
                            Icon = "📊"
                            Action = { 
                                if (Get-Command Get-ReportsScreen -ErrorAction SilentlyContinue) { 
                                    Push-Screen -Screen (Get-ReportsScreen) 
                                } 
                            } 
                        },
                        @{ 
                            Name = "6. Settings"
                            Icon = "⚙️"
                            Action = { 
                                if (Get-Command Get-SettingsScreen -ErrorAction SilentlyContinue) { 
                                    Push-Screen -Screen (Get-SettingsScreen) 
                                } 
                            } 
                        }
                    )
                }
                
                # Initial data refresh
                $self.RefreshAllData.Invoke($self)
                
                # Subscribe to events if available
                if (Get-Command -Name "Subscribe-TuiEvent" -ErrorAction SilentlyContinue) {
                    # Timer events
                    $handlerId = Subscribe-TuiEvent -EventName "Data.Timer.Started" -Handler {
                        $self.RefreshActiveTimers.Invoke($self)
                        Request-TuiRefresh
                    }
                    $self.State.EventHandlers += $handlerId
                    
                    $handlerId = Subscribe-TuiEvent -EventName "Data.Timer.Stopped" -Handler {
                        $self.RefreshActiveTimers.Invoke($self)
                        $self.RefreshQuickStats.Invoke($self)
                        Request-TuiRefresh
                    }
                    $self.State.EventHandlers += $handlerId
                }
            } catch {
                Write-Warning "Dashboard init error: $_"
            }
        }
        
        OnExit = {
            param($self)
            # Cleanup event subscriptions
            if (Get-Command -Name "Unsubscribe-Event" -ErrorAction SilentlyContinue) {
                foreach ($handlerId in $self.State.EventHandlers) {
                    try {
                        Unsubscribe-Event -HandlerId $handlerId
                    } catch {
                        Write-Warning "Failed to unsubscribe event: $_"
                    }
                }
            }
        }
        
        OnResume = {
            param($self)
            # Refresh data when returning to dashboard
            $self.RefreshAllData.Invoke($self)
        }
        
        Render = {
            param($self)
            try {
                # Auto-refresh check
                if (([DateTime]::Now - $self.State.LastRefresh).TotalSeconds -gt $self.State.AutoRefreshInterval) {
                    $self.RefreshActiveTimers.Invoke($self)
                    $self.State.LastRefresh = [DateTime]::Now
                }
                
                # Header with current time
                $headerColor = Get-ThemeColor "Header" -Default "Cyan"
                $currentTime = Get-Date -Format 'dddd, MMMM dd, yyyy HH:mm:ss'
                Write-BufferString -X 2 -Y 1 -Text "PMC Terminal Dashboard - $currentTime" -ForegroundColor $headerColor
                
                # Active timer indicator
                if ($self.State.ActiveTimers.Count -gt 0) {
                    $timerText = "● TIMER ACTIVE"
                    $timerX = $global:TuiState.BufferWidth - $timerText.Length - 2
                    Write-BufferString -X $timerX -Y 1 -Text $timerText -ForegroundColor "Red"
                }
                
                # Render content boxes for each container
                # Quick Actions
                $quickActionsContainer = $self._children["QuickActionsContainer"]
                if ($quickActionsContainer) {
                    Write-BufferBox -X $quickActionsContainer.X -Y $quickActionsContainer.Y `
                        -Width $quickActionsContainer.Width -Height $quickActionsContainer.Height `
                        -Title " Quick Actions " -BorderColor (Get-ThemeColor "Accent")
                    $self.RenderQuickActions.Invoke($self, ($quickActionsContainer.X + 2), ($quickActionsContainer.Y + 2))
                }
                
                # Quick Stats
                $quickStatsContainer = $self._children["QuickStatsContainer"]
                if ($quickStatsContainer) {
                    Write-BufferBox -X $quickStatsContainer.X -Y $quickStatsContainer.Y `
                        -Width $quickStatsContainer.Width -Height $quickStatsContainer.Height `
                        -Title " Today's Stats " -BorderColor (Get-ThemeColor "Success")
                    $self.RenderQuickStats.Invoke($self, ($quickStatsContainer.X + 2), ($quickStatsContainer.Y + 2))
                }
                
                # Active Timers
                $activeTimersContainer = $self._children["ActiveTimersContainer"]
                if ($activeTimersContainer) {
                    Write-BufferBox -X $activeTimersContainer.X -Y $activeTimersContainer.Y `
                        -Width $activeTimersContainer.Width -Height $activeTimersContainer.Height `
                        -Title " Active Timers " -BorderColor (Get-ThemeColor "Info")
                    $self.RenderActiveTimers.Invoke($self, ($activeTimersContainer.X + 2), ($activeTimersContainer.Y + 2))
                }
                
                # Recent Entries
                $recentEntriesContainer = $self._children["RecentEntriesContainer"]
                if ($recentEntriesContainer) {
                    Write-BufferBox -X $recentEntriesContainer.X -Y $recentEntriesContainer.Y `
                        -Width $recentEntriesContainer.Width -Height $recentEntriesContainer.Height `
                        -Title " Recent Time Entries " -BorderColor (Get-ThemeColor "Primary")
                    $self.RenderRecentEntries.Invoke($self, ($recentEntriesContainer.X + 2), ($recentEntriesContainer.Y + 2))
                }
                
                # Today's Tasks
                $todaysTasksContainer = $self._children["TodaysTasksContainer"]
                if ($todaysTasksContainer) {
                    Write-BufferBox -X $todaysTasksContainer.X -Y $todaysTasksContainer.Y `
                        -Width $todaysTasksContainer.Width -Height $todaysTasksContainer.Height `
                        -Title " Today's Tasks " -BorderColor (Get-ThemeColor "Warning")
                    $self.RenderTodaysTasks.Invoke($self, ($todaysTasksContainer.X + 2), ($todaysTasksContainer.Y + 2))
                }
                
                # Status bar
                $subtleColor = Get-ThemeColor "Subtle" -Default "Gray"
                $statusY = $global:TuiState.BufferHeight - 2
                Write-BufferString -X 2 -Y $statusY -Text "↑↓ Navigate • Enter: Select • R: Refresh • P: Command Palette • Q: Quit" -ForegroundColor $subtleColor
            } catch {
                Write-Warning "Dashboard render error: $_"
                Write-BufferString -X 2 -Y 2 -Text "Error rendering dashboard: $_" -ForegroundColor "Red"
            }
        }
        
        # Render methods for content
        RenderQuickActions = { 
            param($self, $x, $y)
            try {
                $actions = $self.GetQuickActions.Invoke()
                $maxWidth = $self._children["QuickActionsContainer"].Width - 4
                
                for ($i = 0; $i -lt $actions.Count; $i++) { 
                    $isSelected = ($i -eq $self.State.SelectedQuickAction)
                    $prefix = if ($isSelected) { "→ " } else { "  " }
                    $color = if ($isSelected) { 
                        Get-ThemeColor "Warning" -Default "Yellow"
                    } else { 
                        Get-ThemeColor "Primary" -Default "White"
                    }
                    
                    $text = "$prefix$($actions[$i].Icon) $($actions[$i].Name)"
                    if ($text.Length -gt $maxWidth) {
                        $text = $text.Substring(0, $maxWidth - 3) + "..."
                    }
                    
                    Write-BufferString -X $x -Y ($y + $i) -Text $text -ForegroundColor $color
                }
            } catch {
                Write-Warning "Quick actions render error: $_"
            }
        }
        
        RenderActiveTimers = { 
            param($self, $x, $y)
            try {
                $maxWidth = $self._children["ActiveTimersContainer"].Width - 4
                
                if ($self.State.ActiveTimers.Count -eq 0) { 
                    $subtleColor = Get-ThemeColor "Subtle" -Default "Gray"
                    Write-BufferString -X $x -Y $y -Text "No active timers" -ForegroundColor $subtleColor
                } else { 
                    $currentY = $y
                    foreach ($timer in $self.State.ActiveTimers) { 
                        if ($timer) {
                            # Project/Task info
                            $project = $null
                            if ($global:Data.Projects -and $timer.ProjectKey) {
                                $project = $global:Data.Projects[$timer.ProjectKey]
                            }
                            
                            $projectName = if ($project) { $project.Name } else { "Unknown" }
                            if ($projectName.Length -gt ($maxWidth - 10)) {
                                $projectName = $projectName.Substring(0, $maxWidth - 13) + "..."
                            }
                            
                            $infoColor = Get-ThemeColor "Info" -Default "Cyan"
                            Write-BufferString -X $x -Y $currentY -Text $projectName -ForegroundColor $infoColor
                            
                            # Time display
                            $accentColor = Get-ThemeColor "Accent" -Default "Yellow"
                            Write-BufferString -X ($x + 2) -Y ($currentY + 1) -Text $timer.ElapsedDisplay -ForegroundColor $accentColor
                            
                            $currentY += 2
                            if ($currentY -gt ($y + 6)) { break }  # Prevent overflow
                        }
                    } 
                }
            } catch {
                Write-Warning "Timers render error: $_"
                Write-BufferString -X $x -Y $y -Text "Error displaying timers" -ForegroundColor "Red"
            }
        }
        
        RenderTodaysTasks = { 
            param($self, $x, $y)
            try {
                $maxWidth = $self._children["TodaysTasksContainer"].Width - 4
                
                if ($self.State.TodaysTasks.Count -eq 0) { 
                    $subtleColor = Get-ThemeColor "Subtle" -Default "Gray"
                    Write-BufferString -X $x -Y $y -Text "No tasks for today" -ForegroundColor $subtleColor
                } else { 
                    $currentY = $y
                    foreach ($task in $self.State.TodaysTasks) { 
                        if ($task -and $task.Description) {
                            # Priority indicator
                            $priorityIcon = switch ($task.Priority) {
                                "Critical" { "🔴" }
                                "High" { "🟡" }
                                "Medium" { "🟢" }
                                default { "⚪" }
                            }
                            
                            $taskText = "$priorityIcon $($task.Description)"
                            if ($taskText.Length -gt $maxWidth) { 
                                $taskText = $taskText.Substring(0, $maxWidth - 3) + "..." 
                            }
                            
                            $primaryColor = Get-ThemeColor "Primary" -Default "White"
                            Write-BufferString -X $x -Y $currentY -Text $taskText -ForegroundColor $primaryColor
                            $currentY++
                            
                            if ($currentY -gt ($y + 5)) { break }  # Prevent overflow
                        }
                    } 
                }
            } catch {
                Write-Warning "Tasks render error: $_"
                Write-BufferString -X $x -Y $y -Text "Error displaying tasks" -ForegroundColor "Red"
            }
        }
        
        RenderRecentEntries = { 
            param($self, $x, $y)
            try {
                $maxWidth = $self._children["RecentEntriesContainer"].Width - 4
                
                if ($self.State.RecentEntries.Count -eq 0) { 
                    $subtleColor = Get-ThemeColor "Subtle" -Default "Gray"
                    Write-BufferString -X $x -Y $y -Text "No recent entries" -ForegroundColor $subtleColor
                } else { 
                    $currentY = $y
                    foreach ($entry in $self.State.RecentEntries) {
                        if ($entry -and $entry.Hours -and $entry.Date) {
                            # Format: Date - Hours - Project
                            $project = $null
                            if ($global:Data.Projects -and $entry.ProjectKey) {
                                $project = $global:Data.Projects[$entry.ProjectKey]
                            }
                            
                            $projectName = if ($project) { $project.Name } else { "Unknown" }
                            $entryText = "$($entry.Date): $($entry.Hours)h - $projectName"
                            
                            if ($entryText.Length -gt $maxWidth) { 
                                $entryText = $entryText.Substring(0, $maxWidth - 3) + "..." 
                            }
                            
                            $primaryColor = Get-ThemeColor "Primary" -Default "White"
                            Write-BufferString -X $x -Y $currentY -Text $entryText -ForegroundColor $primaryColor
                            $currentY++
                            
                            if ($currentY -gt ($y + 3)) { break }  # Prevent overflow
                        }
                    } 
                }
            } catch {
                Write-Warning "Entries render error: $_"
                Write-BufferString -X $x -Y $y -Text "Error displaying entries" -ForegroundColor "Red"
            }
        }
        
        RenderQuickStats = { 
            param($self, $x, $y)
            try {
                if ($self.State.QuickStats) {
                    $stats = $self.State.QuickStats
                    $labelColor = Get-ThemeColor "Subtle" -Default "Gray"
                    $valueColor = Get-ThemeColor "Success" -Default "Green"
                    
                    # Today's hours
                    Write-BufferString -X $x -Y $y -Text "Today:" -ForegroundColor $labelColor
                    Write-BufferString -X ($x + 8) -Y $y -Text "$($stats.TodayHours)h" -ForegroundColor $valueColor
                    
                    # Week hours
                    Write-BufferString -X $x -Y ($y + 2) -Text "Week:" -ForegroundColor $labelColor
                    Write-BufferString -X ($x + 8) -Y ($y + 2) -Text "$($stats.WeekHours)h" -ForegroundColor $valueColor
                    
                    # Active tasks
                    $warningColor = Get-ThemeColor "Warning" -Default "Yellow"
                    Write-BufferString -X $x -Y ($y + 4) -Text "Tasks:" -ForegroundColor $labelColor
                    Write-BufferString -X ($x + 8) -Y ($y + 4) -Text "$($stats.ActiveTasks)" -ForegroundColor $warningColor
                    
                    # Running timers
                    $infoColor = Get-ThemeColor "Info" -Default "Cyan"
                    Write-BufferString -X $x -Y ($y + 6) -Text "Timers:" -ForegroundColor $labelColor
                    Write-BufferString -X ($x + 8) -Y ($y + 6) -Text "$($stats.RunningTimers)" -ForegroundColor $infoColor
                }
            } catch {
                Write-Warning "Stats render error: $_"
                Write-BufferString -X $x -Y $y -Text "Error displaying stats" -ForegroundColor "Red"
            }
        }
        
        HandleInput = {
            param($self, $Key)
            try {
                switch ($Key.Key) {
                    ([ConsoleKey]::UpArrow) { 
                        $self.State.SelectedQuickAction = [Math]::Max(0, $self.State.SelectedQuickAction - 1)
                        Request-TuiRefresh
                        return $true 
                    }
                    ([ConsoleKey]::DownArrow) { 
                        $maxActions = $self.GetQuickActions.Invoke().Count - 1
                        $self.State.SelectedQuickAction = [Math]::Min($maxActions, $self.State.SelectedQuickAction + 1)
                        Request-TuiRefresh
                        return $true 
                    }
                    ([ConsoleKey]::Enter) { 
                        $selectedAction = $self.GetQuickActions.Invoke()[$self.State.SelectedQuickAction]
                        if ($selectedAction -and $selectedAction.Action) {
                            try {
                                & $selectedAction.Action
                            } catch {
                                Write-Warning "Action execution error: $_"
                            }
                        }
                        return $true 
                    }
                    ([ConsoleKey]::R) {
                        # Manual refresh
                        $self.RefreshAllData.Invoke($self)
                        Request-TuiRefresh
                        return $true
                    }
                    ([ConsoleKey]::P) {
                        # Command palette
                        if (Get-Command Get-CommandPaletteScreen -ErrorAction SilentlyContinue) {
                            Push-Screen -Screen (Get-CommandPaletteScreen)
                        }
                        return $true
                    }
                    ([ConsoleKey]::Q) { return "Quit" }
                    ([ConsoleKey]::Escape) { return "Quit" }
                }
                
                # Number keys for quick action selection
                if ($Key.KeyChar -ge '1' -and $Key.KeyChar -le '9') {
                    $index = [int]$Key.KeyChar.ToString() - 1
                    $actions = $self.GetQuickActions.Invoke()
                    if ($index -lt $actions.Count) {
                        $self.State.SelectedQuickAction = $index
                        if ($actions[$index].Action) {
                            & $actions[$index].Action
                        }
                    }
                    return $true
                }
            } catch {
                Write-Warning "Dashboard input error: $_"
            }
            return $false
        }
    }
    
    return $dashboardScreen
}

Export-ModuleMember -Function Get-DashboardScreen