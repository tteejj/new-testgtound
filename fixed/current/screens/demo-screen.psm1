# Demo Screen - Component Showcase
# Demonstrates all available TUI components

function global:Get-DemoScreen {
    $screen = @{
        Name = "DemoScreen"
        
        # 1. State: Central data model for the screen
        State = @{
            textValue = "Hello, World!"
            selectedOption = "Option 1"
            checkboxValue = $false
            progress = 50
            dateValue = Get-Date
        }
        
        # 2. Components: Storage for instantiated component objects
        Components = @{}
        
        # 3. Init: One-time setup
        Init = {
            param($self)
            
            # Title
            $self.Components.titleLabel = New-TuiLabel -Props @{
                X = 2; Y = 1
                Text = "TUI Component Demo"
            }
            
            # Text input demo
            $self.Components.textInput = New-TuiTextBox -Props @{
                X = 2; Y = 4; Width = 30; Height = 3
                Text = $self.State.textValue
                Placeholder = "Enter some text..."
                OnChange = { param($NewValue) $self.State.textValue = $NewValue }
            }
            
            # Button demo
            $self.Components.demoButton = New-TuiButton -Props @{
                X = 35; Y = 4; Width = 15; Height = 3
                Text = "Click Me"
                OnClick = {
                    Show-AlertDialog -Title "Demo" -Message "Button clicked! Text: $($self.State.textValue)"
                }
            }
            
            # Checkbox demo
            $self.Components.demoCheckbox = New-TuiCheckBox -Props @{
                X = 2; Y = 9
                Text = "Enable feature"
                Checked = $self.State.checkboxValue
                OnChange = { param($NewValue) $self.State.checkboxValue = $NewValue }
            }
            
            # Dropdown demo
            $self.Components.demoDropdown = New-TuiDropdown -Props @{
                X = 2; Y = 12; Width = 25; Height = 3
                Options = @(
                    @{ Display = "Option 1"; Value = "opt1" }
                    @{ Display = "Option 2"; Value = "opt2" }
                    @{ Display = "Option 3"; Value = "opt3" }
                )
                Value = "opt1"
                OnChange = { param($NewValue) $self.State.selectedOption = $NewValue }
            }
            
            # Progress bar demo
            $self.Components.demoProgress = New-TuiProgressBar -Props @{
                X = 2; Y = 17; Width = 40
                Value = $self.State.progress
                Max = 100
                ShowPercent = $true
            }
            
            # Date picker demo
            $self.Components.demoDatePicker = New-TuiDatePicker -Props @{
                X = 45; Y = 12; Width = 25; Height = 3
                Value = $self.State.dateValue
                OnChange = { param($NewValue) $self.State.dateValue = $NewValue }
            }
            
            # Back button
            $self.Components.backButton = New-TuiButton -Props @{
                X = 2; Y = 20; Width = 15; Height = 3
                Text = "Back"
                OnClick = { Pop-Screen }
            }
            
            # Focus management
            $self.FocusableComponents = @("textInput", "demoButton", "demoCheckbox", "demoDropdown", "demoDatePicker", "backButton")
            $self.FocusedComponentName = "textInput"
        }
        
        # 4. Render: Draw the screen and its components
        Render = {
            param($self)
            
            # Update progress bar animation
            $self.Components.demoProgress.Value = ($self.Components.demoProgress.Value + 1) % 101
            
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
            
            # Status info
            Write-BufferString -X 2 -Y 25 -Text "State Values:" -ForegroundColor (Get-ThemeColor "Header")
            Write-BufferString -X 2 -Y 26 -Text "Text: $($self.State.textValue)" -ForegroundColor (Get-ThemeColor "Subtle")
            Write-BufferString -X 2 -Y 27 -Text "Checkbox: $($self.State.checkboxValue)" -ForegroundColor (Get-ThemeColor "Subtle")
            Write-BufferString -X 2 -Y 28 -Text "Selected: $($self.State.selectedOption)" -ForegroundColor (Get-ThemeColor "Subtle")
            Write-BufferString -X 2 -Y 29 -Text "Date: $($self.State.dateValue.ToString('yyyy-MM-dd'))" -ForegroundColor (Get-ThemeColor "Subtle")
            
            # Instructions
            $statusY = $global:TuiState.BufferHeight - 2
            Write-BufferString -X 2 -Y $statusY -Text "Tab: Next Field • Enter: Interact • Esc: Back" -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        # 5. HandleInput: Global input handling for the screen
        HandleInput = {
            param($self, $Key)
            
            # Screen-level shortcuts
            switch ($Key.Key) {
                ([ConsoleKey]::Escape) { return "Back" }
                ([ConsoleKey]::Tab) {
                    # Cycle through focusable components
                    $currentIndex = [array]::IndexOf($self.FocusableComponents, $self.FocusedComponentName)
                    if ($currentIndex -eq -1) { $currentIndex = 0 }
                    
                    $direction = if ($Key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
                    $nextIndex = ($currentIndex + $direction + $self.FocusableComponents.Count) % $self.FocusableComponents.Count
                    $self.FocusedComponentName = $self.FocusableComponents[$nextIndex]
                    Request-TuiRefresh
                    return $true
                }
            }
            
            # Delegate to focused component
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
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DemoScreen
