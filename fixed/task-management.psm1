# Enhanced Task Management Screen for PMC Terminal TUI
# Full CRUD operations with advanced filtering and batch operations

#region Task Management Screen

$script:TaskManagementScreen = @{
    Name = "TaskManagement"
    State = @{
        Tasks = @()
        FilteredTasks = @()
        SelectedIndex = 0
        ScrollOffset = 0
        PageSize = 15
        
        # Filters
        FilterText = ""
        FilterStatus = "Active"  # All, Active, Completed, Archived
        FilterPriority = "All"   # All, Critical, High, Medium, Low
        FilterProject = "All"
        FilterDateRange = "All" # All, Today, Week, Month, Overdue
        
        # UI State
        EditingFilter = $false
        MultiSelectMode = $false
        SelectedTasks = @()
        SortBy = "Priority"  # Priority, DueDate, Created, Updated
        SortDescending = $false
        
        # View modes
        ViewMode = "List"  # List, Kanban, Calendar, Gantt
    }
    
    Init = {
        Load-TaskData
        
        # Subscribe to events
        Subscribe-Event -EventName "Task.Created" -Handler {
            param($EventData)
            Load-TaskData
        }
        
        Subscribe-Event -EventName "Task.Updated" -Handler {
            param($EventData)
            Load-TaskData
        }
        
        Subscribe-Event -EventName "Task.Deleted" -Handler {
            param($EventData)
            Load-TaskData
        }
    }
    
    OnExit = {
        Clear-EventSubscriptions -EventName "Task.Created"
        Clear-EventSubscriptions -EventName "Task.Updated"
        Clear-EventSubscriptions -EventName "Task.Deleted"
    }
    
    Render = {
        $state = $script:TaskManagementScreen.State
        
        # Header
        Write-BufferBox -X 1 -Y 0 -Width 78 -Height 5 -Title "Task Management" -BorderColor (Get-ThemeColor "Success")
        
        # Stats bar
        $stats = Get-TaskStats -Tasks $state.Tasks
        Write-BufferString -X 3 -Y 1 -Text "Total: $($stats.Total)" -ForegroundColor (Get-ThemeColor "Info")
        Write-BufferString -X 15 -Y 1 -Text "Active: $($stats.Active)" -ForegroundColor (Get-ThemeColor "Success")
        Write-BufferString -X 28 -Y 1 -Text "Overdue: $($stats.Overdue)" -ForegroundColor (Get-ThemeColor "Error")
        Write-BufferString -X 42 -Y 1 -Text "Today: $($stats.DueToday)" -ForegroundColor (Get-ThemeColor "Warning")
        
        # View mode selector
        $viewX = 55
        foreach ($mode in @("List", "Kanban", "Calendar")) {
            $color = if ($mode -eq $state.ViewMode) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferString -X $viewX -Y 1 -Text "[$mode]" -ForegroundColor $color
            $viewX += 9
        }
        
        # Filter bar
        Render-TaskFilterBar -State $state -Y 3
        
        # Main content area
        switch ($state.ViewMode) {
            "List" { Render-TaskListView -State $state -Y 6 }
            "Kanban" { Render-TaskKanbanView -State $state -Y 6 }
            "Calendar" { Render-TaskCalendarView -State $state -Y 6 }
        }
        
        # Status bar
        Render-TaskStatusBar -State $state
    }
    
    HandleInput = {
        param($Key)
        
        $state = $script:TaskManagementScreen.State
        
        if ($state.EditingFilter) {
            Handle-TaskFilterInput -State $state -Key $Key
        } else {
            Handle-TaskNavigationInput -State $state -Key $Key
        }
    }
}

function Load-TaskData {
    $state = $script:TaskManagementScreen.State
    
    # Load all non-command tasks
    $state.Tasks = @($script:Data.Tasks | Where-Object { 
        -not $_.IsCommand -and
        -not $_.Id.StartsWith("CMD-")
    })
    
    # Apply filters
    Apply-TaskFilters
}

function Apply-TaskFilters {
    $state = $script:TaskManagementScreen.State
    
    $filtered = $state.Tasks
    
    # Status filter
    switch ($state.FilterStatus) {
        "Active" { $filtered = $filtered | Where-Object { -not $_.Completed -and -not $_.Archived } }
        "Completed" { $filtered = $filtered | Where-Object { $_.Completed } }
        "Archived" { $filtered = $filtered | Where-Object { $_.Archived } }
    }
    
    # Priority filter
    if ($state.FilterPriority -ne "All") {
        $filtered = $filtered | Where-Object { $_.Priority -eq $state.FilterPriority }
    }
    
    # Project filter
    if ($state.FilterProject -ne "All") {
        $filtered = $filtered | Where-Object { $_.ProjectKey -eq $state.FilterProject }
    }
    
    # Date range filter
    $today = (Get-Date).Date
    switch ($state.FilterDateRange) {
        "Today" {
            $filtered = $filtered | Where-Object {
                $_.DueDate -and [DateTime]::Parse($_.DueDate).Date -eq $today
            }
        }
        "Week" {
            $weekStart = Get-WeekStart (Get-Date)
            $weekEnd = $weekStart.AddDays(7)
            $filtered = $filtered | Where-Object {
                $_.DueDate -and 
                [DateTime]::Parse($_.DueDate) -ge $weekStart -and
                [DateTime]::Parse($_.DueDate) -lt $weekEnd
            }
        }
        "Month" {
            $monthStart = Get-Date -Day 1
            $monthEnd = $monthStart.AddMonths(1)
            $filtered = $filtered | Where-Object {
                $_.DueDate -and 
                [DateTime]::Parse($_.DueDate) -ge $monthStart -and
                [DateTime]::Parse($_.DueDate) -lt $monthEnd
            }
        }
        "Overdue" {
            $filtered = $filtered | Where-Object {
                $_.DueDate -and [DateTime]::Parse($_.DueDate).Date -lt $today
            }
        }
    }
    
    # Text filter
    if ($state.FilterText) {
        $filtered = $filtered | Where-Object {
            $_.Description -like "*$($state.FilterText)*" -or
            $_.Id -like "*$($state.FilterText)*" -or
            ($_.Tags -and ($_.Tags -join " ") -like "*$($state.FilterText)*") -or
            ($_.Notes -and $_.Notes -like "*$($state.FilterText)*")
        }
    }
    
    # Sort
    $sortProperty = switch ($state.SortBy) {
        "Priority" { 
            { 
                switch ($_.Priority) {
                    "Critical" { 0 }
                    "High" { 1 }
                    "Medium" { 2 }
                    "Low" { 3 }
                    default { 4 }
                }
            }
        }
        "DueDate" { 
            { if ($_.DueDate) { [DateTime]::Parse($_.DueDate) } else { [DateTime]::MaxValue } }
        }
        "Created" { 
            { if ($_.CreatedAt) { [DateTime]::Parse($_.CreatedAt) } else { [DateTime]::MinValue } }
        }
        "Updated" { 
            { if ($_.UpdatedAt) { [DateTime]::Parse($_.UpdatedAt) } else { [DateTime]::MinValue } }
        }
    }
    
    $state.FilteredTasks = @($filtered | Sort-Object -Property $sortProperty -Descending:$state.SortDescending)
    
    # Adjust selection
    if ($state.SelectedIndex -ge $state.FilteredTasks.Count) {
        $state.SelectedIndex = [Math]::Max(0, $state.FilteredTasks.Count - 1)
    }
}

function Get-TaskStats {
    param($Tasks)
    
    $today = (Get-Date).Date
    
    return @{
        Total = $Tasks.Count
        Active = @($Tasks | Where-Object { -not $_.Completed -and -not $_.Archived }).Count
        Completed = @($Tasks | Where-Object { $_.Completed }).Count
        Archived = @($Tasks | Where-Object { $_.Archived }).Count
        Overdue = @($Tasks | Where-Object { 
            -not $_.Completed -and $_.DueDate -and [DateTime]::Parse($_.DueDate).Date -lt $today 
        }).Count
        DueToday = @($Tasks | Where-Object { 
            -not $_.Completed -and $_.DueDate -and [DateTime]::Parse($_.DueDate).Date -eq $today 
        }).Count
    }
}

#endregion

#region Task List View

function Render-TaskListView {
    param($State, $Y)
    
    # Column headers
    Write-BufferString -X 2 -Y $Y -Text "□" -ForegroundColor (Get-ThemeColor "Secondary")
    Write-BufferString -X 4 -Y $Y -Text "Pri" -ForegroundColor (Get-ThemeColor "Accent")
    Write-BufferString -X 8 -Y $Y -Text "ID" -ForegroundColor (Get-ThemeColor "Accent")
    Write-BufferString -X 15 -Y $Y -Text "Task" -ForegroundColor (Get-ThemeColor "Accent")
    Write-BufferString -X 45 -Y $Y -Text "Project" -ForegroundColor (Get-ThemeColor "Accent")
    Write-BufferString -X 58 -Y $Y -Text "Due" -ForegroundColor (Get-ThemeColor "Accent")
    Write-BufferString -X 68 -Y $Y -Text "Progress" -ForegroundColor (Get-ThemeColor "Accent")
    
    Write-BufferString -X 2 -Y ($Y + 1) -Text ("─" * 76) -ForegroundColor (Get-ThemeColor "Secondary")
    
    # Task list
    $listY = $Y + 2
    $visibleTasks = $State.FilteredTasks | Select-Object -Skip $State.ScrollOffset -First $State.PageSize
    
    if ($visibleTasks.Count -eq 0) {
        Write-BufferString -X 25 -Y ($listY + 5) -Text "No tasks match the current filters" `
            -ForegroundColor (Get-ThemeColor "Subtle")
        return
    }
    
    $index = $State.ScrollOffset
    foreach ($task in $visibleTasks) {
        $isSelected = $index -eq $State.SelectedIndex
        $isMultiSelected = $State.SelectedTasks -contains $task.Id
        
        # Selection highlight
        if ($isSelected) {
            for ($x = 1; $x -lt 78; $x++) {
                Write-BufferString -X $x -Y $listY -Text " " -BackgroundColor (Get-ThemeColor "Secondary")
            }
        }
        
        # Multi-select checkbox
        $checkChar = if ($State.MultiSelectMode) {
            if ($isMultiSelected) { "☑" } else { "☐" }
        } else {
            if ($task.Completed) { "✓" } else { "○" }
        }
        $checkColor = if ($task.Completed) { Get-ThemeColor "Success" } else { Get-ThemeColor "Secondary" }
        Write-BufferString -X 2 -Y $listY -Text $checkChar -ForegroundColor $checkColor `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        # Priority
        $priSymbol = switch ($task.Priority) {
            "Critical" { "!!!" }
            "High" { "!! " }
            "Medium" { "!  " }
            "Low" { "   " }
            default { "   " }
        }
        $priColor = switch ($task.Priority) {
            "Critical" { Get-ThemeColor "Error" }
            "High" { Get-ThemeColor "Warning" }
            "Medium" { Get-ThemeColor "Primary" }
            "Low" { Get-ThemeColor "Subtle" }
            default { Get-ThemeColor "Subtle" }
        }
        Write-BufferString -X 4 -Y $listY -Text $priSymbol -ForegroundColor $priColor `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        # ID
        $shortId = if ($task.Id.Length -gt 6) { $task.Id.Substring(0, 6) } else { $task.Id }
        Write-BufferString -X 8 -Y $listY -Text $shortId -ForegroundColor (Get-ThemeColor "Info") `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        # Description
        $desc = $task.Description
        if ($desc.Length -gt 28) { $desc = $desc.Substring(0, 25) + "..." }
        $descColor = if ($task.Completed) { Get-ThemeColor "Subtle" } 
                     elseif ($task.Archived) { Get-ThemeColor "Secondary" }
                     else { Get-ThemeColor "Primary" }
        Write-BufferString -X 15 -Y $listY -Text $desc -ForegroundColor $descColor `
            -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        
        # Project
        if ($task.ProjectKey) {
            $project = Get-ProjectOrTemplate $task.ProjectKey
            $projName = if ($project) { $project.Name } else { $task.ProjectKey }
            if ($projName.Length -gt 11) { $projName = $projName.Substring(0, 8) + "..." }
            Write-BufferString -X 45 -Y $listY -Text $projName -ForegroundColor (Get-ThemeColor "Accent") `
                -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        }
        
        # Due date
        if ($task.DueDate) {
            $dueDate = [DateTime]::Parse($task.DueDate)
            $daysUntil = ($dueDate.Date - (Get-Date).Date).Days
            $dueText = $dueDate.ToString("MM/dd")
            $dueColor = if ($daysUntil -lt 0) { Get-ThemeColor "Error" }
                        elseif ($daysUntil -eq 0) { Get-ThemeColor "Warning" }
                        elseif ($daysUntil -le 3) { Get-ThemeColor "Info" }
                        else { Get-ThemeColor "Primary" }
            
            Write-BufferString -X 58 -Y $listY -Text $dueText -ForegroundColor $dueColor `
                -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        }
        
        # Progress bar
        if ($task.Progress -gt 0) {
            $barWidth = 8
            $filled = [Math]::Floor($barWidth * ($task.Progress / 100))
            $empty = $barWidth - $filled
            $bar = ("█" * $filled) + ("░" * $empty)
            $barColor = if ($task.Progress -eq 100) { Get-ThemeColor "Success" } 
                        elseif ($task.Progress -ge 50) { Get-ThemeColor "Warning" } 
                        else { Get-ThemeColor "Info" }
            Write-BufferString -X 68 -Y $listY -Text $bar -ForegroundColor $barColor `
                -BackgroundColor (if ($isSelected) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
        }
        
        # Tags indicator
        if ($task.Tags -and $task.Tags.Count -gt 0) {
            Write-BufferString -X 77 -Y $listY -Text "●" -ForegroundColor (Get-ThemeColor "Accent")
        }
        
        $listY++
        $index++
    }
    
    # Scroll indicators
    if ($State.ScrollOffset -gt 0) {
        Write-BufferString -X 77 -Y ($Y + 2) -Text "↑" -ForegroundColor (Get-ThemeColor "Info")
    }
    if (($State.ScrollOffset + $State.PageSize) -lt $State.FilteredTasks.Count) {
        Write-BufferString -X 77 -Y ($Y + $State.PageSize + 1) -Text "↓" -ForegroundColor (Get-ThemeColor "Info")
    }
}

#endregion

#region Task Kanban View

function Render-TaskKanbanView {
    param($State, $Y)
    
    # Kanban columns
    $columns = @(
        @{ Name = "To Do"; Status = "Todo"; Tasks = @() }
        @{ Name = "In Progress"; Status = "InProgress"; Tasks = @() }
        @{ Name = "Review"; Status = "Review"; Tasks = @() }
        @{ Name = "Done"; Status = "Done"; Tasks = @() }
    )
    
    # Group tasks by status
    foreach ($task in $State.FilteredTasks) {
        $status = $task.Status ?? "Todo"
        $column = $columns | Where-Object { $_.Status -eq $status } | Select-Object -First 1
        if ($column) {
            $column.Tasks += $task
        }
    }
    
    # Render columns
    $columnWidth = 18
    $columnX = 2
    
    foreach ($column in $columns) {
        # Column header
        Write-BufferBox -X $columnX -Y $Y -Width $columnWidth -Height 20 `
            -Title "$($column.Name) ($($column.Tasks.Count))" `
            -BorderColor (Get-ThemeColor "Secondary")
        
        # Tasks in column
        $taskY = $Y + 2
        foreach ($task in $column.Tasks | Select-Object -First 8) {
            # Task card
            Write-BufferBox -X ($columnX + 1) -Y $taskY -Width ($columnWidth - 2) -Height 2 `
                -BorderStyle "Single" -BorderColor (Get-ThemeColor "Subtle")
            
            # Task description
            $desc = $task.Description
            if ($desc.Length -gt ($columnWidth - 4)) { 
                $desc = $desc.Substring(0, $columnWidth - 7) + "..." 
            }
            Write-BufferString -X ($columnX + 2) -Y ($taskY + 1) -Text $desc `
                -ForegroundColor (Get-ThemeColor "Primary")
            
            $taskY += 3
        }
        
        # More indicator
        if ($column.Tasks.Count -gt 8) {
            Write-BufferString -X ($columnX + 7) -Y ($Y + 18) `
                -Text "+$($column.Tasks.Count - 8) more" `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        $columnX += $columnWidth + 1
    }
}

#endregion

#region Task Filter Bar

function Render-TaskFilterBar {
    param($State, $Y)
    
    # Filter input
    $filterColor = if ($State.EditingFilter) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
    Write-BufferString -X 3 -Y $Y -Text "Filter:" -ForegroundColor (Get-ThemeColor "Primary")
    Write-BufferBox -X 10 -Y ($Y - 1) -Width 25 -Height 3 -BorderColor $filterColor
    
    $filterDisplay = if ($State.EditingFilter) { $State.FilterText + "_" } else { 
        if ($State.FilterText) { $State.FilterText } else { "Type to filter..." }
    }
    Write-BufferString -X 12 -Y $Y -Text $filterDisplay `
        -ForegroundColor (if ($State.FilterText) { Get-ThemeColor "Primary" } else { Get-ThemeColor "Subtle" })
    
    # Quick filters
    $filterX = 38
    
    # Status filter
    $statusColor = if ($State.FilterStatus -ne "Active") { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
    Write-BufferString -X $filterX -Y $Y -Text "[$($State.FilterStatus)]" -ForegroundColor $statusColor
    $filterX += $State.FilterStatus.Length + 3
    
    # Priority filter
    if ($State.FilterPriority -ne "All") {
        Write-BufferString -X $filterX -Y $Y -Text "[$($State.FilterPriority)]" -ForegroundColor (Get-ThemeColor "Warning")
        $filterX += $State.FilterPriority.Length + 3
    }
    
    # Date filter
    if ($State.FilterDateRange -ne "All") {
        Write-BufferString -X $filterX -Y $Y -Text "[$($State.FilterDateRange)]" -ForegroundColor (Get-ThemeColor "Info")
    }
}

#endregion

#region Task Status Bar

function Render-TaskStatusBar {
    param($State)
    
    $statusY = 28
    
    if ($State.MultiSelectMode) {
        $text = "Multi-select: $($State.SelectedTasks.Count) selected | " +
                "[A]ll [N]one [C]omplete [D]elete [M]ove [Esc]Cancel"
        Write-StatusLine -Text " $text" -BackgroundColor (Get-ThemeColor "Warning")
    } else {
        $shortcuts = if ($State.ViewMode -eq "List") {
            "[N]ew [E]dit [C]omplete [D]elete [/]Filter [M]ulti [V]iew"
        } else {
            "[N]ew [V]iew [/]Filter [Esc]Back"
        }
        
        $text = "Tasks: $($State.FilteredTasks.Count)/$($State.Tasks.Count) | $shortcuts"
        Write-StatusLine -Text " $text"
    }
}

#endregion

#region Task Input Handlers

function Handle-TaskNavigationInput {
    param($State, $Key)
    
    if ($State.MultiSelectMode) {
        Handle-MultiSelectInput -State $State -Key $Key
        return
    }
    
    switch ($Key.Key) {
        ([ConsoleKey]::UpArrow) { Move-TaskSelection -State $State -Delta (-1) }
        ([ConsoleKey]::DownArrow) { Move-TaskSelection -State $State -Delta 1 }
        ([ConsoleKey]::PageUp) { Move-TaskSelection -State $State -Delta (-$State.PageSize) }
        ([ConsoleKey]::PageDown) { Move-TaskSelection -State $State -Delta $State.PageSize }
        ([ConsoleKey]::Home) { 
            $State.SelectedIndex = 0
            $State.ScrollOffset = 0
        }
        ([ConsoleKey]::End) { 
            $State.SelectedIndex = [Math]::Max(0, $State.FilteredTasks.Count - 1)
            Adjust-TaskScroll -State $State
        }
        ([ConsoleKey]::Tab) {
            # Cycle view modes
            $modes = @("List", "Kanban", "Calendar")
            $currentIndex = $modes.IndexOf($State.ViewMode)
            $State.ViewMode = $modes[($currentIndex + 1) % $modes.Count]
        }
        ([ConsoleKey]::Enter) {
            if ($State.FilteredTasks.Count -gt 0) {
                $task = $State.FilteredTasks[$State.SelectedIndex]
                Push-Screen -Screen (Get-TaskDetailScreen -TaskId $task.Id)
            }
        }
        ([ConsoleKey]::Escape) { return "Back" }
        default {
            switch ($Key.KeyChar) {
                '/' { $State.EditingFilter = $true }
                'n' { Push-Screen -Screen $script:TaskCreateScreen }
                'e' { 
                    if ($State.FilteredTasks.Count -gt 0) {
                        $task = $State.FilteredTasks[$State.SelectedIndex]
                        Push-Screen -Screen (Get-TaskEditScreen -TaskId $task.Id)
                    }
                }
                'c' {
                    if ($State.FilteredTasks.Count -gt 0) {
                        $task = $State.FilteredTasks[$State.SelectedIndex]
                        Toggle-TaskComplete -TaskId $task.Id
                    }
                }
                'd' {
                    if ($State.FilteredTasks.Count -gt 0) {
                        $task = $State.FilteredTasks[$State.SelectedIndex]
                        if (Confirm-Action -Message "Delete task '$($task.Description)'?") {
                            Delete-Task -TaskId $task.Id
                        }
                    }
                }
                'm' {
                    $State.MultiSelectMode = $true
                    $State.SelectedTasks = @()
                }
                'v' {
                    # Quick view toggle
                    $modes = @("List", "Kanban", "Calendar")
                    $currentIndex = $modes.IndexOf($State.ViewMode)
                    $State.ViewMode = $modes[($currentIndex + 1) % $modes.Count]
                }
                's' {
                    # Sort options
                    Push-Screen -Screen (Get-TaskSortScreen -State $State)
                }
                'f' {
                    # Advanced filters
                    Push-Screen -Screen (Get-TaskFilterScreen -State $State)
                }
            }
        }
    }
}

function Handle-TaskFilterInput {
    param($State, $Key)
    
    switch ($Key.Key) {
        ([ConsoleKey]::Enter) {
            $State.EditingFilter = $false
            Apply-TaskFilters
        }
        ([ConsoleKey]::Escape) {
            $State.EditingFilter = $false
            $State.FilterText = ""
            Apply-TaskFilters
        }
        ([ConsoleKey]::Backspace) {
            if ($State.FilterText.Length -gt 0) {
                $State.FilterText = $State.FilterText.Substring(0, $State.FilterText.Length - 1)
                Apply-TaskFilters
            }
        }
        default {
            if ($Key.KeyChar -and [char]::IsControl($Key.KeyChar) -eq $false) {
                $State.FilterText += $Key.KeyChar
                Apply-TaskFilters
            }
        }
    }
}

function Handle-MultiSelectInput {
    param($State, $Key)
    
    switch ($Key.Key) {
        ([ConsoleKey]::UpArrow) { Move-TaskSelection -State $State -Delta (-1) }
        ([ConsoleKey]::DownArrow) { Move-TaskSelection -State $State -Delta 1 }
        ([ConsoleKey]::Spacebar) {
            if ($State.FilteredTasks.Count -gt 0) {
                $task = $State.FilteredTasks[$State.SelectedIndex]
                if ($State.SelectedTasks -contains $task.Id) {
                    $State.SelectedTasks = @($State.SelectedTasks | Where-Object { $_ -ne $task.Id })
                } else {
                    $State.SelectedTasks += $task.Id
                }
            }
        }
        ([ConsoleKey]::Escape) {
            $State.MultiSelectMode = $false
            $State.SelectedTasks = @()
        }
        default {
            switch ($Key.KeyChar) {
                'a' {
                    # Select all
                    $State.SelectedTasks = @($State.FilteredTasks | ForEach-Object { $_.Id })
                }
                'n' {
                    # Select none
                    $State.SelectedTasks = @()
                }
                'c' {
                    # Complete selected
                    foreach ($taskId in $State.SelectedTasks) {
                        Complete-Task -TaskId $taskId
                    }
                    $State.MultiSelectMode = $false
                    $State.SelectedTasks = @()
                }
                'd' {
                    # Delete selected
                    if (Confirm-Action -Message "Delete $($State.SelectedTasks.Count) tasks?") {
                        foreach ($taskId in $State.SelectedTasks) {
                            Delete-Task -TaskId $taskId
                        }
                    }
                    $State.MultiSelectMode = $false
                    $State.SelectedTasks = @()
                }
                'm' {
                    # Move selected
                    if ($State.SelectedTasks.Count -gt 0) {
                        Push-Screen -Screen (Get-TaskMoveScreen -TaskIds $State.SelectedTasks)
                    }
                }
            }
        }
    }
}

function Move-TaskSelection {
    param($State, $Delta)
    
    $newIndex = [Math]::Max(0, [Math]::Min($State.FilteredTasks.Count - 1, $State.SelectedIndex + $Delta))
    $State.SelectedIndex = $newIndex
    
    Adjust-TaskScroll -State $State
}

function Adjust-TaskScroll {
    param($State)
    
    if ($State.SelectedIndex -lt $State.ScrollOffset) {
        $State.ScrollOffset = $State.SelectedIndex
    } elseif ($State.SelectedIndex -ge ($State.ScrollOffset + $State.PageSize)) {
        $State.ScrollOffset = $State.SelectedIndex - $State.PageSize + 1
    }
}

#endregion

#region Task CRUD Operations

function Create-Task {
    param($TaskData)
    
    $task = @{
        Id = "TSK-" + (Get-Random -Maximum 999999).ToString("D6")
        Description = $TaskData.Description
        Priority = $TaskData.Priority ?? "Medium"
        Status = $TaskData.Status ?? "Todo"
        ProjectKey = $TaskData.ProjectKey
        DueDate = $TaskData.DueDate
        Progress = 0
        Tags = @($TaskData.Tags)
        Notes = $TaskData.Notes
        CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        UpdatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Completed = $false
        Archived = $false
    }
    
    $script:Data.Tasks += $task
    Save-UnifiedData
    
    Publish-Event -EventName "Task.Created" -Data @{
        Task = $task
    }
    
    return $task
}

function Update-Task {
    param($TaskId, $Updates)
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $TaskId } | Select-Object -First 1
    if (-not $task) { return $null }
    
    foreach ($key in $Updates.Keys) {
        $task.$key = $Updates[$key]
    }
    
    $task.UpdatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    
    Save-UnifiedData
    
    Publish-Event -EventName "Task.Updated" -Data @{
        TaskId = $TaskId
        Task = $task
        Updates = $Updates
    }
    
    return $task
}

function Delete-Task {
    param($TaskId)
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $TaskId } | Select-Object -First 1
    if (-not $task) { return $false }
    
    $script:Data.Tasks = @($script:Data.Tasks | Where-Object { $_.Id -ne $TaskId })
    
    Save-UnifiedData
    
    Publish-Event -EventName "Task.Deleted" -Data @{
        TaskId = $TaskId
        Task = $task
    }
    
    return $true
}

function Complete-Task {
    param($TaskId)
    
    Update-Task -TaskId $TaskId -Updates @{
        Completed = $true
        CompletedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Progress = 100
    }
}

function Toggle-TaskComplete {
    param($TaskId)
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $TaskId } | Select-Object -First 1
    if (-not $task) { return }
    
    if ($task.Completed) {
        Update-Task -TaskId $TaskId -Updates @{
            Completed = $false
            CompletedAt = $null
            Progress = if ($task.Progress -eq 100) { 0 } else { $task.Progress }
        }
    } else {
        Complete-Task -TaskId $TaskId
    }
}

#endregion

#region Task Create Screen

$script:TaskCreateScreen = @{
    Name = "TaskCreate"
    State = @{
        Form = $null
    }
    
    Init = {
        # Get project options
        $projectOptions = @(@{ Value = ""; Display = "No Project" })
        foreach ($proj in $script:Data.Projects.GetEnumerator()) {
            $projectOptions += @{ 
                Value = $proj.Key
                Display = "$($proj.Key) - $($proj.Value.Name)"
            }
        }
        
        $fields = @(
            New-TextField -Props @{
                Label = "Task Description"
                IsRequired = $true
                Placeholder = "What needs to be done?"
                MaxLength = 200
                Validators = @($script:Validators.Required)
            }
            
            New-Dropdown -Props @{
                Label = "Priority"
                Options = @(
                    @{ Value = "Critical"; Display = "!!! Critical" }
                    @{ Value = "High"; Display = "!! High" }
                    @{ Value = "Medium"; Display = "! Medium" }
                    @{ Value = "Low"; Display = "Low" }
                )
                Value = "Medium"
            }
            
            New-Dropdown -Props @{
                Label = "Project"
                Options = $projectOptions
                AllowSearch = $true
                Placeholder = "Select project (optional)"
            }
            
            New-DatePicker -Props @{
                Label = "Due Date"
                Value = $null
                MinDate = (Get-Date).Date
            }
            
            New-TextField -Props @{
                Label = "Tags"
                Placeholder = "Enter tags separated by commas"
                MaxLength = 100
            }
            
            New-TextField -Props @{
                Label = "Notes"
                Placeholder = "Additional notes (optional)"
                MaxLength = 500
                Height = 5  # Multi-line
            }
        )
        
        $script:TaskCreateScreen.State.Form = New-Form -Title "Create New Task" -Fields $fields -OnSubmit {
            param($Form, $Data)
            
            # Parse tags
            $tags = if ($Data.Tags) {
                @($Data.Tags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            } else {
                @()
            }
            
            # Create task
            $taskData = @{
                Description = $Data.'Task Description'
                Priority = $Data.Priority
                ProjectKey = if ($Data.Project) { $Data.Project } else { $null }
                DueDate = if ($Data.'Due Date') { $Data.'Due Date'.ToString("yyyy-MM-dd") } else { $null }
                Tags = $tags
                Notes = $Data.Notes
            }
            
            $task = Create-Task -TaskData $taskData
            
            Write-StatusLine -Text " Task created: $($task.Id)" -BackgroundColor (Get-ThemeColor "Success")
            Pop-Screen
        }
        
        # Focus first field
        & $script:TaskCreateScreen.State.Form.Focus -self $script:TaskCreateScreen.State.Form
    }
    
    Render = {
        Clear-BackBuffer
        
        # Render form
        $formWidth = 65
        $formHeight = 25
        $formX = ($script:TuiState.BufferWidth - $formWidth) / 2
        $formY = 2
        
        & $script:TaskCreateScreen.State.Form.Render `
            -self $script:TaskCreateScreen.State.Form `
            -X $formX -Y $formY -Width $formWidth -Height $formHeight
    }
    
    HandleInput = {
        param($Key)
        
        $result = & $script:TaskCreateScreen.State.Form.HandleInput `
            -self $script:TaskCreateScreen.State.Form -key $Key
        
        if ($result -eq "Cancel") {
            return "Back"
        }
        
        return $result
    }
}

#endregion

#region Helper Functions

function Confirm-Action {
    param($Message)
    
    Write-StatusLine -Text " $Message [Y/N]" -BackgroundColor (Get-ThemeColor "Warning")
    
    $key = $null
    while ($key -eq $null) {
        $key = Process-Input
        if ($key) {
            if ($key.KeyChar -eq 'y' -or $key.KeyChar -eq 'Y') {
                return $true
            } else {
                return $false
            }
        }
        Start-Sleep -Milliseconds 50
    }
}

function Get-TaskDetailScreen {
    param($TaskId)
    
    # Implementation for task detail screen
    # This would show full task details with edit capabilities
    return @{
        Name = "TaskDetail"
        State = @{ TaskId = $TaskId }
        Init = { }
        Render = {
            Write-BufferString -X 10 -Y 10 -Text "Task Detail Screen - $($State.TaskId)" `
                -ForegroundColor (Get-ThemeColor "Primary")
        }
        HandleInput = {
            param($Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
        }
    }
}

function Get-TaskEditScreen {
    param($TaskId)
    
    # Similar to create screen but pre-populated with task data
    # Implementation would follow same pattern as TaskCreateScreen
    return $script:TaskCreateScreen  # Placeholder
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Load-TaskData',
    'Apply-TaskFilters',
    'Get-TaskStats',
    'Create-Task',
    'Update-Task',
    'Delete-Task',
    'Complete-Task',
    'Toggle-TaskComplete',
    'Confirm-Action'
) -Variable @(
    'TaskManagementScreen',
    'TaskCreateScreen'
)
