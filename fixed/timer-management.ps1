# Timer Management Screen for PMC Terminal TUI
# Full-featured timer control with live updates

#region Timer Management Screen

$script:TimerManagementScreen = @{
    Name = "TimerManagement"
    State = @{
        ActiveTimers = @{}
        SelectedTimerIndex = 0
        ViewMode = "List"  # List, Details, Summary
        RefreshInterval = 1000  # ms
        LastRefresh = [DateTime]::MinValue
    }
    
    Init = {
        # Load active timers
        Refresh-TimerData
        
        # Subscribe to timer events
        Subscribe-Event -EventName "Timer.Started" -Handler {
            param($EventData)
            Refresh-TimerData
        }
        
        Subscribe-Event -EventName "Timer.Stopped" -Handler {
            param($EventData)
            Refresh-TimerData
        }
    }
    
    OnExit = {
        # Cleanup event subscriptions
        Clear-EventSubscriptions -EventName "Timer.Started"
        Clear-EventSubscriptions -EventName "Timer.Stopped"
    }
    
    Render = {
        $state = $script:TimerManagementScreen.State
        
        # Header
        Write-BufferBox -X 2 -Y 1 -Width 76 -Height 4 -Title "Timer Management" -BorderColor (Get-ThemeColor "Accent")
        
        # Stats bar
        $totalActive = $state.ActiveTimers.Count
        $totalToday = Get-TodayTimerHours
        Write-BufferString -X 4 -Y 2 -Text "Active Timers: $totalActive" -ForegroundColor (Get-ThemeColor "Info")
        Write-BufferString -X 25 -Y 2 -Text "Today: $("{0:F1}h" -f $totalToday)" -ForegroundColor (Get-ThemeColor "Success")
        
        # View mode selector
        $modes = @("List", "Details", "Summary")
        $modeX = 50
        foreach ($mode in $modes) {
            $color = if ($mode -eq $state.ViewMode) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferString -X $modeX -Y 2 -Text "[$mode]" -ForegroundColor $color
            $modeX += 10
        }
        
        # Render based on view mode
        switch ($state.ViewMode) {
            "List" { Render-TimerList -State $state -Y 6 }
            "Details" { Render-TimerDetails -State $state -Y 6 }
            "Summary" { Render-TimerSummary -State $state -Y 6 }
        }
        
        # Instructions
        Write-BufferString -X 4 -Y 27 -Text "[S]tart [Space]Stop [D]etails [R]eport [N]ew [Tab]View [Esc]Back" `
            -ForegroundColor (Get-ThemeColor "Subtle")
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:TimerManagementScreen.State
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) { 
                if ($state.SelectedTimerIndex -gt 0) {
                    $state.SelectedTimerIndex--
                }
            }
            ([ConsoleKey]::DownArrow) { 
                if ($state.SelectedTimerIndex -lt ($state.ActiveTimers.Count - 1)) {
                    $state.SelectedTimerIndex++
                }
            }
            ([ConsoleKey]::Tab) {
                # Cycle view modes
                $modes = @("List", "Details", "Summary")
                $currentIndex = $modes.IndexOf($state.ViewMode)
                $state.ViewMode = $modes[($currentIndex + 1) % $modes.Count]
            }
            ([ConsoleKey]::Enter) {
                if ($state.ViewMode -eq "List") {
                    $state.ViewMode = "Details"
                }
            }
            ([ConsoleKey]::Spacebar) {
                # Stop selected timer
                if ($state.ActiveTimers.Count -gt 0) {
                    $timers = $state.ActiveTimers.GetEnumerator() | Select-Object -Skip $state.SelectedTimerIndex -First 1
                    if ($timers) {
                        Stop-TimerById -TimerId $timers.Key
                        Write-StatusLine -Text " Timer stopped" -BackgroundColor (Get-ThemeColor "Success")
                    }
                }
            }
            ([ConsoleKey]::Escape) { return "Back" }
            default {
                switch ($Key.KeyChar) {
                    's' { Push-Screen -Screen $script:TimerStartScreen }
                    'n' { Push-Screen -Screen $script:TimerStartScreen }
                    'd' { 
                        if ($state.ActiveTimers.Count -gt 0) {
                            $state.ViewMode = "Details"
                        }
                    }
                    'r' { Push-Screen -Screen $script:TimerReportScreen }
                }
            }
        }
    }
}

function Refresh-TimerData {
    $state = $script:TimerManagementScreen.State
    $state.ActiveTimers = $script:Data.ActiveTimers.Clone()
    
    # Ensure selected index is valid
    if ($state.SelectedTimerIndex -ge $state.ActiveTimers.Count) {
        $state.SelectedTimerIndex = [Math]::Max(0, $state.ActiveTimers.Count - 1)
    }
}

function Render-TimerList {
    param($State, $Y)
    
    if ($State.ActiveTimers.Count -eq 0) {
        Write-BufferBox -X 20 -Y $Y -Width 40 -Height 5 -BorderColor (Get-ThemeColor "Secondary")
        Write-BufferString -X 30 -Y ($Y + 2) -Text "No active timers" -ForegroundColor (Get-ThemeColor "Subtle")
        Write-BufferString -X 25 -Y ($Y + 3) -Text "Press [S] to start a timer" -ForegroundColor (Get-ThemeColor "Info")
        return
    }
    
    # Column headers
    Write-BufferString -X 4 -Y $Y -Text "Project" -ForegroundColor (Get-ThemeColor "Accent")
    Write-BufferString -X 35 -Y $Y -Text "Started" -ForegroundColor (Get-ThemeColor "Accent")
    Write-BufferString -X 50 -Y $Y -Text "Elapsed" -ForegroundColor (Get-ThemeColor "Accent")
    Write-BufferString -X 65 -Y $Y -Text "Rate" -ForegroundColor (Get-ThemeColor "Accent")
    
    Write-BufferString -X 4 -Y ($Y + 1) -Text ("─" * 72) -ForegroundColor (Get-ThemeColor "Secondary")
    
    $listY = $Y + 2
    $index = 0
    
    foreach ($timer in $State.ActiveTimers.GetEnumerator()) {
        $isSelected = $index -eq $State.SelectedTimerIndex
        $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
        $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
        
        # Selection highlight
        if ($isSelected) {
            for ($x = 3; $x -lt 77; $x++) {
                Write-BufferString -X $x -Y $listY -Text " " -BackgroundColor (Get-ThemeColor "Secondary")
            }
        }
        
        # Project name
        $projectName = if ($project) { $project.Name } else { "Unknown" }
        if ($projectName.Length -gt 28) { $projectName = $projectName.Substring(0, 25) + "..." }
        Write-BufferString -X 4 -Y $listY -Text $projectName `
            -ForegroundColor (Get-ThemeColor "Primary") `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        # Start time
        $startTime = [DateTime]$timer.Value.StartTime
        Write-BufferString -X 35 -Y $listY -Text $startTime.ToString("HH:mm:ss") `
            -ForegroundColor (Get-ThemeColor "Info") `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        # Elapsed time with live update
        $hours = [Math]::Floor($elapsed.TotalHours)
        $elapsedStr = "{0:D2}:{1:mm}:{1:ss}" -f $hours, $elapsed
        Write-BufferString -X 50 -Y $listY -Text $elapsedStr `
            -ForegroundColor (Get-ThemeColor "Warning") `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        # Hourly rate
        $rate = if ($project -and $project.HourlyRate) { $project.HourlyRate } else { $script:Data.Settings.DefaultRate }
        $rateStr = "`$$("{0:F2}" -f $rate)/h"
        Write-BufferString -X 65 -Y $listY -Text $rateStr `
            -ForegroundColor (Get-ThemeColor "Success") `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        # Live indicator
        $pulse = if (([DateTime]::Now.Second % 2) -eq 0) { "●" } else { "○" }
        Write-BufferString -X 75 -Y $listY -Text $pulse -ForegroundColor (Get-ThemeColor "Error")
        
        $listY++
        $index++
    }
}

function Render-TimerDetails {
    param($State, $Y)
    
    if ($State.ActiveTimers.Count -eq 0) {
        Render-TimerList -State $State -Y $Y
        return
    }
    
    # Get selected timer
    $timers = $State.ActiveTimers.GetEnumerator() | Select-Object -Skip $State.SelectedTimerIndex -First 1
    if (-not $timers) { return }
    
    $timer = $timers.Value
    $project = Get-ProjectOrTemplate $timer.ProjectKey
    $elapsed = (Get-Date) - [DateTime]$timer.StartTime
    
    # Details box
    Write-BufferBox -X 10 -Y $Y -Width 60 -Height 18 -Title "Timer Details" -BorderColor (Get-ThemeColor "Accent")
    
    $detailY = $Y + 2
    
    # Project info
    Write-BufferString -X 12 -Y $detailY -Text "Project:" -ForegroundColor (Get-ThemeColor "Secondary")
    Write-BufferString -X 25 -Y $detailY -Text ($project.Name ?? "Unknown") -ForegroundColor (Get-ThemeColor "Primary")
    $detailY += 2
    
    # Start time
    Write-BufferString -X 12 -Y $detailY -Text "Started:" -ForegroundColor (Get-ThemeColor "Secondary")
    Write-BufferString -X 25 -Y $detailY -Text ([DateTime]$timer.StartTime).ToString("yyyy-MM-dd HH:mm:ss") `
        -ForegroundColor (Get-ThemeColor "Info")
    $detailY += 2
    
    # Elapsed time
    Write-BufferString -X 12 -Y $detailY -Text "Elapsed:" -ForegroundColor (Get-ThemeColor "Secondary")
    $hours = [Math]::Floor($elapsed.TotalHours)
    $elapsedStr = "{0:D2}:{1:mm}:{1:ss}" -f $hours, $elapsed
    Write-BufferString -X 25 -Y $detailY -Text $elapsedStr -ForegroundColor (Get-ThemeColor "Warning")
    $detailY += 2
    
    # Current value
    $rate = if ($project -and $project.HourlyRate) { $project.HourlyRate } else { $script:Data.Settings.DefaultRate }
    $value = $elapsed.TotalHours * $rate
    Write-BufferString -X 12 -Y $detailY -Text "Value:" -ForegroundColor (Get-ThemeColor "Secondary")
    Write-BufferString -X 25 -Y $detailY -Text ("`$$("{0:F2}" -f $value)") -ForegroundColor (Get-ThemeColor "Success")
    $detailY += 2
    
    # Description if available
    if ($timer.Description) {
        Write-BufferString -X 12 -Y $detailY -Text "Notes:" -ForegroundColor (Get-ThemeColor "Secondary")
        $detailY++
        
        # Word wrap description
        $words = $timer.Description -split ' '
        $line = ""
        $maxLineLength = 54
        
        foreach ($word in $words) {
            if (($line + " " + $word).Length -gt $maxLineLength) {
                Write-BufferString -X 14 -Y $detailY -Text $line -ForegroundColor (Get-ThemeColor "Subtle")
                $detailY++
                $line = $word
            } else {
                $line = if ($line) { "$line $word" } else { $word }
            }
        }
        if ($line) {
            Write-BufferString -X 14 -Y $detailY -Text $line -ForegroundColor (Get-ThemeColor "Subtle")
        }
    }
    
    # Actions
    $actionY = $Y + 14
    Write-BufferString -X 12 -Y $actionY -Text "[Space] Stop Timer" -ForegroundColor (Get-ThemeColor "Error")
    Write-BufferString -X 35 -Y $actionY -Text "[E] Edit Description" -ForegroundColor (Get-ThemeColor "Info")
    Write-BufferString -X 12 -Y ($actionY + 1) -Text "[C] Convert to Entry" -ForegroundColor (Get-ThemeColor "Success")
}

function Render-TimerSummary {
    param($State, $Y)
    
    # Today's summary
    Write-BufferBox -X 10 -Y $Y -Width 60 -Height 8 -Title "Today's Summary" -BorderColor (Get-ThemeColor "Info")
    
    $summaryY = $Y + 2
    $todayTotal = 0
    $todayByProject = @{}
    
    # Calculate today's totals
    foreach ($timer in $State.ActiveTimers.GetEnumerator()) {
        $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
        $todayTotal += $elapsed.TotalHours
        
        if (-not $todayByProject.ContainsKey($timer.Value.ProjectKey)) {
            $todayByProject[$timer.Value.ProjectKey] = 0
        }
        $todayByProject[$timer.Value.ProjectKey] += $elapsed.TotalHours
    }
    
    # Add completed entries from today
    $todayEntries = $script:Data.TimeEntries | Where-Object { 
        $_.Date -eq (Get-Date).ToString("yyyy-MM-dd") 
    }
    foreach ($entry in $todayEntries) {
        $todayTotal += $entry.Hours
        if (-not $todayByProject.ContainsKey($entry.ProjectKey)) {
            $todayByProject[$entry.ProjectKey] = 0
        }
        $todayByProject[$entry.ProjectKey] += $entry.Hours
    }
    
    # Display totals
    Write-BufferString -X 12 -Y $summaryY -Text "Total Hours Today:" -ForegroundColor (Get-ThemeColor "Secondary")
    Write-BufferString -X 35 -Y $summaryY -Text ("{0:F1}h" -f $todayTotal) -ForegroundColor (Get-ThemeColor "Success")
    $summaryY += 2
    
    # By project
    Write-BufferString -X 12 -Y $summaryY -Text "By Project:" -ForegroundColor (Get-ThemeColor "Secondary")
    $summaryY++
    
    foreach ($proj in $todayByProject.GetEnumerator() | Sort-Object Value -Descending) {
        $project = Get-ProjectOrTemplate $proj.Key
        $projectName = if ($project) { $project.Name } else { $proj.Key }
        if ($projectName.Length -gt 30) { $projectName = $projectName.Substring(0, 27) + "..." }
        
        Write-BufferString -X 14 -Y $summaryY -Text $projectName -ForegroundColor (Get-ThemeColor "Primary")
        Write-BufferString -X 45 -Y $summaryY -Text ("{0:F1}h" -f $proj.Value) -ForegroundColor (Get-ThemeColor "Info")
        
        # Progress bar
        $barWidth = 20
        $percentage = [Math]::Min(1, $proj.Value / 8)  # Assume 8 hour day
        $filled = [Math]::Floor($barWidth * $percentage)
        $empty = $barWidth - $filled
        $bar = ("█" * $filled) + ("░" * $empty)
        Write-BufferString -X 52 -Y $summaryY -Text $bar -ForegroundColor (Get-ThemeColor "Accent")
        
        $summaryY++
    }
    
    # Week comparison
    $weekY = $Y + 10
    Write-BufferBox -X 10 -Y $weekY -Width 60 -Height 8 -Title "Week Comparison" -BorderColor (Get-ThemeColor "Info")
    
    # Calculate week totals
    $weekStart = Get-WeekStart (Get-Date)
    $weekHours = @{}
    for ($i = 0; $i -lt 7; $i++) {
        $date = $weekStart.AddDays($i)
        $dateStr = $date.ToString("yyyy-MM-dd")
        $dayEntries = $script:Data.TimeEntries | Where-Object { $_.Date -eq $dateStr }
        $dayTotal = ($dayEntries | Measure-Object -Property Hours -Sum).Sum
        
        # Add active timers for today
        if ($date.Date -eq (Get-Date).Date) {
            foreach ($timer in $State.ActiveTimers.GetEnumerator()) {
                $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                $dayTotal += $elapsed.TotalHours
            }
        }
        
        $weekHours[$date.DayOfWeek] = $dayTotal
    }
    
    # Display week graph
    $graphY = $weekY + 2
    $dayNames = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    $maxHours = ($weekHours.Values | Measure-Object -Maximum).Maximum
    $maxHours = [Math]::Max($maxHours, 8)
    
    for ($i = 0; $i -lt 7; $i++) {
        $dayOfWeek = if ($i -eq 6) { 0 } else { $i + 1 }  # Adjust for Sunday
        $hours = $weekHours[[DayOfWeek]$dayOfWeek] ?? 0
        
        Write-BufferString -X 12 -Y $graphY -Text $dayNames[$i] -ForegroundColor (Get-ThemeColor "Secondary")
        
        # Bar
        $barWidth = 30
        $percentage = if ($maxHours -gt 0) { $hours / $maxHours } else { 0 }
        $filled = [Math]::Floor($barWidth * $percentage)
        $bar = "█" * $filled
        
        $barColor = if ($hours -eq 0) { Get-ThemeColor "Secondary" }
                    elseif ($hours -lt 6) { Get-ThemeColor "Warning" }
                    elseif ($hours -le 8) { Get-ThemeColor "Success" }
                    else { Get-ThemeColor "Error" }
        
        Write-BufferString -X 16 -Y $graphY -Text $bar -ForegroundColor $barColor
        Write-BufferString -X 48 -Y $graphY -Text ("{0:F1}h" -f $hours) -ForegroundColor (Get-ThemeColor "Info")
        
        $graphY++
    }
}

function Get-TodayTimerHours {
    $total = 0
    
    # Active timers
    foreach ($timer in $script:Data.ActiveTimers.GetEnumerator()) {
        $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
        $total += $elapsed.TotalHours
    }
    
    # Completed entries
    $todayEntries = $script:Data.TimeEntries | Where-Object { 
        $_.Date -eq (Get-Date).ToString("yyyy-MM-dd") 
    }
    $total += ($todayEntries | Measure-Object -Property Hours -Sum).Sum
    
    return $total
}

function Stop-TimerById {
    param($TimerId)
    
    if ($script:Data.ActiveTimers.ContainsKey($TimerId)) {
        $timer = $script:Data.ActiveTimers[$TimerId]
        $elapsed = (Get-Date) - [DateTime]$timer.StartTime
        
        # Create time entry
        $entry = @{
            ProjectKey = $timer.ProjectKey
            Hours = [Math]::Round($elapsed.TotalHours, 2)
            Description = $timer.Description ?? "Timer entry"
            Date = (Get-Date).ToString("yyyy-MM-dd")
            Category = $timer.Category ?? "General"
            CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            TimerId = $TimerId
        }
        
        $script:Data.TimeEntries += $entry
        $script:Data.ActiveTimers.Remove($TimerId)
        
        Save-UnifiedData
        
        # Publish event
        Publish-Event -EventName "Timer.Stopped" -Data @{
            TimerId = $TimerId
            Timer = $timer
            Entry = $entry
        }
        
        return $true
    }
    
    return $false
}

#endregion

#region Timer Start Screen

$script:TimerStartScreen = @{
    Name = "TimerStart"
    State = @{
        Form = $null
    }
    
    Init = {
        # Create form with new components
        $projectOptions = @()
        foreach ($proj in $script:Data.Projects.GetEnumerator()) {
            $projectOptions += @{ 
                Value = $proj.Key
                Display = "$($proj.Key) - $($proj.Value.Name)"
            }
        }
        foreach ($tmpl in $script:Data.Settings.TimeTrackerTemplates.GetEnumerator()) {
            $projectOptions += @{ 
                Value = $tmpl.Key
                Display = "$($tmpl.Key) - $($tmpl.Value.Name) (Template)"
            }
        }
        
        $fields = @(
            New-Dropdown -Props @{
                Label = "Project"
                Options = $projectOptions
                IsRequired = $true
                Placeholder = "Select a project..."
                AllowSearch = $true
            }
            
            New-TextField -Props @{
                Label = "Description"
                Placeholder = "What are you working on?"
                MaxLength = 200
            }
            
            New-Dropdown -Props @{
                Label = "Category"
                Options = @(
                    @{ Value = "Development"; Display = "Development" }
                    @{ Value = "Meeting"; Display = "Meeting" }
                    @{ Value = "Admin"; Display = "Administrative" }
                    @{ Value = "Support"; Display = "Support" }
                    @{ Value = "Research"; Display = "Research" }
                    @{ Value = "Planning"; Display = "Planning" }
                )
                Value = "Development"
            }
            
            New-Checkbox -Props @{
                Label = "Start timer immediately"
                Value = $true
            }
        )
        
        $script:TimerStartScreen.State.Form = New-Form -Title "Start New Timer" -Fields $fields -OnSubmit {
            param($Form, $Data)
            
            # Start timer
            $timer = @{
                ProjectKey = $Data.Project
                StartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Description = $Data.Description
                Category = $Data.Category
            }
            
            $timerId = [Guid]::NewGuid().ToString()
            $script:Data.ActiveTimers[$timerId] = $timer
            
            Save-UnifiedData
            
            # Publish event
            Publish-Event -EventName "Timer.Started" -Data @{
                TimerId = $timerId
                Timer = $timer
            }
            
            Write-StatusLine -Text " Timer started successfully!" -BackgroundColor (Get-ThemeColor "Success")
            Pop-Screen
        }
    }
    
    Render = {
        Clear-BackBuffer
        
        # Render form centered
        $formWidth = 60
        $formHeight = 20
        $formX = ($script:TuiState.BufferWidth - $formWidth) / 2
        $formY = ($script:TuiState.BufferHeight - $formHeight) / 2
        
        & $script:TimerStartScreen.State.Form.Render `
            -self $script:TimerStartScreen.State.Form `
            -X $formX -Y $formY -Width $formWidth -Height $formHeight
    }
    
    HandleInput = {
        param($Key)
        
        $result = & $script:TimerStartScreen.State.Form.HandleInput `
            -self $script:TimerStartScreen.State.Form -key $Key
        
        if ($result -eq "Cancel") {
            return "Back"
        }
        
        return $result
    }
}

#endregion

#region Timer Report Screen

$script:TimerReportScreen = @{
    Name = "TimerReport"
    State = @{
        ReportType = "Daily"  # Daily, Weekly, Monthly, Project
        SelectedDate = (Get-Date)
        Data = @{}
    }
    
    Init = {
        Load-TimerReportData
    }
    
    Render = {
        $state = $script:TimerReportScreen.State
        
        # Header
        Write-BufferBox -X 2 -Y 1 -Width 76 -Height 4 -Title "Timer Reports" -BorderColor (Get-ThemeColor "Accent")
        
        # Report type selector
        $types = @("Daily", "Weekly", "Monthly", "Project")
        $typeX = 10
        foreach ($type in $types) {
            $color = if ($type -eq $state.ReportType) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferString -X $typeX -Y 2 -Text "[$type]" -ForegroundColor $color
            $typeX += 15
        }
        
        # Date navigation
        $dateStr = switch ($state.ReportType) {
            "Daily" { $state.SelectedDate.ToString("dddd, MMMM dd, yyyy") }
            "Weekly" { 
                $weekStart = Get-WeekStart $state.SelectedDate
                $weekEnd = $weekStart.AddDays(6)
                "Week of $($weekStart.ToString('MMM dd')) - $($weekEnd.ToString('MMM dd, yyyy'))"
            }
            "Monthly" { $state.SelectedDate.ToString("MMMM yyyy") }
            "Project" { "All Time" }
        }
        
        Write-BufferString -X 10 -Y 3 -Text "◄" -ForegroundColor (Get-ThemeColor "Info")
        Write-BufferString -X 13 -Y 3 -Text $dateStr -ForegroundColor (Get-ThemeColor "Primary")
        Write-BufferString -X (13 + $dateStr.Length + 2) -Y 3 -Text "►" -ForegroundColor (Get-ThemeColor "Info")
        
        # Render report content
        switch ($state.ReportType) {
            "Daily" { Render-DailyReport -State $state -Y 6 }
            "Weekly" { Render-WeeklyReport -State $state -Y 6 }
            "Monthly" { Render-MonthlyReport -State $state -Y 6 }
            "Project" { Render-ProjectReport -State $state -Y 6 }
        }
        
        # Export hint
        Write-BufferString -X 4 -Y 27 -Text "[←→]Navigate [Tab]Type [X]Export [Esc]Back" `
            -ForegroundColor (Get-ThemeColor "Subtle")
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:TimerReportScreen.State
        
        switch ($Key.Key) {
            ([ConsoleKey]::LeftArrow) {
                switch ($state.ReportType) {
                    "Daily" { $state.SelectedDate = $state.SelectedDate.AddDays(-1) }
                    "Weekly" { $state.SelectedDate = $state.SelectedDate.AddDays(-7) }
                    "Monthly" { $state.SelectedDate = $state.SelectedDate.AddMonths(-1) }
                }
                Load-TimerReportData
            }
            ([ConsoleKey]::RightArrow) {
                switch ($state.ReportType) {
                    "Daily" { $state.SelectedDate = $state.SelectedDate.AddDays(1) }
                    "Weekly" { $state.SelectedDate = $state.SelectedDate.AddDays(7) }
                    "Monthly" { $state.SelectedDate = $state.SelectedDate.AddMonths(1) }
                }
                Load-TimerReportData
            }
            ([ConsoleKey]::Tab) {
                $types = @("Daily", "Weekly", "Monthly", "Project")
                $currentIndex = $types.IndexOf($state.ReportType)
                $state.ReportType = $types[($currentIndex + 1) % $types.Count]
                Load-TimerReportData
            }
            ([ConsoleKey]::Escape) { return "Back" }
            default {
                if ($Key.KeyChar -eq 'x') {
                    Export-TimerReport -State $state
                    Write-StatusLine -Text " Report exported to clipboard" -BackgroundColor (Get-ThemeColor "Success")
                }
            }
        }
    }
}

function Load-TimerReportData {
    $state = $script:TimerReportScreen.State
    $state.Data = @{}
    
    switch ($state.ReportType) {
        "Daily" {
            $dateStr = $state.SelectedDate.ToString("yyyy-MM-dd")
            $entries = $script:Data.TimeEntries | Where-Object { $_.Date -eq $dateStr }
            
            # Add active timers if today
            if ($state.SelectedDate.Date -eq (Get-Date).Date) {
                foreach ($timer in $script:Data.ActiveTimers.GetEnumerator()) {
                    $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                    $entries += @{
                        ProjectKey = $timer.Value.ProjectKey
                        Hours = $elapsed.TotalHours
                        Description = $timer.Value.Description ?? "(Active timer)"
                        Category = $timer.Value.Category ?? "General"
                        IsActive = $true
                    }
                }
            }
            
            $state.Data.Entries = $entries
            $state.Data.TotalHours = ($entries | Measure-Object -Property Hours -Sum).Sum
        }
        
        "Weekly" {
            $weekStart = Get-WeekStart $state.SelectedDate
            $weekData = @{}
            $totalHours = 0
            
            for ($i = 0; $i -lt 7; $i++) {
                $date = $weekStart.AddDays($i)
                $dateStr = $date.ToString("yyyy-MM-dd")
                $dayEntries = $script:Data.TimeEntries | Where-Object { $_.Date -eq $dateStr }
                
                $dayTotal = ($dayEntries | Measure-Object -Property Hours -Sum).Sum
                
                # Add active timers if today
                if ($date.Date -eq (Get-Date).Date) {
                    foreach ($timer in $script:Data.ActiveTimers.GetEnumerator()) {
                        $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                        $dayTotal += $elapsed.TotalHours
                    }
                }
                
                $weekData[$dateStr] = @{
                    Entries = $dayEntries
                    Total = $dayTotal
                }
                $totalHours += $dayTotal
            }
            
            $state.Data.WeekData = $weekData
            $state.Data.TotalHours = $totalHours
        }
        
        "Monthly" {
            $year = $state.SelectedDate.Year
            $month = $state.SelectedDate.Month
            $daysInMonth = [DateTime]::DaysInMonth($year, $month)
            
            $monthData = @{}
            $totalHours = 0
            
            for ($day = 1; $day -le $daysInMonth; $day++) {
                $date = Get-Date -Year $year -Month $month -Day $day
                $dateStr = $date.ToString("yyyy-MM-dd")
                $dayEntries = $script:Data.TimeEntries | Where-Object { $_.Date -eq $dateStr }
                
                if ($dayEntries) {
                    $dayTotal = ($dayEntries | Measure-Object -Property Hours -Sum).Sum
                    $monthData[$dateStr] = $dayTotal
                    $totalHours += $dayTotal
                }
            }
            
            $state.Data.MonthData = $monthData
            $state.Data.TotalHours = $totalHours
        }
        
        "Project" {
            $projectTotals = @{}
            
            foreach ($entry in $script:Data.TimeEntries) {
                if (-not $projectTotals.ContainsKey($entry.ProjectKey)) {
                    $projectTotals[$entry.ProjectKey] = 0
                }
                $projectTotals[$entry.ProjectKey] += $entry.Hours
            }
            
            # Add active timers
            foreach ($timer in $script:Data.ActiveTimers.GetEnumerator()) {
                $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
                if (-not $projectTotals.ContainsKey($timer.Value.ProjectKey)) {
                    $projectTotals[$timer.Value.ProjectKey] = 0
                }
                $projectTotals[$timer.Value.ProjectKey] += $elapsed.TotalHours
            }
            
            $state.Data.ProjectTotals = $projectTotals
            $state.Data.TotalHours = ($projectTotals.Values | Measure-Object -Sum).Sum
        }
    }
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Refresh-TimerData',
    'Get-TodayTimerHours',
    'Stop-TimerById',
    'Load-TimerReportData'
) -Variable @(
    'TimerManagementScreen',
    'TimerStartScreen',
    'TimerReportScreen'
)
