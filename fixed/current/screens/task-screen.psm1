# Task Management Screen - Enhanced Version
# Full CRUD task management with consistent navigation and improved UX

function global:Get-TaskManagementScreen {
    
    $taskScreen = Create-TuiScreen -Definition @{
        Name = "TaskScreen"
        State = @{
            tasks = @()
            selectedIndex = 0
            filter = "all"
            sortBy = "priority"
            categories = @("Work", "Personal", "Urgent", "Projects")
            showingForm = $false
            editingTaskId = $null
            formData = @{}
            activePanel = "list"  # list, form, help
            showHelp = $false
        }
        
        Init = {
            param($self)
            
            # Initialize sample tasks
            $sampleTasks = @(
                @{
                    Id = [Guid]::NewGuid().ToString()
                    Title = "Review documentation"
                    Description = "Go through TUI framework docs and identify gaps"
                    Category = "Work"
                    Priority = "High"
                    Status = "Active"
                    DueDate = (Get-Date).AddDays(2)
                    Created = (Get-Date).AddDays(-3)
                    Completed = $null
                }
                @{
                    Id = [Guid]::NewGuid().ToString()
                    Title = "Fix memory leaks"
                    Description = "Address critical memory leak issues in event system"
                    Category = "Urgent"
                    Priority = "Critical"
                    Status = "Active"
                    DueDate = (Get-Date).AddDays(1)
                    Created = (Get-Date).AddDays(-1)
                    Completed = $null
                }
                @{
                    Id = [Guid]::NewGuid().ToString()
                    Title = "Add clipboard support"
                    Description = "Implement Ctrl+C/V in text components"
                    Category = "Projects"
                    Priority = "Medium"
                    Status = "Completed"
                    DueDate = (Get-Date).AddDays(-1)
                    Created = (Get-Date).AddDays(-7)
                    Completed = (Get-Date).AddDays(-1)
                }
            )
            
            $self.State.tasks = $sampleTasks
            
            # Methods
            $self.GetFilteredTasks = {
                $tasks = $self.State.tasks
                $filter = $self.State.filter
                
                # Apply filter
                $filtered = switch ($filter) {
                    "active" { $tasks | Where-Object { $_.Status -eq "Active" } }
                    "completed" { $tasks | Where-Object { $_.Status -eq "Completed" } }
                    default { $tasks }
                }
                
                # Apply sort
                $sorted = switch ($self.State.sortBy) {
                    "priority" { 
                        $filtered | Sort-Object @{
                            Expression = {
                                switch ($_.Priority) {
                                    "Critical" { 0 }
                                    "High" { 1 }
                                    "Medium" { 2 }
                                    "Low" { 3 }
                                }
                            }
                        }, Created
                    }
                    "dueDate" { $filtered | Sort-Object DueDate, Priority }
                    "created" { $filtered | Sort-Object Created -Descending }
                    default { $filtered }
                }
                
                return @($sorted)
            }
            
            $self.ShowAddTaskForm = {
                $self.State.showingForm = $true
                $self.State.editingTaskId = $null
                $self.State.activePanel = "form"
                $self.State.formData = @{
                    title = ""
                    description = ""
                    category = "Work"
                    priority = "Medium"
                    dueDate = (Get-Date).AddDays(7).ToString("yyyy-MM-dd")
                }
                Request-TuiRefresh
            }
            
            $self.ShowEditTaskForm = {
                param($task)
                $self.State.showingForm = $true
                $self.State.editingTaskId = $task.Id
                $self.State.activePanel = "form"
                $self.State.formData = @{
                    title = $task.Title
                    description = $task.Description
                    category = $task.Category
                    priority = $task.Priority
                    dueDate = $task.DueDate.ToString("yyyy-MM-dd")
                }
                Request-TuiRefresh
            }
            
            $self.SaveTask = {
                $formData = $self.State.formData
                $editingId = $self.State.editingTaskId
                
                if ($editingId) {
                    # Update existing
                    $task = $self.State.tasks | Where-Object { $_.Id -eq $editingId }
                    if ($task) {
                        $task.Title = $formData.title
                        $task.Description = $formData.description
                        $task.Category = $formData.category
                        $task.Priority = $formData.priority
                        $task.DueDate = [DateTime]::Parse($formData.dueDate)
                    }
                } else {
                    # Add new
                    $newTask = @{
                        Id = [Guid]::NewGuid().ToString()
                        Title = $formData.title
                        Description = $formData.description
                        Category = $formData.category
                        Priority = $formData.priority
                        Status = "Active"
                        DueDate = [DateTime]::Parse($formData.dueDate)
                        Created = Get-Date
                        Completed = $null
                    }
                    $self.State.tasks += $newTask
                }
                
                $self.State.showingForm = $false
                $self.State.activePanel = "list"
                Request-TuiRefresh
            }
            
            $self.DeleteTask = {
                param($taskId)
                $self.State.tasks = @($self.State.tasks | Where-Object { $_.Id -ne $taskId })
                if ($self.State.selectedIndex -ge $self.State.tasks.Count -and $self.State.selectedIndex -gt 0) {
                    $self.State.selectedIndex--
                }
                Request-TuiRefresh
            }
            
            $self.ToggleTaskStatus = {
                param($taskId)
                $task = $self.State.tasks | Where-Object { $_.Id -eq $taskId }
                if ($task) {
                    if ($task.Status -eq "Active") {
                        $task.Status = "Completed"
                        $task.Completed = Get-Date
                    } else {
                        $task.Status = "Active"
                        $task.Completed = $null
                    }
                }
                Request-TuiRefresh
            }
        }
        
        Render = {
            param($self)
            
            # Header
            $headerColor = Get-ThemeColor "Header" -Default "Cyan"
            Write-BufferString -X 2 -Y 1 -Text "Task Management" -ForegroundColor $headerColor
            
            # Filter/Sort toolbar
            $toolbarY = 3
            Write-BufferString -X 2 -Y $toolbarY -Text "Filter: " -ForegroundColor "Gray"
            $filterOptions = @("All", "Active", "Completed")
            $filterX = 10
            foreach ($option in $filterOptions) {
                $isSelected = ($option.ToLower() -eq $self.State.filter)
                $color = if ($isSelected) { "Yellow" } else { "White" }
                Write-BufferString -X $filterX -Y $toolbarY -Text "[$option]" -ForegroundColor $color
                $filterX += $option.Length + 4
            }
            
            Write-BufferString -X 40 -Y $toolbarY -Text "Sort: " -ForegroundColor "Gray"
            $sortOptions = @(@{Display="Priority"; Value="priority"}, @{Display="Due Date"; Value="dueDate"}, @{Display="Created"; Value="created"})
            $sortX = 46
            foreach ($option in $sortOptions) {
                $isSelected = ($option.Value -eq $self.State.sortBy)
                $color = if ($isSelected) { "Yellow" } else { "White" }
                Write-BufferString -X $sortX -Y $sortY -Text "[$($option.Display)]" -ForegroundColor $color
                $sortX += $option.Display.Length + 4
            }
            
            # Main content area
            if ($self.State.showingForm) {
                # Show form
                $self.RenderTaskForm.Invoke($self)
            } else {
                # Show task list
                $self.RenderTaskList.Invoke($self)
                
                # Help panel
                if ($self.State.showHelp) {
                    $self.RenderHelpPanel.Invoke($self)
                }
            }
            
            # Status bar
            $statusY = $global:TuiState.BufferHeight - 2
            $statusText = if ($self.State.showingForm) {
                "Tab: Next Field • Enter: Save • Esc: Cancel"
            } elseif ($self.State.showHelp) {
                "Esc/H: Close Help"
            } else {
                "↑↓: Navigate • Space: Toggle • N: New • E: Edit • D: Delete • H: Help • Q: Back"
            }
            Write-BufferString -X 2 -Y $statusY -Text $statusText -ForegroundColor "Gray"
        }
        
        RenderTaskList = {
            param($self)
            
            $tasks = & $self.GetFilteredTasks
            $listY = 5
            $listHeight = $global:TuiState.BufferHeight - 8
            
            # Task list header
            Write-BufferBox -X 2 -Y $listY -Width 76 -Height $listHeight -Title " Tasks " -BorderColor "Cyan"
            
            # Column headers
            $headerY = $listY + 1
            Write-BufferString -X 4 -Y $headerY -Text "Status" -ForegroundColor "Gray"
            Write-BufferString -X 12 -Y $headerY -Text "Priority" -ForegroundColor "Gray"
            Write-BufferString -X 23 -Y $headerY -Text "Title" -ForegroundColor "Gray"
            Write-BufferString -X 54 -Y $headerY -Text "Category" -ForegroundColor "Gray"
            Write-BufferString -X 66 -Y $headerY -Text "Due Date" -ForegroundColor "Gray"
            
            # Divider
            Write-BufferString -X 3 -Y ($headerY + 1) -Text ("─" * 74) -ForegroundColor "DarkGray"
            
            # Tasks
            if ($tasks.Count -eq 0) {
                Write-BufferString -X 4 -Y ($headerY + 3) -Text "No tasks found. Press 'N' to add a new task." -ForegroundColor "Gray"
            } else {
                $startY = $headerY + 2
                $visibleTasks = [Math]::Min($tasks.Count, $listHeight - 4)
                
                for ($i = 0; $i -lt $visibleTasks; $i++) {
                    $task = $tasks[$i]
                    $y = $startY + $i
                    $isSelected = ($i -eq $self.State.selectedIndex)
                    
                    # Selection indicator
                    if ($isSelected) {
                        Write-BufferString -X 3 -Y $y -Text "→" -ForegroundColor "Yellow"
                    }
                    
                    # Status
                    $status = if ($task.Status -eq "Completed") { "[X]" } else { "[ ]" }
                    $statusColor = if ($task.Status -eq "Completed") { "DarkGray" } else { "White" }
                    Write-BufferString -X 4 -Y $y -Text $status -ForegroundColor $statusColor
                    
                    # Priority
                    $priorityColor = switch ($task.Priority) {
                        "Critical" { "Red" }
                        "High" { "Yellow" }
                        "Medium" { "Cyan" }
                        "Low" { "Gray" }
                    }
                    Write-BufferString -X 12 -Y $y -Text $task.Priority.PadRight(10) -ForegroundColor $priorityColor
                    
                    # Title
                    $titleColor = if ($task.Status -eq "Completed") { "DarkGray" } else { "White" }
                    $title = if ($task.Title.Length -gt 30) { $task.Title.Substring(0, 27) + "..." } else { $task.Title }
                    Write-BufferString -X 23 -Y $y -Text $title.PadRight(30) -ForegroundColor $titleColor
                    
                    # Category
                    Write-BufferString -X 54 -Y $y -Text $task.Category.PadRight(11) -ForegroundColor $titleColor
                    
                    # Due Date
                    if ($task.DueDate) {
                        $daysUntil = ($task.DueDate.Date - (Get-Date).Date).Days
                        $dateColor = if ($daysUntil -lt 0) { "Red" }
                                   elseif ($daysUntil -eq 0) { "Yellow" }
                                   else { $titleColor }
                        Write-BufferString -X 66 -Y $y -Text $task.DueDate.ToString("MM/dd/yy") -ForegroundColor $dateColor
                    }
                }
            }
        }
        
        RenderTaskForm = {
            param($self)
            
            $formWidth = 60
            $formHeight = 16
            $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            $formY = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)
            
            # Form background
            for ($y = $formY; $y -lt ($formY + $formHeight); $y++) {
                for ($x = $formX; $x -lt ($formX + $formWidth); $x++) {
                    Write-BufferString -X $x -Y $y -Text " " -BackgroundColor "DarkGray"
                }
            }
            
            $title = if ($self.State.editingTaskId) { "Edit Task" } else { "New Task" }
            Write-BufferBox -X $formX -Y $formY -Width $formWidth -Height $formHeight -Title " $title " -BorderColor "Yellow"
            
            $fieldY = $formY + 2
            $fieldX = $formX + 3
            
            # Title field
            Write-BufferString -X $fieldX -Y $fieldY -Text "Title:" -ForegroundColor "White"
            Write-BufferBox -X $fieldX -Y ($fieldY + 1) -Width 54 -Height 3 -BorderColor "Gray"
            Write-BufferString -X ($fieldX + 2) -Y ($fieldY + 2) -Text $self.State.formData.title
            
            # Description field
            $fieldY += 4
            Write-BufferString -X $fieldX -Y $fieldY -Text "Description:" -ForegroundColor "White"
            Write-BufferBox -X $fieldX -Y ($fieldY + 1) -Width 54 -Height 3 -BorderColor "Gray"
            Write-BufferString -X ($fieldX + 2) -Y ($fieldY + 2) -Text $self.State.formData.description
            
            # Category and Priority
            $fieldY += 4
            Write-BufferString -X $fieldX -Y $fieldY -Text "Category:" -ForegroundColor "White"
            Write-BufferString -X ($fieldX + 10) -Y $fieldY -Text "[$($self.State.formData.category)]" -ForegroundColor "Cyan"
            
            Write-BufferString -X ($fieldX + 28) -Y $fieldY -Text "Priority:" -ForegroundColor "White"
            Write-BufferString -X ($fieldX + 38) -Y $fieldY -Text "[$($self.State.formData.priority)]" -ForegroundColor "Cyan"
            
            # Due Date
            $fieldY += 2
            Write-BufferString -X $fieldX -Y $fieldY -Text "Due Date (yyyy-MM-dd):" -ForegroundColor "White"
            Write-BufferString -X ($fieldX + 24) -Y $fieldY -Text $self.State.formData.dueDate -ForegroundColor "Cyan"
        }
        
        RenderHelpPanel = {
            param($self)
            
            $helpWidth = 40
            $helpHeight = 20
            $helpX = $global:TuiState.BufferWidth - $helpWidth - 2
            $helpY = 5
            
            # Help background
            for ($y = $helpY; $y -lt ($helpY + $helpHeight); $y++) {
                for ($x = $helpX; $x -lt ($helpX + $helpWidth); $x++) {
                    Write-BufferString -X $x -Y $y -Text " " -BackgroundColor "DarkBlue"
                }
            }
            
            Write-BufferBox -X $helpX -Y $helpY -Width $helpWidth -Height $helpHeight -Title " Help " -BorderColor "Yellow"
            
            $commands = @(
                @{ Key = "↑/↓"; Description = "Navigate tasks" }
                @{ Key = "Space"; Description = "Toggle task completion" }
                @{ Key = "N"; Description = "Add new task" }
                @{ Key = "E"; Description = "Edit selected task" }
                @{ Key = "D"; Description = "Delete selected task" }
                @{ Key = "1-3"; Description = "Change filter (All/Active/Done)" }
                @{ Key = "P"; Description = "Sort by priority" }
                @{ Key = "U"; Description = "Sort by due date" }
                @{ Key = "C"; Description = "Sort by created date" }
                @{ Key = "H"; Description = "Toggle this help" }
                @{ Key = "Q/Esc"; Description = "Go back" }
            )
            
            $cmdY = $helpY + 2
            foreach ($cmd in $commands) {
                Write-BufferString -X ($helpX + 2) -Y $cmdY -Text $cmd.Key -ForegroundColor "Yellow"
                Write-BufferString -X ($helpX + 10) -Y $cmdY -Text $cmd.Description -ForegroundColor "White"
                $cmdY++
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            if ($self.State.showingForm) {
                # Handle form input
                switch ($Key.Key) {
                    ([ConsoleKey]::Escape) {
                        $self.State.showingForm = $false
                        $self.State.activePanel = "list"
                        Request-TuiRefresh
                        return $true
                    }
                    ([ConsoleKey]::Enter) {
                        & $self.SaveTask
                        return $true
                    }
                    # Simplified form handling for now
                }
                return $false
            }
            
            # Handle list navigation
            $tasks = & $self.GetFilteredTasks
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.selectedIndex -gt 0) {
                        $self.State.selectedIndex--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.State.selectedIndex -lt ($tasks.Count - 1)) {
                        $self.State.selectedIndex++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    if ($tasks.Count -gt 0) {
                        $task = $tasks[$self.State.selectedIndex]
                        & $self.ToggleTaskStatus -taskId $task.Id
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($tasks.Count -gt 0) {
                        $task = $tasks[$self.State.selectedIndex]
                        & $self.ShowEditTaskForm -task $task
                    }
                    return $true
                }
                ([ConsoleKey]::H) {
                    $self.State.showHelp = -not $self.State.showHelp
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Q) { return "Back" }
                ([ConsoleKey]::Escape) {
                    if ($self.State.showHelp) {
                        $self.State.showHelp = $false
                        Request-TuiRefresh
                        return $true
                    }
                    return "Back"
                }
            }
            
            # Handle key characters
            if ($Key.KeyChar) {
                switch ($Key.KeyChar.ToString().ToUpper()) {
                    'N' {
                        & $self.ShowAddTaskForm
                        return $true
                    }
                    'E' {
                        if ($tasks.Count -gt 0) {
                            $task = $tasks[$self.State.selectedIndex]
                            & $self.ShowEditTaskForm -task $task
                        }
                        return $true
                    }
                    'D' {
                        if ($tasks.Count -gt 0) {
                            $task = $tasks[$self.State.selectedIndex]
                            & $self.DeleteTask -taskId $task.Id
                        }
                        return $true
                    }
                    '1' {
                        $self.State.filter = "all"
                        $self.State.selectedIndex = 0
                        Request-TuiRefresh
                        return $true
                    }
                    '2' {
                        $self.State.filter = "active"
                        $self.State.selectedIndex = 0
                        Request-TuiRefresh
                        return $true
                    }
                    '3' {
                        $self.State.filter = "completed"
                        $self.State.selectedIndex = 0
                        Request-TuiRefresh
                        return $true
                    }
                    'P' {
                        $self.State.sortBy = "priority"
                        Request-TuiRefresh
                        return $true
                    }
                    'U' {
                        $self.State.sortBy = "dueDate"
                        Request-TuiRefresh
                        return $true
                    }
                    'C' {
                        $self.State.sortBy = "created"
                        Request-TuiRefresh
                        return $true
                    }
                }
            }
            
            return $false
        }
    }
    
    return $taskScreen
}

Export-ModuleMember -Function Get-TaskManagementScreen
