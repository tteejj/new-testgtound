# screens/task-screen-layout.psm1
# Task Management Screen - AUTOMATIC LAYOUT VERSION
# Using layout panels for easier component management.

function global:Get-TaskManagementScreenLayout {
    $screen = Get-TaskManagementScreen # Start with the old screen definition

    # --- OVERRIDE THE INIT METHOD FOR AUTOMATIC LAYOUT ---
    $screen.Init = {
        param($self)

        # Load tasks data (same as before)
        if ($global:Data -and $global:Data.Tasks -and $global:Data.Tasks.Count -gt 0) {
            $self.State.tasks = @($global:Data.Tasks | ForEach-Object { $_ })
        } else {
            # Use sample tasks if none are loaded
            $self.State.tasks = @(
                @{ Id = [Guid]::NewGuid().ToString(); Title = "Review documentation"; Description = "Go through TUI framework docs"; Category = "Work"; Priority = "High"; Status = "Active"; DueDate = (Get-Date).AddDays(2).ToString("MM/dd/yy"); Created = (Get-Date).AddDays(-3); Completed = $null },
                @{ Id = [Guid]::NewGuid().ToString(); Title = "Fix memory leaks"; Description = "Address issues in event system"; Category = "Urgent"; Priority = "Critical"; Status = "Active"; DueDate = (Get-Date).AddDays(1).ToString("MM/dd/yy"); Created = (Get-Date).AddDays(-1); Completed = $null },
                @{ Id = [Guid]::NewGuid().ToString(); Title = "Add clipboard support"; Description = "Implement Ctrl+C/V"; Category = "Projects"; Priority = "Medium"; Status = "Completed"; DueDate = (Get-Date).AddDays(-1).ToString("MM/dd/yy"); Created = (Get-Date).AddDays(-7); Completed = (Get-Date).AddDays(-1) }
            )
        }

        # Create main task table (manually positioned is fine for the main element)
        $self.Components.taskTable = New-TuiDataTable -Props @{
            X = 2; Y = 5; Width = $global:TuiState.BufferWidth - 4; Height = $global:TuiState.BufferHeight - 10
            Columns = @(
                @{ Name = "Status"; Header = "✓"; Width = 3 }; @{ Name = "Priority"; Header = "Priority"; Width = 10 };
                @{ Name = "Title"; Header = "Title"; Width = 30 }; @{ Name = "Category"; Header = "Category"; Width = 11 };
                @{ Name = "DueDate"; Header = "Due Date"; Width = 10 }
            )
            Data = & $self.GetFilteredTasks -screen $self
            OnRowSelect = { & $self.ToggleTaskStatus -screen $self }
        }

        # --- AUTOMATIC LAYOUT FOR THE FORM ---
        $formScreen = $self

        # 1. Create the main form panel with a vertical stack layout
        $self.Components.formPanel = New-TuiPanel -Props @{
            # Position and size will be set when the form is shown
            Width = 60; Height = 26
            Layout = 'Stack'; Orientation = 'Vertical'; Spacing = 0; Padding = 1
            ShowBorder = $true; Title = " Task Form "; Visible = $false
        }

        # 2. Create all form fields WITHOUT X/Y coordinates
        $self.Components.formTitle = New-TuiTextBox -Props @{ Width = 56; Placeholder = "Enter task title..."; IsFocusable = $false }
        $self.Components.formDescription = New-TuiTextArea -Props @{ Width = 56; Height = 4; Placeholder = "Enter task description..."; IsFocusable = $false }
        $self.Components.formCategory = New-TuiDropdown -Props @{ Width = 25; Options = ($self.State.categories | ForEach-Object { @{ Display = $_; Value = $_ } }); IsFocusable = $false }
        $self.Components.formPriority = New-TuiDropdown -Props @{ Width = 25; Options = @(@{ Display="Critical";Value="Critical" },@{ Display="High";Value="High" },@{ Display="Medium";Value="Medium" },@{ Display="Low";Value="Low" }); IsFocusable = $false }
        $self.Components.formDueDate = New-TuiDatePicker -Props @{ Width = 25; IsFocusable = $false }

        # Create a horizontal panel for the buttons
        $buttonPanel = New-TuiPanel -Props @{
            Layout = 'Stack'; Orientation = 'Horizontal'; Spacing = 2; Width = 32; Height = 3
        }
        $self.Components.formSaveButton = New-TuiButton -Props @{ Width = 15; Text = "Save"; IsFocusable = $false; OnClick = { & $formScreen.SaveTask -screen $formScreen } }
        $self.Components.formCancelButton = New-TuiButton -Props @{ Width = 15; Text = "Cancel"; IsFocusable = $false; OnClick = { & $formScreen.HideForm -screen $formScreen } }

        & $buttonPanel.AddChild -self $buttonPanel -Child $self.Components.formSaveButton
        & $buttonPanel.AddChild -self $buttonPanel -Child $self.Components.formCancelButton

        # 3. Add all components to the form panel in the desired order
        #    The panel will automatically position them.
        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = "Title:" })
        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $self.Components.formTitle

        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = "Description:"; Height=2 }) # Add extra height for spacing
        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $self.Components.formDescription

        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = "Category:"; Height=2 })
        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $self.Components.formCategory

        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = "Priority:"; Height=2 })
        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $self.Components.formPriority

        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = "Due Date:"; Height=2 })
        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $self.Components.formDueDate

        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child (New-TuiLabel -Props @{ Text = ""; Height=2 }) # Spacer
        & $self.Components.formPanel.AddChild -self $self.Components.formPanel -Child $buttonPanel
    }

    # --- OVERRIDE THE ShowAddTaskForm and ShowEditTaskForm METHODS ---
    $showFormLogic = {
        param($screen)

        # Center the form panel automatically
        $screen.Components.formPanel.X = [Math]::Floor(($global:TuiState.BufferWidth - $screen.Components.formPanel.Width) / 2)
        $screen.Components.formPanel.Y = [Math]::Floor(($global:TuiState.BufferHeight - $screen.Components.formPanel.Height) / 2)

        # Recalculate child positions based on the panel's new location
        & $screen.Components.formPanel._RecalculateLayout -self $screen.Components.formPanel

        # Show form panel
        $screen.Components.formPanel.Visible = $true

        # Enable focus on form components
        $formFields = @('formTitle', 'formDescription', 'formCategory', 'formPriority', 'formDueDate', 'formSaveButton', 'formCancelButton')
        foreach ($field in $formFields) {
            $screen.Components[$field].IsFocusable = $true
        }

        # Hide table
        $screen.Components.taskTable.Visible = $false
        $screen.Components.taskTable.IsFocusable = $false

        # Focus first field
        $screen.FocusedComponentName = 'formTitle'
        Request-TuiRefresh
    }

    $screen.ShowAddTaskForm = {
        param($screen)
        $screen.State.showingForm = $true
        $screen.State.editingTaskId = $null

        # Reset form fields
        $screen.Components.formTitle.Text = ""
        $screen.Components.formDescription.Text = ""
        $screen.Components.formCategory.Value = "Work"
        $screen.Components.formPriority.Value = "Medium"
        $screen.Components.formDueDate.Value = (Get-Date).AddDays(7)
        $screen.Components.formPanel.Title = " New Task "

        & $showFormLogic -screen $screen
    }

    $screen.ShowEditTaskForm = {
        param($screen, $taskId)
        $task = $screen.State.tasks | Where-Object { $_.Id -eq $taskId }
        if (-not $task) { return }

        $screen.State.showingForm = $true
        $screen.State.editingTaskId = $task.Id

        # Populate form fields
        $screen.Components.formTitle.Text = $task.Title
        $screen.Components.formDescription.Text = $task.Description
        $screen.Components.formCategory.Value = $task.Category
        $screen.Components.formPriority.Value = $task.Priority
        $screen.Components.formDueDate.Value = [DateTime]::Parse($task.DueDate)
        $screen.Components.formPanel.Title = " Edit Task "

        & $showFormLogic -screen $screen
    }

    return $screen
}

# Alias for compatibility
function global:Get-TaskScreen {
    return Get-TaskManagementScreenLayout
}

Export-ModuleMember -Function Get-TaskManagementScreenLayout, Get-TaskScreen
