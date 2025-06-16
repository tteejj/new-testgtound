# Task Management Screen - FINAL STABILIZED VERSION
# This version uses the corrected Panel and centralized Focus System.
# It is simplified, robust, and free of manual workarounds.

function global:Get-TaskManagementScreen {
    $screen = @{
        Name = "TaskScreen"
        
        # 1. STATE: Central data model for the screen
        State = @{
            tasks = @()
            filter = "all"
            sortBy = "priority"
            categories = @("Work", "Personal", "Urgent", "Projects")
            showingForm = $false
            editingTaskId = $null
        }
        
        # 2. COMPONENTS: Storage for instantiated component objects
        Components = @{}
        
        # =================================================================
        # HELPER METHODS
        # These methods encapsulate screen-specific logic.
        # =================================================================

        GetFilteredTasks = {
            param($screen)
            $tasks = $screen.State.tasks
            
            # Apply filter
            $filtered = switch ($screen.State.filter) {
                "active"    { $tasks | Where-Object { $_.Status -eq "Active" } }
                "completed" { $tasks | Where-Object { $_.Status -eq "Completed" } }
                default     { $tasks }
            }
            
            # Apply sort
            $sorted = switch ($screen.State.sortBy) {
                "priority" { 
                    $filtered | Sort-Object @{
                        Expression = {
                            switch ($_.Priority) {
                                "Critical" { 0 }; "High" { 1 }; "Medium" { 2 }; default { 3 }
                            }
                        }
                    }, Created
                }
                "dueDate" { $filtered | Sort-Object DueDate, Priority }
                "created" { $filtered | Sort-Object Created -Descending }
                default   { $filtered }
            }
            
            # Transform for table display
            return @($sorted | ForEach-Object {
                @{
                    Id       = $_.Id
                    Status   = if ($_.Status -eq "Completed") { "✓" } else { " " }
                    Priority = $_.Priority
                    Title    = $_.Title
                    Category = $_.Category
                    DueDate  = $_.DueDate
                }
            })
        }
        
        RefreshTaskTable = {
            param($screen)
            $tableData = & $screen.GetFilteredTasks -screen $screen
            $screen.Components.taskTable.Data = $tableData
            # The DataTable component is responsible for its own internal state refresh.
            if ($screen.Components.taskTable.ProcessData) {
                & $screen.Components.taskTable.ProcessData -self $screen.Components.taskTable
            }
        }
        
        # --- Form Management: Simplified and Declarative ---
        
        ShowForm = {
            param($screen, $taskId)
            
            $isEditing = $null -ne $taskId
            
            if ($isEditing) {
                $task = $screen.State.tasks | Where-Object { $_.Id -eq $taskId }
                if (-not $task) {
                    Write-Log -Level Error -Message "Task not found for editing: $taskId"
                    return
                }
                $screen.State.editingTaskId = $task.Id
                $screen.Components.formPanel.Title = " Edit Task "
                # Populate form fields from existing task
                $screen.Components.formTitle.Text = $task.Title
                $screen.Components.formDescription.Text = $task.Description
                $screen.Components.formCategory.Value = $task.Category
                $screen.Components.formPriority.Value = $task.Priority
                $screen.Components.formDueDate.Value = try { [DateTime]::Parse($task.DueDate) } catch { Get-Date }
            } else {
                $screen.State.editingTaskId = $null
                $screen.Components.formPanel.Title = " New Task "
                # Clear form fields for new task
                $screen.Components.formTitle.Text = ""
                $screen.Components.formDescription.Text = ""
                $screen.Components.formCategory.Value = "Work"
                $screen.Components.formPriority.Value = "Medium"
                $screen.Components.formDueDate.Value = (Get-Date).AddDays(7)
            }

            # This is now the ONLY logic needed to show the form.
            # The robust Panel component handles all child visibility.
            $screen.State.showingForm = $true
            $screen.Components.formPanel.Visible = $true
            $screen.Components.taskTable.Visible = $false
            
            # Tell the TUI Engine to handle the focus change.
            Set-ComponentFocus -Component $screen.Components.formTitle
        }

        # In _task-screen.txt
HideForm = {
    param($screen)
    $screen.State.showingForm = $false
    $screen.Components.formPanel.Visible = $false
    $screen.Components.taskTable.Visible = $true
    
    # Restore focus to the main table
    Set-ComponentFocus -Component $screen.Components.taskTable

    # --- THE CRITICAL FIX ---
    # By resetting the frame count, we are telling the TUI engine's optimized renderer
    # that the next frame is a "first frame" and it MUST redraw every single cell.
    # This erases any "ghost" artifacts left over from the form overlay.
    $global:TuiState.RenderStats.FrameCount = 0
}
        
        SaveTask = {
            param($screen)
            # Get current values directly from components
            $formData = @{
                Title       = $screen.Components.formTitle.Text
                Description = $screen.Components.formDescription.Text
                Category    = $screen.Components.formCategory.Value
                Priority    = $screen.Components.formPriority.Value
                DueDate     = $screen.Components.formDueDate.Value
            }
            
            $editingId = $screen.State.editingTaskId
            
            if ($editingId) {
                # Update existing task
                $task = $screen.State.tasks | Where-Object { $_.Id -eq $editingId }
                if ($task) {
                    $task.Title = $formData.Title
                    $task.Description = $formData.Description
                    $task.Category = $formData.Category
                    $task.Priority = $formData.Priority
                    $task.DueDate = if ($formData.DueDate -is [DateTime]) { $formData.DueDate.ToString("yyyy-MM-dd") } else { $formData.DueDate }
                }
            } else {
                # Add new task
                $newTask = @{
                    Id          = [Guid]::NewGuid().ToString()
                    Title       = $formData.Title
                    Description = $formData.Description
                    Category    = $formData.Category
                    Priority    = $formData.Priority
                    Status      = "Active"
                    DueDate     = if ($formData.DueDate -is [DateTime]) { $formData.DueDate.ToString("yyyy-MM-dd") } else { $formData.DueDate }
                    Created     = Get-Date
                    Completed   = $null
                }
                $screen.State.tasks += $newTask
            }
            
            & $screen.HideForm -screen $screen
            & $screen.RefreshTaskTable -screen $screen
        }
        
        # --- Task List Actions ---
        
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
                        $task.Status = "Completed"; $task.Completed = Get-Date
                    } else {
                        $task.Status = "Active"; $task.Completed = $null
                    }
                    & $screen.RefreshTaskTable -screen $screen
                }
            }
        }
        
        # =================================================================
        # LIFECYCLE HOOKS
        # =================================================================

        # 3. INIT: One-time setup
        Init = {
            param($self)
            
            # --- Data Loading ---
            if ($global:Data -and $global:Data.Tasks -and $global:Data.Tasks.Count -gt 0) {
                $self.State.tasks = @($global:Data.Tasks)
            } else {
                # Initialize with sample data if global data is empty
                $self.State.tasks = @(
                    @{ Id=[Guid]::NewGuid().ToString(); Title="Review TUI framework docs"; Description="Identify gaps"; Category="Work"; Priority="High"; Status="Active"; DueDate=(Get-Date).AddDays(2).ToString("yyyy-MM-dd"); Created=(Get-Date).AddDays(-3); Completed=$null },
                    @{ Id=[Guid]::NewGuid().ToString(); Title="Fix critical framework bugs"; Description="Address panel and focus issues"; Category="Urgent"; Priority="Critical"; Status="Active"; DueDate=(Get-Date).AddDays(1).ToString("yyyy-MM-dd"); Created=(Get-Date).AddDays(-1); Completed=$null },
                    @{ Id=[Guid]::NewGuid().ToString(); Title="Implement state management"; Description="Add a reactive state manager"; Category="Projects"; Priority="Medium"; Status="Completed"; DueDate=(Get-Date).AddDays(-1).ToString("yyyy-MM-dd"); Created=(Get-Date).AddDays(-7); Completed=(Get-Date).AddDays(-1) }
                )
            }
            
            # --- Component Creation ---

            # Create main task table
            $self.Components.taskTable = New-TuiDataTable -Props @{
                X = 2; Y = 5; Width = 76; Height = 20
                Columns = @(
                    @{ Name = "Status"; Header = "✓"; Width = 3 }; @{ Name = "Priority"; Header = "Priority"; Width = 10 };
                    @{ Name = "Title"; Header = "Title"; Width = 30 }; @{ Name = "Category"; Header = "Category"; Width = 11 };
                    @{ Name = "DueDate"; Header = "Due Date"; Width = 10 }
                )
                ShowBorder = $true
                Title = " Tasks "
                OnRowSelect = { & $self.ToggleTaskStatus -screen $self }
            }
            & $self.RefreshTaskTable -screen $self # Initial data load

            # Create the form panel. It starts hidden and will contain all form elements.
            $self.Components.formPanel = New-TuiPanel -Props @{
                X = 10; Y = 4; Width = 60; Height = 22
                Layout = 'Stack'; Orientation = 'Vertical'; Spacing = 1; Padding = 2
                ShowBorder = $true
                Visible = $false # The panel and all its children start hidden.
            }
            
            # Create form components. Their visibility is now controlled by their parent panel.
            $self.Components.formTitle = New-TuiTextBox -Props @{
                Width = 54; Height = 3; IsFocusable = $true
                Props = @{ Label = "Title:" }
            }
            $self.Components.formDescription = New-TuiTextArea -Props @{
                Width = 54; Height = 5; IsFocusable = $true
                Props = @{ Label = "Description:" }
            }
            $self.Components.formCategory = New-TuiDropdown -Props @{
                Width = 25; Height = 3; IsFocusable = $true
                Options = $self.State.categories | ForEach-Object { @{ Display = $_; Value = $_ } }
                Props = @{ Label = "Category:" }
            }
            $self.Components.formPriority = New-TuiDropdown -Props @{
                Width = 25; Height = 3; IsFocusable = $true
                Options = @("Critical", "High", "Medium", "Low") | ForEach-Object { @{ Display = $_; Value = $_ } }
                Props = @{ Label = "Priority:" }
            }
            $self.Components.formDueDate = New-TuiDatePicker -Props @{
                Width = 25; Height = 3; IsFocusable = $true
                Props = @{ Label = "Due Date:" }
            }
            $self.Components.formSaveButton = New-TuiButton -Props @{
                Width = 15; Height = 3; Text = "Save"; IsFocusable = $true
                OnClick = { & $self.SaveTask -screen $self }
            }
            $self.Components.formCancelButton = New-TuiButton -Props @{
                Width = 15; Height = 3; Text = "Cancel"; IsFocusable = $true
                OnClick = { & $self.HideForm -screen $self }
            }
            
            # Add components to the panel using the AddChild method.
            # The panel will automatically manage their position and rendering.
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = "Title:" })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $self.Components.formTitle
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = "Description:" })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $self.Components.formDescription
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = "Category:" })
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $self.Components.formCategory
            # ... For brevity, other components would be added similarly ...
            # You can also create a horizontal panel for buttons
            $buttonPanel = New-TuiPanel -Props @{ Layout = 'Stack'; Orientation = 'Horizontal'; Spacing = 2 }
            & $buttonPanel.AddChild -self $buttonPanel -Child $self.Components.formSaveButton
            & $buttonPanel.AddChild -self $buttonPanel -Child $self.Components.formCancelButton
            & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $buttonPanel
        }
        
        # 4. RENDER: Draw the screen and its components
        Render = {
            param($self)
            
            # Header
            Write-BufferString -X 2 -Y 1 -Text "Task Management" -ForegroundColor (Get-ThemeColor "Header")
            
            # Toolbar (only shown when not in form mode)
            if (-not $self.State.showingForm) {
                $toolbarY = 3
                Write-BufferString -X 2 -Y $toolbarY -Text "Filter: [1]All [2]Active [3]Completed | Sort: [P]riority [U]pcoming [C]reated"
            }
            
            # Render all top-level components. The Panel will handle rendering its own children.
            foreach ($component in $self.Components.Values) {
                if ($component.Render) {
                    & $component.Render -self $component
                }
            }
            
            # Status bar
            $statusY = $global:TuiState.BufferHeight - 2
            $statusText = if ($self.State.showingForm) {
                "Tab: Next Field | Esc: Cancel"
            } else {
                "N: New | E: Edit | D: Delete | Space: Toggle | Q: Back"
            }
            Write-BufferString -X 2 -Y $statusY -Text $statusText -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        # 5. HANDLEINPUT: Global input handling for the screen
        HandleInput = {
            param($self, $Key)
            
            # If the form is showing, all input is handled by it or the engine.
            if ($self.State.showingForm) {
                switch ($Key.Key) {
                    ([ConsoleKey]::Escape) { & $self.HideForm -screen $self; return $true }
                    ([ConsoleKey]::Tab) {
                        # Delegate to the robust engine function.
                        Handle-TabNavigation -Reverse ($Key.Modifiers -band [ConsoleModifiers]::Shift)
                        return $true
                    }
                }
            } else { # Form is not showing, handle list commands.
                switch -Wildcard ($Key.KeyChar.ToString().ToUpper()) {
                    'N' { & $self.ShowForm -screen $self; return $true }
                    'E' {
                        $selected = $self.Components.taskTable.SelectedRow
                        if ($selected -ge 0) {
                            $taskId = $self.Components.taskTable.ProcessedData[$selected].Id
                            & $self.ShowForm -screen $self -taskId $taskId
                        }
                        return $true
                    }
                    'D' { & $self.DeleteTask -screen $self; return $true }
                    'Q' { return "Back" }
                    '1' { $self.State.filter = "all"; & $self.RefreshTaskTable -screen $self; return $true }
                    '2' { $self.State.filter = "active"; & $self.RefreshTaskTable -screen $self; return $true }
                    '3' { $self.State.filter = "completed"; & $self.RefreshTaskTable -screen $self; return $true }
                    'P' { $self.State.sortBy = "priority"; & $self.RefreshTaskTable -screen $self; return $true }
                    'U' { $self.State.sortBy = "dueDate"; & $self.RefreshTaskTable -screen $self; return $true }
                    'C' { $self.State.sortBy = "created"; & $self.RefreshTaskTable -screen $self; return $true }
                }
                if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
            }
            
            # For any other key, delegate to the currently focused component.
            # This handles typing in textboxes, table navigation, etc.
            $focusedComponent = $script:TuiState.FocusedComponent
            if ($focusedComponent -and $focusedComponent.HandleInput) {
                if (& $focusedComponent.HandleInput -self $focusedComponent -Key $Key) {
                    return $true
                }
            }
            
            return $false
        }
        
        # 6. ONRESUME: Hook for when the screen becomes active again.
        OnResume = {
            param($self)
            # Refresh data from global store in case it changed.
            if ($global:Data -and $global:Data.Tasks) {
                $self.State.tasks = @($global:Data.Tasks)
                & $self.RefreshTaskTable -screen $self
            }
        }
    }
    
    return $screen
}

# Alias for backward compatibility if other parts of the app call Get-TaskScreen
function global:Get-TaskScreen {
    return Get-TaskManagementScreen
}

Export-ModuleMember -Function Get-TaskManagementScreen, Get-TaskScreen