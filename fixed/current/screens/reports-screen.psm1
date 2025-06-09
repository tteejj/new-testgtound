# Reports Screen - View various reports

function Get-ReportsMenuScreen {
    $screen = @{
        Name = "ReportsMenuScreen"
        State = @{
            SelectedIndex = 0
            MenuItems = @(
                @{ Text = "Daily Time Report"; Action = "DailyReport" }
                @{ Text = "Weekly Time Report"; Action = "WeeklyReport" }
                @{ Text = "Project Summary"; Action = "ProjectSummary" }
                @{ Text = "Task Summary"; Action = "TaskSummary" }
                @{ Text = "Back to Main Menu"; Action = "Back" }
            )
        }
        
        Render = {
            param($self)
            
            # Calculate centered position
            $screenWidth = $script:TuiState.BufferWidth
            $screenHeight = $script:TuiState.BufferHeight
            
            $boxWidth = 50
            $boxHeight = 12
            $boxX = [Math]::Floor(($screenWidth - $boxWidth) / 2)
            $boxY = [Math]::Floor(($screenHeight - $boxHeight) / 2)
            
            Write-BufferBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight `
                -Title " Reports " -BorderColor (Get-ThemeColor "Accent")
            
            # Menu Items
            for ($i = 0; $i -lt $self.State.MenuItems.Count; $i++) {
                $item = $self.State.MenuItems[$i]
                $y = $boxY + 2 + $i
                
                $prefix = if ($i -eq $self.State.SelectedIndex) { "> " } else { "  " }
                $fg = if ($i -eq $self.State.SelectedIndex) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                
                Write-BufferString -X ($boxX + 2) -Y $y -Text "$prefix$($item.Text)" -ForegroundColor $fg
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.SelectedIndex -gt 0) {
                        $self.State.SelectedIndex--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.State.SelectedIndex -lt ($self.State.MenuItems.Count - 1)) {
                        $self.State.SelectedIndex++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    $selectedItem = $self.State.MenuItems[$self.State.SelectedIndex]
                    switch ($selectedItem.Action) {
                        "DailyReport" {
                            Push-Screen -Screen (Get-TimeReportScreen -ReportType "Daily")
                        }
                        "WeeklyReport" {
                            Push-Screen -Screen (Get-TimeReportScreen -ReportType "Weekly")
                        }
                        "ProjectSummary" {
                            Push-Screen -Screen (Get-ProjectSummaryScreen)
                        }
                        "TaskSummary" {
                            Push-Screen -Screen (Get-TaskSummaryScreen)
                        }
                        "Back" {
                            return "Back"
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    return "Back"
                }
            }
            
            return $false
        }
    }
    
    return $screen
}

function Get-TimeReportScreen {
    param([string]$ReportType = "Daily")
    
    $screen = @{
        Name = "TimeReportScreen"
        State = @{
            ReportType = $ReportType
            ReportData = @()
            CurrentDate = Get-Date
        }
        
        Init = {
            param($self)
            & $self.GenerateReport -self $self
        }
        
        GenerateReport = {
            param($self)
            
            $entries = @()
            $startDate = $null
            $endDate = $null
            
            switch ($self.State.ReportType) {
                "Daily" {
                    $startDate = $self.State.CurrentDate.Date
                    $endDate = $startDate.AddDays(1).AddSeconds(-1)
                }
                "Weekly" {
                    $startDate = $self.State.CurrentDate.Date.AddDays(-[int]$self.State.CurrentDate.DayOfWeek)
                    $endDate = $startDate.AddDays(7).AddSeconds(-1)
                }
            }
            
            # Get entries in date range
            $entries = @($script:Data.TimeEntries | Where-Object {
                $entryDate = [DateTime]::Parse($_.Date)
                $entryDate -ge $startDate -and $entryDate -le $endDate
            })
            
            # Group by date and project
            $grouped = @{}
            foreach ($entry in $entries) {
                $key = "$($entry.Date)|$($entry.ProjectKey)"
                if (-not $grouped.ContainsKey($key)) {
                    $grouped[$key] = @{
                        Date = $entry.Date
                        ProjectKey = $entry.ProjectKey
                        Hours = 0
                        Entries = @()
                    }
                }
                $grouped[$key].Hours += $entry.Hours
                $grouped[$key].Entries += $entry
            }
            
            $self.State.ReportData = $grouped.Values | Sort-Object Date, ProjectKey
        }
        
        Render = {
            param($self)
            
            # Title
            $title = "$($self.State.ReportType) Time Report"
            $dateRange = switch ($self.State.ReportType) {
                "Daily" { $self.State.CurrentDate.ToString("yyyy-MM-dd") }
                "Weekly" { 
                    $weekStart = $self.State.CurrentDate.Date.AddDays(-[int]$self.State.CurrentDate.DayOfWeek)
                    $weekEnd = $weekStart.AddDays(6)
                    "$($weekStart.ToString('yyyy-MM-dd')) to $($weekEnd.ToString('yyyy-MM-dd'))"
                }
            }
            
            Write-BufferBox -X 2 -Y 1 -Width ($script:TuiState.BufferWidth - 4) -Height ($script:TuiState.BufferHeight - 3) `
                -Title " $title - $dateRange " -BorderColor (Get-ThemeColor "Accent")
            
            $y = 3
            
            if ($self.State.ReportData.Count -eq 0) {
                Write-BufferString -X 4 -Y $y -Text "No time entries found for this period."
            } else {
                # Header
                Write-BufferString -X 4 -Y $y -Text "Date        Project                  Hours  Details" -ForegroundColor (Get-ThemeColor "Header")
                Write-BufferString -X 4 -Y ($y + 1) -Text ("-" * 70) -ForegroundColor (Get-ThemeColor "Subtle")
                $y += 2
                
                $totalHours = 0
                $currentDate = ""
                
                foreach ($group in $self.State.ReportData) {
                    $project = Get-ProjectOrTemplate $group.ProjectKey
                    
                    # Date separator
                    if ($group.Date -ne $currentDate) {
                        if ($currentDate -ne "") { $y++ }
                        $currentDate = $group.Date
                    }
                    
                    # Project line
                    $line = "{0,-12} {1,-25} {2,6:F1}" -f $group.Date, $project.Name.Substring(0, [Math]::Min(25, $project.Name.Length)), $group.Hours
                    Write-BufferString -X 4 -Y $y -Text $line
                    $y++
                    
                    # Show individual entries
                    foreach ($entry in $group.Entries) {
                        $desc = if ($entry.Description) { $entry.Description.Substring(0, [Math]::Min(40, $entry.Description.Length)) } else { "" }
                        Write-BufferString -X 44 -Y ($y - 1) -Text $desc -ForegroundColor (Get-ThemeColor "Secondary")
                        if ($group.Entries.Count -gt 1) {
                            Write-BufferString -X 16 -Y $y -Text "└─ $($entry.Hours.ToString('0.0'))h: $desc" -ForegroundColor (Get-ThemeColor "Subtle")
                            $y++
                        }
                    }
                    
                    $totalHours += $group.Hours
                }
                
                # Total
                $y++
                Write-BufferString -X 4 -Y $y -Text ("-" * 70) -ForegroundColor (Get-ThemeColor "Subtle")
                Write-BufferString -X 4 -Y ($y + 1) -Text ("Total Hours: {0:F1}" -f $totalHours) -ForegroundColor (Get-ThemeColor "Success")
            }
            
            # Navigation
            $navText = switch ($self.State.ReportType) {
                "Daily" { "[←→] Previous/Next Day | [W] Week View | [Esc] Back" }
                "Weekly" { "[←→] Previous/Next Week | [D] Day View | [Esc] Back" }
            }
            Write-BufferString -X ([Math]::Floor(($script:TuiState.BufferWidth - $navText.Length) / 2)) `
                -Y ($script:TuiState.BufferHeight - 2) -Text $navText -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    switch ($self.State.ReportType) {
                        "Daily" { $self.State.CurrentDate = $self.State.CurrentDate.AddDays(-1) }
                        "Weekly" { $self.State.CurrentDate = $self.State.CurrentDate.AddDays(-7) }
                    }
                    & $self.GenerateReport -self $self
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    switch ($self.State.ReportType) {
                        "Daily" { $self.State.CurrentDate = $self.State.CurrentDate.AddDays(1) }
                        "Weekly" { $self.State.CurrentDate = $self.State.CurrentDate.AddDays(7) }
                    }
                    & $self.GenerateReport -self $self
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::W) {
                    if ($self.State.ReportType -eq "Daily") {
                        $self.State.ReportType = "Weekly"
                        & $self.GenerateReport -self $self
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::D) {
                    if ($self.State.ReportType -eq "Weekly") {
                        $self.State.ReportType = "Daily"
                        & $self.GenerateReport -self $self
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    return "Back"
                }
            }
            
            return $false
        }
    }
    
    return $screen
}

function Get-ProjectSummaryScreen {
    $screen = @{
        Name = "ProjectSummaryScreen"
        State = @{
            ProjectStats = @()
        }
        
        Init = {
            param($self)
            
            # Calculate project statistics
            $stats = @{}
            
            foreach ($project in $script:Data.Projects.GetEnumerator()) {
                $stats[$project.Key] = @{
                    Project = $project.Value
                    TotalHours = 0
                    TaskCount = 0
                    CompletedTasks = 0
                    ActiveTimers = 0
                }
            }
            
            # Count hours
            foreach ($entry in $script:Data.TimeEntries) {
                if ($stats.ContainsKey($entry.ProjectKey)) {
                    $stats[$entry.ProjectKey].TotalHours += $entry.Hours
                }
            }
            
            # Count tasks
            foreach ($task in $script:Data.Tasks) {
                if ($stats.ContainsKey($task.ProjectKey)) {
                    $stats[$task.ProjectKey].TaskCount++
                    if ($task.Completed) {
                        $stats[$task.ProjectKey].CompletedTasks++
                    }
                }
            }
            
            # Count active timers
            foreach ($timer in $script:Data.ActiveTimers.Values) {
                if ($stats.ContainsKey($timer.ProjectKey)) {
                    $stats[$timer.ProjectKey].ActiveTimers++
                }
            }
            
            $self.State.ProjectStats = $stats.Values | Sort-Object { $_.Project.Name }
        }
        
        Render = {
            param($self)
            
            Write-BufferBox -X 2 -Y 1 -Width ($script:TuiState.BufferWidth - 4) -Height ($script:TuiState.BufferHeight - 3) `
                -Title " Project Summary " -BorderColor (Get-ThemeColor "Accent")
            
            $y = 3
            
            # Header
            Write-BufferString -X 4 -Y $y -Text "Project                     Status    Hours    Tasks      Progress" -ForegroundColor (Get-ThemeColor "Header")
            Write-BufferString -X 4 -Y ($y + 1) -Text ("-" * 75) -ForegroundColor (Get-ThemeColor "Subtle")
            $y += 2
            
            foreach ($stat in $self.State.ProjectStats) {
                $project = $stat.Project
                $status = if ($project.IsActive -eq $false) { "Inactive" } else { "Active" }
                $statusColor = if ($project.IsActive -eq $false) { Get-ThemeColor "Subtle" } else { Get-ThemeColor "Success" }
                
                $taskProgress = if ($stat.TaskCount -gt 0) {
                    "$($stat.CompletedTasks)/$($stat.TaskCount)"
                } else {
                    "0/0"
                }
                
                $progressPercent = if ($stat.TaskCount -gt 0) {
                    [Math]::Round(($stat.CompletedTasks / $stat.TaskCount) * 100)
                } else {
                    0
                }
                
                $line = "{0,-28} {1,-9} {2,7:F1}  {3,-10} {4,3}%" -f `
                    $project.Name.Substring(0, [Math]::Min(28, $project.Name.Length)),
                    $status,
                    $stat.TotalHours,
                    $taskProgress,
                    $progressPercent
                
                Write-BufferString -X 4 -Y $y -Text $line
                Write-BufferString -X 32 -Y $y -Text $status -ForegroundColor $statusColor
                
                # Active timer indicator
                if ($stat.ActiveTimers -gt 0) {
                    Write-BufferString -X 75 -Y $y -Text "⏱" -ForegroundColor (Get-ThemeColor "Warning")
                }
                
                $y++
            }
            
            # Totals
            $totalHours = ($self.State.ProjectStats | Measure-Object -Property TotalHours -Sum).Sum
            $totalTasks = ($self.State.ProjectStats | Measure-Object -Property TaskCount -Sum).Sum
            $completedTasks = ($self.State.ProjectStats | Measure-Object -Property CompletedTasks -Sum).Sum
            
            $y++
            Write-BufferString -X 4 -Y $y -Text ("-" * 75) -ForegroundColor (Get-ThemeColor "Subtle")
            Write-BufferString -X 4 -Y ($y + 1) -Text ("Totals:                              {0,7:F1}  {1}/{2}" -f $totalHours, $completedTasks, $totalTasks) `
                -ForegroundColor (Get-ThemeColor "Info")
            
            Write-BufferString -X ([Math]::Floor(($script:TuiState.BufferWidth - 14) / 2)) `
                -Y ($script:TuiState.BufferHeight - 2) -Text "[Esc] Back" -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                return "Back"
            }
            return $false
        }
    }
    
    return $screen
}

function Get-TaskSummaryScreen {
    $screen = @{
        Name = "TaskSummaryScreen"
        Render = {
            Write-BufferBox -X 10 -Y 5 -Width 60 -Height 15 `
                -Title " Task Summary " -BorderColor (Get-ThemeColor "Accent")
            
            $y = 7
            
            # Count tasks by status
            $openTasks = @($script:Data.Tasks | Where-Object { -not $_.Completed }).Count
            $completedTasks = @($script:Data.Tasks | Where-Object { $_.Completed }).Count
            $totalTasks = $script:Data.Tasks.Count
            
            # Count by priority
            $criticalTasks = @($script:Data.Tasks | Where-Object { $_.Priority -eq "Critical" -and -not $_.Completed }).Count
            $highTasks = @($script:Data.Tasks | Where-Object { $_.Priority -eq "High" -and -not $_.Completed }).Count
            $mediumTasks = @($script:Data.Tasks | Where-Object { $_.Priority -eq "Medium" -and -not $_.Completed }).Count
            $lowTasks = @($script:Data.Tasks | Where-Object { $_.Priority -eq "Low" -and -not $_.Completed }).Count
            
            Write-BufferString -X 20 -Y $y -Text "Task Statistics:" -ForegroundColor (Get-ThemeColor "Header")
            $y += 2
            
            Write-BufferString -X 20 -Y $y -Text "Total Tasks: $totalTasks"
            $y++
            Write-BufferString -X 20 -Y $y -Text "Open Tasks: $openTasks" -ForegroundColor (Get-ThemeColor "Warning")
            $y++
            Write-BufferString -X 20 -Y $y -Text "Completed Tasks: $completedTasks" -ForegroundColor (Get-ThemeColor "Success")
            $y += 2
            
            Write-BufferString -X 20 -Y $y -Text "Open Tasks by Priority:" -ForegroundColor (Get-ThemeColor "Header")
            $y++
            Write-BufferString -X 22 -Y $y -Text "Critical: $criticalTasks" -ForegroundColor (Get-ThemeColor "Error")
            $y++
            Write-BufferString -X 22 -Y $y -Text "High: $highTasks" -ForegroundColor (Get-ThemeColor "Warning")
            $y++
            Write-BufferString -X 22 -Y $y -Text "Medium: $mediumTasks" -ForegroundColor (Get-ThemeColor "Info")
            $y++
            Write-BufferString -X 22 -Y $y -Text "Low: $lowTasks" -ForegroundColor (Get-ThemeColor "Success")
            
            Write-BufferString -X 25 -Y 18 -Text "Press ESC to return" -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                return "Back"
            }
            return $false
        }
    }
    
    return $screen
}

Export-ModuleMember -Function @(
    'Get-ReportsMenuScreen', 'Get-TimeReportScreen', 
    'Get-ProjectSummaryScreen', 'Get-TaskSummaryScreen'
)
