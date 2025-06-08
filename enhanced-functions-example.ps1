# Core Functions Updated with Enhanced Selection
# Example implementations showing how to integrate the enhanced selection system

# Updated Time Management Functions

function global:Add-ManualTimeEntry-Enhanced {
    Write-Header "Manual Time Entry"
    
    # Project selection with visual interface
    $projectKeyInput = Select-ProjectOrTemplate -Title "Select Project/Template for Time Entry"
    if (-not $projectKeyInput) {
        Write-Info "Time entry cancelled."
        return
    }
    
    $project = Get-ProjectOrTemplate $projectKeyInput
    Write-Host "`nSelected: $($project.Name)" -ForegroundColor Green
    
    # Hours entry remains the same
    Write-Host "`nTime format examples: 2.5, 2:30, 2h30m, 150m" -ForegroundColor Gray
    $hoursInput = Read-Host "Hours worked"
    # ... rest of parsing logic
    
    # Date selection could be enhanced with calendar picker
    $dateOptions = @(
        [PSCustomObject]@{ Value = (Get-Date).ToString("yyyy-MM-dd"); Display = "Today - $((Get-Date).ToString('MMM dd, yyyy'))" }
        [PSCustomObject]@{ Value = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd"); Display = "Yesterday - $((Get-Date).AddDays(-1).ToString('MMM dd, yyyy'))" }
        [PSCustomObject]@{ Value = "custom"; Display = "Enter custom date..." }
    )
    
    # Add last 5 days as options
    for ($i = 2; $i -le 6; $i++) {
        $date = (Get-Date).AddDays(-$i)
        $dateOptions += [PSCustomObject]@{
            Value = $date.ToString("yyyy-MM-dd")
            Display = "$($date.ToString('dddd')) - $($date.ToString('MMM dd, yyyy'))"
        }
    }
    
    $selectedDate = Show-EnhancedSelection `
        -Items $dateOptions `
        -Title "Select Date for Time Entry" `
        -DisplayProperty "Display" `
        -ValueProperty "Value"
    
    if (-not $selectedDate) {
        Write-Info "Time entry cancelled."
        return
    }
    
    if ($selectedDate -eq "custom") {
        $selectedDate = Read-Host "Enter date (YYYY-MM-DD)"
        # Validate date...
    }
    
    # Description
    $description = Read-Host "`nDescription"
    
    # Task linking with visual selection
    if (Get-EnhancedConfirmation -Message "Link this time to a specific task?" -Title "Link to Task") {
        $taskId = Select-Task `
            -Title "Select Task to Link" `
            -ActiveOnly `
            -ProjectFilter $projectKeyInput
        
        if ($taskId) {
            $task = $script:Data.Tasks | Where-Object { $_.Id -eq $taskId }
            Write-Host "Linked to task: $($task.Description)" -ForegroundColor Green
        }
    }
    
    # Continue with rest of time entry creation...
}

function global:Start-Timer-Enhanced {
    param(
        [string]$ProjectKeyParam,
        [string]$TaskIdParam
    )
    
    Write-Header "Start Timer"
    
    # Check for existing timers with visual display
    if ($script:Data.ActiveTimers -and $script:Data.ActiveTimers.Count -gt 0) {
        Write-Warning "You have $($script:Data.ActiveTimers.Count) active timer(s):"
        
        $timerItems = @()
        foreach ($timer in $script:Data.ActiveTimers.GetEnumerator()) {
            $elapsed = (Get-Date) - [DateTime]$timer.Value.StartTime
            $project = Get-ProjectOrTemplate $timer.Value.ProjectKey
            $timerItems += [PSCustomObject]@{
                Key = $timer.Key
                Display = "$($project.Name) - Running for $($elapsed.ToString('hh\:mm\:ss'))"
                ProjectKey = $timer.Value.ProjectKey
                StartTime = $timer.Value.StartTime
            }
        }
        
        $options = @(
            [PSCustomObject]@{ Value = "stop"; Display = "Stop all timers and start new" }
            [PSCustomObject]@{ Value = "continue"; Display = "Keep running and start new" }
            [PSCustomObject]@{ Value = "cancel"; Display = "Cancel (don't start new timer)" }
        )
        
        $choice = Show-EnhancedSelection `
            -Items $options `
            -Title "Active Timers Found" `
            -DisplayProperty "Display" `
            -ValueProperty "Value"
        
        switch ($choice) {
            "stop" {
                foreach ($key in @($script:Data.ActiveTimers.Keys)) {
                    Stop-SingleTimer -Key $key -Silent
                }
                Save-UnifiedData
                Write-Success "All timers stopped."
            }
            "cancel" {
                Write-Info "Timer start cancelled."
                return
            }
        }
    }
    
    # Project selection
    $projectKey = $ProjectKeyParam
    if (-not $projectKey) {
        $projectKey = Select-ProjectOrTemplate -Title "Select Project/Template for Timer"
        if (-not $projectKey) {
            Write-Info "Timer start cancelled."
            return
        }
    }
    
    # Optional task linking
    $taskId = $TaskIdParam
    if (-not $taskId) {
        if (Get-EnhancedConfirmation -Message "Link timer to a specific task?" -Title "Task Linking" -DefaultNo) {
            $taskId = Select-Task `
                -Title "Select Task for Timer" `
                -ActiveOnly `
                -ProjectFilter $projectKey
        }
    }
    
    # Create timer with visual feedback
    $timerKey = [Guid]::NewGuid().ToString()
    $script:Data.ActiveTimers[$timerKey] = @{
        ProjectKey = $projectKey
        TaskId = $taskId
        StartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Description = ""
    }
    
    Save-UnifiedData
    
    $project = Get-ProjectOrTemplate $projectKey
    Write-Host ""
    Show-Notification -Message "Timer started for: $($project.Name)" -Type "Success" -Persist
}

# Updated Task Management Functions

function global:Show-TaskManagementMenu-Enhanced {
    $filterString = ""
    $sortByOption = "Smart"
    $showCompletedTasks = $false
    $viewModeOption = "Default"
    
    while ($true) {
        Clear-Host
        Write-Header "Task Management"
        
        # Show current tasks
        Show-TasksView -Filter $filterString -SortBy $sortByOption -ShowCompleted:$showCompletedTasks -View $viewModeOption
        
        # Enhanced menu options
        $menuItems = @(
            @{ Key = "A"; Label = "Add New Task"; Action = { Add-TodoTask } }
            @{ Key = "Q"; Label = "Quick Add Task"; Action = { 
                $input = Read-Host "Quick add (e.g., 'Task #category @tag !High due:tomorrow')"
                if ($input) { Quick-AddTask -InputString $input }
            }}
            @{ Key = "C"; Label = "Complete Task"; Action = { Complete-Task-Enhanced } }
            @{ Key = "E"; Label = "Edit Task"; Action = { Edit-Task-Enhanced } }
            @{ Key = "D"; Label = "Delete Task"; Action = { Remove-Task-Enhanced } }
            @{ Key = "P"; Label = "Update Progress"; Action = { Update-TaskProgress-Enhanced } }
            @{ Key = "S"; Label = "Manage Subtasks"; Action = { Manage-Subtasks-Enhanced } }
            @{ Key = "F"; Label = "Filter Tasks"; Action = {
                $script:TempFilter = Read-Host "Filter (empty to clear)"
                if ($script:TempFilter -eq "") { $script:TempFilter = $null }
            }}
            @{ Key = "O"; Label = "Sort Options"; Action = { Select-SortOption } }
            @{ Key = "V"; Label = "Change View"; Action = { Select-ViewMode } }
            @{ Key = "T"; Label = "Toggle Completed"; Action = { $script:TempShowCompleted = -not $showCompletedTasks } }
        )
        
        $result = Show-EnhancedMenu `
            -Title "Task Management Options" `
            -MenuItems $menuItems `
            -BackLabel "Back to Dashboard"
        
        # Handle filter/sort/view changes
        if ($null -ne $script:TempFilter) { 
            $filterString = $script:TempFilter
            $script:TempFilter = $null
        }
        if ($script:TempSortBy) { 
            $sortByOption = $script:TempSortBy
            $script:TempSortBy = $null
        }
        if ($script:TempViewMode) {
            $viewModeOption = $script:TempViewMode
            $script:TempViewMode = $null
        }
        if ($null -ne $script:TempShowCompleted) {
            $showCompletedTasks = $script:TempShowCompleted
            $script:TempShowCompleted = $null
        }
        
        if ($result) { return } # Back was selected
    }
}

function global:Complete-Task-Enhanced {
    $taskId = Select-Task `
        -Title "Select Task to Complete" `
        -ActiveOnly
    
    if (-not $taskId) {
        Write-Info "Cancelled."
        return
    }
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $taskId }
    
    # Show task details before completing
    Clear-Host
    Write-Header "Complete Task"
    Write-Host "Task: " -NoNewline
    Write-Host $task.Description -ForegroundColor Yellow
    
    if ($task.Subtasks -and ($task.Subtasks | Where-Object { -not $_.Completed }).Count -gt 0) {
        $uncompletedCount = ($task.Subtasks | Where-Object { -not $_.Completed }).Count
        Write-Warning "`nTask has $uncompletedCount uncompleted subtask(s):"
        foreach ($subtask in $task.Subtasks | Where-Object { -not $_.Completed }) {
            Write-Host "  ○ $($subtask.Description)" -ForegroundColor Gray
        }
    }
    
    if (Get-EnhancedConfirmation -Message "`nComplete this task?" -Title "Confirm Completion") {
        $task.Completed = $true
        $task.Progress = 100
        $task.CompletedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $task.LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        
        if ($task.ProjectKey) {
            Update-ProjectStatistics -ProjectKey $task.ProjectKey
        }
        
        Save-UnifiedData
        Show-Notification -Message "Task completed: $($task.Description)" -Type "Success"
    } else {
        Write-Info "Task completion cancelled."
    }
}

function global:Edit-Task-Enhanced {
    $taskId = Select-Task `
        -Title "Select Task to Edit" `
        -IncludeCompleted
    
    if (-not $taskId) {
        Write-Info "Cancelled."
        return
    }
    
    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $taskId }
    
    while ($true) {
        Clear-Host
        Write-Header "Edit Task"
        
        # Show current task details
        Write-Host "Current Task Details:" -ForegroundColor Yellow
        Write-Host "  Description: $($task.Description)"
        Write-Host "  Priority: $($task.Priority)"
        Write-Host "  Category: $($task.Category)"
        Write-Host "  Project: $(if ($task.ProjectKey) { (Get-ProjectOrTemplate $task.ProjectKey).Name } else { 'None' })"
        Write-Host "  Due Date: $(if ($task.DueDate) { Format-TodoDate $task.DueDate } else { 'None' })"
        Write-Host "  Progress: $($task.Progress)%"
        Write-Host "  Tags: $(if ($task.Tags -and $task.Tags.Count -gt 0) { $task.Tags -join ', ' } else { 'None' })"
        
        $editOptions = @(
            @{ Key = "1"; Label = "Edit Description"; Action = {
                $new = Read-Host "`nNew description (empty to keep current)"
                if ($new) { $task.Description = $new }
            }}
            @{ Key = "2"; Label = "Change Priority"; Action = {
                $priorities = @("Critical", "High", "Medium", "Low")
                $selected = Show-EnhancedSelection -Items $priorities -Title "Select Priority"
                if ($selected) { $task.Priority = $selected }
            }}
            @{ Key = "3"; Label = "Change Category"; Action = {
                $new = Read-Host "`nNew category"
                if ($new) { $task.Category = $new }
            }}
            @{ Key = "4"; Label = "Change Project"; Action = {
                $selected = Select-ProjectOrTemplate -Title "Select Project" -IncludeNone
                if ($null -ne $selected) { $task.ProjectKey = $selected }
            }}
            @{ Key = "5"; Label = "Set Due Date"; Action = {
                # Could be enhanced with date picker
                $new = Read-Host "`nDue date (YYYY-MM-DD, 'today', '+X', or 'clear')"
                if ($new -eq 'clear') { $task.DueDate = $null }
                elseif ($new) { 
                    # Parse date logic here
                    $task.DueDate = $new 
                }
            }}
            @{ Key = "6"; Label = "Update Progress"; Action = {
                $new = Read-Host "`nProgress percentage (0-100)"
                if ($new -match '^\d+$') {
                    $percent = [int]$new
                    if ($percent -ge 0 -and $percent -le 100) {
                        $task.Progress = $percent
                        if ($percent -eq 100 -and -not $task.Completed) {
                            if (Get-EnhancedConfirmation -Message "Mark task as completed?") {
                                $task.Completed = $true
                                $task.CompletedDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            }
                        }
                    }
                }
            }}
            @{ Key = "7"; Label = "Edit Tags"; Action = {
                $current = if ($task.Tags) { $task.Tags -join ', ' } else { '' }
                $new = Read-Host "`nTags (comma-separated, current: $current)"
                if ($new -eq 'clear') { $task.Tags = @() }
                elseif ($new) { 
                    $task.Tags = $new -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                }
            }}
        )
        
        $result = Show-EnhancedMenu `
            -Title "Select Field to Edit" `
            -MenuItems $editOptions `
            -BackLabel "Done Editing"
        
        $task.LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Save-UnifiedData
        
        if ($result) { 
            Write-Success "Task updated successfully!"
            Start-Sleep -Seconds 1
            return 
        }
    }
}

function global:Select-SortOption {
    $sortOptions = @(
        [PSCustomObject]@{ Value = "Smart"; Display = "Smart Sort (Status, Priority, Due Date)" }
        [PSCustomObject]@{ Value = "Priority"; Display = "Priority (Critical → Low)" }
        [PSCustomObject]@{ Value = "DueDate"; Display = "Due Date (Earliest → Latest)" }
        [PSCustomObject]@{ Value = "Created"; Display = "Created Date (Newest → Oldest)" }
        [PSCustomObject]@{ Value = "Category"; Display = "Category (A → Z)" }
        [PSCustomObject]@{ Value = "Project"; Display = "Project (Grouped)" }
    )
    
    $selected = Show-EnhancedSelection `
        -Items $sortOptions `
        -Title "Select Sort Order" `
        -DisplayProperty "Display" `
        -ValueProperty "Value"
    
    if ($selected) {
        $script:TempSortBy = $selected
    }
}

function global:Select-ViewMode {
    $viewOptions = @(
        [PSCustomObject]@{ Value = "Default"; Display = "Default List View" }
        [PSCustomObject]@{ Value = "Kanban"; Display = "Kanban Board" }
        [PSCustomObject]@{ Value = "Timeline"; Display = "Timeline View" }
        [PSCustomObject]@{ Value = "Project"; Display = "Project Grouped View" }
    )
    
    $selected = Show-EnhancedSelection `
        -Items $viewOptions `
        -Title "Select View Mode" `
        -DisplayProperty "Display" `
        -ValueProperty "Value"
    
    if ($selected) {
        $script:TempViewMode = $selected
    }
}

# Test function to demonstrate the enhanced selection
function Test-EnhancedSelection {
    Write-Host "`nTesting Enhanced Selection System..." -ForegroundColor Green
    
    # Test 1: Simple list
    Write-Host "`n1. Testing simple list selection:"
    $fruits = @("Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape")
    $selected = Show-EnhancedSelection -Items $fruits -Title "Select a Fruit"
    Write-Host "You selected: $selected" -ForegroundColor Yellow
    
    # Test 2: Project selection
    Write-Host "`n2. Testing project selection:"
    $project = Select-ProjectOrTemplate -Title "Test Project Selection"
    if ($project) {
        Write-Host "You selected project: $project" -ForegroundColor Yellow
    }
    
    # Test 3: Multi-select
    Write-Host "`n3. Testing multi-select:"
    $colors = @("Red", "Green", "Blue", "Yellow", "Orange", "Purple", "Pink")
    $selected = Show-EnhancedSelection -Items $colors -Title "Select Multiple Colors" -AllowMultiple
    Write-Host "You selected: $($selected -join ', ')" -ForegroundColor Yellow
    
    # Test 4: Confirmation
    Write-Host "`n4. Testing confirmation:"
    $result = Get-EnhancedConfirmation -Message "Do you like the enhanced selection?" -Title "Feedback"
    Write-Host "You answered: $(if ($result) { 'Yes' } else { 'No' })" -ForegroundColor Yellow
    
    Write-Host "`nTest complete!" -ForegroundColor Green
}

Write-Host "`nEnhanced function examples loaded. Run Test-EnhancedSelection to see demos." -ForegroundColor Cyan
