# Time Entry Form Screen - Built with the v3.0 Framework

function Get-TimeEntryFormScreen {
    $formScreen = @{
        Name = "TimeEntryFormScreen"
        State = @{
            Project         = $null
            Hours           = ""
            Description     = ""
            HoursCursor     = 0
            DescriptionCursor = 0
            FocusedChildName = "project_dropdown"
        }
        
        # Fixed: Create form container ONCE in Init
        Init = {
            param($self)
            
            # Create the persistent form container
            $self.FormContainer = New-TuiForm -Props @{
                X = ([Math]::Floor(($script:TuiState.BufferWidth - 60) / 2))
                Y = 4
                Width = 60
                Height = 20
                Title = " Add Time Entry "
                Padding = 2
                Children = @(
                    New-TuiLabel -Props @{
                        Name = "project_label"
                        X = 0
                        Y = 0
                        Text = "Project:"
                    }
                    New-TuiDropdown -Props @{
                        Name = "project_dropdown"
                        X = 0
                        Y = 1
                        Width = 56
                        Options = @($script:Data.Projects.GetEnumerator() | ForEach-Object { 
                            @{ Value = $_.Key; Display = $_.Value.Name } 
                        })
                        ValueProp = "Project"
                        OnChange = { 
                            param($NewValue) 
                            $formScreen.State.Project = $NewValue
                            Request-TuiRefresh 
                        }
                    }
                    New-TuiLabel -Props @{
                        Name = "hours_label"
                        X = 0
                        Y = 4
                        Text = "Hours:"
                    }
                    New-TuiTextBox -Props @{
                        Name = "hours_textbox"
                        X = 0
                        Y = 5
                        Width = 56
                        Placeholder = "e.g., 2.5"
                        TextProp = "Hours"
                        CursorProp = "HoursCursor"
                        OnChange = { 
                            param($NewText, $NewCursorPosition) 
                            $formScreen.State.Hours = $NewText
                            $formScreen.State.HoursCursor = $NewCursorPosition
                            Request-TuiRefresh 
                        }
                    }
                    New-TuiLabel -Props @{
                        Name = "description_label"
                        X = 0
                        Y = 8
                        Text = "Description:"
                    }
                    New-TuiTextBox -Props @{
                        Name = "description_textbox"
                        X = 0
                        Y = 9
                        Width = 56
                        Placeholder = "Work details..."
                        TextProp = "Description"
                        CursorProp = "DescriptionCursor"
                        OnChange = { 
                            param($NewText, $NewCursorPosition) 
                            $formScreen.State.Description = $NewText
                            $formScreen.State.DescriptionCursor = $NewCursorPosition
                            Request-TuiRefresh 
                        }
                    }
                    New-TuiButton -Props @{
                        Name = "submit_button"
                        X = 0
                        Y = 13
                        Width = 12
                        Text = "Submit"
                        OnClick = {
                            Publish-Event -EventName "Data.Create.TimeEntry" -Data @{
                                Project = $formScreen.State.Project
                                Hours = $formScreen.State.Hours
                                Description = $formScreen.State.Description
                            }
                        }
                    }
                    New-TuiButton -Props @{
                        Name = "cancel_button"
                        X = 14
                        Y = 13
                        Width = 12
                        Text = "Cancel"
                        OnClick = { Pop-Screen | Out-Null }
                    }
                )
                OnFocusChange = { 
                    param($NewFocusedChildName) 
                    $formScreen.State.FocusedChildName = $NewFocusedChildName
                    Request-TuiRefresh 
                }
            }
        }
        
        # Fixed: Render now just updates state and delegates
        Render = {
            param($self)
            $self.FormContainer.State = $self.State
            & $self.FormContainer.Render -self $self.FormContainer
        }
        
        # Fixed: HandleInput updates state and delegates
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) {
                return "Back"
            }
            
            $self.FormContainer.State = $self.State
            return & $self.FormContainer.HandleInput -self $self.FormContainer -Key $Key
        }
    }
    
    return $formScreen
}

Export-ModuleMember -Function 'Get-TimeEntryFormScreen'
