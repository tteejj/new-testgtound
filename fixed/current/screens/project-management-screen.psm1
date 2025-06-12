# Project Management Screen

function Get-ProjectManagementScreen {
    $screen = @{
        Name = "ProjectManagementScreen"
        State = @{
            Projects = @()
            SelectedIndex = 0
            ShowInactive = $false
        }
        
        Init = {
            param($self)
            & $self.RefreshProjects -self $self
        }
        
        RefreshProjects = {
            param($self)
            
            # Ensure Data structure exists
            if (-not $script:Data) {
                $script:Data = @{
                    Projects = @{}
                    Tasks = @()
                    TimeEntries = @()
                }
            }
            
            # Ensure Projects exists
            if (-not $script:Data.Projects) {
                $script:Data.Projects = @{}
            }
            
            # Get projects as array
            $projects = @()
            if ($script:Data.Projects -is [hashtable]) {
                $projects = @($script:Data.Projects.GetEnumerator())
            } elseif ($script:Data.Projects -is [array]) {
                # Convert array to hashtable entries for compatibility
                $tempHash = @{}
                foreach ($proj in $script:Data.Projects) {
                    if ($proj.Key) {
                        $tempHash[$proj.Key] = $proj
                    }
                }
                $projects = @($tempHash.GetEnumerator())
            }
            
            if (-not $self.State.ShowInactive -and $projects.Count -gt 0) {
                $projects = $projects | Where-Object { $_.Value.IsActive -ne $false }
            }
            
            $self.State.Projects = $projects | Sort-Object { $_.Value.Name }
        }
        
        Render = {
            param($self)
            
            # Header
            Write-BufferString -X 2 -Y 1 -Text "Project Management" -ForegroundColor (Get-ThemeColor "Header")
            
            # Project count
            $activeCount = @($self.State.Projects | Where-Object { $_.Value.IsActive -ne $false }).Count
            $totalCount = $self.State.Projects.Count
            $countText = "$activeCount active / $totalCount total projects"
            Write-BufferString -X ($script:TuiState.BufferWidth - $countText.Length - 2) -Y 1 `
                -Text $countText -ForegroundColor (Get-ThemeColor "Info")
            
            # Filter info
            if ($self.State.ShowInactive) {
                Write-BufferString -X 2 -Y 3 -Text "Showing: All projects" -ForegroundColor (Get-ThemeColor "Subtle")
            } else {
                Write-BufferString -X 2 -Y 3 -Text "Showing: Active projects only" -ForegroundColor (Get-ThemeColor "Subtle")
            }
            
            # Project list
            $listY = 5
            $visibleProjects = $script:TuiState.BufferHeight - $listY - 4
            $startIdx = [Math]::Max(0, $self.State.SelectedIndex - [Math]::Floor($visibleProjects / 2))
            $endIdx = [Math]::Min($self.State.Projects.Count, $startIdx + $visibleProjects)
            
            if ($self.State.Projects.Count -eq 0) {
                $emptyMsg = "No projects found"
                $msgX = [Math]::Floor(($script:TuiState.BufferWidth - $emptyMsg.Length) / 2)
                $msgY = [Math]::Floor($script:TuiState.BufferHeight / 2)
                Write-BufferString -X $msgX -Y $msgY -Text $emptyMsg -ForegroundColor (Get-ThemeColor "Subtle")
                
                # Add instruction to create new project
                $helpMsg = "Press [N] to create a new project"
                $helpX = [Math]::Floor(($script:TuiState.BufferWidth - $helpMsg.Length) / 2)
                Write-BufferString -X $helpX -Y ($msgY + 2) -Text $helpMsg -ForegroundColor (Get-ThemeColor "Accent")
            } else {
                for ($i = $startIdx; $i -lt $endIdx; $i++) {
                    $project = $self.State.Projects[$i]
                    $projectData = $project.Value
                    $rowY = $listY + ($i - $startIdx)
                    
                    $isSelected = ($i -eq $self.State.SelectedIndex)
                    $boxWidth = $script:TuiState.BufferWidth - 4
                    $borderColor = if ($isSelected) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
                    
                    # Project box
                    Write-BufferBox -X 2 -Y $rowY -Width $boxWidth -Height 4 -BorderColor $borderColor
                    
                    # Project name and ID
                    $nameColor = if ($projectData.IsActive -eq $false) { Get-ThemeColor "Subtle" } else { Get-ThemeColor "Primary" }
                    Write-BufferString -X 4 -Y ($rowY + 1) -Text $projectData.Name -ForegroundColor $nameColor
                    Write-BufferString -X ($boxWidth - 10) -Y ($rowY + 1) -Text "[$($project.Key)]" `
                        -ForegroundColor (Get-ThemeColor "Subtle")
                    
                    # Status
                    $statusText = if ($projectData.IsActive -eq $false) { "Inactive" } else { "Active" }
                    $statusColor = if ($projectData.IsActive -eq $false) { Get-ThemeColor "Subtle" } else { Get-ThemeColor "Success" }
                    Write-BufferString -X 4 -Y ($rowY + 2) -Text "● $statusText" -ForegroundColor $statusColor
                    
                    # Stats
                    $taskCount = 0
                    $hoursLogged = 0
                    
                    if ($script:Data.Tasks) {
                        $taskCount = @($script:Data.Tasks | Where-Object { $_.ProjectKey -eq $project.Key }).Count
                    }
                    
                    if ($script:Data.TimeEntries) {
                        $hoursLogged = ($script:Data.TimeEntries | Where-Object { $_.ProjectKey -eq $project.Key } | 
                            Measure-Object -Property Hours -Sum).Sum
                        if (-not $hoursLogged) { $hoursLogged = 0 }
                    }
                    
                    $statsText = "$taskCount tasks | $($hoursLogged.ToString('0.0')) hours logged"
                    Write-BufferString -X ($boxWidth - $statsText.Length - 2) -Y ($rowY + 2) -Text $statsText `
                        -ForegroundColor (Get-ThemeColor "Secondary")
                }
            }
            
            # Instructions
            $instructions = "[↑↓] Navigate | [N] New | [E] Edit | [T] Toggle Active | [A] Show All/Active | [Esc] Back"
            Write-BufferString -X ([Math]::Floor(($script:TuiState.BufferWidth - $instructions.Length) / 2)) `
                -Y ($script:TuiState.BufferHeight - 2) -Text $instructions -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.SelectedIndex -gt 0) {
                        $self.State.SelectedIndex--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.State.SelectedIndex -lt $self.State.Projects.Count - 1) {
                        $self.State.SelectedIndex++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::N) {
                    Push-Screen -Screen (Get-AddProjectScreen)
                    return $true
                }
                ([ConsoleKey]::E) {
                    if ($self.State.Projects.Count -gt 0) {
                        $project = $self.State.Projects[$self.State.SelectedIndex]
                        # TODO: Push edit project screen
                        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
                            Publish-Event -EventName "Notification.Show" -Data @{
                                Text = "Edit project not implemented yet"
                                Type = "Info"
                            }
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::T) {
                    if ($self.State.Projects.Count -gt 0) {
                        $project = $self.State.Projects[$self.State.SelectedIndex]
                        $project.Value.IsActive = -not $project.Value.IsActive
                        
                        if (Get-Command -Name "Save-UnifiedData" -ErrorAction SilentlyContinue) {
                            Save-UnifiedData
                        }
                        
                        & $self.RefreshProjects -self $self
                        Request-TuiRefresh
                        
                        $status = if ($project.Value.IsActive) { "activated" } else { "deactivated" }
                        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
                            Publish-Event -EventName "Notification.Show" -Data @{
                                Text = "Project $status"
                                Type = "Success"
                            }
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::A) {
                    $self.State.ShowInactive = -not $self.State.ShowInactive
                    & $self.RefreshProjects -self $self
                    $self.State.SelectedIndex = 0
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    return "Back"
                }
            }
            
            return $false
        }
        
        OnResume = {
            param($self)
            & $self.RefreshProjects -self $self
            Request-TuiRefresh
        }
    }
    
    return $screen
}

function Get-AddProjectScreen {
    $screen = @{
        Name = "AddProjectScreen"
        State = @{
            Name = ""
            Description = ""
            NameCursor = 0
            DescriptionCursor = 0
            FocusedChildName = "name_textbox"
        }
        FormContainer = $null
        
        Init = {
            param($self)
            
            # Ensure TUI components are available
            if (-not (Get-Command -Name "New-TuiLabel" -ErrorAction SilentlyContinue)) {
                Write-Warning "TUI components not available for Add Project screen"
                return
            }
            
            $children = @(
                New-TuiLabel -Props @{
                    Y = 0
                    Text = "Project Name:"
                }
                
                New-TuiTextBox -Props @{
                    Name = "name_textbox"
                    Y = 1
                    Width = 56
                    Placeholder = "Enter project name..."
                    TextProp = "Name"
                    CursorProp = "NameCursor"
                    OnChange = { 
                        param($NewText, $NewCursorPosition) 
                        $self.State.Name = $NewText
                        $self.State.NameCursor = $NewCursorPosition
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiLabel -Props @{
                    Y = 4
                    Text = "Description:"
                }
                
                New-TuiTextArea -Props @{
                    Name = "description_textarea"
                    Y = 5
                    Width = 56
                    Height = 6
                    Placeholder = "Enter project description..."
                    OnChange = { 
                        param($NewText) 
                        $self.State.Description = $NewText
                        Request-TuiRefresh 
                    }
                }
                
                New-TuiButton -Props @{
                    Name = "create_button"
                    Y = 13
                    Width = 12
                    Text = "Create"
                    OnClick = {
                        if ([string]::IsNullOrWhiteSpace($self.State.Name)) {
                            if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
                                Publish-Event -EventName "Notification.Show" -Data @{
                                    Text = "Project name is required"
                                    Type = "Error"
                                }
                            }
                            return
                        }
                        
                        # Create project manually if event system not available
                        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
                            Publish-Event -EventName "Data.Create.Project" -Data @{
                                Name = $self.State.Name
                                Description = $self.State.Description
                            }
                        } else {
                            # Direct creation fallback
                            if (-not $script:Data) {
                                $script:Data = @{ Projects = @{} }
                            }
                            if (-not $script:Data.Projects) {
                                $script:Data.Projects = @{}
                            }
                            
                            $projectKey = "PROJ" + ($script:Data.Projects.Count + 1)
                            $script:Data.Projects[$projectKey] = @{
                                Key = $projectKey
                                Name = $self.State.Name
                                Description = $self.State.Description
                                IsActive = $true
                                CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            }
                        }
                        
                        Pop-Screen
                    }
                }
                
                New-TuiButton -Props @{
                    Name = "cancel_button"
                    X = 44
                    Y = 13
                    Width = 12
                    Text = "Cancel"
                    OnClick = { Pop-Screen }
                }
            )
            
            $self.FormContainer = New-TuiForm -Props @{
                X = [Math]::Floor(($script:TuiState.BufferWidth - 60) / 2)
                Y = [Math]::Floor(($script:TuiState.BufferHeight - 20) / 2)
                Width = 60
                Height = 20
                Title = " New Project "
                Padding = 2
                Children = $children
                OnFocusChange = { 
                    param($NewFocusedChildName) 
                    $self.State.FocusedChildName = $NewFocusedChildName
                    Request-TuiRefresh 
                }
            }
        }
        
        Render = {
            param($self)
            if ($self.FormContainer) {
                $self.FormContainer.State = $self.State
                & $self.FormContainer.Render -self $self.FormContainer
            } else {
                # Fallback render if form container not initialized
                Write-BufferBox -X 10 -Y 5 -Width 60 -Height 10 -Title " Add Project Error " -BorderColor "Red"
                Write-BufferString -X 15 -Y 8 -Text "Unable to initialize form components" -ForegroundColor "Red"
                Write-BufferString -X 15 -Y 10 -Text "Press [Esc] to go back" -ForegroundColor "Yellow"
            }
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                return "Back"
            }
            
            if ($self.FormContainer) {
                $self.FormContainer.State = $self.State
                return & $self.FormContainer.HandleInput -self $self.FormContainer -Key $Key
            }
            
            return $false
        }
    }
    
    return $screen
}

Export-ModuleMember -Function 'Get-ProjectManagementScreen', 'Get-AddProjectScreen'
