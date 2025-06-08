# Enhanced TUI Components for PMC Terminal
# Time tracking specific widgets and screens

#region Timer Widget Component

$script:TimerWidget = @{
    X = 0
    Y = 0
    Width = 30
    Height = 10
    
    Render = {
        param($X, $Y)
        
        if (-not $script:Data.ActiveTimers -or $script:Data.ActiveTimers.Count -eq 0) {
            Write-BufferBox -X $X -Y $Y -Width 30 -Height 3 -BorderStyle "Single" -BorderColor [ConsoleColor]::DarkGray
            Write-BufferString -X ($X + 2) -Y ($Y + 1) -Text "No active timers" -ForegroundColor [ConsoleColor]::DarkGray
            return
        }
        
        $timerY = $Y
        foreach ($timer in $script:Data.ActiveTimers.GetEnumerator()) {
            $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
            $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
            
            # Draw timer box
            Write-BufferBox -X $X -Y $timerY -Width 30 -Height 4 -BorderStyle "Rounded" -BorderColor [ConsoleColor]::Red
            
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
            
            $timerY += 5
        }
    }
}

#endregion

#region Time Entry Form Screen

$script:TimeEntryFormScreen = @{
    Name = "TimeEntryForm"
    State = @{
        Fields = @(
            @{ Name = "Project"; Value = ""; Type = "Select"; Options = @() }
            @{ Name = "Hours"; Value = ""; Type = "Number"; Validation = { param($v) [double]::TryParse($v, [ref]$null) } }
            @{ Name = "Description"; Value = ""; Type = "Text"; MaxLength = 100 }
            @{ Name = "Date"; Value = (Get-Date).ToString("yyyy-MM-dd"); Type = "Date" }
            @{ Name = "Category"; Value = "Development"; Type = "Select"; Options = @("Development", "Meeting", "Admin", "Support") }
        )
        CurrentField = 0
        EditMode = $false
        EditBuffer = ""
        ErrorMessage = ""
    }
    
    Init = {
        # Load projects for selection
        $projectOptions = @()
        foreach ($proj in $script:Data.Projects.GetEnumerator()) {
            $projectOptions += @{ Key = $proj.Key; Display = "$($proj.Key) - $($proj.Value.Name)" }
        }
        foreach ($tmpl in $script:Data.Settings.TimeTrackerTemplates.GetEnumerator()) {
            $projectOptions += @{ Key = $tmpl.Key; Display = "$($tmpl.Key) - $($tmpl.Value.Name)" }
        }
        $script:TimeEntryFormScreen.State.Fields[0].Options = $projectOptions
    }
    
    Render = {
        $state = $script:TimeEntryFormScreen.State
        
        # Header
        Write-BufferBox -X 10 -Y 2 -Width 60 -Height 3 -Title "Add Time Entry" -BorderColor [ConsoleColor]::Cyan
        
        # Form fields
        $fieldY = 6
        for ($i = 0; $i -lt $state.Fields.Count; $i++) {
            $field = $state.Fields[$i]
            $isSelected = $i -eq $state.CurrentField
            $labelColor = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White }
            
            # Label
            Write-BufferString -X 12 -Y $fieldY -Text "$($field.Name):" -ForegroundColor $labelColor
            
            # Value box
            $boxX = 25
            $boxWidth = 40
            $boxColor = if ($isSelected -and $state.EditMode) { [ConsoleColor]::Cyan } else { [ConsoleColor]::DarkGray }
            Write-BufferBox -X $boxX -Y ($fieldY - 1) -Width $boxWidth -Height 3 -BorderColor $boxColor
            
            # Value text
            $displayValue = if ($isSelected -and $state.EditMode) { 
                $state.EditBuffer + "_" 
            } else { 
                $field.Value 
            }
            
            if ($field.Type -eq "Select" -and $field.Options.Count -gt 0 -and $field.Value) {
                $selected = $field.Options | Where-Object { $_.Key -eq $field.Value } | Select-Object -First 1
                if ($selected) { $displayValue = $selected.Display }
            }
            
            Write-BufferString -X ($boxX + 2) -Y $fieldY -Text $displayValue -ForegroundColor [ConsoleColor]::White
            
            $fieldY += 4
        }
        
        # Error message
        if ($state.ErrorMessage) {
            Write-BufferString -X 12 -Y ($fieldY + 1) -Text $state.ErrorMessage -ForegroundColor [ConsoleColor]::Red
        }
        
        # Instructions
        $instructionY = 24
        Write-BufferString -X 10 -Y $instructionY -Text "↑↓: Navigate fields | Enter: Edit/Confirm | Tab: Next field | Esc: Cancel" -ForegroundColor [ConsoleColor]::DarkGray
        
        # Buttons
        $saveColor = if ($state.CurrentField -eq $state.Fields.Count) { [ConsoleColor]::Green } else { [ConsoleColor]::DarkGreen }
        $cancelColor = if ($state.CurrentField -eq ($state.Fields.Count + 1)) { [ConsoleColor]::Red } else { [ConsoleColor]::DarkRed }
        
        Write-BufferString -X 20 -Y ($fieldY + 3) -Text "[Save]" -ForegroundColor $saveColor
        Write-BufferString -X 30 -Y ($fieldY + 3) -Text "[Cancel]" -ForegroundColor $cancelColor
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:TimeEntryFormScreen.State
        
        if ($state.EditMode) {
            # Handle editing
            switch ($Key.Key) {
                ([ConsoleKey]::Enter) {
                    # Validate and save
                    $field = $state.Fields[$state.CurrentField]
                    if ($field.Validation -and -not (& $field.Validation $state.EditBuffer)) {
                        $state.ErrorMessage = "Invalid value for $($field.Name)"
                    } else {
                        $field.Value = $state.EditBuffer
                        $state.EditMode = $false
                        $state.ErrorMessage = ""
                    }
                }
                ([ConsoleKey]::Escape) {
                    $state.EditMode = $false
                    $state.EditBuffer = ""
                    $state.ErrorMessage = ""
                }
                ([ConsoleKey]::Backspace) {
                    if ($state.EditBuffer.Length -gt 0) {
                        $state.EditBuffer = $state.EditBuffer.Substring(0, $state.EditBuffer.Length - 1)
                    }
                }
                default {
                    if ($Key.KeyChar -and [char]::IsLetterOrDigit($Key.KeyChar) -or $Key.KeyChar -eq ' ' -or $Key.KeyChar -eq '.' -or $Key.KeyChar -eq '-') {
                        $field = $state.Fields[$state.CurrentField]
                        if (-not $field.MaxLength -or $state.EditBuffer.Length -lt $field.MaxLength) {
                            $state.EditBuffer += $Key.KeyChar
                        }
                    }
                }
            }
        } else {
            # Handle navigation
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($state.CurrentField -gt 0) { $state.CurrentField-- }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($state.CurrentField -lt ($state.Fields.Count + 1)) { $state.CurrentField++ }
                }
                ([ConsoleKey]::Tab) {
                    $state.CurrentField = ($state.CurrentField + 1) % ($state.Fields.Count + 2)
                }
                ([ConsoleKey]::Enter) {
                    if ($state.CurrentField -lt $state.Fields.Count) {
                        $state.EditMode = $true
                        $state.EditBuffer = $state.Fields[$state.CurrentField].Value
                    } elseif ($state.CurrentField -eq $state.Fields.Count) {
                        # Save
                        if (Save-TimeEntry) {
                            Write-StatusLine -Text " Time entry saved successfully!" -BackgroundColor [ConsoleColor]::DarkGreen
                            return "Back"
                        }
                    } else {
                        # Cancel
                        return "Back"
                    }
                }
                ([ConsoleKey]::Escape) {
                    return "Back"
                }
            }
        }
    }
}

function Save-TimeEntry {
    $state = $script:TimeEntryFormScreen.State
    
    # Validate all required fields
    if (-not $state.Fields[0].Value) { 
        $state.ErrorMessage = "Project is required"
        return $false 
    }
    if (-not $state.Fields[1].Value -or [double]$state.Fields[1].Value -le 0) { 
        $state.ErrorMessage = "Hours must be greater than 0"
        return $false 
    }
    
    # Create entry
    $entry = @{
        ProjectKey = $state.Fields[0].Value
        Hours = [double]$state.Fields[1].Value
        Description = $state.Fields[2].Value
        Date = $state.Fields[3].Value
        Category = $state.Fields[4].Value
        CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Add to data
    $script:Data.TimeEntries += $entry
    Save-UnifiedData
    
    return $true
}

#endregion

#region Task List Screen with Live Filtering

$script:EnhancedTaskListScreen = @{
    Name = "EnhancedTaskList"
    State = @{
        AllTasks = @()
        FilteredTasks = @()
        SelectedIndex = 0
        ScrollOffset = 0
        PageSize = 15
        FilterText = ""
        FilterMode = "Active" # Active, Completed, All
        SortBy = "Priority" # Priority, DueDate, Created
        EditingFilter = $false
    }
    
    Init = {
        Refresh-TaskList
    }
    
    Render = {
        $state = $script:EnhancedTaskListScreen.State
        
        # Header with filter
        Write-BufferBox -X 2 -Y 1 -Width 76 -Height 4 -Title "Task Management" -BorderColor [ConsoleColor]::Green
        
        # Filter bar
        $filterColor = if ($state.EditingFilter) { [ConsoleColor]::Yellow } else { [ConsoleColor]::DarkGray }
        Write-BufferString -X 4 -Y 2 -Text "Filter: " -ForegroundColor [ConsoleColor]::White
        Write-BufferBox -X 12 -Y 1 -Width 30 -Height 3 -BorderColor $filterColor
        $filterDisplay = if ($state.EditingFilter) { $state.FilterText + "_" } else { $state.FilterText }
        Write-BufferString -X 14 -Y 2 -Text $filterDisplay -ForegroundColor [ConsoleColor]::White
        
        # Mode indicators
        $modes = @("Active", "Completed", "All")
        $modeX = 45
        foreach ($mode in $modes) {
            $color = if ($mode -eq $state.FilterMode) { [ConsoleColor]::Cyan } else { [ConsoleColor]::DarkGray }
            Write-BufferString -X $modeX -Y 2 -Text "[$mode]" -ForegroundColor $color
            $modeX += 12
        }
        
        # Column headers
        Write-BufferString -X 4 -Y 6 -Text "Pri  ID      Task                                      Due        Progress" -ForegroundColor [ConsoleColor]::Cyan
        Write-BufferString -X 4 -Y 7 -Text "───  ──────  ────────────────────────────────────────  ─────────  ────────" -ForegroundColor [ConsoleColor]::DarkGray
        
        # Task list
        $visibleTasks = $state.FilteredTasks | Select-Object -Skip $state.ScrollOffset -First $state.PageSize
        $y = 8
        
        foreach ($task in $visibleTasks) {
            $index = $state.FilteredTasks.IndexOf($task)
            $isSelected = $index -eq $state.SelectedIndex
            
            # Priority indicator
            $priColor = switch ($task.Priority) {
                "Critical" { [ConsoleColor]::Red }
                "High" { [ConsoleColor]::Yellow }
                "Medium" { [ConsoleColor]::White }
                "Low" { [ConsoleColor]::DarkGray }
            }
            $priSymbol = switch ($task.Priority) {
                "Critical" { "!!!" }
                "High" { "!! " }
                "Medium" { "!  " }
                "Low" { "   " }
            }
            
            # Selection highlight
            if ($isSelected) {
                for ($x = 2; $x -lt 78; $x++) {
                    Write-BufferString -X $x -Y $y -Text " " -BackgroundColor [ConsoleColor]::DarkBlue
                }
            }
            
            # Render task line
            Write-BufferString -X 4 -Y $y -Text $priSymbol -ForegroundColor $priColor -BackgroundColor (if ($isSelected) { [ConsoleColor]::DarkBlue } else { [ConsoleColor]::Black })
            
            $id = $task.Id.Substring(0, 6)
            Write-BufferString -X 8 -Y $y -Text $id -ForegroundColor [ConsoleColor]::DarkCyan -BackgroundColor (if ($isSelected) { [ConsoleColor]::DarkBlue } else { [ConsoleColor]::Black })
            
            $desc = if ($task.Description.Length -gt 40) { $task.Description.Substring(0, 37) + "..." } else { $task.Description.PadRight(40) }
            $descColor = if ($task.Completed) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::White }
            Write-BufferString -X 16 -Y $y -Text $desc -ForegroundColor $descColor -BackgroundColor (if ($isSelected) { [ConsoleColor]::DarkBlue } else { [ConsoleColor]::Black })
            
            $due = if ($task.DueDate) { 
                $dueDate = [DateTime]::Parse($task.DueDate)
                $daysUntil = ($dueDate - [DateTime]::Today).Days
                $dueColor = if ($daysUntil -lt 0) { [ConsoleColor]::Red }
                            elseif ($daysUntil -eq 0) { [ConsoleColor]::Yellow }
                            elseif ($daysUntil -le 3) { [ConsoleColor]::Cyan }
                            else { [ConsoleColor]::White }
                @{ Text = $dueDate.ToString("MM/dd/yy"); Color = $dueColor }
            } else { 
                @{ Text = "        "; Color = [ConsoleColor]::DarkGray }
            }
            Write-BufferString -X 58 -Y $y -Text $due.Text -ForegroundColor $due.Color -BackgroundColor (if ($isSelected) { [ConsoleColor]::DarkBlue } else { [ConsoleColor]::Black })
            
            # Progress bar
            if ($task.Progress -gt 0) {
                $barWidth = 8
                $filled = [Math]::Floor($barWidth * ($task.Progress / 100))
                $empty = $barWidth - $filled
                $bar = ("█" * $filled) + ("░" * $empty)
                $barColor = if ($task.Progress -eq 100) { [ConsoleColor]::Green } 
                            elseif ($task.Progress -ge 50) { [ConsoleColor]::Yellow } 
                            else { [ConsoleColor]::Red }
                Write-BufferString -X 68 -Y $y -Text $bar -ForegroundColor $barColor -BackgroundColor (if ($isSelected) { [ConsoleColor]::DarkBlue } else { [ConsoleColor]::Black })
            }
            
            $y++
        }
        
        # Status bar
        $statusText = "Tasks: $($state.FilteredTasks.Count) | Selected: $($state.SelectedIndex + 1) | [/]Filter [Tab]Mode [N]ew [E]dit [C]omplete [D]elete"
        Write-StatusLine -Text " $statusText"
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:EnhancedTaskListScreen.State
        
        if ($state.EditingFilter) {
            switch ($Key.Key) {
                ([ConsoleKey]::Enter) {
                    $state.EditingFilter = $false
                    Apply-TaskFilter
                }
                ([ConsoleKey]::Escape) {
                    $state.EditingFilter = $false
                    $state.FilterText = ""
                    Apply-TaskFilter
                }
                ([ConsoleKey]::Backspace) {
                    if ($state.FilterText.Length -gt 0) {
                        $state.FilterText = $state.FilterText.Substring(0, $state.FilterText.Length - 1)
                        Apply-TaskFilter
                    }
                }
                default {
                    if ($Key.KeyChar) {
                        $state.FilterText += $Key.KeyChar
                        Apply-TaskFilter
                    }
                }
            }
        } else {
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) { Move-TaskSelection -1 }
                ([ConsoleKey]::DownArrow) { Move-TaskSelection 1 }
                ([ConsoleKey]::PageUp) { Move-TaskSelection -$state.PageSize }
                ([ConsoleKey]::PageDown) { Move-TaskSelection $state.PageSize }
                ([ConsoleKey]::Home) { 
                    $state.SelectedIndex = 0
                    $state.ScrollOffset = 0
                }
                ([ConsoleKey]::End) { 
                    $state.SelectedIndex = [Math]::Max(0, $state.FilteredTasks.Count - 1)
                    $state.ScrollOffset = [Math]::Max(0, $state.FilteredTasks.Count - $state.PageSize)
                }
                ([ConsoleKey]::Tab) {
                    # Cycle filter mode
                    $modes = @("Active", "Completed", "All")
                    $currentIndex = $modes.IndexOf($state.FilterMode)
                    $state.FilterMode = $modes[($currentIndex + 1) % $modes.Count]
                    Apply-TaskFilter
                }
                ([ConsoleKey]::Enter) {
                    if ($state.FilteredTasks.Count -gt 0) {
                        $task = $state.FilteredTasks[$state.SelectedIndex]
                        Push-Screen -Screen (Get-TaskDetailScreen -Task $task)
                    }
                }
                ([ConsoleKey]::Escape) { return "Back" }
                default {
                    switch ($Key.KeyChar) {
                        '/' { $state.EditingFilter = $true }
                        'n' { Push-Screen -Screen $script:TaskFormScreen }
                        'e' { 
                            if ($state.FilteredTasks.Count -gt 0) {
                                $task = $state.FilteredTasks[$state.SelectedIndex]
                                Push-Screen -Screen (Get-TaskEditScreen -Task $task)
                            }
                        }
                        'c' {
                            if ($state.FilteredTasks.Count -gt 0) {
                                $task = $state.FilteredTasks[$state.SelectedIndex]
                                Complete-Task -TaskId $task.Id
                                Refresh-TaskList
                            }
                        }
                        'd' {
                            if ($state.FilteredTasks.Count -gt 0) {
                                $task = $state.FilteredTasks[$state.SelectedIndex]
                                # Confirm deletion
                                Write-StatusLine -Text " Delete task? Press Y to confirm, any other key to cancel" -BackgroundColor [ConsoleColor]::DarkRed
                                $confirm = Process-Input
                                if ($confirm -and $confirm.KeyChar -eq 'y') {
                                    $script:Data.Tasks = $script:Data.Tasks | Where-Object { $_.Id -ne $task.Id }
                                    Save-UnifiedData
                                    Refresh-TaskList
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

function Refresh-TaskList {
    $state = $script:EnhancedTaskListScreen.State
    $state.AllTasks = $script:Data.Tasks | Where-Object { $_.IsCommand -ne $true }
    Apply-TaskFilter
}

function Apply-TaskFilter {
    $state = $script:EnhancedTaskListScreen.State
    
    # Apply mode filter
    $filtered = switch ($state.FilterMode) {
        "Active" { $state.AllTasks | Where-Object { -not $_.Completed } }
        "Completed" { $state.AllTasks | Where-Object { $_.Completed } }
        "All" { $state.AllTasks }
    }
    
    # Apply text filter
    if ($state.FilterText) {
        $filtered = $filtered | Where-Object {
            $_.Description -like "*$($state.FilterText)*" -or
            $_.Id -like "*$($state.FilterText)*" -or
            ($_.Tags -and ($_.Tags -join " ") -like "*$($state.FilterText)*")
        }
    }
    
    # Sort
    $state.FilteredTasks = @($filtered | Sort-Object -Property @(
        @{Expression = { $_.Completed }; Ascending = $true},
        @{Expression = { 
            switch ($_.Priority) {
                "Critical" { 0 }
                "High" { 1 }
                "Medium" { 2 }
                "Low" { 3 }
                default { 4 }
            }
        }; Ascending = $true},
        @{Expression = { if ($_.DueDate) { [DateTime]::Parse($_.DueDate) } else { [DateTime]::MaxValue } }; Ascending = $true}
    ))
    
    # Reset selection if needed
    if ($state.SelectedIndex -ge $state.FilteredTasks.Count) {
        $state.SelectedIndex = [Math]::Max(0, $state.FilteredTasks.Count - 1)
    }
    if ($state.ScrollOffset -gt $state.SelectedIndex) {
        $state.ScrollOffset = $state.SelectedIndex
    }
}

function Move-TaskSelection {
    param([int]$Delta)
    
    $state = $script:EnhancedTaskListScreen.State
    $newIndex = [Math]::Max(0, [Math]::Min($state.FilteredTasks.Count - 1, $state.SelectedIndex + $Delta))
    $state.SelectedIndex = $newIndex
    
    # Adjust scroll
    if ($newIndex -lt $state.ScrollOffset) {
        $state.ScrollOffset = $newIndex
    } elseif ($newIndex -ge ($state.ScrollOffset + $state.PageSize)) {
        $state.ScrollOffset = $newIndex - $state.PageSize + 1
    }
}

#endregion

#region Week Report Screen with Interactive Navigation

$script:WeekReportScreen = @{
    Name = "WeekReport"
    State = @{
        CurrentWeek = (Get-WeekStart (Get-Date))
        WeekData = @{}
        SelectedDay = [int](Get-Date).DayOfWeek
        ViewMode = "Summary" # Summary, Detailed, Export
    }
    
    Init = {
        Load-WeekData
    }
    
    Render = {
        $state = $script:WeekReportScreen.State
        
        # Header
        $weekEnd = $state.CurrentWeek.AddDays(6)
        $title = "Week Report: $($state.CurrentWeek.ToString('MMM dd')) - $($weekEnd.ToString('MMM dd, yyyy'))"
        Write-BufferBox -X 5 -Y 2 -Width 70 -Height 3 -Title $title -BorderColor [ConsoleColor]::Yellow
        
        # Week navigation
        Write-BufferString -X 7 -Y 3 -Text "[←]Prev Week  [→]Next Week  [T]his Week  [M]ode: $($state.ViewMode)" -ForegroundColor [ConsoleColor]::White
        
        # Week overview
        $y = 6
        $dayNames = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        $totalHours = 0
        
        for ($i = 0; $i -lt 7; $i++) {
            $date = $state.CurrentWeek.AddDays($i)
            $dayData = $state.WeekData[$date.ToString("yyyy-MM-dd")]
            $hours = if ($dayData) { $dayData.TotalHours } else { 0 }
            $totalHours += $hours
            
            $isSelected = $i -eq $state.SelectedDay
            $isToday = $date.Date -eq [DateTime]::Today
            
            # Day box
            $boxColor = if ($isSelected) { [ConsoleColor]::Cyan } 
                        elseif ($isToday) { [ConsoleColor]::Green } 
                        else { [ConsoleColor]::DarkGray }
            
            $x = 7 + ($i * 10)
            Write-BufferBox -X $x -Y $y -Width 9 -Height 5 -BorderColor $boxColor
            
            # Day name and date
            Write-BufferString -X ($x + 2) -Y ($y + 1) -Text $dayNames[$i] -ForegroundColor $boxColor
            Write-BufferString -X ($x + 1) -Y ($y + 2) -Text $date.ToString("MM/dd") -ForegroundColor [ConsoleColor]::White
            
            # Hours with color coding
            $hoursColor = if ($hours -eq 0) { [ConsoleColor]::DarkGray }
                         elseif ($hours -lt 6) { [ConsoleColor]::Yellow }
                         elseif ($hours -le 8) { [ConsoleColor]::Green }
                         else { [ConsoleColor]::Red }
            
            $hoursText = "{0:F1}h" -f $hours
            Write-BufferString -X ($x + 2) -Y ($y + 3) -Text $hoursText -ForegroundColor $hoursColor
        }
        
        # Total and average
        $y = 12
        $avgHours = $totalHours / 5  # Assuming 5 work days
        Write-BufferString -X 7 -Y $y -Text "Week Total: $("{0:F1}" -f $totalHours) hours | Daily Average: $("{0:F1}" -f $avgHours) hours" -ForegroundColor [ConsoleColor]::Cyan
        
        # Selected day details
        if ($state.ViewMode -eq "Detailed" -or $state.ViewMode -eq "Summary") {
            $selectedDate = $state.CurrentWeek.AddDays($state.SelectedDay)
            $dayData = $state.WeekData[$selectedDate.ToString("yyyy-MM-dd")]
            
            $y = 14
            Write-BufferBox -X 7 -Y $y -Width 66 -Height 12 -Title "$($dayNames[$state.SelectedDay]) - $($selectedDate.ToString('MMM dd'))" -BorderColor [ConsoleColor]::Cyan
            
            if ($dayData -and $dayData.Entries.Count -gt 0) {
                $entryY = $y + 2
                foreach ($entry in $dayData.Entries | Sort-Object CreatedAt) {
                    if ($entryY -ge ($y + 10)) { break }
                    
                    $project = Get-ProjectOrTemplate $entry.ProjectKey
                    $projectName = if ($project) { $project.Name } else { $entry.ProjectKey }
                    
                    Write-BufferString -X 9 -Y $entryY -Text ("• {0:F1}h" -f $entry.Hours) -ForegroundColor [ConsoleColor]::Yellow
                    Write-BufferString -X 16 -Y $entryY -Text $projectName -ForegroundColor [ConsoleColor]::White
                    
                    if ($entry.Description -and $state.ViewMode -eq "Detailed") {
                        $desc = if ($entry.Description.Length -gt 40) { $entry.Description.Substring(0, 37) + "..." } else { $entry.Description }
                        Write-BufferString -X 18 -Y ($entryY + 1) -Text $desc -ForegroundColor [ConsoleColor]::DarkGray
                        $entryY += 2
                    } else {
                        $entryY++
                    }
                }
            } else {
                Write-BufferString -X 9 -Y ($y + 2) -Text "No entries for this day" -ForegroundColor [ConsoleColor]::DarkGray
            }
        }
        
        # Instructions
        Write-BufferString -X 7 -Y 27 -Text "[←→]Navigate days  [↑↓]Change week  [X]Export  [Esc]Back" -ForegroundColor [ConsoleColor]::DarkGray
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:WeekReportScreen.State
        
        switch ($Key.Key) {
            ([ConsoleKey]::LeftArrow) {
                $state.SelectedDay = [Math]::Max(0, $state.SelectedDay - 1)
            }
            ([ConsoleKey]::RightArrow) {
                $state.SelectedDay = [Math]::Min(6, $state.SelectedDay + 1)
            }
            ([ConsoleKey]::UpArrow) {
                $state.CurrentWeek = $state.CurrentWeek.AddDays(-7)
                Load-WeekData
            }
            ([ConsoleKey]::DownArrow) {
                $state.CurrentWeek = $state.CurrentWeek.AddDays(7)
                Load-WeekData
            }
            ([ConsoleKey]::Escape) {
                return "Back"
            }
            default {
                switch ($Key.KeyChar) {
                    't' {
                        $state.CurrentWeek = Get-WeekStart (Get-Date)
                        $state.SelectedDay = [int](Get-Date).DayOfWeek
                        Load-WeekData
                    }
                    'm' {
                        # Toggle view mode
                        $modes = @("Summary", "Detailed", "Export")
                        $currentIndex = $modes.IndexOf($state.ViewMode)
                        $state.ViewMode = $modes[($currentIndex + 1) % $modes.Count]
                    }
                    'x' {
                        # Export week data
                        Export-WeekData
                        Write-StatusLine -Text " Week data exported to clipboard" -BackgroundColor [ConsoleColor]::DarkGreen
                    }
                }
            }
        }
    }
}

function Load-WeekData {
    $state = $script:WeekReportScreen.State
    $state.WeekData = @{}
    
    for ($i = 0; $i -lt 7; $i++) {
        $date = $state.CurrentWeek.AddDays($i)
        $dateStr = $date.ToString("yyyy-MM-dd")
        
        $dayEntries = $script:Data.TimeEntries | Where-Object { $_.Date -eq $dateStr }
        if ($dayEntries) {
            $state.WeekData[$dateStr] = @{
                Entries = $dayEntries
                TotalHours = ($dayEntries | Measure-Object -Property Hours -Sum).Sum
            }
        }
    }
}

function Export-WeekData {
    $state = $script:WeekReportScreen.State
    $output = [System.Text.StringBuilder]::new()
    
    $output.AppendLine("Week Report: $($state.CurrentWeek.ToString('yyyy-MM-dd')) to $($state.CurrentWeek.AddDays(6).ToString('yyyy-MM-dd'))")
    $output.AppendLine("="*60)
    
    $totalWeekHours = 0
    for ($i = 0; $i -lt 7; $i++) {
        $date = $state.CurrentWeek.AddDays($i)
        $dateStr = $date.ToString("yyyy-MM-dd")
        $dayData = $state.WeekData[$dateStr]
        
        $output.AppendLine("`n$($date.ToString('dddd, MMM dd'))")
        $output.AppendLine("-"*30)
        
        if ($dayData -and $dayData.Entries.Count -gt 0) {
            foreach ($entry in $dayData.Entries | Sort-Object CreatedAt) {
                $project = Get-ProjectOrTemplate $entry.ProjectKey
                $projectName = if ($project) { $project.Name } else { $entry.ProjectKey }
                $output.AppendLine("  $("{0,5:F1}" -f $entry.Hours)h - $projectName")
                if ($entry.Description) {
                    $output.AppendLine("           $($entry.Description)")
                }
            }
            $output.AppendLine("  -----")
            $output.AppendLine("  Total: $("{0:F1}" -f $dayData.TotalHours)h")
            $totalWeekHours += $dayData.TotalHours
        } else {
            $output.AppendLine("  No entries")
        }
    }
    
    $output.AppendLine("`n" + "="*60)
    $output.AppendLine("Week Total: $("{0:F1}" -f $totalWeekHours) hours")
    $output.AppendLine("Daily Average: $("{0:F1}" -f ($totalWeekHours / 5)) hours (5 work days)")
    
    # Copy to clipboard
    $output.ToString() | Set-Clipboard
}

#endregion

#region Command Palette Integration

$script:CommandPaletteScreen = @{
    Name = "CommandPalette"
    State = @{
        SearchText = ""
        FilteredCommands = @()
        SelectedIndex = 0
        MaxResults = 10
    }
    
    Init = {
        # Initialize with all commands
        Filter-Commands
    }
    
    Render = {
        $state = $script:CommandPaletteScreen.State
        
        # Overlay effect - darken background
        for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
            for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
                $cell = $script:TuiState.BackBuffer[$y, $x]
                if ($cell.FG -ne [ConsoleColor]::Black) {
                    $cell.FG = [ConsoleColor]::DarkGray
                }
            }
        }
        
        # Command palette box
        $boxWidth = 60
        $boxHeight = [Math]::Min(15, $state.FilteredCommands.Count + 6)
        $boxX = ($script:TuiState.BufferWidth - $boxWidth) / 2
        $boxY = 5
        
        Write-BufferBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight -BorderStyle "Double" -BorderColor [ConsoleColor]::Cyan
        
        # Search box
        Write-BufferString -X ($boxX + 2) -Y ($boxY + 1) -Text "Command Search:" -ForegroundColor [ConsoleColor]::Yellow
        Write-BufferBox -X ($boxX + 2) -Y ($boxY + 2) -Width ($boxWidth - 4) -Height 3 -BorderColor [ConsoleColor]::Yellow
        Write-BufferString -X ($boxX + 4) -Y ($boxY + 3) -Text ($state.SearchText + "_") -ForegroundColor [ConsoleColor]::White
        
        # Results
        $resultY = $boxY + 6
        $displayed = 0
        
        foreach ($cmd in $state.FilteredCommands | Select-Object -First $state.MaxResults) {
            $isSelected = $displayed -eq $state.SelectedIndex
            
            if ($isSelected) {
                for ($x = ($boxX + 2); $x -lt ($boxX + $boxWidth - 2); $x++) {
                    Write-BufferString -X $x -Y $resultY -Text " " -BackgroundColor [ConsoleColor]::DarkBlue
                }
            }
            
            # Command name
            Write-BufferString -X ($boxX + 4) -Y $resultY `
                -Text $cmd.Name `
                -ForegroundColor (if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::Cyan }) `
                -BackgroundColor (if ($isSelected) { [ConsoleColor]::DarkBlue } else { [ConsoleColor]::Black })
            
            # Description
            $desc = if ($cmd.Description.Length -gt 40) { $cmd.Description.Substring(0, 37) + "..." } else { $cmd.Description }
            Write-BufferString -X ($boxX + 25) -Y $resultY `
                -Text $desc `
                -ForegroundColor (if ($isSelected) { [ConsoleColor]::White } else { [ConsoleColor]::DarkGray }) `
                -BackgroundColor (if ($isSelected) { [ConsoleColor]::DarkBlue } else { [ConsoleColor]::Black })
            
            $resultY++
            $displayed++
        }
        
        # Instructions
        $instrY = $boxY + $boxHeight - 2
        Write-BufferString -X ($boxX + 2) -Y $instrY -Text "↑↓Navigate  Enter:Execute  Esc:Cancel" -ForegroundColor [ConsoleColor]::DarkGray
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:CommandPaletteScreen.State
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($state.SelectedIndex -gt 0) { $state.SelectedIndex-- }
            }
            ([ConsoleKey]::DownArrow) {
                if ($state.SelectedIndex -lt ([Math]::Min($state.MaxResults, $state.FilteredCommands.Count) - 1)) { 
                    $state.SelectedIndex++ 
                }
            }
            ([ConsoleKey]::Enter) {
                if ($state.FilteredCommands.Count -gt 0) {
                    $cmd = $state.FilteredCommands[$state.SelectedIndex]
                    Pop-Screen  # Close palette
                    & $cmd.Action
                }
            }
            ([ConsoleKey]::Escape) {
                return "Back"
            }
            ([ConsoleKey]::Backspace) {
                if ($state.SearchText.Length -gt 0) {
                    $state.SearchText = $state.SearchText.Substring(0, $state.SearchText.Length - 1)
                    Filter-Commands
                }
            }
            default {
                if ($Key.KeyChar) {
                    $state.SearchText += $Key.KeyChar
                    Filter-Commands
                }
            }
        }
    }
}

function Filter-Commands {
    $state = $script:CommandPaletteScreen.State
    
    # Get all available commands
    $allCommands = @(
        @{ Name = "Add Time Entry"; Description = "Log time manually"; Action = { Push-Screen -Screen $script:TimeEntryFormScreen } }
        @{ Name = "Start Timer"; Description = "Start a new timer"; Action = { Push-Screen -Screen $script:TimerStartScreen } }
        @{ Name = "View Tasks"; Description = "Open task management"; Action = { Push-Screen -Screen $script:EnhancedTaskListScreen } }
        @{ Name = "Week Report"; Description = "View weekly time report"; Action = { Push-Screen -Screen $script:WeekReportScreen } }
        @{ Name = "Projects"; Description = "Manage projects"; Action = { Push-Screen -Screen $script:ProjectListScreen } }
        @{ Name = "Settings"; Description = "Application settings"; Action = { Push-Screen -Screen $script:SettingsScreen } }
        @{ Name = "Export Data"; Description = "Export all data"; Action = { Export-AllData; Write-StatusLine -Text " Data exported!" } }
        @{ Name = "Quit"; Description = "Exit application"; Action = { $script:TuiState.Running = $false } }
    )
    
    # Filter based on search
    if ($state.SearchText) {
        $state.FilteredCommands = @($allCommands | Where-Object {
            $_.Name -like "*$($state.SearchText)*" -or
            $_.Description -like "*$($state.SearchText)*"
        })
    } else {
        $state.FilteredCommands = $allCommands
    }
    
    # Reset selection
    $state.SelectedIndex = 0
}

#endregion

#region Live Dashboard Components

function Update-DashboardComponents {
    # This function is called every frame to update live components
    
    # Update timer widget if visible
    if ($script:MainDashboardScreen -eq $script:TuiState.CurrentScreen) {
        $script:TimerWidget.Render.Invoke(50, 10)
    }
    
    # Update any other live components
}

#endregion

# Export functions
Export-ModuleMember -Function @(
    'Update-DashboardComponents',
    'Refresh-TaskList',
    'Load-WeekData',
    'Filter-Commands'
) -Variable @(
    'TimerWidget',
    'TimeEntryFormScreen',
    'EnhancedTaskListScreen', 
    'WeekReportScreen',
    'CommandPaletteScreen'
)
