# Timer Start Screen - For starting a new timer

function Get-TimerStartScreen {
    $screen = @{
        Name = "TimerStartScreen"
        State = @{
            SelectedProject = $null
            Description = ""
            DescriptionCursor = 0
            FocusedChildName = "project_dropdown"
        }
        
        Init = {
            param($self)
            
            # Create the form container once
            $self.FormContainer = New-TuiForm -Props @{
                X = ([Math]::Floor(($script:TuiState.BufferWidth - 50) / 2))
                Y = 6
                Width = 50
                Height = 16
                Title = " Start Timer "
                Padding = 2
                Children = @(
                    New-TuiLabel -Props @{
                        Name = "project_label"
                        X = 0
                        Y = 0
                        Text = "Select Project:"
                    }
                    New-TuiDropdown -Props @{
                        Name = "project_dropdown"
                        X = 0
                        Y = 1
                        Width = 46
                        Options = @($script:Data.Projects.GetEnumerator() | 
                            Where-Object { $_.Value.IsActive } |
                            ForEach-Object { 
                                @{ Value = $_.Key; Display = $_.Value.Name } 
                            })
                        ValueProp = "SelectedProject"
                        OnChange = { 
                            param($NewValue) 
                            $screen.State.SelectedProject = $NewValue
                            Request-TuiRefresh 
                        }
                    }
                    New-TuiLabel -Props @{
                        Name = "description_label"
                        X = 0
                        Y = 4
                        Text = "Description (optional):"
                    }
                    New-TuiTextBox -Props @{
                        Name = "description_textbox"
                        X = 0
                        Y = 5
                        Width = 46
                        Placeholder = "What are you working on?"
                        TextProp = "Description"
                        CursorProp = "DescriptionCursor"
                        OnChange = { 
                            param($NewText, $NewCursorPosition) 
                            $screen.State.Description = $NewText
                            $screen.State.DescriptionCursor = $NewCursorPosition
                            Request-TuiRefresh 
                        }
                    }
                    New-TuiButton -Props @{
                        Name = "start_button"
                        X = 0
                        Y = 9
                        Width = 12
                        Text = "Start"
                        OnClick = {
                            if ($screen.State.SelectedProject) {
                                Publish-Event -EventName "Timer.Start" -Data @{
                                    ProjectKey = $screen.State.SelectedProject
                                    Description = $screen.State.Description
                                }
                                Pop-Screen | Out-Null
                            } else {
                                Publish-Event -EventName "Notification.Show" -Data @{
                                    Text = "Please select a project"
                                    Type = "Warning"
                                }
                            }
                        }
                    }
                    New-TuiButton -Props @{
                        Name = "cancel_button"
                        X = 14
                        Y = 9
                        Width = 12
                        Text = "Cancel"
                        OnClick = { Pop-Screen | Out-Null }
                    }
                )
                OnFocusChange = { 
                    param($NewFocusedChildName) 
                    $screen.State.FocusedChildName = $NewFocusedChildName
                    Request-TuiRefresh 
                }
            }
        }
        
        Render = {
            param($self)
            $self.FormContainer.State = $self.State
            & $self.FormContainer.Render -self $self.FormContainer
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                return "Back"
            }
            
            $self.FormContainer.State = $self.State
            return & $self.FormContainer.HandleInput -self $self.FormContainer -Key $Key
        }
    }
    
    return $screen
}

Export-ModuleMember -Function 'Get-TimerStartScreen'
