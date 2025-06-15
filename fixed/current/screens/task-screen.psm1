# Task Management Screen - COMPLIANT VERSION
# Using programmatic pattern with DataTable component

function global:Get-TaskManagementScreen {
    $screen = @{
        Name = "TaskScreen"
        
        # 1. State: Central data model for the screen
        State = @{
            tasks = @()
            filter = "all"
            sortBy = "priority"
            categories = @("Work", "Personal", "Urgent", "Projects")
            showingForm = $false
            editingTaskId = $null
            formData = @{}
            showHelp = $false
        }
        
        # 2. Components: Storage for instantiated component objects
        Components = @{}
        
        # Focus management
        FocusedComponentName = 'taskTable'
        
        # Define helper methods directly on the screen
        GetFilteredTasks = {
            param($screen)
            $tasks = $screen.State.tasks
            $filter = $screen.State.filter
            
            # Apply filter
            $filtered = switch ($filter) {
                "active" { $tasks | Where-Object { $_.Status -eq "Active" } }
                "completed" { $tasks | Where-Object { $_.Status -eq "Completed" } }
                default { $tasks }
            }
            
            # Apply sort
            $sorted = switch ($screen.State.sortBy) {
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
            
            # Transform for table display
            return @($sorted | ForEach-Object {
                @{
                    Id = $_.Id
                    Status = if ($_.Status -eq "Completed") { "X" } else { " " }
                    Priority = $_.Priority
                    Title = if ($_.Title.Length -gt 30) { $_.Title.Substring(0, 27) + "..." } else { $_.Title }
                    Category = $_.Category
                    DueDate = $_.DueDate
                }
            })
        }
        
        RefreshTaskTable = {
            param($screen)
            $tableData = & $screen.GetFilteredTasks -screen $screen
            $screen.Components.taskTable.Data = $tableData
            # Force process data to refresh the display
            if ($screen.Components.taskTable.ProcessData) {
                & $screen.Components.taskTable.ProcessData -self $screen.Components.taskTable
            }
            Request-TuiRefresh
        }
        
        ShowAddTaskForm = {
            param($screen)
            $screen.State.showingForm = $true
            $screen.State.editingTaskId = $null
            $screen.State.formData = @{
                title = ""
                description = ""
                category = "Work"
                priority = "Medium"
                dueDate = (Get-Date).AddDays(7).ToString("MM/dd/yy")
            }
            
            # Update form components
            $screen.Components.formTitle.Text = ""
            $screen.Components.formDescription.Text = ""
            $screen.Components.formCategory.Value = "Work"
            $screen.Components.formPriority.Value = "Medium"
            $screen.Components.formDueDate.Value = (Get-Date).AddDays(7)
            
            # Show form components
            foreach ($comp in @('formTitle', 'formDescription', 'formCategory', 'formPriority', 'formDueDate', 'formSaveButton', 'formCancelButton')) {
                $screen.Components[$comp].Visible = $true
            }
            
            # Hide table
            $screen.Components.taskTable.Visible = $false
            
            # Focus first field
            $screen.FocusedComponentName = 'formTitle'
            Request-TuiRefresh
        }
        
        ShowEditTaskForm = {
            param($screen, $taskId)
            $task = $screen.State.tasks | Where-Object { $_.Id -eq $taskId }
            if (-not $task) { return }
            
            $screen.State.showingForm = $true
            $screen.State.editingTaskId = $task.Id
            $screen.State.formData = @{
                title = $task.Title
                description = $task.Description
                category = $task.Category
                priority = $task.Priority
                dueDate = $task.DueDate
            }
            
            # Update form components
            $screen.Components.formTitle.Text = $task.Title
            $screen.Components.formDescription.Text = $task.Description
            $screen.Components.formCategory.Value = $task.Category
            $screen.Components.formPriority.Value = $task.Priority
            $screen.Components.formDueDate.Value = [DateTime]::Parse($task.DueDate)
            
            # Show form components
            foreach ($comp in @('formTitle', 'formDescription', 'formCategory', 'formPriority', 'formDueDate', 'formSaveButton', 'formCancelButton')) {
                $screen.Components[$comp].Visible = $true
            }
            
            # Hide table
            $screen.Components.taskTable.Visible = $false
            
            # Focus first field
            $screen.FocusedComponentName = 'formTitle'
            Request-TuiRefresh
        }
        
        SaveTask = {
            param($screen)
            $formData = $screen.State.formData
            $editingId = $screen.State.editingTaskId
            
            if ($editingId) {
                # Update existing
                $task = $screen.State.tasks | Where-Object { $_.Id -eq $editingId }
                if ($task) {
                    $task.Title = $formData.title
                    $task.Description = $formData.description
                    $task.Category = $formData.category
                    $task.Priority = $formData.priority
                    $task.DueDate = $formData.dueDate
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
                    DueDate = $formData.dueDate
                    Created = Get-Date
                    Completed = $null
                }
                $screen.State.tasks += $newTask
            }
            
            & $screen.HideForm -screen $screen
            & $screen.RefreshTaskTable -screen $screen
        }
        
        HideForm = {
            param($screen)
            $screen.State.showingForm = $false
            
            # Hide form components
            foreach ($comp in @('formTitle', 'formDescription', 'formCategory', 'formPriority', 'formDueDate', 'formSaveButton', 'formCancelButton')) {
                $screen.Components[$comp].Visible = $false
            }
            
            # Show table
            $screen.Components.taskTable.Visible = $true
            $screen.FocusedComponentName = 'taskTable'
            Request-TuiRefresh
        }
        
        DeleteTask = {
            param($screen)
            $selectedRow = $screen.Components.taskTable.SelectedRow
            if ($selectedRow -ge 0 -and $selectedRow -lt $screen.Components.taskTable.ProcessedData.Count) {
                $taskData = $screen.Components.taskTable.ProcessedData[$selectedRow]
                $screen.State.tasks = @($screen.State.tasks | Where-Object { $_.Id -ne $taskData.Id })
                & $screen.RefreshTaskTable -screen $screen
            }
        }
        
        ToggleTaskStatus = {
            param($screen)
            $selectedRow = $screen.Components.taskTable.SelectedRow
            if ($selectedRow -ge 0 -and $selectedRow -lt $screen.Components.taskTable.ProcessedData.Count) {
                $taskData = $screen.Components.taskTable.ProcessedData[$selectedRow]
                $task = $screen.State.tasks | Where-Object { $_.Id -eq $taskData.Id }
                if ($task) {
                    if ($task.Status -eq "Active") {
                        $task.Status = "Completed"
                        $task.Completed = Get-Date
                    } else {
                        $task.Status = "Active"
                        $task.Completed = $null
                    }
                    & $screen.RefreshTaskTable -screen $screen
                }
            }
        }
        
        # 3. Init: One-time setup
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
                    DueDate = (Get-Date).AddDays(2).ToString("MM/dd/yy")
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
                    DueDate = (Get-Date).AddDays(1).ToString("MM/dd/yy")
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
                    DueDate = (Get-Date).AddDays(-1).ToString("MM/dd/yy")
                    Created = (Get-Date).AddDays(-7)
                    Completed = (Get-Date).AddDays(-1)
                }
            )
            
            $self.State.tasks = $sampleTasks
            
            # Create main task table
            $tableScreen = $self  # Capture reference for closure
            $self.Components.taskTable = New-TuiDataTable -Props @{
                X = 2; Y = 5; Width = 76; Height = 20
                Columns = @(
                    @{ Name = "Status"; Header = "✓"; Width = 3 }
                    @{ Name = "Priority"; Header = "Priority"; Width = 10 }
                    @{ Name = "Title"; Header = "Title"; Width = 30 }
                    @{ Name = "Category"; Header = "Category"; Width = 11 }
                    @{ Name = "DueDate"; Header = "Due Date"; Width = 10 }
                )
                Data = & $self.GetFilteredTasks -screen $self
                AllowSort = $false  # We handle sorting ourselves
                AllowFilter = $false
                MultiSelect = $false
                Title = "Tasks"
                OnRowSelect = {
                    param($SelectedData, $SelectedIndex)
                    # Toggle task status on Enter
                    $task = $tableScreen.State.tasks | Where-Object { $_.Id -eq $SelectedData.Id }
                    if ($task) {
                        if ($task.Status -eq "Active") {
                            $task.Status = "Completed"
                            $task.Completed = Get-Date
                        } else {
                            $task.Status = "Active"
                            $task.Completed = $null
                        }
                        & $tableScreen.RefreshTaskTable -screen $tableScreen
                    }
                }
            }
            
            # Force process data to ensure display
            if ($self.Components.taskTable.ProcessData) {
                & $self.Components.taskTable.ProcessData -self $self.Components.taskTable
            }
            
            # Form components (hidden by default)
            $formScreen = $self  # Capture reference for closures
            $self.Components.formTitle = New-TuiTextBox -Props @{
                X = 25; Y = 10; Width = 54; Height = 3
                Placeholder = "Enter task title..."
                Visible = $false
                OnChange = { param($self, $Key) $formScreen.State.formData.title = $self.Text }
            }
            
            $self.Components.formDescription = New-TuiTextArea -Props @{
                X = 25; Y = 14; Width = 54; Height = 5
                Placeholder = "Enter task description..."
                Visible = $false
                OnChange = { param($self, $Key) $formScreen.State.formData.description = $self.Text }
            }
            
            $self.Components.formCategory = New-TuiDropdown -Props @{
                X = 25; Y = 20; Width = 20; Height = 3
                Options = $self.State.categories | ForEach-Object { @{ Display = $_; Value = $_ } }
                Visible = $false
                OnChange = { param($NewValue) $formScreen.State.formData.category = $NewValue }
            }
            
            $self.Components.formPriority = New-TuiDropdown -Props @{
                X = 50; Y = 20; Width = 20; Height = 3
                Options = @(
                    @{ Display = "Critical"; Value = "Critical" }
                    @{ Display = "High"; Value = "High" }
                    @{ Display = "Medium"; Value = "Medium" }
                    @{ Display = "Low"; Value = "Low" }
                )
                Visible = $false
                OnChange = { param($NewValue) $formScreen.State.formData.priority = $NewValue }
            }
            
            $self.Components.formDueDate = New-TuiDatePicker -Props @{
                X = 25; Y = 24; Width = 20; Height = 3
                Visible = $false
                OnChange = { param($NewValue) $formScreen.State.formData.dueDate = $NewValue.ToString("MM/dd/yy") }
            }
            
            $self.Components.formSaveButton = New-TuiButton -Props @{
                X = 30; Y = 28; Width = 15; Height = 3
                Text = "Save"
                Visible = $false
                OnClick = { & $formScreen.SaveTask -screen $formScreen }
            }
            
            $self.Components.formCancelButton = New-TuiButton -Props @{
                X = 50; Y = 28; Width = 15; Height = 3
                Text = "Cancel"
                Visible = $false
                OnClick = { & $formScreen.HideForm -screen $formScreen }
            }
        }
        
        # 4. Render: Draw the screen and its components
        Render = {
            param($self)
            
            # Header
            $headerColor = Get-ThemeColor "Header"
            Write-BufferString -X 2 -Y 1 -Text "Task Management" -ForegroundColor $headerColor
            
            # Filter/Sort toolbar
            $toolbarY = 3
            Write-BufferString -X 2 -Y $toolbarY -Text "Filter: " -ForegroundColor ([ConsoleColor]::Gray)
            $filterOptions = @("All", "Active", "Completed")
            $filterX = 10
            foreach ($option in $filterOptions) {
                $isSelected = ($option.ToLower() -eq $self.State.filter)
                $color = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White }
                Write-BufferString -X $filterX -Y $toolbarY -Text "[$option]" -ForegroundColor $color
                $filterX += $option.Length + 4
            }
            
            Write-BufferString -X 40 -Y $toolbarY -Text "Sort: " -ForegroundColor ([ConsoleColor]::Gray)
            $sortOptions = @(@{Display="Priority"; Value="priority"}, @{Display="Due Date"; Value="dueDate"}, @{Display="Created"; Value="created"})
            $sortX = 46
            foreach ($option in $sortOptions) {
                $isSelected = ($option.Value -eq $self.State.sortBy)
                $color = if ($isSelected) { [ConsoleColor]::Yellow } else { [ConsoleColor]::White }
                Write-BufferString -X $sortX -Y $toolbarY -Text "[$($option.Display)]" -ForegroundColor $color
                $sortX += $option.Display.Length + 4
            }
            
            # Form overlay
            if ($self.State.showingForm) {
                $formWidth = 60
                $formHeight = 24
                $formX = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
                $formY = 6
                
                # Form background
                for ($y = $formY; $y -lt ($formY + $formHeight); $y++) {
                    for ($x = $formX; $x -lt ($formX + $formWidth); $x++) {
                        Write-BufferString -X $x -Y $y -Text " " -BackgroundColor ([ConsoleColor]::DarkGray)
                    }
                }
                
                $title = if ($self.State.editingTaskId) { "Edit Task" } else { "New Task" }
                Write-BufferBox -X $formX -Y $formY -Width $formWidth -Height $formHeight -Title " $title " -BorderColor ([ConsoleColor]::Yellow)
                
                # Form labels
                Write-BufferString -X ($formX + 3) -Y ($formY + 2) -Text "Title:" -ForegroundColor ([ConsoleColor]::White)
                Write-BufferString -X ($formX + 3) -Y ($formY + 6) -Text "Description:" -ForegroundColor ([ConsoleColor]::White)
                Write-BufferString -X ($formX + 3) -Y ($formY + 12) -Text "Category:" -ForegroundColor ([ConsoleColor]::White)
                Write-BufferString -X ($formX + 28) -Y ($formY + 12) -Text "Priority:" -ForegroundColor ([ConsoleColor]::White)
                Write-BufferString -X ($formX + 3) -Y ($formY + 16) -Text "Due Date:" -ForegroundColor ([ConsoleColor]::White)
            }
            
            # Help panel
            if ($self.State.showHelp) {
                $helpWidth = 40
                $helpHeight = 20
                $helpX = $global:TuiState.BufferWidth - $helpWidth - 2
                $helpY = 5
                
                # Help background
                for ($y = $helpY; $y -lt ($helpY + $helpHeight); $y++) {
                    for ($x = $helpX; $x -lt ($helpX + $helpWidth); $x++) {
                        Write-BufferString -X $x -Y $y -Text " " -BackgroundColor ([ConsoleColor]::DarkBlue)
                    }
                }
                
                Write-BufferBox -X $helpX -Y $helpY -Width $helpWidth -Height $helpHeight -Title " Help " -BorderColor ([ConsoleColor]::Yellow)
                
                $commands = @(
                    @{ Key = "↑/↓"; Description = "Navigate tasks" }
                    @{ Key = "Space"; Description = "Toggle task completion" }
                    @{ Key = "N"; Description = "Add new task" }
                    @{ Key = "E"; Description = "Edit selected task" }
                    @{ Key = "D"; Description = "Delete selected task" }
                    @{ Key = "1-3"; Description = "Change filter" }
                    @{ Key = "P"; Description = "Sort by priority" }
                    @{ Key = "U"; Description = "Sort by due date" }
                    @{ Key = "C"; Description = "Sort by created date" }
                    @{ Key = "H"; Description = "Toggle this help" }
                    @{ Key = "Q/Esc"; Description = "Go back" }
                )
                
                $cmdY = $helpY + 2
                foreach ($cmd in $commands) {
                    Write-BufferString -X ($helpX + 2) -Y $cmdY -Text $cmd.Key -ForegroundColor ([ConsoleColor]::Yellow)
                    Write-BufferString -X ($helpX + 10) -Y $cmdY -Text $cmd.Description -ForegroundColor ([ConsoleColor]::White)
                    $cmdY++
                }
            }
            
            # Render all components
            foreach ($kvp in $self.Components.GetEnumerator()) {
                $component = $kvp.Value
                if ($component -and $component.Visible -ne $false) {
                    # Set focus state
                    $component.IsFocused = ($self.FocusedComponentName -eq $kvp.Key)
                    if ($component.Render) {
                        & $component.Render -self $component
                    }
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
            Write-BufferString -X 2 -Y $statusY -Text $statusText -ForegroundColor ([ConsoleColor]::Gray)
        }
        
        # 5. HandleInput: Global input handling for the screen
        HandleInput = {
            param($self, $Key)
            
            if ($self.State.showingForm) {
                # Handle form navigation
                switch ($Key.Key) {
                    ([ConsoleKey]::Escape) {
                        & $self.HideForm -screen $self
                        return $true
                    }
                    ([ConsoleKey]::Tab) {
                        # Cycle through form fields
                        $formFields = @('formTitle', 'formDescription', 'formCategory', 'formPriority', 'formDueDate', 'formSaveButton', 'formCancelButton')
                        $currentIndex = [array]::IndexOf($formFields, $self.FocusedComponentName)
                        $nextIndex = ($currentIndex + 1) % $formFields.Count
                        $self.FocusedComponentName = $formFields[$nextIndex]
                        Request-TuiRefresh
                        return $true
                    }
                }
                
                # Delegate to focused form component
                $focusedComponent = if ($self.FocusedComponentName) { $self.Components[$self.FocusedComponentName] } else { $null }
                if ($focusedComponent -and $focusedComponent.HandleInput) {
                    $result = & $focusedComponent.HandleInput -self $focusedComponent -Key $Key
                    if ($result) {
                        Request-TuiRefresh
                        return $true
                    }
                }
                return $false
            }
            
            # Handle list navigation
            switch ($Key.Key) {
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
                ([ConsoleKey]::Spacebar) {
                    & $self.ToggleTaskStatus -screen $self
                    return $true
                }
            }
            
            # Handle key characters
            if ($Key.KeyChar) {
                switch ($Key.KeyChar.ToString().ToUpper()) {
                    'N' {
                        & $self.ShowAddTaskForm -screen $self
                        return $true
                    }
                    'E' {
                        $selectedRow = $self.Components.taskTable.SelectedRow
                        if ($selectedRow -ge 0 -and $selectedRow -lt $self.Components.taskTable.ProcessedData.Count) {
                            $taskData = $self.Components.taskTable.ProcessedData[$selectedRow]
                            & $self.ShowEditTaskForm -screen $self -taskId $taskData.Id
                        }
                        return $true
                    }
                    'D' {
                        & $self.DeleteTask -screen $self
                        return $true
                    }
                    '1' {
                        $self.State.filter = "all"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    '2' {
                        $self.State.filter = "active"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    '3' {
                        $self.State.filter = "completed"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    'P' {
                        $self.State.sortBy = "priority"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    'U' {
                        $self.State.sortBy = "dueDate"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                    'C' {
                        $self.State.sortBy = "created"
                        & $self.RefreshTaskTable -screen $self
                        return $true
                    }
                }
            }
            
            # Delegate to task table
            if ($self.Components.taskTable.Visible -and $self.Components.taskTable.HandleInput) {
                $result = & $self.Components.taskTable.HandleInput -self $self.Components.taskTable -Key $Key
                if ($result) {
                    Request-TuiRefresh
                    return $true
                }
            }
            
            return $false
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-TaskManagementScreen