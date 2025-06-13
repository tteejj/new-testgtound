# Dashboard Screen v5.0 - Fixed Grid Layout
# Simplified to work with the current framework

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
                                $weekStart = (Get-Date).AddDays(-[