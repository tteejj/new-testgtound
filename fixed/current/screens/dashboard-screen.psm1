# Simplified Dashboard Screen for Testing

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
            Write-Verbose "Dashboard Init"
        }
        
        Render = {
            param($self)
            
            # Simple header - centered
            $headerText = "PMC Terminal Dashboard - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            $headerX = [Math]::Max(2, [Math]::Floor(($script:TuiState.BufferWidth - $headerText.Length) / 2))
            Write-BufferString -X $headerX -Y 1 -Text $headerText -ForegroundColor "Cyan"
            
            # Simple menu
            Write-BufferBox -X 2 -Y 3 -Width 40 -Height 10 -Title " Quick Actions " -BorderColor "Yellow"
            
            $actions = @("1. Add Time Entry", "2. Start Timer", "3. Manage Tasks", "4. Manage Projects", "5. View Reports", "6. Settings")
            
            $y = 5
            foreach ($i in 0..($actions.Count - 1)) {
                $isSelected = $i -eq $self.State.SelectedQuickAction
                
                # Fixed: Replace $(if...) with proper conditional logic
                if ($isSelected) {
                    $text = "→ " + $actions[$i]
                    $color = "Yellow"
                } else {
                    $text = "  " + $actions[$i]
                    $color = "White"
                }
                
                Write-BufferString -X 4 -Y $y -Text $text -ForegroundColor $color
                $y++
            }
            
            # Instructions
            Write-BufferString -X 2 -Y 20 -Text "↑↓ Navigate • Enter: Select • Q: Quit" -ForegroundColor "Gray"
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
                    $self.State.SelectedQuickAction = [Math]::Min(5, $self.State.SelectedQuickAction + 1)
                    Request-TuiRefresh
                    return $true 
                }
                ([ConsoleKey]::Enter) { 
                    switch ($self.State.SelectedQuickAction) {
                        0 {
                            if (Get-Command Get-TimeEntryFormScreen -ErrorAction SilentlyContinue) { 
                                Push-Screen -Screen (Get-TimeEntryFormScreen) 
                            }
                        }
                        1 {
                            if (Get-Command Get-TimerStartScreen -ErrorAction SilentlyContinue) { 
                                Push-Screen -Screen (Get-TimerStartScreen) 
                            }
                        }
                        2 {
                            if (Get-Command Get-TaskManagementScreen -ErrorAction SilentlyContinue) { 
                                Push-Screen -Screen (Get-TaskManagementScreen) 
                            }
                        }
                        3 {
                            if (Get-Command Get-ProjectManagementScreen -ErrorAction SilentlyContinue) { 
                                Push-Screen -Screen (Get-ProjectManagementScreen) 
                            }
                        }
                        4 {
                            if (Get-Command Get-ReportsScreen -ErrorAction SilentlyContinue) { 
                                Push-Screen -Screen (Get-ReportsScreen) 
                            }
                        }
                        5 {
                            if (Get-Command Get-SettingsScreen -ErrorAction SilentlyContinue) { 
                                Push-Screen -Screen (Get-SettingsScreen) 
                            }
                        }
                    }
                    return $true 
                }
                ([ConsoleKey]::Q) { return "Quit" }
                ([ConsoleKey]::Escape) { return "Quit" }
            }
            
            return $false
        }
    }
    
    return $dashboardScreen
}

Export-ModuleMember -Function Get-DashboardScreen
