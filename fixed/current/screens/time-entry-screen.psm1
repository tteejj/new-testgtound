# Time Entry Form Screen Module - Demonstrates new declarative form pattern

function global:Get-TimeEntryFormScreen {
    $formScreen = @{
        Name = "TimeEntryFormScreen"
        State = @{
            Project = $null
            Hours = ""
            Description = ""
            Date = (Get-Date).ToString("yyyy-MM-dd")
            FocusedField = "project"
            ValidationErrors = @{}
        }
        
        Init = {
            param($self)
            # Pre-populate with project from context if available
            if ($script:ContextData -and $script:ContextData.ProjectKey) {
                $self.State.Project = $script:ContextData.ProjectKey
                $self.State.FocusedField = "hours"
            }
        }
        
        Render = {
            param($self)
            
            # Center the form
            $formWidth = 60
            $formHeight = 20
            $formX = [Math]::Floor(($script:TuiState.BufferWidth - $formWidth) / 2)
            $formY = [Math]::Floor(($script:TuiState.BufferHeight - $formHeight) / 2)
            
            # Main form container
            Write-BufferBox -X $formX -Y $formY -Width $formWidth -Height $formHeight -Title " Add Time Entry " -BorderColor (Get-ThemeColor "Accent")
            
            $fieldX = $formX + 3
            $currentY = $formY + 3
            
            # Project selection
            $self.RenderFormField("Project/Template:", $fieldX, $currentY, "project")
            if ($self.State.Project) {
                $project = Get-ProjectOrTemplate $self.State.Project
                if ($project) {
                    Write-BufferString -X ($fieldX + 18) -Y $currentY -Text $project.Name -ForegroundColor (Get-ThemeColor "Success")
                } else {
                    Write-BufferString -X ($fieldX + 18) -Y $currentY -Text "Invalid Project" -ForegroundColor (Get-ThemeColor "Error")
                }
            } else {
                Write-BufferString -X ($fieldX + 18) -Y $currentY -Text "[Select Project]" -ForegroundColor (Get-ThemeColor "Subtle")
            }
            $currentY += 3
            
            # Hours input
            $self.RenderFormField("Hours:", $fieldX, $currentY, "hours")
            $self.RenderTextInput($fieldX + 18, $currentY, 20, $self.State.Hours, "hours")
            if ($self.State.ValidationErrors.Hours) {
                Write-BufferString -X ($fieldX + 18) -Y ($currentY + 1) -Text $self.State.ValidationErrors.Hours -ForegroundColor (Get-ThemeColor "Error")
            }
            $currentY += 3
            
            # Description input
            $self.RenderFormField("Description:", $fieldX, $currentY, "description")
            $self.RenderTextInput($fieldX + 18, $currentY, 35, $self.State.Description, "description")
            $currentY += 3
            
            # Date input
            $self.RenderFormField("Date:", $fieldX, $currentY, "date")
            $self.RenderTextInput($fieldX + 18, $currentY, 12, $self.State.Date, "date")
            $currentY += 4
            
            # Action buttons
            $buttonY = $formY + $formHeight - 4
            $self.RenderButton($fieldX + 15, $buttonY, "Submit", "submit")
            $self.RenderButton($fieldX + 30, $buttonY, "Cancel", "cancel")
            
            # Instructions
            Write-BufferString -X $fieldX -Y ($formY + $formHeight - 2) -Text "Tab: Next Field • Enter: Submit • Esc: Cancel" -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            
            # Global navigation
            switch ($Key.Key) {
                ([ConsoleKey]::Escape) { return "Back" }
                ([ConsoleKey]::Tab) {
                    $fields = @("project", "hours", "description", "date", "submit", "cancel")
                    $currentIndex = [array]::IndexOf($fields, $self.State.FocusedField)
                    $direction = if ($Key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
                    $newIndex = ($currentIndex + $direction + $fields.Count) % $fields.Count
                    $self.State.FocusedField = $fields[$newIndex]
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($self.State.FocusedField -eq "submit") {
                        return $self.SubmitForm()
                    } elseif ($self.State.FocusedField -eq "cancel") {
                        return "Back"
                    } elseif ($self.State.FocusedField -eq "project") {
                        if (Get-Command -Name "Get-ProjectSelectorScreen" -ErrorAction SilentlyContinue) {
                            Push-Screen -Screen (Get-ProjectSelectorScreen -OnSelect { 
                                param($ProjectKey) 
                                $self.State.Project = $ProjectKey
                                Pop-Screen
                            })
                        } else {
                            # Simple project input dialog
                            Show-InputDialog -Data @{
                                Title = "Enter Project Key"
                                Prompt = "Project key (e.g., PROJ1):"
                                OnSubmit = {
                                    param($value)
                                    $self.State.Project = $value
                                    Request-TuiRefresh
                                }
                            }
                        }
                        return $true
                    }
                }
            }
            
            # Field-specific input handling
            switch ($self.State.FocusedField) {
                "hours" {
                    return $self.HandleTextInput($Key, "Hours")
                }
                "description" {
                    return $self.HandleTextInput($Key, "Description")
                }
                "date" {
                    return $self.HandleDateInput($Key)
                }
            }
            
            return $false
        }
        
        # Helper methods
        RenderFormField = {
            param($label, $x, $y, $fieldName)
            $color = if ($this.State.FocusedField -eq $fieldName) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
            Write-BufferString -X $x -Y $y -Text $label -ForegroundColor $color
        }
        
        RenderTextInput = {
            param($x, $y, $width, $text, $fieldName)
            $isFocused = ($this.State.FocusedField -eq $fieldName)
            $borderColor = if ($isFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            
            # Input box
            Write-BufferString -X $x -Y $y -Text ("[" + $text.PadRight($width - 2) + "]") -ForegroundColor $borderColor
            
            # Cursor
            if ($isFocused) {
                $cursorX = $x + 1 + $text.Length
                if ($cursorX -lt $x + $width - 1) {
                    Write-BufferString -X $cursorX -Y $y -Text "_" -ForegroundColor (Get-ThemeColor "Warning")
                }
            }
        }
        
        RenderButton = {
            param($x, $y, $text, $buttonName)
            $isFocused = ($this.State.FocusedField -eq $buttonName)
            $color = if ($isFocused) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
            $prefix = if ($isFocused) { "[" } else { " " }
            $suffix = if ($isFocused) { "]" } else { " " }
            Write-BufferString -X $x -Y $y -Text "$prefix$text$suffix" -ForegroundColor $color
        }
        
        HandleTextInput = {
            param($key, $fieldName)
            $text = $this.State.$fieldName
            
            switch ($key.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($text.Length -gt 0) {
                        $this.State.$fieldName = $text.Substring(0, $text.Length - 1)
                        $this.State.ValidationErrors.Remove($fieldName)
                    }
                }
                default {
                    if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                        $this.State.$fieldName = $text + $key.KeyChar
                        $this.State.ValidationErrors.Remove($fieldName)
                    }
                }
            }
            return $true
        }
        
        HandleDateInput = {
            param($key)
            # Special handling for date format validation
            return $this.HandleTextInput($key, "Date")
        }
        
        SubmitForm = {
            # Clear previous validation errors
            $this.State.ValidationErrors = @{}
            
            # Validation
            if (-not $this.State.Project) {
                $this.State.ValidationErrors.Project = "Project is required"
                $this.State.FocusedField = "project"
                return $true
            }
            
            $hours = 0.0
            if (-not [double]::TryParse($this.State.Hours, [ref]$hours) -or $hours -le 0) {
                $this.State.ValidationErrors.Hours = "Valid hours required (e.g., 2.5)"
                $this.State.FocusedField = "hours"
                return $true
            }
            
            try {
                $date = [DateTime]::Parse($this.State.Date)
            } catch {
                $this.State.ValidationErrors.Date = "Invalid date format"
                $this.State.FocusedField = "date"
                return $true
            }
            
            # If validation passes, publish the event
            Publish-Event -EventName "Data.Create.TimeEntry" -Data @{
                Project = $this.State.Project
                Hours = $hours
                Description = $this.State.Description
                Date = $date.ToString("yyyy-MM-dd")
            }
            
            return "Back"
        }
    }
    
    return $formScreen
}

# Export module members
Export-ModuleMember -Function 'Get-TimeEntryFormScreen'