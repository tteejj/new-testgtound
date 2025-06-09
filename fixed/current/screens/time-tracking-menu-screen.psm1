# Time Tracking Menu Screen

function Get-TimeTrackingMenuScreen {
    $screen = @{
        Name = "TimeTrackingMenuScreen"
        State = @{
            SelectedIndex = 0
            MenuItems = @(
                @{ Text = "Add Time Entry"; Action = "AddTimeEntry" }
                @{ Text = "Start Timer"; Action = "StartTimer" }
                @{ Text = "Stop Timer"; Action = "StopTimer" }
                @{ Text = "View Today's Entries"; Action = "ViewToday" }
                @{ Text = "View This Week"; Action = "ViewWeek" }
                @{ Text = "Back to Main Menu"; Action = "Back" }
            )
        }
        
        Render = {
            param($self)
            
            # Calculate centered position
            $screenWidth = $script:TuiState.BufferWidth
            $screenHeight = $script:TuiState.BufferHeight
            
            $boxWidth = 60
            $boxHeight = 15
            $boxX = [Math]::Floor(($screenWidth - $boxWidth) / 2)
            $boxY = [Math]::Floor(($screenHeight - $boxHeight) / 2)
            
            # Ensure box fits on screen
            if ($boxX -lt 2) { $boxX = 2 }
            if ($boxY -lt 2) { $boxY = 2 }
            if (($boxX + $boxWidth) -gt ($screenWidth - 2)) { 
                $boxWidth = $screenWidth - $boxX - 2 
            }
            if (($boxY + $boxHeight) -gt ($screenHeight - 2)) { 
                $boxHeight = $screenHeight - $boxY - 2 
            }
            
            Write-BufferBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight `
                -Title " Time Tracking " -BorderColor (Get-ThemeColor "Accent")
            
            # Active Timer Status
            $statusY = $boxY + 2
            if ($script:Data -and $script:Data.ActiveTimers -and $script:Data.ActiveTimers.Count -gt 0) {
                $timerCount = $script:Data.ActiveTimers.Count
                $timerText = if ($timerCount -eq 1) { "1 timer running" } else { "$timerCount timers running" }
                Write-BufferString -X ($boxX + 2) -Y $statusY -Text $timerText -ForegroundColor (Get-ThemeColor "Success")
                $menuY = $statusY + 2
            } else {
                $menuY = $statusY
            }
            
            # Menu Items
            for ($i = 0; $i -lt $self.State.MenuItems.Count; $i++) {
                $item = $self.State.MenuItems[$i]
                $y = $menuY + $i
                
                # Ensure we don't render outside the box
                if ($y -ge ($boxY + $boxHeight - 1)) { break }
                
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
                        "AddTimeEntry" {
                            Push-Screen -Screen (Get-TimeEntryFormScreen)
                        }
                        "StartTimer" {
                            Push-Screen -Screen (Get-TimerStartScreen)
                        }
                        "StopTimer" {
                            if ($script:Data -and $script:Data.ActiveTimers -and $script:Data.ActiveTimers.Count -gt 0) {
                                # Navigate to timer management to select which timer to stop
                                Push-Screen -Screen (Get-TimerManagementScreen)
                            } else {
                                Publish-Event -EventName "Notification.Show" -Data @{
                                    Text = "No active timers to stop"
                                    Type = "Warning"
                                }
                            }
                        }
                        "ViewToday" {
                            Push-Screen -Screen (Get-TimeEntriesListScreen -Filter "Today")
                        }
                        "ViewWeek" {
                            Push-Screen -Screen (Get-TimeEntriesListScreen -Filter "Week")
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

Export-ModuleMember -Function 'Get-TimeTrackingMenuScreen'
