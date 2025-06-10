# File: dashboard-screen.psm1 (SIMPLIFIED FIXED LAYOUT)
# Simplified dashboard with better spacing and no overlapping

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
            & $self.RefreshAllData -self $self
        }
        
        Render = {
            param($self)
            
            # Header
            Write-BufferString -X 2 -Y 1 -Text "PMC Terminal - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor "Cyan"
            
            # Timer indicator
            if ($self.State.ActiveTimers.Count -gt 0) {
                Write-BufferString -X 60 -Y 1 -Text "[TIMER ACTIVE]" -ForegroundColor "Red"
            }
            
            # Quick Actions (Left)
            Write-BufferBox -X 2 -Y 3 -Width 25 -Height 10 -Title " Quick Actions " -BorderColor "Yellow"
            & $self.RenderQuickActions -self $self -x 4 -y 5
            
            # Quick Stats (Center)
            Write-BufferBox -X 30 -Y 3 -Width 25 -Height 10 -Title " Quick Stats " -BorderColor "Green"
            & $self.RenderQuickStats -self $self -x 32 -y 5
            
            # Active Timers (Right)
            Write-BufferBox -X 58 -Y 3 -Width 25 -Height 10 -Title " Active Timers " -BorderColor "Cyan"
            & $self.RenderActiveTimers -self $self -x 60 -y 5
            
            # Recent Entries (Bottom Left)
            Write-BufferBox -X 2 -Y 14 -Width 40 -Height 8 -Title " Recent Time Entries " -BorderColor "Blue"
            & $self.RenderRecentEntries -self $self -x 4 -y 16
            
            # Today's Tasks (Bottom Right)
            Write-BufferBox -X 44 -Y 14 -Width 39 -Height 8 -Title " Today's Tasks " -BorderColor "Magenta"
            & $self.RenderTodaysTasks -self $self -x 46 -y 16
            
            # Status bar
            Write-BufferString -X 2 -Y 23 -Text "Use arrows to select, Enter to execute, Q to quit" -ForegroundColor "Gray"
        }
        
        HandleInput = {
            param($self, $Key)
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) { 
                    $self.State.SelectedQuickAction = [Math]::Max(0, $self.State.SelectedQuickAction - 1)
                    Request-TuiRefresh
                    return $true 
                }
                ([ConsoleKey]::DownArrow) { 
                    $maxActions = (& $self.GetQuickActions -self $self).Count - 1
                    $self.State.SelectedQuickAction = [Math]::Min($maxActions, $self.State.SelectedQuickAction + 1)
                    Request-TuiRefresh
                    return $true 
                }
                ([ConsoleKey]::Enter) { 
                    $selectedAction = (& $self.GetQuickActions -self $self)[$self.State.SelectedQuickAction]
                    if ($selectedAction -and $selectedAction.Action) {
                        & $selectedAction.Action
                    }
                    return $true 
                }
                ([ConsoleKey]::Q) { return "Quit" }
            }
            return $false
        }
        
        RefreshAllData = { 
            param($self)
            & $self.RefreshActiveTimers -self $self
            & $self.RefreshTodaysTasks -self $self
            & $self.RefreshRecentEntries -self $self
            & $self.RefreshQuickStats -self $self
        }
        
        RefreshActiveTimers = { 
            param($self)
            if ($global:Data -and $global:Data.ActiveTimers) {
                $self.State.ActiveTimers = @($global:Data.ActiveTimers.GetEnumerator() | Select-Object -First 5)
            } else {
                $self.State.ActiveTimers = @()
            }
        }
        
        RefreshTodaysTasks = { 
            param($self)
            if ($global:Data -and $global:Data.Tasks) {
                $today = (Get-Date).ToString("yyyy-MM-dd")
                $self.State.TodaysTasks = @($global:Data.Tasks | Where-Object { 
                    (-not $_.Completed) -and ($_.DueDate -eq $today -or [string]::IsNullOrEmpty($_.DueDate))
                } | Select-Object -First 5)
            } else {
                $self.State.TodaysTasks = @()
            }
        }
        
        RefreshRecentEntries = { 
            param($self)
            if ($global:Data -and $global:Data.TimeEntries) {
                $self.State.RecentEntries = @($global:Data.TimeEntries | Select-Object -Last 5)
            } else {
                $self.State.RecentEntries = @()
            }
        }
        
        RefreshQuickStats = { 
            param($self)
            $today = (Get-Date).ToString("yyyy-MM-dd")
            
            if ($global:Data -and $global:Data.TimeEntries) {
                $todayEntries = @($global:Data.TimeEntries | Where-Object { $_.Date -eq $today })
                $todayHours = ($todayEntries | Measure-Object -Property Hours -Sum).Sum
                
                $self.State.QuickStats = @{ 
                    TodayHours = if ($todayHours) { $todayHours } else { 0 }
                    ActiveTasks = if ($global:Data.Tasks) { @($global:Data.Tasks | Where-Object { -not $_.Completed }).Count } else { 0 }
                    RunningTimers = if ($global:Data.ActiveTimers) { $global:Data.ActiveTimers.Count } else { 0 }
                }
            } else {
                $self.State.QuickStats = @{ TodayHours = 0; ActiveTasks = 0; RunningTimers = 0 }
            }
        }
        
        GetQuickActions = { 
            param($self)
            return @( 
                @{ Name = "Add Time Entry"; Action = { 
                    if (Get-Command -Name "Get-TimeEntryScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-TimeEntryScreen)
                    }
                }}
                @{ Name = "Start Timer"; Action = { 
                    if (Get-Command -Name "Get-TimerStartScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-TimerStartScreen)
                    }
                }}
                @{ Name = "Manage Tasks"; Action = { 
                    if (Get-Command -Name "Get-TaskManagementScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-TaskManagementScreen)
                    }
                }}
                @{ Name = "View Reports"; Action = { 
                    if (Get-Command -Name "Get-ReportsScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-ReportsScreen)
                    }
                }}
                @{ Name = "Settings"; Action = { 
                    if (Get-Command -Name "Get-SettingsScreen" -ErrorAction SilentlyContinue) {
                        Push-Screen -Screen (Get-SettingsScreen)
                    }
                }}
            )
        }
        
        RenderQuickActions = { 
            param($self, $x, $y)
            $actions = & $self.GetQuickActions -self $self
            for ($i = 0; $i -lt $actions.Count; $i++) { 
                $isSelected = ($i -eq $self.State.SelectedQuickAction)
                $prefix = if ($isSelected) { "> " } else { "  " }
                $color = if ($isSelected) { "Yellow" } else { "White" }
                Write-BufferString -X $x -Y ($y + $i) -Text "$prefix$($actions[$i].Name)" -ForegroundColor $color
            }
        }
        
        RenderActiveTimers = { 
            param($self, $x, $y)
            if ($self.State.ActiveTimers.Count -eq 0) { 
                Write-BufferString -X $x -Y $y -Text "No active timers" -ForegroundColor "Gray"
            } else { 
                $currentY = $y
                foreach ($timer in $self.State.ActiveTimers) { 
                    if ($timer.Value -and $timer.Value.StartTime) {
                        $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                        $hours = [Math]::Floor($elapsed.TotalHours)
                        $mins = $elapsed.Minutes
                        $timeText = "{0}h {1}m" -f $hours, $mins
                        Write-BufferString -X $x -Y $currentY -Text $timeText -ForegroundColor "Cyan"
                        $currentY++
                    }
                } 
            }
        }
        
        RenderTodaysTasks = { 
            param($self, $x, $y)
            if ($self.State.TodaysTasks.Count -eq 0) { 
                Write-BufferString -X $x -Y $y -Text "No tasks for today" -ForegroundColor "Gray"
            } else { 
                $currentY = $y
                foreach ($task in $self.State.TodaysTasks) { 
                    $taskText = "- " + $task.Description
                    if ($taskText.Length -gt 35) { 
                        $taskText = $taskText.Substring(0, 32) + "..."
                    }
                    Write-BufferString -X $x -Y $currentY -Text $taskText -ForegroundColor "White"
                    $currentY++ 
                } 
            }
        }
        
        RenderRecentEntries = { 
            param($self, $x, $y)
            if ($self.State.RecentEntries.Count -eq 0) { 
                Write-BufferString -X $x -Y $y -Text "No recent entries" -ForegroundColor "Gray"
            } else { 
                $currentY = $y
                foreach ($entry in $self.State.RecentEntries) {
                    if ($entry.Hours -and $entry.Date) {
                        $entryText = "$($entry.Date): $($entry.Hours)h"
                        if ($entry.Description) {
                            $desc = $entry.Description
                            if ($desc.Length -gt 20) { $desc = $desc.Substring(0, 17) + "..." }
                            $entryText += " - $desc"
                        }
                        if ($entryText.Length -gt 36) {
                            $entryText = $entryText.Substring(0, 33) + "..."
                        }
                        Write-BufferString -X $x -Y $currentY -Text $entryText -ForegroundColor "White"
                        $currentY++
                    }
                } 
            }
        }
        
        RenderQuickStats = { 
            param($self, $x, $y)
            $stats = $self.State.QuickStats
            Write-BufferString -X $x -Y $y -Text "Today's Hours:" -ForegroundColor "Gray"
            Write-BufferString -X $x -Y ($y + 1) -Text "$($stats.TodayHours)h" -ForegroundColor "Green"
            
            Write-BufferString -X $x -Y ($y + 3) -Text "Active Tasks:" -ForegroundColor "Gray"
            Write-BufferString -X $x -Y ($y + 4) -Text "$($stats.ActiveTasks)" -ForegroundColor "Yellow"
            
            Write-BufferString -X $x -Y ($y + 6) -Text "Running Timers:" -ForegroundColor "Gray"
            Write-BufferString -X $x -Y ($y + 7) -Text "$($stats.RunningTimers)" -ForegroundColor "Cyan"
        }
    }
    
    return [PSCustomObject]$dashboardScreen
}

# Helper function for getting week start
function Get-WeekStart {
    param([DateTime]$Date = (Get-Date))
    $dayOfWeek = $Date.DayOfWeek
    $daysToSubtract = if ($dayOfWeek -eq [DayOfWeek]::Sunday) { 6 } else { [int]$dayOfWeek - 1 }
    return $Date.Date.AddDays(-$daysToSubtract)
}

Export-ModuleMember -Function 'Get-DashboardScreen', 'Get-WeekStart'