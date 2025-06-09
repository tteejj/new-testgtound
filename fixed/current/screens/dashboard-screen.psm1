# Dashboard Screen - Main menu and status overview

function Get-DashboardScreen {
    $dashboardScreen = @{
        Name = "DashboardScreen"
        State = @{
            SelectedIndex = 0
            MenuItems = @(
                @{ Text = "Time Tracking"; Action = "TimeTracking" }
                @{ Text = "Project Management"; Action = "ProjectManagement" }
                @{ Text = "Task Management"; Action = "TaskManagement" }
                @{ Text = "Reports"; Action = "Reports" }
                @{ Text = "Settings"; Action = "Settings" }
                @{ Text = "Exit"; Action = "Exit" }
            )
            ActiveTimer = $null
            LastRefresh = [DateTime]::Now
        }
        
        Init = {
            param($self)
            # Subscribe to timer events
            $null = Subscribe-Event -EventName "Timer.Tick" -Handler {
                param($EventData)
                $self.State.ActiveTimer = $EventData.Data
                Request-TuiRefresh
            }
            
            # Load initial data
            if ($script:Data -and $script:Data.ActiveTimer) {
                $self.State.ActiveTimer = $script:Data.ActiveTimer
            }
        }
        
        Render = {
            param($self)
            
            # Calculate centered positions
            $screenWidth = $script:TuiState.BufferWidth
            $screenHeight = $script:TuiState.BufferHeight
            
            # Header - centered at top
            $headerWidth = [Math]::Min(60, $screenWidth - 4)
            $headerX = [Math]::Floor(($screenWidth - $headerWidth) / 2)
            Write-BufferBox -X $headerX -Y 1 -Width $headerWidth -Height 5 `
                -Title " PMC Terminal v3.0 " -BorderColor (Get-ThemeColor "Accent")
            
            # Active Timer Display
            $timerY = 3
            if ($self.State.ActiveTimer) {
                $elapsed = [DateTime]::Now - [DateTime]::Parse($self.State.ActiveTimer.StartTime)
                $timerText = "Active Timer: $($self.State.ActiveTimer.ProjectName) - $($elapsed.ToString('hh\:mm\:ss'))"
            } else {
                $timerText = "No active timer"
            }
            $timerX = $headerX + [Math]::Floor(($headerWidth - $timerText.Length) / 2)
            Write-BufferString -X $timerX -Y $timerY -Text $timerText `
                -ForegroundColor $(if ($self.State.ActiveTimer) { Get-ThemeColor "Success" } else { Get-ThemeColor "Subtle" })
            
            # Menu - left side
            $menuWidth = 40
            $menuHeight = $self.State.MenuItems.Count + 4
            $menuX = 4
            $menuY = 8
            
            Write-BufferBox -X $menuX -Y $menuY -Width $menuWidth -Height $menuHeight `
                -Title " Main Menu " -BorderColor (Get-ThemeColor "Primary")
            
            for ($i = 0; $i -lt $self.State.MenuItems.Count; $i++) {
                $item = $self.State.MenuItems[$i]
                $y = $menuY + 2 + $i
                $prefix = if ($i -eq $self.State.SelectedIndex) { "> " } else { "  " }
                $fg = if ($i -eq $self.State.SelectedIndex) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                
                Write-BufferString -X ($menuX + 2) -Y $y -Text "$prefix$($item.Text)" -ForegroundColor $fg
            }
            
            # Quick Stats Panel - right side
            $statsWidth = 35
            $statsHeight = 10
            $statsX = $menuX + $menuWidth + 4
            
            # Ensure stats panel fits on screen
            if (($statsX + $statsWidth) -le ($screenWidth - 2)) {
                Write-BufferBox -X $statsX -Y $menuY -Width $statsWidth -Height $statsHeight `
                    -Title " Quick Stats " -BorderColor (Get-ThemeColor "Secondary")
                
                # Calculate stats
                $todayHours = 0
                $weekHours = 0
                $today = (Get-Date).Date
                $weekStart = $today.AddDays(-[int]$today.DayOfWeek)
                
                if ($script:Data -and $script:Data.TimeEntries) {
                    foreach ($entry in $script:Data.TimeEntries) {
                        $entryDate = [DateTime]::Parse($entry.Date)
                        if ($entryDate.Date -eq $today) {
                            $todayHours += $entry.Hours
                        }
                        if ($entryDate -ge $weekStart) {
                            $weekHours += $entry.Hours
                        }
                    }
                }
                
                $projectCount = if ($script:Data -and $script:Data.Projects) { $script:Data.Projects.Count } else { 0 }
                $openTaskCount = if ($script:Data -and $script:Data.Tasks) { 
                    @($script:Data.Tasks | Where-Object { $_.Status -ne 'Completed' }).Count 
                } else { 0 }
                
                Write-BufferString -X ($statsX + 2) -Y ($menuY + 2) `
                    -Text "Today: $($todayHours.ToString('0.0')) hours"
                Write-BufferString -X ($statsX + 2) -Y ($menuY + 3) `
                    -Text "This Week: $($weekHours.ToString('0.0')) hours"
                Write-BufferString -X ($statsX + 2) -Y ($menuY + 5) `
                    -Text "Active Projects: $projectCount"
                Write-BufferString -X ($statsX + 2) -Y ($menuY + 6) `
                    -Text "Open Tasks: $openTaskCount"
            }
            
            # Status Bar
            $statusText = "↑↓ Navigate | Enter: Select | Esc: Exit"
            Write-StatusLine -Text $statusText
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
                        "TimeTracking" {
                            Push-Screen -Screen (Get-TimeTrackingMenuScreen)
                        }
                        "ProjectManagement" {
                            Push-Screen -Screen (Get-ProjectManagementScreen)
                        }
                        "TaskManagement" {
                            Push-Screen -Screen (Get-TaskManagementScreen)
                        }
                        "Reports" {
                            Push-Screen -Screen (Get-ReportsMenuScreen)
                        }
                        "Settings" {
                            Push-Screen -Screen (Get-SettingsScreen)
                        }
                        "Exit" {
                            return "Quit"
                        }
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
    
    return $dashboardScreen
}

Export-ModuleMember -Function 'Get-DashboardScreen'
