# Dashboard Screen Module - Central hub for PMC Terminal

function global:Get-DashboardScreen {
    $dashboardScreen = @{
        Name = "DashboardScreen"
        State = @{
            ActiveTimers = @()
            TodaysTasks = @()
            RecentEntries = @()
            QuickStats = @{}
            SelectedQuickAction = 0
        }
        
        Init = {
            param($self)
            # Subscribe to data events for real-time updates
            Subscribe-Event -EventName "Data.Timer.Started" -Handler {
                $self.RefreshActiveTimers()
                Request-TuiRefresh
            }
            Subscribe-Event -EventName "Data.Timer.Stopped" -Handler {
                $self.RefreshActiveTimers()
                Request-TuiRefresh
            }
            Subscribe-Event -EventName "Data.TimeEntry.Created" -Handler {
                $self.RefreshRecentEntries()
                Request-TuiRefresh
            }
            $self.RefreshAllData()
        }
        
        Render = {
            param($self)
            
            # Header with current time and active timer indicator
            $headerY = 2
            Write-BufferString -X 2 -Y $headerY -Text "PMC Terminal - $(Get-Date -Format 'dddd, MMMM dd, yyyy HH:mm')" -ForegroundColor (Get-ThemeColor "Header")
            
            if ($self.State.ActiveTimers.Count -gt 0) {
                $timerText = "🔴 TIMER ACTIVE"
                Write-BufferString -X ($script:TuiState.BufferWidth - $timerText.Length - 2) -Y $headerY -Text $timerText -ForegroundColor "Red"
            }
            
            # Three-column layout
            $leftCol = 2
            $middleCol = 30
            $rightCol = 58
            $contentY = 4
            
            # Left Column: Quick Actions
            Write-BufferBox -X $leftCol -Y $contentY -Width 26 -Height 15 -Title " Quick Actions " -BorderColor (Get-ThemeColor "Accent")
            $self.RenderQuickActions($leftCol + 2, $contentY + 2)
            
            # Middle Column: Active Timers & Today's Tasks
            Write-BufferBox -X $middleCol -Y $contentY -Width 26 -Height 8 -Title " Active Timers " -BorderColor (Get-ThemeColor "Info")
            $self.RenderActiveTimers($middleCol + 2, $contentY + 2)
            
            Write-BufferBox -X $middleCol -Y ($contentY + 9) -Width 26 -Height 7 -Title " Today's Tasks " -BorderColor (Get-ThemeColor "Warning")
            $self.RenderTodaysTasks($middleCol + 2, $contentY + 11)
            
            # Right Column: Recent Entries & Stats
            Write-BufferBox -X $rightCol -Y $contentY -Width 30 -Height 10 -Title " Recent Time Entries " -BorderColor (Get-ThemeColor "Success")
            $self.RenderRecentEntries($rightCol + 2, $contentY + 2)
            
            Write-BufferBox -X $rightCol -Y ($contentY + 11) -Width 30 -Height 5 -Title " Quick Stats " -BorderColor (Get-ThemeColor "Accent")
            $self.RenderQuickStats($rightCol + 2, $contentY + 13)
            
            # Status bar
            $statusY = $script:TuiState.BufferHeight - 2
            Write-BufferString -X 2 -Y $statusY -Text "Navigation: ↑↓ Select • Enter: Execute • Tab: Switch Sections • P: Command Palette • Q: Quit" -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) { 
                    $self.State.SelectedQuickAction = [Math]::Max(0, $self.State.SelectedQuickAction - 1)
                    return $true 
                }
                ([ConsoleKey]::DownArrow) { 
                    $maxActions = $self.GetQuickActions().Count - 1
                    $self.State.SelectedQuickAction = [Math]::Min($maxActions, $self.State.SelectedQuickAction + 1)
                    return $true 
                }
                ([ConsoleKey]::Enter) {
                    $selectedAction = $self.GetQuickActions()[$self.State.SelectedQuickAction]
                    & $selectedAction.Action
                    return $true
                }
                ([ConsoleKey]::P) {
                    if (Get-Command -Name "Get-CommandPaletteScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-CommandPaletteScreen)
                    }
                    return $true
                }
                ([ConsoleKey]::Q) { return "Quit" }
            }
            return $false
        }
        
        # Helper methods for data management
        RefreshActiveTimers = {
            $this.State.ActiveTimers = @($script:Data.ActiveTimers.GetEnumerator())
        }
        
        RefreshTodaysTasks = {
            $today = (Get-Date).ToString("yyyy-MM-dd")
            $this.State.TodaysTasks = @($script:Data.Tasks | Where-Object { 
                (-not $_.Completed) -and (
                    [string]::IsNullOrEmpty($_.DueDate) -or $_.DueDate -eq $today
                )
            } | Sort-Object Priority, DueDate | Select-Object -First 5)
        }
        
        RefreshRecentEntries = {
            $this.State.RecentEntries = @($script:Data.TimeEntries | 
                Sort-Object Date, EnteredAt -Descending | 
                Select-Object -First 5)
        }
        
        RefreshQuickStats = {
            $today = (Get-Date).ToString("yyyy-MM-dd")
            $todayEntries = $script:Data.TimeEntries | Where-Object { $_.Date -eq $today }
            $this.State.QuickStats = @{
                TodayHours = ($todayEntries | Measure-Object -Property Hours -Sum).Sum
                ActiveTasks = ($script:Data.Tasks | Where-Object { -not $_.Completed }).Count
                ActiveProjects = ($script:Data.Projects.Keys).Count
                RunningTimers = $script:Data.ActiveTimers.Count
            }
        }
        
        RefreshAllData = {
            $this.RefreshActiveTimers()
            $this.RefreshTodaysTasks() 
            $this.RefreshRecentEntries()
            $this.RefreshQuickStats()
        }
        
        GetQuickActions = {
            return @(
                @{ Name = "📝 Add Time Entry"; Action = { 
                    if (Get-Command -Name "Get-TimeEntryFormScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-TimeEntryFormScreen) 
                    }
                }}
                @{ Name = "⏱️  Start Timer"; Action = { 
                    if (Get-Command -Name "Get-TimerStartScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-TimerStartScreen) 
                    }
                }}
                @{ Name = "📋 Add Task"; Action = { 
                    if (Get-Command -Name "Get-TaskFormScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-TaskFormScreen) 
                    }
                }}
                @{ Name = "🏗️  Manage Projects"; Action = { 
                    if (Get-Command -Name "Get-ProjectManagementScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-ProjectManagementScreen) 
                    }
                }}
                @{ Name = "📊 Reports"; Action = { 
                    if (Get-Command -Name "Get-ReportsMenuScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-ReportsMenuScreen) 
                    }
                }}
                @{ Name = "📁 File Browser"; Action = { 
                    if (Get-Command -Name "Start-TerminalFileBrowser" -ErrorAction SilentlyContinue) {
                        Start-TerminalFileBrowser 
                    }
                }}
                @{ Name = "🎨 Settings"; Action = { 
                    if (Get-Command -Name "Get-SettingsScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-SettingsScreen) 
                    }
                }}
            )
        }
        
        RenderQuickActions = {
            param($x, $y)
            $actions = $this.GetQuickActions()
            for ($i = 0; $i -lt $actions.Count; $i++) {
                $isSelected = ($i -eq $this.State.SelectedQuickAction)
                $prefix = if ($isSelected) { "→ " } else { "  " }
                $color = if ($isSelected) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
                Write-BufferString -X $x -Y ($y + $i) -Text "$prefix$($actions[$i].Name)" -ForegroundColor $color
            }
        }
        
        RenderActiveTimers = {
            param($x, $y)
            if ($this.State.ActiveTimers.Count -eq 0) {
                Write-BufferString -X $x -Y $y -Text "No active timers" -ForegroundColor (Get-ThemeColor "Subtle")
            } else {
                $currentY = $y
                foreach ($timer in $this.State.ActiveTimers) {
                    $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                    $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
                    if ($project) {
                        Write-BufferString -X $x -Y $currentY -Text "$($project.Name)" -ForegroundColor (Get-ThemeColor "Info")
                    } else {
                        Write-BufferString -X $x -Y $currentY -Text "Unknown Project" -ForegroundColor (Get-ThemeColor "Error")
                    }
                    Write-BufferString -X $x -Y ($currentY + 1) -Text "  $([Math]::Floor($elapsed.TotalHours)):$($elapsed.ToString('mm\:ss'))" -ForegroundColor (Get-ThemeColor "Accent")
                    $currentY += 2
                    if ($currentY -ge ($y + 5)) { break }  # Limit display
                }
            }
        }
        
        RenderTodaysTasks = {
            param($x, $y)
            if ($this.State.TodaysTasks.Count -eq 0) {
                Write-BufferString -X $x -Y $y -Text "No tasks for today" -ForegroundColor (Get-ThemeColor "Subtle")
            } else {
                $currentY = $y
                foreach ($task in $this.State.TodaysTasks) {
                    $priority = switch ($task.Priority) {
                        "Critical" { "🔥" }
                        "High" { "🔴" }
                        "Medium" { "🟡" }
                        "Low" { "🟢" }
                        default { "⚪" }
                    }
                    $taskText = "$priority $($task.Description)"
                    if ($taskText.Length -gt 22) { $taskText = $taskText.Substring(0, 19) + "..." }
                    Write-BufferString -X $x -Y $currentY -Text $taskText -ForegroundColor (Get-ThemeColor "Primary")
                    $currentY++
                    if ($currentY -ge ($y + 4)) { break }  # Limit display
                }
            }
        }
        
        RenderRecentEntries = {
            param($x, $y)
            if ($this.State.RecentEntries.Count -eq 0) {
                Write-BufferString -X $x -Y $y -Text "No recent entries" -ForegroundColor (Get-ThemeColor "Subtle")
            } else {
                $currentY = $y
                foreach ($entry in $this.State.RecentEntries) {
                    $project = Get-ProjectOrTemplate $entry.ProjectKey
                    $entryText = "$($entry.Date): $($entry.Hours)h"
                    Write-BufferString -X $x -Y $currentY -Text $entryText -ForegroundColor (Get-ThemeColor "Success")
                    if ($project) {
                        Write-BufferString -X ($x + 2) -Y ($currentY + 1) -Text $project.Name -ForegroundColor (Get-ThemeColor "Subtle")
                    }
                    $currentY += 2
                    if ($currentY -ge ($y + 7)) { break }  # Limit display
                }
            }
        }
        
        RenderQuickStats = {
            param($x, $y)
            $stats = $this.State.QuickStats
            Write-BufferString -X $x -Y $y -Text "Today: $($stats.TodayHours)h" -ForegroundColor (Get-ThemeColor "Info")
            Write-BufferString -X $x -Y ($y + 1) -Text "Active: $($stats.ActiveTasks) tasks, $($stats.RunningTimers) timers" -ForegroundColor (Get-ThemeColor "Warning")
        }
    }
    
    return $dashboardScreen
}

# Export module members
Export-ModuleMember -Function 'Get-DashboardScreen'