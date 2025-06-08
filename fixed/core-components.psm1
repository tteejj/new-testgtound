# Core Components Library for TUI Engine v2
# Provides reusable, declarative components built on the enhanced TUI engine

#region Label Component

function global:New-TuiLabel {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "Label"
    $component.Height = 1
    $component.Text = $Props.Text ?? ""
    $component.Alignment = $Props.Alignment ?? "Left"  # Left, Center, Right
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible -or [string]::IsNullOrEmpty($self.Text)) { return }
        
        # Get absolute position
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Calculate text position based on alignment
        $textX = $pos.X
        switch ($self.Alignment) {
            "Center" { $textX = $pos.X + [Math]::Floor(($self.Width - $self.Text.Length) / 2) }
            "Right" { $textX = $pos.X + $self.Width - $self.Text.Length }
        }
        
        # Clip text if too long
        $displayText = $self.Text
        if ($displayText.Length -gt $self.Width) {
            $displayText = $displayText.Substring(0, $self.Width - 3) + "..."
        }
        
        $color = if ($self.ForegroundColor) { $self.ForegroundColor } else { Get-ThemeColor "Primary" }
        $bgColor = if ($self.BackgroundColor) { $self.BackgroundColor } else { Get-ThemeColor "Background" }
        
        Write-BufferString -X $textX -Y $pos.Y -Text $displayText `
            -ForegroundColor $color -BackgroundColor $bgColor
    }
    
    return $component
}

#endregion

#region Button Component

function global:New-TuiButton {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "Button"
    $component.Height = 3
    $component.Text = $Props.Text ?? "Button"
    $component.OnClick = $Props.OnClick
    $component.IsFocusable = $true
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Determine colors based on state
        $borderColor = if ($self.Focused) { Get-ThemeColor "Accent" } 
                      elseif ($self.Hovered) { Get-ThemeColor "Secondary" }
                      else { Get-ThemeColor "Primary" }
        
        $bgColor = if ($self.Pressed) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
        
        # Draw button box
        Write-BufferBox -X $pos.X -Y $pos.Y -Width $self.Width -Height $self.Height `
            -BorderColor $borderColor -BackgroundColor $bgColor -BorderStyle "Single"
        
        # Center text
        $textX = $pos.X + [Math]::Floor(($self.Width - $self.Text.Length) / 2)
        $textY = $pos.Y + 1
        
        Write-BufferString -X $textX -Y $textY -Text $self.Text `
            -ForegroundColor $borderColor -BackgroundColor $bgColor
    }
    
    $component.HandleInput = {
        param($self, $Key)
        
        if ($Key.Key -eq [ConsoleKey]::Enter -or $Key.Key -eq [ConsoleKey]::Spacebar) {
            $self.Pressed = $true
            
            # Execute callback
            if ($self.OnClick) {
                & $self.OnClick -Button $self
            }
            
            # Publish event
            Publish-TuiEvent -EventName "Component.ButtonClick" -Data @{ Component = $self }
            
            # Visual feedback
            $self.Pressed = $false
            
            return $true
        }
        
        return $false
    }
    
    $component.OnFocus = {
        param($self)
        $self.Focused = $true
    }
    
    $component.OnBlur = {
        param($self)
        $self.Focused = $false
    }
    
    return $component
}

#endregion

#region TextBox Component

function global:New-TuiTextBox {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "TextBox"
    $component.Height = 3
    $component.Text = $Props.Text ?? ""
    $component.PlaceHolder = $Props.PlaceHolder ?? ""
    $component.MaxLength = $Props.MaxLength ?? 100
    $component.PasswordChar = $Props.PasswordChar ?? $null
    $component.OnChange = $Props.OnChange
    $component.IsFocusable = $true
    $component.CursorPosition = $component.Text.Length
    $component.ScrollOffset = 0
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Border color based on focus
        $borderColor = if ($self.Focused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        
        # Draw box
        Write-BufferBox -X $pos.X -Y $pos.Y -Width $self.Width -Height $self.Height `
            -BorderColor $borderColor -BackgroundColor (Get-ThemeColor "Background")
        
        # Calculate visible text
        $displayText = $self.Text
        if ($self.PasswordChar) {
            $displayText = $self.PasswordChar * $displayText.Length
        }
        
        # Handle empty text
        if ([string]::IsNullOrEmpty($displayText) -and -not $self.Focused) {
            $displayText = $self.PlaceHolder
            $textColor = Get-ThemeColor "Subtle"
        } else {
            $textColor = Get-ThemeColor "Primary"
        }
        
        # Calculate scroll
        $maxVisibleChars = $self.Width - 4
        if ($self.Focused) {
            # Ensure cursor is visible
            if ($self.CursorPosition - $self.ScrollOffset >= $maxVisibleChars) {
                $self.ScrollOffset = $self.CursorPosition - $maxVisibleChars + 1
            } elseif ($self.CursorPosition < $self.ScrollOffset) {
                $self.ScrollOffset = $self.CursorPosition
            }
        }
        
        # Get visible portion
        if ($displayText.Length -gt $self.ScrollOffset) {
            $visibleText = $displayText.Substring($self.ScrollOffset)
            if ($visibleText.Length -gt $maxVisibleChars) {
                $visibleText = $visibleText.Substring(0, $maxVisibleChars)
            }
        } else {
            $visibleText = ""
        }
        
        # Draw text
        Write-BufferString -X ($pos.X + 2) -Y ($pos.Y + 1) -Text $visibleText `
            -ForegroundColor $textColor -BackgroundColor (Get-ThemeColor "Background")
        
        # Draw cursor if focused
        if ($self.Focused) {
            $cursorScreenPos = $self.CursorPosition - $self.ScrollOffset
            if ($cursorScreenPos -ge 0 -and $cursorScreenPos -le $maxVisibleChars) {
                $cursorX = $pos.X + 2 + $cursorScreenPos
                Write-BufferString -X $cursorX -Y ($pos.Y + 1) -Text "_" `
                    -ForegroundColor (Get-ThemeColor "Accent") -BackgroundColor (Get-ThemeColor "Background")
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        
        $oldText = $self.Text
        $handled = $true
        
        switch ($Key.Key) {
            ([ConsoleKey]::Backspace) {
                if ($self.CursorPosition -gt 0) {
                    $self.Text = $self.Text.Remove($self.CursorPosition - 1, 1)
                    $self.CursorPosition--
                }
            }
            ([ConsoleKey]::Delete) {
                if ($self.CursorPosition -lt $self.Text.Length) {
                    $self.Text = $self.Text.Remove($self.CursorPosition, 1)
                }
            }
            ([ConsoleKey]::LeftArrow) {
                if ($self.CursorPosition -gt 0) {
                    $self.CursorPosition--
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($self.CursorPosition -lt $self.Text.Length) {
                    $self.CursorPosition++
                }
            }
            ([ConsoleKey]::Home) {
                $self.CursorPosition = 0
            }
            ([ConsoleKey]::End) {
                $self.CursorPosition = $self.Text.Length
            }
            default {
                # Handle character input
                if ($Key.KeyChar -and [char]::IsLetterOrDigit($Key.KeyChar) -or 
                    [char]::IsPunctuation($Key.KeyChar) -or 
                    [char]::IsSymbol($Key.KeyChar) -or 
                    $Key.KeyChar -eq ' ') {
                    
                    if ($self.Text.Length -lt $self.MaxLength) {
                        $self.Text = $self.Text.Insert($self.CursorPosition, $Key.KeyChar)
                        $self.CursorPosition++
                    }
                } else {
                    $handled = $false
                }
            }
        }
        
        # Fire change event if text changed
        if ($oldText -ne $self.Text -and $self.OnChange) {
            & $self.OnChange -Component $self -OldValue $oldText -NewValue $self.Text
        }
        
        return $handled
    }
    
    $component.OnFocus = {
        param($self)
        $self.Focused = $true
    }
    
    $component.OnBlur = {
        param($self)
        $self.Focused = $false
    }
    
    return $component
}

#endregion

#region CheckBox Component

function global:New-TuiCheckBox {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "CheckBox"
    $component.Height = 1
    $component.Width = 3 + ($Props.Label ?? "").Length + 1
    $component.Checked = $Props.Checked ?? $false
    $component.Label = $Props.Label ?? ""
    $component.OnChange = $Props.OnChange
    $component.IsFocusable = $true
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Checkbox symbol
        $checkSymbol = if ($self.Checked) { "☑" } else { "☐" }
        $color = if ($self.Focused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        
        # Draw checkbox
        Write-BufferString -X $pos.X -Y $pos.Y -Text "[$checkSymbol]" -ForegroundColor $color
        
        # Draw label
        if ($self.Label) {
            Write-BufferString -X ($pos.X + 4) -Y $pos.Y -Text $self.Label -ForegroundColor $color
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        
        if ($Key.Key -eq [ConsoleKey]::Spacebar -or $Key.Key -eq [ConsoleKey]::Enter) {
            $oldValue = $self.Checked
            $self.Checked = -not $self.Checked
            
            # Fire change event
            if ($self.OnChange) {
                & $self.OnChange -Component $self -OldValue $oldValue -NewValue $self.Checked
            }
            
            # Publish event
            Publish-TuiEvent -EventName "Component.CheckBoxChanged" -Data @{ 
                Component = $self
                Checked = $self.Checked
            }
            
            return $true
        }
        
        return $false
    }
    
    $component.OnFocus = {
        param($self)
        $self.Focused = $true
    }
    
    $component.OnBlur = {
        param($self)
        $self.Focused = $false
    }
    
    return $component
}

#endregion

#region ListBox Component

function global:New-TuiListBox {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "ListBox"
    $component.Items = $Props.Items ?? @()
    $component.SelectedIndex = $Props.SelectedIndex ?? 0
    $component.ScrollOffset = 0
    $component.OnSelectionChange = $Props.OnSelectionChange
    $component.IsFocusable = $true
    $component.ShowBorder = $Props.ShowBorder ?? $true
    $component.ItemRenderer = $Props.ItemRenderer ?? { param($item) $item.ToString() }
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Draw border if enabled
        if ($self.ShowBorder) {
            $borderColor = if ($self.Focused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
            Write-BufferBox -X $pos.X -Y $pos.Y -Width $self.Width -Height $self.Height `
                -BorderColor $borderColor -BackgroundColor (Get-ThemeColor "Background")
            
            $contentX = $pos.X + 1
            $contentY = $pos.Y + 1
            $contentWidth = $self.Width - 2
            $contentHeight = $self.Height - 2
        } else {
            $contentX = $pos.X
            $contentY = $pos.Y
            $contentWidth = $self.Width
            $contentHeight = $self.Height
        }
        
        # Calculate visible items
        $visibleCount = $contentHeight
        
        # Adjust scroll offset to keep selection visible
        if ($self.SelectedIndex -lt $self.ScrollOffset) {
            $self.ScrollOffset = $self.SelectedIndex
        } elseif ($self.SelectedIndex -ge ($self.ScrollOffset + $visibleCount)) {
            $self.ScrollOffset = $self.SelectedIndex - $visibleCount + 1
        }
        
        # Render items
        for ($i = 0; $i -lt $visibleCount; $i++) {
            $itemIndex = $self.ScrollOffset + $i
            if ($itemIndex -ge $self.Items.Count) { break }
            
            $item = $self.Items[$itemIndex]
            $displayText = & $self.ItemRenderer -item $item
            
            # Truncate if too long
            if ($displayText.Length -gt $contentWidth - 2) {
                $displayText = $displayText.Substring(0, $contentWidth - 5) + "..."
            }
            
            # Determine colors
            if ($itemIndex -eq $self.SelectedIndex) {
                $fgColor = Get-ThemeColor "Background"
                $bgColor = if ($self.Focused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
                $prefix = ">"
            } else {
                $fgColor = Get-ThemeColor "Primary"
                $bgColor = Get-ThemeColor "Background"
                $prefix = " "
            }
            
            # Clear line and draw item
            $lineText = "$prefix $displayText".PadRight($contentWidth)
            Write-BufferString -X $contentX -Y ($contentY + $i) -Text $lineText `
                -ForegroundColor $fgColor -BackgroundColor $bgColor
        }
        
        # Draw scrollbar if needed
        if ($self.Items.Count -gt $visibleCount -and $self.ShowBorder) {
            $scrollbarX = $pos.X + $self.Width - 1
            $scrollbarHeight = $contentHeight
            $thumbSize = [Math]::Max(1, [Math]::Floor($scrollbarHeight * $visibleCount / $self.Items.Count))
            $thumbPos = [Math]::Floor($scrollbarHeight * $self.ScrollOffset / $self.Items.Count)
            
            for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "░" }
                Write-BufferString -X $scrollbarX -Y ($contentY + $i) -Text $char `
                    -ForegroundColor (Get-ThemeColor "Subtle")
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        
        $oldIndex = $self.SelectedIndex
        $handled = $true
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($self.SelectedIndex -gt 0) {
                    $self.SelectedIndex--
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($self.SelectedIndex -lt ($self.Items.Count - 1)) {
                    $self.SelectedIndex++
                }
            }
            ([ConsoleKey]::PageUp) {
                $self.SelectedIndex = [Math]::Max(0, $self.SelectedIndex - 10)
            }
            ([ConsoleKey]::PageDown) {
                $self.SelectedIndex = [Math]::Min($self.Items.Count - 1, $self.SelectedIndex + 10)
            }
            ([ConsoleKey]::Home) {
                $self.SelectedIndex = 0
            }
            ([ConsoleKey]::End) {
                $self.SelectedIndex = $self.Items.Count - 1
            }
            ([ConsoleKey]::Enter) {
                # Fire selection event
                Publish-TuiEvent -EventName "Component.ListBoxItemSelected" -Data @{
                    Component = $self
                    SelectedIndex = $self.SelectedIndex
                    SelectedItem = $self.Items[$self.SelectedIndex]
                }
            }
            default {
                $handled = $false
            }
        }
        
        # Fire change event if selection changed
        if ($oldIndex -ne $self.SelectedIndex -and $self.OnSelectionChange) {
            & $self.OnSelectionChange -Component $self -OldIndex $oldIndex -NewIndex $self.SelectedIndex
        }
        
        return $handled
    }
    
    $component.OnFocus = {
        param($self)
        $self.Focused = $true
    }
    
    $component.OnBlur = {
        param($self)
        $self.Focused = $false
    }
    
    return $component
}

#endregion

#region ProgressBar Component

function global:New-TuiProgressBar {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "ProgressBar"
    $component.Height = 1
    $component.Value = [Math]::Max(0, [Math]::Min(100, $Props.Value ?? 0))
    $component.ShowPercentage = $Props.ShowPercentage ?? $true
    $component.BarChar = $Props.BarChar ?? "█"
    $component.EmptyChar = $Props.EmptyChar ?? "░"
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Calculate bar dimensions
        $percentageText = if ($self.ShowPercentage) { " $($self.Value)%" } else { "" }
        $barWidth = $self.Width - $percentageText.Length
        $filledWidth = [Math]::Floor($barWidth * ($self.Value / 100))
        
        # Create bar string
        $barString = ($self.BarChar * $filledWidth) + ($self.EmptyChar * ($barWidth - $filledWidth))
        
        # Determine color based on value
        $color = if ($self.Value -lt 30) { Get-ThemeColor "Error" }
                elseif ($self.Value -lt 70) { Get-ThemeColor "Warning" }
                else { Get-ThemeColor "Success" }
        
        # Draw bar
        Write-BufferString -X $pos.X -Y $pos.Y -Text $barString -ForegroundColor $color
        
        # Draw percentage
        if ($self.ShowPercentage) {
            Write-BufferString -X ($pos.X + $barWidth) -Y $pos.Y -Text $percentageText `
                -ForegroundColor (Get-ThemeColor "Primary")
        }
    }
    
    $component.SetValue = {
        param($self, $value)
        $self.Value = [Math]::Max(0, [Math]::Min(100, $value))
    }
    
    return $component
}

#endregion

#region Panel Component

function global:New-TuiPanel {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "Panel"
    $component.Title = $Props.Title ?? ""
    $component.BorderStyle = $Props.BorderStyle ?? "Single"
    $component.Padding = $Props.Padding ?? 1
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Draw border
        Write-BufferBox -X $pos.X -Y $pos.Y -Width $self.Width -Height $self.Height `
            -BorderStyle $self.BorderStyle -Title $self.Title `
            -BorderColor (Get-ThemeColor "Secondary") `
            -BackgroundColor (Get-ThemeColor "Background")
        
        # Render children with padding
        foreach ($child in $self.Children) {
            if ($child.Visible) {
                # Adjust child position for padding
                $originalX = $child.X
                $originalY = $child.Y
                
                $child.X += $self.Padding
                $child.Y += $self.Padding
                
                # Render child
                if ($child.Render) {
                    & $child.Render -self $child
                }
                
                # Restore original position
                $child.X = $originalX
                $child.Y = $originalY
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        
        # Pass input to focused child
        foreach ($child in $self.Children) {
            if ($child.Focused -and $child.HandleInput) {
                return & $child.HandleInput -self $child -Key $Key
            }
        }
        
        return $false
    }
    
    return $component
}

#endregion

#region Menu Component

function global:New-TuiMenu {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "Menu"
    $component.Items = $Props.Items ?? @()  # Array of @{ Text = ""; Action = {} }
    $component.SelectedIndex = 0
    $component.IsFocusable = $true
    $component.Orientation = $Props.Orientation ?? "Vertical"  # Vertical or Horizontal
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible -or $self.Items.Count -eq 0) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        $x = $pos.X
        $y = $pos.Y
        
        for ($i = 0; $i -lt $self.Items.Count; $i++) {
            $item = $self.Items[$i]
            
            # Determine colors
            if ($i -eq $self.SelectedIndex -and $self.Focused) {
                $fgColor = Get-ThemeColor "Background"
                $bgColor = Get-ThemeColor "Accent"
            } else {
                $fgColor = Get-ThemeColor "Primary"
                $bgColor = Get-ThemeColor "Background"
            }
            
            # Add selection indicator
            $text = if ($i -eq $self.SelectedIndex -and $self.Focused) { "► $($item.Text)" } else { "  $($item.Text)" }
            
            Write-BufferString -X $x -Y $y -Text $text.PadRight($self.Width) `
                -ForegroundColor $fgColor -BackgroundColor $bgColor
            
            if ($self.Orientation -eq "Vertical") {
                $y++
            } else {
                $x += $text.Length + 2
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        
        $handled = $true
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($self.Orientation -eq "Vertical" -and $self.SelectedIndex -gt 0) {
                    $self.SelectedIndex--
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($self.Orientation -eq "Vertical" -and $self.SelectedIndex -lt ($self.Items.Count - 1)) {
                    $self.SelectedIndex++
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::LeftArrow) {
                if ($self.Orientation -eq "Horizontal" -and $self.SelectedIndex -gt 0) {
                    $self.SelectedIndex--
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($self.Orientation -eq "Horizontal" -and $self.SelectedIndex -lt ($self.Items.Count - 1)) {
                    $self.SelectedIndex++
                } else {
                    $handled = $false
                }
            }
            ([ConsoleKey]::Enter) {
                $selectedItem = $self.Items[$self.SelectedIndex]
                if ($selectedItem.Action) {
                    & $selectedItem.Action -MenuItem $selectedItem
                }
                
                # Publish event
                Publish-TuiEvent -EventName "Component.MenuItemSelected" -Data @{
                    Component = $self
                    SelectedItem = $selectedItem
                    SelectedIndex = $self.SelectedIndex
                }
            }
            default {
                $handled = $false
            }
        }
        
        return $handled
    }
    
    $component.OnFocus = {
        param($self)
        $self.Focused = $true
    }
    
    $component.OnBlur = {
        param($self)
        $self.Focused = $false
    }
    
    return $component
}

#endregion

#region Container Component with Focus Management

function global:New-TuiContainer {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "Container"
    $component.FocusedChildIndex = -1
    $component.Layout = $Props.Layout ?? "None"  # None, Stack, Grid, Dock, Flow
    $component.LayoutProps = $Props.LayoutProps ?? @{}
    
    $component.GetFocusableChildren = {
        param($self)
        return $self.Children | Where-Object { $_.IsFocusable -and $_.Visible }
    }
    
    $component.FocusNext = {
        param($self)
        $focusable = & $self.GetFocusableChildren -self $self
        if ($focusable.Count -eq 0) { return }
        
        # Blur current
        if ($self.FocusedChildIndex -ge 0 -and $self.FocusedChildIndex -lt $focusable.Count) {
            $current = $focusable[$self.FocusedChildIndex]
            if ($current.OnBlur) {
                & $current.OnBlur -self $current
            }
        }
        
        # Focus next
        $self.FocusedChildIndex = ($self.FocusedChildIndex + 1) % $focusable.Count
        $next = $focusable[$self.FocusedChildIndex]
        if ($next.OnFocus) {
            & $next.OnFocus -self $next
        }
    }
    
    $component.FocusPrevious = {
        param($self)
        $focusable = & $self.GetFocusableChildren -self $self
        if ($focusable.Count -eq 0) { return }
        
        # Blur current
        if ($self.FocusedChildIndex -ge 0 -and $self.FocusedChildIndex -lt $focusable.Count) {
            $current = $focusable[$self.FocusedChildIndex]
            if ($current.OnBlur) {
                & $current.OnBlur -self $current
            }
        }
        
        # Focus previous
        $self.FocusedChildIndex = ($self.FocusedChildIndex - 1 + $focusable.Count) % $focusable.Count
        $prev = $focusable[$self.FocusedChildIndex]
        if ($prev.OnFocus) {
            & $prev.OnFocus -self $prev
        }
    }
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        # Apply layout if specified
        if ($self.Layout -ne "None" -and $script:LayoutManagers.ContainsKey($self.Layout)) {
            $layoutFunc = $script:LayoutManagers[$self.Layout]
            & $layoutFunc -Container $self @($self.LayoutProps)
        }
        
        # Render all children
        foreach ($child in $self.Children) {
            if ($child.Visible -and $child.Render) {
                & $child.Render -self $child
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        
        # Tab navigation
        if ($Key.Key -eq [ConsoleKey]::Tab) {
            if ($Key.Modifiers -band [ConsoleModifiers]::Shift) {
                & $self.FocusPrevious -self $self
            } else {
                & $self.FocusNext -self $self
            }
            return $true
        }
        
        # Pass to focused child
        $focusable = & $self.GetFocusableChildren -self $self
        if ($self.FocusedChildIndex -ge 0 -and $self.FocusedChildIndex -lt $focusable.Count) {
            $child = $focusable[$self.FocusedChildIndex]
            if ($child.HandleInput) {
                return & $child.HandleInput -self $child -Key $Key
            }
        }
        
        return $false
    }
    
    $component.OnFocus = {
        param($self)
        $self.Focused = $true
        
        # Focus first focusable child
        $focusable = & $self.GetFocusableChildren -self $self
        if ($focusable.Count -gt 0 -and $self.FocusedChildIndex -eq -1) {
            $self.FocusedChildIndex = 0
            $child = $focusable[0]
            if ($child.OnFocus) {
                & $child.OnFocus -self $child
            }
        }
    }
    
    $component.OnBlur = {
        param($self)
        $self.Focused = $false
        
        # Blur focused child
        $focusable = & $self.GetFocusableChildren -self $self
        if ($self.FocusedChildIndex -ge 0 -and $self.FocusedChildIndex -lt $focusable.Count) {
            $child = $focusable[$self.FocusedChildIndex]
            if ($child.OnBlur) {
                & $child.OnBlur -self $child
            }
        }
    }
    
    return $component
}

#endregion

#region StatusBar Component

function global:New-TuiStatusBar {
    param([hashtable]$Props = @{})
    
    $component = New-TuiComponent -Properties $Props
    $component.Type = "StatusBar"
    $component.Height = 1
    $component.Items = $Props.Items ?? @()  # Array of @{ Text = ""; Alignment = "Left|Center|Right" }
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Clear background
        $clearText = " " * $self.Width
        Write-BufferString -X $pos.X -Y $pos.Y -Text $clearText `
            -BackgroundColor (Get-ThemeColor "Accent")
        
        # Group items by alignment
        $leftItems = $self.Items | Where-Object { $_.Alignment -eq "Left" -or -not $_.Alignment }
        $centerItems = $self.Items | Where-Object { $_.Alignment -eq "Center" }
        $rightItems = $self.Items | Where-Object { $_.Alignment -eq "Right" }
        
        # Render left items
        $x = $pos.X + 1
        foreach ($item in $leftItems) {
            Write-BufferString -X $x -Y $pos.Y -Text $item.Text `
                -ForegroundColor (Get-ThemeColor "Background") `
                -BackgroundColor (Get-ThemeColor "Accent")
            $x += $item.Text.Length + 2
        }
        
        # Render center items
        if ($centerItems.Count -gt 0) {
            $centerText = ($centerItems | ForEach-Object { $_.Text }) -join "  "
            $centerX = $pos.X + [Math]::Floor(($self.Width - $centerText.Length) / 2)
            Write-BufferString -X $centerX -Y $pos.Y -Text $centerText `
                -ForegroundColor (Get-ThemeColor "Background") `
                -BackgroundColor (Get-ThemeColor "Accent")
        }
        
        # Render right items
        if ($rightItems.Count -gt 0) {
            $rightText = ($rightItems | ForEach-Object { $_.Text }) -join "  "
            $rightX = $pos.X + $self.Width - $rightText.Length - 1
            Write-BufferString -X $rightX -Y $pos.Y -Text $rightText `
                -ForegroundColor (Get-ThemeColor "Background") `
                -BackgroundColor (Get-ThemeColor "Accent")
        }
    }
    
    $component.SetItem = {
        param($self, $index, $text)
        if ($index -ge 0 -and $index -lt $self.Items.Count) {
            $self.Items[$index].Text = $text
        }
    }
    
    return $component
}

#endregion

#region Dialog Component

function global:New-TuiDialog {
    param([hashtable]$Props = @{})
    
    $component = New-TuiContainer -Properties $Props
    $component.Type = "Dialog"
    $component.Title = $Props.Title ?? "Dialog"
    $component.Message = $Props.Message ?? ""
    $component.Buttons = $Props.Buttons ?? @("OK")
    $component.SelectedButton = 0
    $component.Result = $null
    $component.Modal = $Props.Modal ?? $true
    
    # Calculate size based on content
    $messageLines = $component.Message -split "`n"
    $maxLineLength = ($messageLines | Measure-Object -Property Length -Maximum).Maximum
    $component.Width = [Math]::Max(40, [Math]::Min(80, $maxLineLength + 6))
    $component.Height = [Math]::Min(20, $messageLines.Count + 7)
    
    # Center in parent or screen
    if ($component.Parent) {
        $component.X = [Math]::Floor(($component.Parent.Width - $component.Width) / 2)
        $component.Y = [Math]::Floor(($component.Parent.Height - $component.Height) / 2)
    } else {
        $component.X = [Math]::Floor(($script:TuiState.BufferWidth - $component.Width) / 2)
        $component.Y = [Math]::Floor(($script:TuiState.BufferHeight - $component.Height) / 2)
    }
    
    $component.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        $pos = & $self.GetAbsolutePosition -self $self
        
        # Draw shadow
        for ($y = 1; $y -lt $self.Height; $y++) {
            for ($x = 1; $x -lt $self.Width; $x++) {
                Write-BufferString -X ($pos.X + $x) -Y ($pos.Y + $y) -Text " " `
                    -BackgroundColor [ConsoleColor]::DarkGray
            }
        }
        
        # Draw dialog box
        Write-BufferBox -X $pos.X -Y $pos.Y -Width $self.Width -Height $self.Height `
            -Title $self.Title -BorderStyle "Double" `
            -BorderColor (Get-ThemeColor "Accent") `
            -BackgroundColor (Get-ThemeColor "Background")
        
        # Draw message
        $messageLines = $self.Message -split "`n"
        $messageY = $pos.Y + 2
        foreach ($line in $messageLines) {
            $centeredX = $pos.X + [Math]::Floor(($self.Width - $line.Length) / 2)
            Write-BufferString -X $centeredX -Y $messageY -Text $line `
                -ForegroundColor (Get-ThemeColor "Primary")
            $messageY++
        }
        
        # Draw buttons
        $buttonY = $pos.Y + $self.Height - 3
        $totalButtonWidth = ($self.Buttons | ForEach-Object { $_.Length + 4 }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $buttonSpacing = 2
        $totalWidth = $totalButtonWidth + ($self.Buttons.Count - 1) * $buttonSpacing
        
        $buttonX = $pos.X + [Math]::Floor(($self.Width - $totalWidth) / 2)
        
        for ($i = 0; $i -lt $self.Buttons.Count; $i++) {
            $buttonText = " $($self.Buttons[$i]) "
            
            if ($i -eq $self.SelectedButton) {
                Write-BufferString -X $buttonX -Y $buttonY -Text "[$buttonText]" `
                    -ForegroundColor (Get-ThemeColor "Background") `
                    -BackgroundColor (Get-ThemeColor "Accent")
            } else {
                Write-BufferString -X $buttonX -Y $buttonY -Text "[$buttonText]" `
                    -ForegroundColor (Get-ThemeColor "Secondary")
            }
            
            $buttonX += $buttonText.Length + 2 + $buttonSpacing
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        
        switch ($Key.Key) {
            ([ConsoleKey]::LeftArrow) {
                if ($self.SelectedButton -gt 0) {
                    $self.SelectedButton--
                }
                return $true
            }
            ([ConsoleKey]::RightArrow) {
                if ($self.SelectedButton -lt ($self.Buttons.Count - 1)) {
                    $self.SelectedButton++
                }
                return $true
            }
            ([ConsoleKey]::Tab) {
                $self.SelectedButton = ($self.SelectedButton + 1) % $self.Buttons.Count
                return $true
            }
            ([ConsoleKey]::Enter) {
                $self.Result = $self.Buttons[$self.SelectedButton]
                $self.Visible = $false
                
                # Publish event
                Publish-TuiEvent -EventName "Component.DialogClosed" -Data @{
                    Component = $self
                    Result = $self.Result
                }
                
                return $true
            }
            ([ConsoleKey]::Escape) {
                $self.Result = $null
                $self.Visible = $false
                
                # Publish event
                Publish-TuiEvent -EventName "Component.DialogClosed" -Data @{
                    Component = $self
                    Result = $null
                }
                
                return $true
            }
        }
        
        return $false
    }
    
    return $component
}

#endregion

# Export all component creation functions
Export-ModuleMember -Function @(
    'New-TuiLabel',
    'New-TuiButton',
    'New-TuiTextBox',
    'New-TuiCheckBox',
    'New-TuiListBox',
    'New-TuiProgressBar',
    'New-TuiPanel',
    'New-TuiMenu',
    'New-TuiContainer',
    'New-TuiStatusBar',
    'New-TuiDialog'
)