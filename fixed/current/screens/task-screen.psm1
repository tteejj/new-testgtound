# Task Management Screen
# Full CRUD task management with categories, priorities, and due dates

function Create-TaskScreen {
    $screen = Create-TuiScreen -Definition @{
        Title = "Task Management"
        Layout = "Dock"
        InitialState = @{
            tasks = @()
            selectedTask = $null
            filter = "all"  # all, active, completed
            sortBy = "priority"  # priority, dueDate, created
            categories = @("Work", "Personal", "Urgent", "Projects")
            isAddingTask = $false
            editingTaskId = $null
        }
        Init = {
            param($self)
            
            # Load tasks from storage (for now just create sample data)
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
            
            & $self.State.Update @{ tasks = $sampleTasks }
            
            # Subscribe to filter changes
            & $self.State.Subscribe -Path "filter" -Handler {
                param($filter)
                $self.RefreshTaskDisplay()
            }
            
            # Subscribe to sort changes
            & $self.State.Subscribe -Path "sortBy" -Handler {
                param($sortBy)
                $self.RefreshTaskDisplay()
            }
        }
        CustomMethods = @{
            RefreshTaskDisplay = {
                param($self)
                $tasks = & $self.State.GetValue "tasks"
                $filter = & $self.State.GetValue "filter"
                $sortBy = & $self.State.GetValue "sortBy"
                
                # Apply filter
                $filtered = switch ($filter) {
                    "active" { $tasks | Where-Object { $_.Status -eq "Active" } }
                    "completed" { $tasks | Where-Object { $_.Status -eq "Completed" } }
                    default { $tasks }
                }
                
                # Apply sort
                $sorted = switch ($sortBy) {
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
                
                # Update table
                $table = & $self.GetComponent "taskTable"
                if ($table) {
                    $table.Properties.Data = $sorted
                    Request-TuiRefresh
                }
            }
            
            ShowAddTaskForm = {
                param($self)
                & $self.State.Update @{ isAddingTask = $true }
                $form = & $self.GetComponent "taskForm"
                if ($form) {
                    $form.Properties.IsVisible = $true
                    & $form.Reset
                    & $form.SetFocus
                }
                Request-TuiRefresh
            }
            
            ShowEditTaskForm = {
                param($self, $task)
                & $self.State.Update @{ 
                    editingTaskId = $task.Id
                    isAddingTask = $false
                }
                $form = & $self.GetComponent "taskForm"
                if ($form) {
                    $form.Properties.IsVisible = $true
                    & $form.SetValues @{
                        title = $task.Title
                        description = $task.Description
                        category = $task.Category
                        priority = $task.Priority
                        dueDate = $task.DueDate.ToString("yyyy-MM-dd")
                    }
                    & $form.SetFocus
                }
                Request-TuiRefresh
            }
            
            SaveTask = {
                param($self, $formData)
                $tasks = & $self.State.GetValue "tasks"
                $editingId = & $self.State.GetValue "editingTaskId"
                
                if ($editingId) {
                    # Update existing task
                    $task = $tasks | Where-Object { $_.Id -eq $editingId }
                    if ($task) {
                        $task.Title = $formData.title
                        $task.Description = $formData.description
                        $task.Category = $formData.category
                        $task.Priority = $formData.priority
                        $task.DueDate = [DateTime]::Parse($formData.dueDate)
                    }
                } else {
                    # Add new task
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
                    $tasks += $newTask
                }
                
                & $self.State.Update @{ 
                    tasks = $tasks
                    isAddingTask = $false
                    editingTaskId = $null
                }
                
                $form = & $self.GetComponent "taskForm"
                if ($form) {
                    $form.Properties.IsVisible = $false
                }
                
                $self.RefreshTaskDisplay()
            }
            
            DeleteTask = {
                param($self, $taskId)
                $tasks = & $self.State.GetValue "tasks"
                $tasks = $tasks | Where-Object { $_.Id -ne $taskId }
                & $self.State.Update @{ tasks = $tasks }
                $self.RefreshTaskDisplay()
            }
            
            ToggleTaskStatus = {
                param($self, $taskId)
                $tasks = & $self.State.GetValue "tasks"
                $task = $tasks | Where-Object { $_.Id -eq $taskId }
                if ($task) {
                    if ($task.Status -eq "Active") {
                        $task.Status = "Completed"
                        $task.Completed = Get-Date
                    } else {
                        $task.Status = "Active"
                        $task.Completed = $null
                    }
                }
                & $self.State.Update @{ tasks = $tasks }
                $self.RefreshTaskDisplay()
            }
        }
        Components = @{
            # Top toolbar
            toolbar = @{
                Type = "Panel"
                Properties = @{
                    Dock = "Top"
                    Height = 3
                    BackgroundColor = "DarkBlue"
                    Components = @{
                        toolbarStack = @{
                            Type = "Stack"
                            Properties = @{
                                Orientation = "Horizontal"
                                Spacing = 2
                                X = 2
                                Y = 1
                                Components = @{
                                    addBtn = @{
                                        Type = "Button"
                                        Properties = @{
                                            Text = "[+] Add Task"
                                            ForegroundColor = "Green"
                                            OnClick = {
                                                $screen = Get-TuiScreen
                                                $screen.ShowAddTaskForm()
                                            }
                                        }
                                    }
                                    filterCombo = @{
                                        Type = "ComboBox"
                                        Properties = @{
                                            Width = 15
                                            Items = @("All Tasks", "Active", "Completed")
                                            SelectedIndex = 0
                                            OnChange = {
                                                param($self, $value)
                                                $screen = Get-TuiScreen
                                                $filter = switch ($value) {
                                                    "All Tasks" { "all" }
                                                    "Active" { "active" }
                                                    "Completed" { "completed" }
                                                }
                                                & $screen.State.Update @{ filter = $filter }
                                            }
                                        }
                                    }
                                    sortCombo = @{
                                        Type = "ComboBox"
                                        Properties = @{
                                            Width = 15
                                            Items = @("Priority", "Due Date", "Created")
                                            SelectedIndex = 0
                                            OnChange = {
                                                param($self, $value)
                                                $screen = Get-TuiScreen
                                                $sort = switch ($value) {
                                                    "Priority" { "priority" }
                                                    "Due Date" { "dueDate" }
                                                    "Created" { "created" }
                                                }
                                                & $screen.State.Update @{ sortBy = $sort }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            # Main content area
            content = @{
                Type = "Panel"
                Properties = @{
                    Dock = "Fill"
                    Components = @{
                        taskTable = @{
                            Type = "DataTable"
                            Properties = @{
                                X = 2
                                Y = 1
                                Width = 76
                                Height = 20
                                Data = @()
                                Columns = @(
                                    @{ Name = "Status"; Width = 8 }
                                    @{ Name = "Priority"; Width = 10 }
                                    @{ Name = "Title"; Width = 30 }
                                    @{ Name = "Category"; Width = 12 }
                                    @{ Name = "Due"; Width = 12 }
                                )
                                RenderCell = {
                                    param($column, $row)
                                    switch ($column.Name) {
                                        "Status" { 
                                            if ($row.Status -eq "Completed") { "[X]" } else { "[ ]" }
                                        }
                                        "Priority" { 
                                            $color = switch ($row.Priority) {
                                                "Critical" { "Red" }
                                                "High" { "Yellow" }
                                                "Medium" { "Cyan" }
                                                "Low" { "Gray" }
                                            }
                                            @{
                                                Text = $row.Priority
                                                ForegroundColor = $color
                                            }
                                        }
                                        "Title" { 
                                            if ($row.Status -eq "Completed") {
                                                @{
                                                    Text = $row.Title
                                                    ForegroundColor = "DarkGray"
                                                }
                                            } else {
                                                $row.Title
                                            }
                                        }
                                        "Category" { $row.Category }
                                        "Due" { 
                                            if ($row.DueDate) {
                                                $daysUntil = ($row.DueDate - (Get-Date)).Days
                                                $color = if ($daysUntil -lt 0) { "Red" }
                                                elseif ($daysUntil -eq 0) { "Yellow" }
                                                else { "White" }
                                                @{
                                                    Text = $row.DueDate.ToString("MM/dd/yyyy")
                                                    ForegroundColor = $color
                                                }
                                            } else { "-" }
                                        }
                                    }
                                }
                                OnRowSelect = {
                                    param($self, $row)
                                    $screen = Get-TuiScreen
                                    & $screen.State.Update @{ selectedTask = $row }
                                }
                                OnKeyPress = {
                                    param($self, $key)
                                    if ($key.Key -eq "Enter" -or $key.Key -eq "Spacebar") {
                                        $selected = $self.Properties.SelectedRow
                                        if ($selected) {
                                            $screen = Get-TuiScreen
                                            $screen.ToggleTaskStatus($selected.Id)
                                        }
                                        return $true
                                    }
                                    elseif ($key.Key -eq "E" -and $key.Modifiers -eq "Control") {
                                        $selected = $self.Properties.SelectedRow
                                        if ($selected) {
                                            $screen = Get-TuiScreen
                                            $screen.ShowEditTaskForm($selected)
                                        }
                                        return $true
                                    }
                                    elseif ($key.Key -eq "Delete") {
                                        $selected = $self.Properties.SelectedRow
                                        if ($selected) {
                                            $screen = Get-TuiScreen
                                            $screen.DeleteTask($selected.Id)
                                        }
                                        return $true
                                    }
                                    return $false
                                }
                            }
                        }
                        
                        # Task form (hidden by default)
                        taskForm = @{
                            Type = "Form"
                            Properties = @{
                                X = 10
                                Y = 5
                                Width = 60
                                IsVisible = $false
                                BackgroundColor = "DarkGray"
                                BorderStyle = "Double"
                                Fields = @(
                                    @{
                                        Name = "title"
                                        Label = "Title"
                                        Type = "TextBox"
                                        Required = $true
                                        Width = 40
                                    }
                                    @{
                                        Name = "description"
                                        Label = "Description"
                                        Type = "TextBox"
                                        Width = 40
                                        Height = 3
                                    }
                                    @{
                                        Name = "category"
                                        Label = "Category"
                                        Type = "ComboBox"
                                        Items = @("Work", "Personal", "Urgent", "Projects")
                                        Required = $true
                                    }
                                    @{
                                        Name = "priority"
                                        Label = "Priority"
                                        Type = "ComboBox"
                                        Items = @("Low", "Medium", "High", "Critical")
                                        Required = $true
                                    }
                                    @{
                                        Name = "dueDate"
                                        Label = "Due Date"
                                        Type = "TextBox"
                                        Placeholder = "yyyy-MM-dd"
                                        Validation = {
                                            param($value)
                                            try {
                                                $date = [DateTime]::Parse($value)
                                                @{ Valid = $true }
                                            } catch {
                                                @{ Valid = $false; Message = "Invalid date format" }
                                            }
                                        }
                                    }
                                )
                                OnSubmit = {
                                    param($formData)
                                    $screen = Get-TuiScreen
                                    $screen.SaveTask($formData)
                                }
                                OnCancel = {
                                    $screen = Get-TuiScreen
                                    & $screen.State.Update @{ 
                                        isAddingTask = $false
                                        editingTaskId = $null
                                    }
                                    $form = Get-TuiComponent -ComponentId "taskForm"
                                    $form.Properties.IsVisible = $false
                                    Request-TuiRefresh
                                }
                            }
                        }
                    }
                }
            }
            
            # Status bar
            statusBar = @{
                Type = "Panel"
                Properties = @{
                    Dock = "Bottom"
                    Height = 2
                    BackgroundColor = "DarkBlue"
                    Components = @{
                        statusText = @{
                            Type = "Label"
                            Properties = @{
                                X = 2
                                Y = 0
                                Text = "Space/Enter: Toggle | Ctrl+E: Edit | Delete: Remove | Tab: Navigate"
                                ForegroundColor = "Gray"
                            }
                        }
                    }
                }
            }
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Create-TaskScreen
