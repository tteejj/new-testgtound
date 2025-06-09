# Settings Screen - Configure application settings

function Get-SettingsScreen {
    $screen = @{
        Name = "SettingsScreen"
        State = @{
            Categories = @(
                @{ Name = "Appearance"; Icon = "🎨" }
                @{ Name = "Time Format"; Icon = "⏰" }
                @{ Name = "Data"; Icon = "💾" }
            )
            SelectedCategory = 0
            SelectedItem = 0
            CurrentTheme = $script:TuiState.CurrentTheme
        }
        
        Render = {
            param($self)
            
            # Main container
            Write-BufferBox -X 2 -Y 1 -Width ($script:TuiState.BufferWidth - 4) -Height ($script:TuiState.BufferHeight - 3) `
                -Title " Settings " -BorderColor (Get-ThemeColor "Accent")
            
            # Categories on the left
            $categoryX = 4
            $categoryY = 3
            $categoryWidth = 20
            
            Write-BufferString -X $categoryX -Y $categoryY -Text "Categories:" -ForegroundColor (Get-ThemeColor "Header")
            
            for ($i = 0; $i -lt $self.State.Categories.Count; $i++) {
                $cat = $self.State.Categories[$i]
                $y = $categoryY + 2 + $i
                $prefix = if ($i -eq $self.State.SelectedCategory) { "> " } else { "  " }
                $fg = if ($i -eq $self.State.SelectedCategory) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                
                Write-BufferString -X $categoryX -Y $y -Text "$prefix$($cat.Icon) $($cat.Name)" -ForegroundColor $fg
            }
            
            # Settings panel on the right
            $panelX = $categoryX + $categoryWidth + 4
            $panelY = $categoryY
            $panelWidth = $script:TuiState.BufferWidth - $panelX - 4
            
            # Divider
            for ($y = 2; $y -lt ($script:TuiState.BufferHeight - 3); $y++) {
                Write-BufferString -X ($panelX - 2) -Y $y -Text "│" -ForegroundColor (Get-ThemeColor "Secondary")
            }
            
            switch ($self.State.SelectedCategory) {
                0 { # Appearance
                    & $self.RenderAppearanceSettings -self $self -X $panelX -Y $panelY
                }
                1 { # Time Format
                    & $self.RenderTimeFormatSettings -self $self -X $panelX -Y $panelY
                }
                2 { # Data
                    & $self.RenderDataSettings -self $self -X $panelX -Y $panelY
                }
            }
            
            # Instructions
            $instructions = "[↑↓] Navigate | [←→] Change Value | [Enter] Apply | [Esc] Back"
            Write-BufferString -X ([Math]::Floor(($script:TuiState.BufferWidth - $instructions.Length) / 2)) `
                -Y ($script:TuiState.BufferHeight - 2) -Text $instructions -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        RenderAppearanceSettings = {
            param($self, $X, $Y)
            
            Write-BufferString -X $X -Y $Y -Text "Appearance Settings" -ForegroundColor (Get-ThemeColor "Header")
            $Y += 2
            
            # Theme selection
            Write-BufferString -X $X -Y $Y -Text "Theme:" -ForegroundColor (Get-ThemeColor "Primary")
            $Y++
            
            $themes = @("Default", "Dark", "Light")
            for ($i = 0; $i -lt $themes.Count; $i++) {
                $theme = $themes[$i]
                $isSelected = ($theme -eq $self.State.CurrentTheme)
                $prefix = if ($isSelected) { "(•) " } else { "( ) " }
                $fg = if ($self.State.SelectedItem -eq $i) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                
                Write-BufferString -X ($X + 2) -Y ($Y + $i) -Text "$prefix$theme" -ForegroundColor $fg
            }
            
            # Preview
            $Y += $themes.Count + 2
            Write-BufferString -X $X -Y $Y -Text "Preview:" -ForegroundColor (Get-ThemeColor "Primary")
            $Y++
            
            Write-BufferBox -X $X -Y $Y -Width 30 -Height 6 -BorderColor (Get-ThemeColor "Accent")
            Write-BufferString -X ($X + 2) -Y ($Y + 1) -Text "Primary Text" -ForegroundColor (Get-ThemeColor "Primary")
            Write-BufferString -X ($X + 2) -Y ($Y + 2) -Text "Secondary Text" -ForegroundColor (Get-ThemeColor "Secondary")
            Write-BufferString -X ($X + 2) -Y ($Y + 3) -Text "Success Message" -ForegroundColor (Get-ThemeColor "Success")
            Write-BufferString -X ($X + 2) -Y ($Y + 4) -Text "Error Message" -ForegroundColor (Get-ThemeColor "Error")
        }
        
        RenderTimeFormatSettings = {
            param($self, $X, $Y)
            
            Write-BufferString -X $X -Y $Y -Text "Time Format Settings" -ForegroundColor (Get-ThemeColor "Header")
            $Y += 2
            
            # Time format
            $timeFormat = $script:Data.Settings.TimeFormat ?? "24h"
            Write-BufferString -X $X -Y $Y -Text "Time Format:" -ForegroundColor (Get-ThemeColor "Primary")
            $Y++
            
            $formats = @("12h", "24h")
            for ($i = 0; $i -lt $formats.Count; $i++) {
                $format = $formats[$i]
                $isSelected = ($format -eq $timeFormat)
                $prefix = if ($isSelected) { "(•) " } else { "( ) " }
                $fg = if ($self.State.SelectedItem -eq $i) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                
                $example = if ($format -eq "12h") { "3:45 PM" } else { "15:45" }
                Write-BufferString -X ($X + 2) -Y ($Y + $i) -Text "$prefix$format (e.g., $example)" -ForegroundColor $fg
            }
            
            # Week start day
            $Y += 4
            $weekStart = $script:Data.Settings.WeekStartsOn ?? "Monday"
            Write-BufferString -X $X -Y $Y -Text "Week Starts On:" -ForegroundColor (Get-ThemeColor "Primary")
            $Y++
            
            $days = @("Sunday", "Monday")
            for ($i = 0; $i -lt $days.Count; $i++) {
                $day = $days[$i]
                $isSelected = ($day -eq $weekStart)
                $prefix = if ($isSelected) { "(•) " } else { "( ) " }
                $fg = if ($self.State.SelectedItem -eq ($i + 2)) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                
                Write-BufferString -X ($X + 2) -Y ($Y + $i) -Text "$prefix$day" -ForegroundColor $fg
            }
        }
        
        RenderDataSettings = {
            param($self, $X, $Y)
            
            Write-BufferString -X $X -Y $Y -Text "Data Settings" -ForegroundColor (Get-ThemeColor "Header")
            $Y += 2
            
            # Data location
            Write-BufferString -X $X -Y $Y -Text "Data Location:" -ForegroundColor (Get-ThemeColor "Primary")
            Write-BufferString -X ($X + 2) -Y ($Y + 1) -Text $script:Data.DataPath -ForegroundColor (Get-ThemeColor "Secondary")
            $Y += 3
            
            # Last saved
            if ($script:Data.LastSaved) {
                Write-BufferString -X $X -Y $Y -Text "Last Saved:" -ForegroundColor (Get-ThemeColor "Primary")
                Write-BufferString -X ($X + 2) -Y ($Y + 1) -Text $script:Data.LastSaved.ToString("yyyy-MM-dd HH:mm:ss") `
                    -ForegroundColor (Get-ThemeColor "Secondary")
                $Y += 3
            }
            
            # Actions
            Write-BufferString -X $X -Y $Y -Text "Actions:" -ForegroundColor (Get-ThemeColor "Primary")
            $Y++
            
            $actions = @("Export Data", "Import Data", "Reset to Defaults")
            for ($i = 0; $i -lt $actions.Count; $i++) {
                $action = $actions[$i]
                $prefix = if ($self.State.SelectedItem -eq $i) { "> " } else { "  " }
                $fg = if ($self.State.SelectedItem -eq $i) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                
                Write-BufferString -X ($X + 2) -Y ($Y + $i) -Text "$prefix$action" -ForegroundColor $fg
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.SelectedItem -gt 0) {
                        $self.State.SelectedItem--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    # Get max items for current category
                    $maxItems = switch ($self.State.SelectedCategory) {
                        0 { 2 } # 3 themes (0-2)
                        1 { 3 } # 2 time formats + 2 week days (0-3)
                        2 { 2 } # 3 actions (0-2)
                    }
                    
                    if ($self.State.SelectedItem -lt $maxItems) {
                        $self.State.SelectedItem++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($self.State.SelectedCategory -gt 0) {
                        $self.State.SelectedCategory--
                        $self.State.SelectedItem = 0
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    if ($self.State.SelectedCategory -lt $self.State.Categories.Count - 1) {
                        $self.State.SelectedCategory++
                        $self.State.SelectedItem = 0
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    switch ($self.State.SelectedCategory) {
                        0 { # Appearance
                            $themes = @("Default", "Dark", "Light")
                            if ($self.State.SelectedItem -le 2) {
                                $newTheme = $themes[$self.State.SelectedItem]
                                Set-TuiTheme -ThemeName $newTheme
                                $self.State.CurrentTheme = $newTheme
                                $script:Data.Settings.Theme = $newTheme
                                Save-UnifiedData
                                
                                Publish-Event -EventName "Notification.Show" -Data @{
                                    Text = "Theme changed to $newTheme"
                                    Type = "Success"
                                }
                            }
                        }
                        1 { # Time Format
                            if ($self.State.SelectedItem -le 1) {
                                # Time format
                                $formats = @("12h", "24h")
                                $script:Data.Settings.TimeFormat = $formats[$self.State.SelectedItem]
                                Save-UnifiedData
                                
                                Publish-Event -EventName "Notification.Show" -Data @{
                                    Text = "Time format changed"
                                    Type = "Success"
                                }
                            } elseif ($self.State.SelectedItem -le 3) {
                                # Week start
                                $days = @("Sunday", "Monday")
                                $script:Data.Settings.WeekStartsOn = $days[$self.State.SelectedItem - 2]
                                Save-UnifiedData
                                
                                Publish-Event -EventName "Notification.Show" -Data @{
                                    Text = "Week start day changed"
                                    Type = "Success"
                                }
                            }
                        }
                        2 { # Data
                            switch ($self.State.SelectedItem) {
                                0 { # Export
                                    Publish-Event -EventName "Notification.Show" -Data @{
                                        Text = "Export feature coming soon"
                                        Type = "Info"
                                    }
                                }
                                1 { # Import
                                    Publish-Event -EventName "Notification.Show" -Data @{
                                        Text = "Import feature coming soon"
                                        Type = "Info"
                                    }
                                }
                                2 { # Reset
                                    Publish-Event -EventName "Confirm.Request" -Data @{
                                        Title = "Reset Data"
                                        Message = "Reset all data to defaults? This cannot be undone!"
                                        OnConfirm = {
                                            Initialize-DefaultData
                                            Save-UnifiedData
                                            
                                            Publish-Event -EventName "Notification.Show" -Data @{
                                                Text = "Data reset to defaults"
                                                Type = "Success"
                                            }
                                            
                                            Request-TuiRefresh
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Request-TuiRefresh
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

Export-ModuleMember -Function 'Get-SettingsScreen'
