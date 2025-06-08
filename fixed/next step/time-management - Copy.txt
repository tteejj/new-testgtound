#
# Time Management TUI Module
# Version: Final
#
# Contains all screens and components related to time tracking,
# timers, and reporting. This is a self-contained feature module.
#

#region Timer Widget Component

$script:TimerWidget = @{
    Render = {
        param($X, $Y)
        
        if (-not $script:Data.ActiveTimers -or $script:Data.ActiveTimers.Count -eq 0) {
            # Don't render anything if there are no timers
            return
        }
        
        $timerY = $Y
        # In a real multi-timer app, you'd loop here. For now, show the first one.
        $timer = $script:Data.ActiveTimers.GetEnumerator() | Select-Object -First 1
        
        if ($timer) {
            $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
            $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
            
            # Draw timer box
            Write-BufferBox -X $X -Y $timerY -Width 30 -Height 4 -BorderStyle "Rounded" -BorderColor [ConsoleColor]::Red -Title "LIVE TIMER"
            
            # Project name
            $projectName = if($project) { $project.Name } else { "Unknown Project" }
            if ($projectName.Length -gt 26) { $projectName = $projectName.Substring(0, 23) + "..." }
            Write-BufferString -X ($X + 2) -Y ($timerY + 1) -Text $projectName -ForegroundColor [ConsoleColor]::Yellow
            
            # Timer display with live update
            $hours = [Math]::Floor($elapsed.TotalHours)
            $timeStr = "{0:D2}:{1:mm}:{1:ss}" -f $hours, $elapsed
            Write-BufferString -X ($X + 2) -Y ($timerY + 2) -Text $timeStr -ForegroundColor [ConsoleColor]::Red
            
            # Add pulsing indicator
            $pulse = if (([DateTime]::Now.Second % 2) -eq 0) { "●" } else { "○" }
            Write-BufferString -X ($X + 26) -Y ($timerY + 1) -Text $pulse -ForegroundColor [ConsoleColor]::Red
        }
    }
}

#endregion

#region Time Entry Form Screen

$script:TimeEntryFormScreen = @{
    Name = "TimeEntryForm"
    State = @{
        Fields = @() # Initialized in Init
        CurrentField = 0
        EditMode = $false
        EditBuffer = ""
        ErrorMessage = ""
    }
    
    Init = {
        # This Init runs every time the screen is pushed
        $state = $script:TimeEntryFormScreen.State
        
        # Load projects for selection
        $projectOptions = @()
        foreach ($proj in $script:Data.Projects.GetEnumerator() | Sort-Object {$_.Value.Name}) {
            $projectOptions += @{ Key = $proj.Key; Display = "$($proj.Key) - $($proj.Value.Name)" }
        }
        foreach ($tmpl in $script:Data.Settings.TimeTrackerTemplates.GetEnumerator() | Sort-Object {$_.Value.Name}) {
            $projectOptions += @{ Key = $tmpl.Key; Display = "$($tmpl.Key) - $($tmpl.Value.Name)" }
        }

        $state.Fields = @(
            @{ Name = "Project"; Value = ""; Type = "Select"; Options = $projectOptions }
            @{ Name = "Hours"; Value = ""; Type = "Number"; Validation = { param($v) try { [double]$v > 0 } catch { $false } } }
            @{ Name = "Description"; Value = ""; Type = "Text"; MaxLength = 100 }
            @{ Name = "Date"; Value = (Get-Date).ToString("yyyy-MM-dd"); Type = "Date"; Validation = { param($v) try { [datetime]::Parse($v) | Out-Null; $true } catch { $false } } }
            @{ Name = "Category"; Value = "Development"; Type = "Select"; Options = @("Development", "Meeting", "Admin", "Support", "General") }
        )
        $state.CurrentField = 0
        $state.EditMode = $false
        $state.EditBuffer = ""
        $state.ErrorMessage = ""
        Write-StatusLine -Text "↑↓: Navigate | Enter: Edit/Confirm | Esc: Cancel"
    }
    
    Render = {
        $state = $script:TimeEntryFormScreen.State
        
        Write-BufferBox -X 10 -Y 2 -Width 60 -Height 24 -Title "Manual Time Entry" -BorderColor [ConsoleColor]::Cyan
        
        $fieldY = 5
        for ($i = 0; $i -lt $state.Fields.Count; $i++) {
            $field = $state.Fields[$i]
            $isSelected = $i -eq $state.CurrentField
            $labelColor = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White }
            
            Write-BufferString -X 12 -Y $fieldY -Text "$($field.Name):" -ForegroundColor $labelColor
            
            $boxX = 25; $boxWidth = 40
            $boxColor = if ($isSelected -and $state.EditMode) { [ConsoleColor]::Cyan } elseif ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::DarkGray }
            Write-BufferBox -X $boxX -Y ($fieldY - 1) -Width $boxWidth -Height 3 -BorderColor $boxColor
            
            $displayValue = $field.Value
            if ($field.Type -eq "Select") {
                if ($field.Options[0] -is [hashtable]) { # Project/Template list
                    $selectedOption = $field.Options | Where-Object { $_.Key -eq $field.Value }
                    if ($selectedOption) { $displayValue = $selectedOption.Display }
                }
            }

            if ($isSelected -and $state.EditMode) { 
                $displayValue = $state.EditBuffer + "_" 
            }
            
            Write-BufferString -X ($boxX + 2) -Y $fieldY -Text $displayValue.ToString().PadRight($boxWidth - 4) -ForegroundColor [ConsoleColor]::White
            
            $fieldY += 4
        }
        
        if ($state.ErrorMessage) {
            Write-BufferString -X 12 -Y ($fieldY + 1) -Text "Error: $($state.ErrorMessage)" -ForegroundColor [ConsoleColor]::Red
        }
        
        $saveColor = if ($state.CurrentField -eq $state.Fields.Count) { [ConsoleColor]::Green } else { [ConsoleColor]::DarkGreen }
        $cancelColor = if ($state.CurrentField -eq ($state.Fields.Count + 1)) { [ConsoleColor]::Red } else { [ConsoleColor]::DarkRed }
        
        Write-BufferString -X 30 -Y 23 -Text "[ Save ]" -ForegroundColor $saveColor -BackgroundColor (if($state.CurrentField -eq $state.Fields.Count){[ConsoleColor]::DarkGray}else{[ConsoleColor]::Black})
        Write-BufferString -X 45 -Y 23 -Text "[ Cancel ]" -ForegroundColor $cancelColor -BackgroundColor (if($state.CurrentField -eq ($state.Fields.Count + 1)){[ConsoleColor]::DarkGray}else{[ConsoleColor]::Black})
    }
    
    HandleInput = {
        param($Key)
        $state = $script:TimeEntryFormScreen.State
        $field = $state.Fields[$state.CurrentField]

        if ($state.EditMode) {
            switch ($Key.Key) {
                ([ConsoleKey]::Enter) {
                    if ($field.Validation -and -not (& $field.Validation $state.EditBuffer)) {
                        $state.ErrorMessage = "Invalid value for $($field.Name)"
                    } else {
                        $field.Value = $state.EditBuffer
                        $state.EditMode = $false; $state.ErrorMessage = ""
                    }
                }
                ([ConsoleKey]::Escape) { $state.EditMode = $false; $state.EditBuffer = "" }
                ([ConsoleKey]::Backspace) { if ($state.EditBuffer.Length -gt 0) { $state.EditBuffer = $state.EditBuffer.Substring(0, $state.EditBuffer.Length - 1) } }
                default {
                    if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                        if (-not $field.MaxLength -or $state.EditBuffer.Length -lt $field.MaxLength) {
                            $state.EditBuffer += $Key.KeyChar
                        }
                    }
                }
            }
        } else { # Navigation mode
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) { $state.CurrentField = [Math]::Max(0, $state.CurrentField - 1) }
                ([ConsoleKey]::DownArrow) { $state.CurrentField = [Math]::Min($state.Fields.Count + 1, $state.CurrentField + 1) }
                ([ConsoleKey]::Enter) {
                    if ($state.CurrentField -lt $state.Fields.Count) { # Edit a field
                        $state.EditMode = $true
                        $state.EditBuffer = $field.Value
                        if ($field.Type -eq "Select") {
                            # Special handling for select to show a list
                            $options = $field.Options
                            $displayProperty = if ($options[0] -is [hashtable]) { "Display" } else { $_ }
                            $valueProperty = if ($options[0] -is [hashtable]) { "Key" } else { $_ }
                            
                            # A real implementation would use a proper dropdown component.
                            # For now, we cycle through options.
                            $currentIndex = if ($options[0] -is [hashtable]) {
                                [array]::FindIndex($options, [Predicate[object]]{param($o) $o.Key -eq $field.Value})
                            } else {
                                $options.IndexOf($field.Value)
                            }
                            $nextIndex = ($currentIndex + 1) % $options.Count
                            $field.Value = if ($options[0] -is [hashtable]) { $options[$nextIndex].Key } else { $options[$nextIndex] }
                            $state.EditMode = $false # No text edit for select
                        }
                    } elseif ($state.CurrentField -eq $state.Fields.Count) { # Save
                        if (Save-TimeEntryFromForm) { return "Back" }
                    } else { # Cancel
                        return "Back"
                    }
                }
                ([ConsoleKey]::Escape) { return "Back" }
            }
        }
    }
}

function Save-TimeEntryFromForm {
    $state = $script:TimeEntryFormScreen.State
    if (-not $state.Fields[0].Value) { $state.ErrorMessage = "Project is required"; return $false }
    if (-not $state.Fields[1].Value -or [double]$state.Fields[1].Value -le 0) { $state.ErrorMessage = "Hours must be a number greater than 0"; return $false }
    
    $entry = @{
        ProjectKey = $state.Fields[0].Value
        Hours = [double]$state.Fields[1].Value
        Description = $state.Fields[2].Value
        Date = $state.Fields[3].Value
        Category = $state.Fields[4].Value
        CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $script:Data.TimeEntries += $entry
    Save-UnifiedData
    Write-StatusLine -Text "Time entry saved successfully!" -BackgroundColor [ConsoleColor]::DarkGreen
    return $true
}

#endregion

#region Week Report Screen

$script:WeekReportScreen = @{
    Name = "WeekReport"
    State = @{
        CurrentWeek = (Get-WeekStart (Get-Date))
        WeekData = @{}
        SelectedDay = -1 # -1 means no day selected
        ViewMode = "Summary" # Summary, Detailed
    }
    
    Init = {
        $state = $script:WeekReportScreen.State
        $state.CurrentWeek = (Get-WeekStart (Get-Date))
        $state.SelectedDay = [int](Get-Date).DayOfWeek
        if ($state.SelectedDay -eq 0) { $state.SelectedDay = 6 } else { $state.SelectedDay-- } # Mon=0..Sun=6
        Load-WeekData
        Write-StatusLine -Text "[←→] Navigate Days | [↑↓] Change Week | [M]ode | [T]oday | [Esc] Back"
    }
    
    Render = {
        $state = $script:WeekReportScreen.State
        $weekEnd = $state.CurrentWeek.AddDays(6)
        $title = "Week Report: $($state.CurrentWeek.ToString('MMM dd')) - $($weekEnd.ToString('MMM dd, yyyy'))"
        Write-BufferBox -X 5 -Y 1 -Width 70 -Height 3 -Title $title -BorderColor [ConsoleColor]::Yellow
        
        $dayNames = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        $totalHours = 0
        
        for ($i = 0; $i -lt 7; $i++) {
            $date = $state.CurrentWeek.AddDays($i)
            $dayData = $state.WeekData[$date.ToString("yyyy-MM-dd")]
            $hours = if ($dayData) { $dayData.TotalHours } else { 0 }
            $totalHours += $hours
            
            $isSelected = $i -eq $state.SelectedDay
            $isToday = $date.Date -eq [DateTime]::Today
            
            $boxColor = if ($isSelected) { [ConsoleColor]::Cyan } elseif ($isToday) { [ConsoleColor]::Green } else { [ConsoleColor]::DarkGray }
            $x = 7 + ($i * 10)
            Write-BufferBox -X $x -Y 5 -Width 9 -Height 5 -BorderColor $boxColor
            
            Write-BufferString -X ($x + 2) -Y 6 -Text $dayNames[$i] -ForegroundColor $boxColor
            Write-BufferString -X ($x + 1) -Y 7 -Text $date.ToString("MM/dd") -ForegroundColor [ConsoleColor]::White
            
            $hoursColor = if ($hours -eq 0) { [ConsoleColor]::DarkGray } elseif ($hours -lt 6) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Green }
            Write-BufferString -X ($x + 2) -Y 8 -Text ("{0:F1}h" -f $hours) -ForegroundColor $hoursColor
        }
        
        $avgHours = if ($totalHours -gt 0) { $totalHours / 5 } else { 0 }
        Write-BufferString -X 7 -Y 11 -Text "Week Total: $("{0:F1}" -f $totalHours) hours | Daily Average (5-day): $("{0:F1}" -f $avgHours) hours" -ForegroundColor [ConsoleColor]::Cyan
        
        if ($state.SelectedDay -ne -1) {
            $selectedDate = $state.CurrentWeek.AddDays($state.SelectedDay)
            $dayData = $state.WeekData[$selectedDate.ToString("yyyy-MM-dd")]
            
            Write-BufferBox -X 7 -Y 13 -Width 66 -Height 12 -Title "Details for $($dayNames[$state.SelectedDay]), $($selectedDate.ToString('MMM dd')) | Mode: $($state.ViewMode)" -BorderColor [ConsoleColor]::Cyan
            
            if ($dayData -and $dayData.Entries.Count -gt 0) {
                $entryY = 15
                foreach ($entry in $dayData.Entries | Sort-Object CreatedAt) {
                    if ($entryY -ge (13 + 10)) { break }
                    $project = Get-ProjectOrTemplate $entry.ProjectKey
                    $projectName = if ($project) { $project.Name } else { $entry.ProjectKey }
                    
                    Write-BufferString -X 9 -Y $entryY -Text ("• {0,4:F1}h" -f $entry.Hours) -ForegroundColor [ConsoleColor]::Yellow
                    Write-BufferString -X 17 -Y $entryY -Text $projectName -ForegroundColor [ConsoleColor]::White
                    
                    if ($entry.Description -and $state.ViewMode -eq "Detailed") {
                        $desc = if ($entry.Description.Length -gt 40) { $entry.Description.Substring(0, 37) + "..." } else { $entry.Description }
                        Write-BufferString -X 11 -Y ($entryY + 1) -Text "└─ $desc" -ForegroundColor [ConsoleColor]::DarkGray
                        $entryY += 2
                    } else {
                        $entryY++
                    }
                }
            } else {
                Write-BufferString -X 9 -Y 15 -Text "No entries for this day." -ForegroundColor [ConsoleColor]::DarkGray
            }
        }
    }
    
    HandleInput = {
        param($Key)
        $state = $script:WeekReportScreen.State
        switch ($Key.Key) {
            ([ConsoleKey]::LeftArrow) { $state.SelectedDay = [Math]::Max(0, $state.SelectedDay - 1) }
            ([ConsoleKey]::RightArrow) { $state.SelectedDay = [Math]::Min(6, $state.SelectedDay + 1) }
            ([ConsoleKey]::UpArrow) { $state.CurrentWeek = $state.CurrentWeek.AddDays(-7); Load-WeekData }
            ([ConsoleKey]::DownArrow) { $state.CurrentWeek = $state.CurrentWeek.AddDays(7); Load-WeekData }
            ([ConsoleKey]::Escape) { return "Back" }
            default {
                switch ($Key.KeyChar.ToString().ToLower()) {
                    't' { $state.CurrentWeek = Get-WeekStart (Get-Date); $state.SelectedDay = [int](Get-Date).DayOfWeek; if ($state.SelectedDay -eq 0) { $state.SelectedDay = 6 } else { $state.SelectedDay-- }; Load-WeekData }
                    'm' { $state.ViewMode = if ($state.ViewMode -eq "Summary") { "Detailed" } else { "Summary" } }
                }
            }
        }
    }
}

function Load-WeekData {
    $state = $script:WeekReportScreen.State
    $state.WeekData = @{}
    for ($i = 0; $i -lt 7; $i++) {
        $date = $state.CurrentWeek.AddDays($i); $dateStr = $date.ToString("yyyy-MM-dd")
        $dayEntries = $script:Data.TimeEntries | Where-Object { $_.Date -eq $dateStr }
        if ($dayEntries) {
            $state.WeekData[$dateStr] = @{
                Entries = $dayEntries
                TotalHours = ($dayEntries | Measure-Object -Property Hours -Sum).Sum
            }
        }
    }
}

#endregion

#region Placeholder Screens (to be implemented in their own modules later)

$script:TimeManagementMenuScreen = @{ Name="TimeManagementMenu"; Render={ Write-BufferString -X 2 -Y 2 -Text "Time Management Menu (Not Implemented)" }; HandleInput={ if($_.Key -eq 'Escape'){return "Back"} } }
$script:ReportsMenuScreen = @{ Name="ReportsMenuScreen"; Render={ Write-BufferString -X 2 -Y 2 -Text "Reports Menu (Not Implemented)" }; HandleInput={ if($_.Key -eq 'Escape'){return "Back"} } }
$script:TimerStartScreen = @{ Name="TimerStartScreen"; Render={ Write-BufferString -X 2 -Y 2 -Text "Start Timer Screen (Not Implemented)" }; HandleInput={ if($_.Key -eq 'Escape'){return "Back"} } }
$script:TodayViewScreen = @{ Name="TodayViewScreen"; Render={ Write-BufferString -X 2 -Y 2 -Text "Today View Screen (Not Implemented)" }; HandleInput={ if($_.Key -eq 'Escape'){return "Back"} } }

#endregion

#region Active Timers Screen

$script:ActiveTimersScreen = @{
    Name = "ActiveTimers"
    Render = {
        Write-BufferBox -X 10 -Y 5 -Width 60 -Height 20 -Title "Active Timers" -BorderColor [ConsoleColor]::Red
        if (-not $script:Data.ActiveTimers -or $script:Data.ActiveTimers.Count -eq 0) {
            Write-BufferString -X 25 -Y 12 -Text "No active timers running." -ForegroundColor [ConsoleColor]::DarkGray
        } else {
            $y = 7
            foreach ($timer in $script:Data.ActiveTimers.GetEnumerator()) {
                $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
                Write-BufferString -X 12 -Y $y -Text "Project:" -ForegroundColor [ConsoleColor]::DarkGray
                Write-BufferString -X 21 -Y $y -Text $project.Name -ForegroundColor [ConsoleColor]::Yellow
                $y++; $hours = [Math]::Floor($elapsed.TotalHours); $timeStr = "{0:D2}:{1:mm}:{1:ss}" -f $hours, $elapsed
                Write-BufferString -X 12 -Y $y -Text "Elapsed:" -ForegroundColor [ConsoleColor]::DarkGray
                Write-BufferString -X 21 -Y $y -Text $timeStr -ForegroundColor [ConsoleColor]::Red
                $y++; Write-BufferString -X 12 -Y $y -Text "[S] to Stop this timer" -ForegroundColor [ConsoleColor]::Cyan
                $y += 2
            }
        }
        Write-BufferString -X 12 -Y 23 -Text "Press Esc to go back" -ForegroundColor [ConsoleColor]::DarkGray
    }
    HandleInput = {
        param($Key)
        switch ($Key.Key) {
            ([ConsoleKey]::S) {
                if ($script:Data.ActiveTimers.Count -gt 0) {
                    $timerKey = ($script:Data.ActiveTimers.GetEnumerator() | Select-Object -First 1).Key
                    Stop-Timer -Key $timerKey # Assumes Stop-Timer can handle specific keys
                    Write-StatusLine -Text "Timer stopped." -BackgroundColor [ConsoleColor]::DarkGreen
                }
            }
            ([ConsoleKey]::Escape) { return "Back" }
        }
    }
}

#endregion

Export-ModuleMember -Variable @(
    'TimerWidget',
    'TimeEntryFormScreen',
    'WeekReportScreen',
    'ActiveTimersScreen',
    'TimeManagementMenuScreen',
    'ReportsMenuScreen',
    'TimerStartScreen',
    'TodayViewScreen'
)