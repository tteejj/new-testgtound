# TUI Component Library v3.1
# A library of stateless, declarative components for building robust TUIs.

#region Base Component & Container

function global:New-TuiComponent {
    param([hashtable]$Props = @{})

    $component = @{
        Name        = $Props.Name ?? "comp_$(Get-Random)"
        Type        = "Component"
        IsFocusable = $false
        Children    = @()
        Visible     = if ($Props.ContainsKey('Visible')) { $Props.Visible } else { $true }
        X           = $Props.X ?? 0
        Y           = $Props.Y ?? 0
        Width       = $Props.Width ?? 10
        Height      = $Props.Height ?? 1
        
        # Default Methods
        Render      = { param($self) }
        HandleInput = { param($self, $Key) return $false }
        Clone       = { param($self) $self.Clone() }
    }
    
    foreach ($key in $Props.Keys) { 
        $component[$key] = $Props[$key] 
    }
    return $component
}

function global:New-TuiForm {
    param([hashtable]$Props = @{})
    $form = New-TuiComponent -Props $Props
    $form.Type = "Form"
    
    $form.Render = {
        param($self)
        if (-not $self.Visible) { return }
        
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
            -Title $self.Title -BorderColor (Get-ThemeColor "Accent")
        
        foreach ($child in $self.Children) {
            if ($child.Visible) {
                # Create a temporary clone with absolute coordinates
                $childToRender = $child.Clone()
                $childToRender.X += $self.X + ($self.Padding ?? 1)
                $childToRender.Y += $self.Y + ($self.Padding ?? 1)
                
                # Pass state to the child
                $childToRender.IsFocused = ($self.State.FocusedChildName -eq $child.Name)
                if ($child.TextProp -and $self.State.ContainsKey($child.TextProp)) { 
                    $childToRender.Text = $self.State.($child.TextProp) 
                }
                if ($child.CursorProp -and $self.State.ContainsKey($child.CursorProp)) { 
                    $childToRender.CursorPosition = $self.State.($child.CursorProp) 
                }
                if ($child.ValueProp -and $self.State.ContainsKey($child.ValueProp)) { 
                    $childToRender.Value = $self.State.($child.ValueProp) 
                }

                & $childToRender.Render -self $childToRender
            }
        }
    }

    $form.HandleInput = {
        param($self, $Key)
        $state = $self.State
        
        $focusableChildren = @($self.Children | Where-Object { $_.IsFocusable -and $_.Visible })
        if ($focusableChildren.Count -eq 0) { return $false }

        if ($Key.Key -eq [ConsoleKey]::Tab) {
            $currentIndex = [array]::IndexOf($focusableChildren.Name, $state.FocusedChildName)
            if ($currentIndex -eq -1) { $currentIndex = 0 }
            
            $direction = if ($Key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
            $nextIndex = ($currentIndex + $direction + $focusableChildren.Count) % $focusableChildren.Count
            
            if ($self.OnFocusChange) { 
                & $self.OnFocusChange -NewFocusedChildName $focusableChildren[$nextIndex].Name 
            }
            return $true
        }
        
        $focusedChild = $focusableChildren | Where-Object { $_.Name -eq $state.FocusedChildName } | Select-Object -First 1
        if ($focusedChild) {
            # Clone and set state
            $childClone = $focusedChild.Clone()
            $childClone.IsFocused = $true
            if ($focusedChild.TextProp -and $state.ContainsKey($focusedChild.TextProp)) { 
                $childClone.Text = $state.($focusedChild.TextProp) 
            }
            if ($focusedChild.CursorProp -and $state.ContainsKey($focusedChild.CursorProp)) { 
                $childClone.CursorPosition = $state.($focusedChild.CursorProp) 
            }
            if ($focusedChild.ValueProp -and $state.ContainsKey($focusedChild.ValueProp)) { 
                $childClone.Value = $state.($focusedChild.ValueProp) 
            }

            # Set callbacks
            foreach ($prop in $focusedChild.Keys) {
                if ($prop -like "On*" -and $focusedChild[$prop] -is [scriptblock]) {
                    $childClone[$prop] = $focusedChild[$prop]
                }
            }

            return & $childClone.HandleInput -self $childClone -Key $Key
        }
        return $false
    }
    return $form
}

#endregion

#region All Concrete Components

function global:New-TuiLabel {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Label"
    $component.Render = { 
        param($self) 
        Write-BufferString -X $self.X -Y $self.Y -Text $self.Text -ForegroundColor (Get-ThemeColor "Primary")
    }
    return $component
}

function global:New-TuiButton {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Button"
    $component.IsFocusable = $true
    $component.Height = 3
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        $bgColor = if ($self.IsPressed) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
        $fgColor = if ($self.IsPressed) { Get-ThemeColor "Background" } else { Get-ThemeColor "Primary" }
        
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
            -BorderColor $borderColor -BackgroundColor $bgColor
            
        $textX = $self.X + [Math]::Floor(($self.Width - $self.Text.Length) / 2)
        Write-BufferString -X $textX -Y ($self.Y + 1) -Text $self.Text `
            -ForegroundColor $fgColor -BackgroundColor $bgColor
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            if ($self.OnClick) { & $self.OnClick }
            return $true
        }
        return $false
    }
    return $component
}

function global:New-TuiTextBox {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "TextBox"
    $component.IsFocusable = $true
    $component.Height = 3

    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        
        $displayText = $self.Text ?? ""
        $cursorPos = $self.CursorPosition ?? 0
        
        if ([string]::IsNullOrEmpty($displayText) -and -not $self.IsFocused -and $self.Placeholder) { 
            Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $self.Placeholder `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        else {
            # Handle text scrolling if text is longer than display width
            $displayWidth = $self.Width - 4
            $scrollOffset = 0
            
            if ($cursorPos > $displayWidth - 1) {
                $scrollOffset = $cursorPos - $displayWidth + 1
            }
            
            $visibleText = if ($displayText.Length -gt $scrollOffset) {
                $displayText.Substring($scrollOffset, [Math]::Min($displayWidth, $displayText.Length - $scrollOffset))
            } else { "" }
            
            Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $visibleText
            
            # Draw cursor if focused
            if ($self.IsFocused) {
                $cursorX = $self.X + 2 + ($cursorPos - $scrollOffset)
                if ($cursorX -ge ($self.X + 2) -and $cursorX -lt ($self.X + $self.Width - 2)) {
                    Write-BufferString -X $cursorX -Y ($self.Y + 1) -Text "_" `
                        -ForegroundColor (Get-ThemeColor "Background") `
                        -BackgroundColor (Get-ThemeColor "Accent")
                }
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        $text = $self.Text ?? ""
        $cursorPos = $self.CursorPosition ?? 0
        $oldText = $text
        $handled = $true

        switch ($Key.Key) {
            ([ConsoleKey]::Backspace) { 
                if ($cursorPos -gt 0) { 
                    $text = $text.Remove($cursorPos - 1, 1)
                    $cursorPos-- 
                } 
            }
            ([ConsoleKey]::Delete) { 
                if ($cursorPos -lt $text.Length) { 
                    $text = $text.Remove($cursorPos, 1) 
                } 
            }
            ([ConsoleKey]::LeftArrow) { 
                if ($cursorPos -gt 0) { $cursorPos-- } 
            }
            ([ConsoleKey]::RightArrow) { 
                if ($cursorPos -lt $text.Length) { $cursorPos++ } 
            }
            ([ConsoleKey]::Home) { 
                $cursorPos = 0 
            }
            ([ConsoleKey]::End) { 
                $cursorPos = $text.Length 
            }
            default {
                if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                    $text = $text.Insert($cursorPos, $Key.KeyChar)
                    $cursorPos++
                } else { 
                    $handled = $false 
                }
            }
        }
        
        if ($handled -and $self.OnChange) {
            & $self.OnChange -NewText $text -NewCursorPosition $cursorPos
        }
        return $handled
    }
    return $component
}

function global:New-TuiDropdown {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Dropdown"
    $component.IsFocusable = $true
    $component.Height = 3
    $component.IsOpen = $false
    $component.SelectedIndex = 0
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        
        # Draw the main box
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        
        # Display selected item or placeholder
        $displayText = if ($self.Value -and $self.Options) {
            $selected = $self.Options | Where-Object { $_.Value -eq $self.Value } | Select-Object -First 1
            if ($selected) { $selected.Display } else { "Select..." }
        } else { "Select..." }
        
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $displayText
        Write-BufferString -X ($self.X + $self.Width - 3) -Y ($self.Y + 1) -Text "▼" -ForegroundColor $borderColor
        
        # Draw dropdown list if open
        if ($self.IsOpen -and $self.Options -and $self.Options.Count -gt 0) {
            $dropHeight = [Math]::Min($self.Options.Count + 2, 10)
            Write-BufferBox -X $self.X -Y ($self.Y + 2) -Width $self.Width -Height $dropHeight `
                -BorderColor (Get-ThemeColor "Accent") -BackgroundColor (Get-ThemeColor "Background")
            
            $startIdx = [Math]::Max(0, $self.SelectedIndex - 4)
            $endIdx = [Math]::Min($self.Options.Count - 1, $startIdx + $dropHeight - 3)
            
            for ($i = $startIdx; $i -le $endIdx; $i++) {
                $item = $self.Options[$i]
                $yPos = ($self.Y + 3) + ($i - $startIdx)
                
                if ($i -eq $self.SelectedIndex) {
                    # Highlight selected item
                    Write-BufferString -X ($self.X + 1) -Y $yPos `
                        -Text (" " * ($self.Width - 2)) -BackgroundColor (Get-ThemeColor "Accent")
                    Write-BufferString -X ($self.X + 2) -Y $yPos -Text $item.Display `
                        -ForegroundColor (Get-ThemeColor "Background") -BackgroundColor (Get-ThemeColor "Accent")
                } else {
                    Write-BufferString -X ($self.X + 2) -Y $yPos -Text $item.Display
                }
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if (-not $self.Options -or $self.Options.Count -eq 0) { return $false }
        
        $handled = $true
        
        if ($self.IsOpen) {
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.SelectedIndex -gt 0) { 
                        $self.SelectedIndex-- 
                        Request-TuiRefresh
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.SelectedIndex -lt $self.Options.Count - 1) { 
                        $self.SelectedIndex++ 
                        Request-TuiRefresh
                    }
                }
                ([ConsoleKey]::Enter) {
                    $selectedValue = $self.Options[$self.SelectedIndex].Value
                    $self.IsOpen = $false
                    if ($self.OnChange) {
                        & $self.OnChange -NewValue $selectedValue
                    }
                }
                ([ConsoleKey]::Escape) {
                    $self.IsOpen = $false
                    Request-TuiRefresh
                }
                default { $handled = $false }
            }
        } else {
            if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar, [ConsoleKey]::DownArrow)) {
                $self.IsOpen = $true
                # Find current value in options
                if ($self.Value) {
                    for ($i = 0; $i -lt $self.Options.Count; $i++) {
                        if ($self.Options[$i].Value -eq $self.Value) {
                            $self.SelectedIndex = $i
                            break
                        }
                    }
                }
                Request-TuiRefresh
            } else {
                $handled = $false
            }
        }
        
        return $handled
    }
    
    return $component
}

function global:New-TuiCheckBox {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "CheckBox"
    $component.IsFocusable = $true
    $component.Checked = $Props.Checked ?? $false
    
    $component.Render = {
        param($self)
        $checkbox = if ($self.Checked) { "[X]" } else { "[ ]" }
        $fgColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        
        Write-BufferString -X $self.X -Y $self.Y -Text "$checkbox $($self.Text)" -ForegroundColor $fgColor
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            if ($self.OnChange) {
                & $self.OnChange -NewValue (-not $self.Checked)
            }
            return $true
        }
        return $false
    }
    
    return $component
}

function global:New-TuiRadioButton {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "RadioButton"
    $component.IsFocusable = $true
    $component.Selected = $Props.Selected ?? $false
    
    $component.Render = {
        param($self)
        $radio = if ($self.Selected) { "(•)" } else { "( )" }
        $fgColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        
        Write-BufferString -X $self.X -Y $self.Y -Text "$radio $($self.Text)" -ForegroundColor $fgColor
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            if ($self.OnSelect -and -not $self.Selected) {
                & $self.OnSelect -Value $self.Value
            }
            return $true
        }
        return $false
    }
    
    return $component
}

function global:New-TuiProgressBar {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "ProgressBar"
    $component.Value = $Props.Value ?? 0
    $component.Maximum = $Props.Maximum ?? 100
    
    $component.Render = {
        param($self)
        $percentage = [Math]::Min(100, [Math]::Max(0, ($self.Value / $self.Maximum) * 100))
        $filledWidth = [Math]::Floor(($self.Width - 2) * ($percentage / 100))
        $emptyWidth = ($self.Width - 2) - $filledWidth
        
        $bar = "█" * $filledWidth + "░" * $emptyWidth
        Write-BufferString -X $self.X -Y $self.Y -Text "[$bar]" -ForegroundColor (Get-ThemeColor "Accent")
        
        if ($self.ShowPercentage) {
            $percentText = "$([Math]::Round($percentage))%"
            $textX = $self.X + [Math]::Floor(($self.Width - $percentText.Length) / 2)
            Write-BufferString -X $textX -Y $self.Y -Text $percentText -ForegroundColor (Get-ThemeColor "Primary")
        }
    }
    
    return $component
}

#endregion

Export-ModuleMember -Function @(
    'New-TuiComponent', 'New-TuiForm', 'New-TuiLabel', 'New-TuiButton', 
    'New-TuiTextBox', 'New-TuiDropdown', 'New-TuiCheckBox', 
    'New-TuiRadioButton', 'New-TuiProgressBar'
)
