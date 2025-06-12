# TUI Component Library - Consolidated
# A comprehensive library of stateless, declarative components for building robust TUIs.
# This file merges the base component set with the extended components.

#region Base Component & Container

function global:New-TuiComponent {
    param([hashtable]$Props = @{})

    $component = @{
        Name        = if ($Props.Name) { $Props.Name } else { "comp_$(Get-Random)" }
        Type        = "Component"
        IsFocusable = $false
        Children    = @()
        Visible     = if ($Props.ContainsKey('Visible')) { $Props.Visible } else { $true }
        X           = if ($null -ne $Props.X) { $Props.X } else { 0 }
        Y           = if ($null -ne $Props.Y) { $Props.Y } else { 0 }
        Width       = if ($Props.Width) { $Props.Width } else { 10 }
        Height      = if ($Props.Height) { $Props.Height } else { 1 }
        
        # Default Methods
        Render      = { param($self) }
        HandleInput = { param($self, $Key) return $false }
        Clone       = { 
            $clone = @{}
            foreach ($key in $this.Keys) {
                if ($this[$key] -is [scriptblock]) {
                    $clone[$key] = $this[$key]
                } elseif ($this[$key] -is [array]) {
                    $clone[$key] = @($this[$key])
                } elseif ($this[$key] -is [hashtable]) {
                    $clone[$key] = $this[$key].Clone()
                } else {
                    $clone[$key] = $this[$key]
                }
            }
            return $clone
        }
    }
    
    foreach ($key in $Props.Keys) { 
        if ($key -notin @('X', 'Y', 'Width', 'Height', 'Name', 'Type', 'IsFocusable', 'Visible')) {
            $component[$key] = $Props[$key] 
        }
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
                $childToRender = $child.Clone()
                $childToRender.X += $self.X + (if ($null -ne $self.Padding) { $self.Padding } else { 1 })
                $childToRender.Y += $self.Y + (if ($null -ne $self.Padding) { $self.Padding } else { 1 })
                
                $childToRender.IsFocused = ($self.State.FocusedChildName -eq $child.Name)
                if ($child.TextProp) { $childToRender.Text = $self.State.($child.TextProp) }
                if ($child.CursorProp) { $childToRender.CursorPosition = $self.State.($child.CursorProp) }
                if ($child.ValueProp) { $childToRender.Value = $self.State.($child.ValueProp) }

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
            $childClone = $focusedChild.Clone()
            if ($focusedChild.TextProp) { $childClone.Text = $state.($focusedChild.TextProp) }
            if ($focusedChild.CursorProp) { $childClone.CursorPosition = $state.($focusedChild.CursorProp) }
            if ($focusedChild.ValueProp) { $childClone.Value = $state.($focusedChild.ValueProp) }

            return & $childClone.HandleInput -self $childClone -Key $Key
        }
        return $false
    }
    return $form
}

#endregion

#region Basic Components

function global:New-TuiLabel {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Label"
    $component.Render = { 
        param($self) 
        Write-BufferString -X $self.X -Y $self.Y -Text $self.Text `
            -ForegroundColor (if ($self.ForegroundColor) { $self.ForegroundColor } else { Get-ThemeColor "Primary" })
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
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        $bgColor = if ($self.IsPressed) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
        $fgColor = if ($self.IsPressed) { Get-ThemeColor "Background" } else { $borderColor }
        
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
    $component.Text = if ($Props.Text) { $Props.Text } else { "" }
    $component.CursorPosition = if ($null -ne $Props.CursorPosition) { $Props.CursorPosition } else { 0 }

    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        
        $displayText = if ($self.Text) { $self.Text } else { "" }
        if ([string]::IsNullOrEmpty($displayText) -and -not $self.IsFocused) { 
            $displayText = if ($self.Placeholder) { $self.Placeholder } else { "" }
        }
        
        $maxDisplayLength = $self.Width - 4
        if ($displayText.Length -gt $maxDisplayLength) {
            $displayText = $displayText.Substring(0, $maxDisplayLength)
        }
        
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $displayText
        
        if ($self.IsFocused -and $self.CursorPosition -le $displayText.Length) {
            $cursorX = $self.X + 2 + $self.CursorPosition
            Write-BufferString -X $cursorX -Y ($self.Y + 1) -Text "_" `
                -BackgroundColor (Get-ThemeColor "Accent")
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        $text = if ($self.Text) { $self.Text } else { "" }
        $cursorPos = if ($null -ne $self.CursorPosition) { $self.CursorPosition } else { 0 }
        $oldText = $text

        switch ($Key.Key) {
            ([ConsoleKey]::Backspace) { if ($cursorPos -gt 0) { $text = $text.Remove($cursorPos - 1, 1); $cursorPos-- } }
            ([ConsoleKey]::Delete)    { if ($cursorPos -lt $text.Length) { $text = $text.Remove($cursorPos, 1) } }
            ([ConsoleKey]::LeftArrow) { if ($cursorPos -gt 0) { $cursorPos-- } }
            ([ConsoleKey]::RightArrow){ if ($cursorPos -lt $text.Length) { $cursorPos++ } }
            ([ConsoleKey]::Home)      { $cursorPos = 0 }
            ([ConsoleKey]::End)       { $cursorPos = $text.Length }
            default {
                if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                    $text = $text.Insert($cursorPos, $Key.KeyChar)
                    $cursorPos++
                } else { return $false }
            }
        }
        
        if ($text -ne $oldText -or $cursorPos -ne $self.CursorPosition) {
            if ($self.OnChange) { & $self.OnChange -NewText $text -NewCursorPosition $cursorPos }
        }
        return $true
    }
    return $component
}

function global:New-TuiCheckBox {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "CheckBox"
    $component.IsFocusable = $true
    $component.Checked = if ($null -ne $Props.Checked) { $Props.Checked } else { $false }
    
    $component.Render = {
        param($self)
        $fg = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        $checkbox = if ($self.Checked) { "[X]" } else { "[ ]" }
        Write-BufferString -X $self.X -Y $self.Y -Text "$checkbox $($self.Text)" -ForegroundColor $fg
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar)) {
            $newCheckedState = -not $self.Checked
            if ($self.OnChange) { & $self.OnChange -Checked $newCheckedState }
            Request-TuiRefresh
            return $true
        }
        return $false
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
    $component.Options = if ($Props.Options) { $Props.Options } else { @() }
    $component.ValueProp = if ($Props.ValueProp) { $Props.ValueProp } else { "Value" }
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        
        $displayText = "Select..."
        if ($self.Value -and $self.Options) {
            $selected = $self.Options | Where-Object { $_.Value -eq $self.Value } | Select-Object -First 1
            if ($selected) { $displayText = $selected.Display }
        }
        
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $displayText
        $indicator = if ($self.IsOpen) { "▲" } else { "▼" }
        Write-BufferString -X ($self.X + $self.Width - 3) -Y ($self.Y + 1) -Text $indicator
        
        if ($self.IsOpen -and $self.Options.Count -gt 0) {
            $listHeight = [Math]::Min($self.Options.Count + 2, 8)
            Write-BufferBox -X $self.X -Y ($self.Y + 3) -Width $self.Width -Height $listHeight -BorderColor $borderColor -BackgroundColor (Get-ThemeColor "Background")
            
            $displayCount = [Math]::Min($self.Options.Count, 6)
            for ($i = 0; $i -lt $displayCount; $i++) {
                $option = $self.Options[$i]
                $y = $self.Y + 4 + $i
                $fg = if ($i -eq $self.SelectedIndex) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
                $bg = if ($i -eq $self.SelectedIndex) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" }
                $text = $option.Display
                if ($text.Length -gt ($self.Width - 4)) { $text = $text.Substring(0, $self.Width - 7) + "..." }
                Write-BufferString -X ($self.X + 2) -Y $y -Text $text -ForegroundColor $fg -BackgroundColor $bg
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if (-not $self.IsOpen) {
            if ($Key.Key -in @([ConsoleKey]::Enter, [ConsoleKey]::Spacebar, [ConsoleKey]::DownArrow)) {
                $self.IsOpen = $true
                Request-TuiRefresh
                return $true
            }
        } else {
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) { if ($self.SelectedIndex -gt 0) { $self.SelectedIndex--; Request-TuiRefresh }; return $true }
                ([ConsoleKey]::DownArrow) { if ($self.SelectedIndex -lt ($self.Options.Count - 1)) { $self.SelectedIndex++; Request-TuiRefresh }; return $true }
                ([ConsoleKey]::Enter) {
                    if ($self.Options.Count -gt 0) {
                        $selected = $self.Options[$self.SelectedIndex]
                        if ($self.OnChange) { & $self.OnChange -NewValue $selected.Value }
                    }
                    $self.IsOpen = $false
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Escape) { $self.IsOpen = $false; Request-TuiRefresh; return $true }
            }
        }
        return $false
    }
    
    return $component
}

function global:New-TuiProgressBar {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "ProgressBar"
    $component.Value = if ($null -ne $Props.Value) { $Props.Value } else { 0 }
    $component.Max = if ($Props.Max) { $Props.Max } else { 100 }
    
    $component.Render = {
        param($self)
        $percent = [Math]::Min(100, [Math]::Max(0, ($self.Value / $self.Max) * 100))
        $filled = [Math]::Floor(($self.Width - 2) * ($percent / 100))
        $empty = ($self.Width - 2) - $filled
        
        $bar = "█" * $filled + "░" * $empty
        Write-BufferString -X $self.X -Y $self.Y -Text "[$bar]" -ForegroundColor (Get-ThemeColor "Accent")
        
        if ($self.ShowPercent) {
            $percentText = "$([Math]::Round($percent))%"
            $textX = $self.X + [Math]::Floor(($self.Width - $percentText.Length) / 2)
            Write-BufferString -X $textX -Y $self.Y -Text $percentText -ForegroundColor (Get-ThemeColor "Primary")
        }
    }
    
    return $component
}

function global:New-TuiTextArea {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "TextArea"
    $component.IsFocusable = $true
    $component.Height = if ($Props.Height) { $Props.Height } else { 6 }
    $component.Text = if ($Props.Text) { $Props.Text } else { "" }
    $component.Lines = @($component.Text -split "`n")
    $component.CursorX = 0
    $component.CursorY = 0
    $component.ScrollOffset = 0
    $component.WrapText = if ($null -ne $Props.WrapText) { $Props.WrapText } else { $true }
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor
        
        $innerWidth = $self.Width - 4
        $innerHeight = $self.Height - 2
        $displayLines = @()
        if ($self.Lines.Count -eq 0) { $self.Lines = @("") }
        
        # This part can be slow for large text, consider caching
        foreach ($line in $self.Lines) {
            if ($self.WrapText -and $line.Length -gt $innerWidth) {
                for ($i = 0; $i -lt $line.Length; $i += $innerWidth) {
                    $displayLines += $line.Substring($i, [Math]::Min($innerWidth, $line.Length - $i))
                }
            } else { $displayLines += $line }
        }
        
        if ($displayLines.Count -eq 1 -and $displayLines[0] -eq "" -and -not $self.IsFocused) {
            Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text (if ($self.Placeholder) { $self.Placeholder } else { "Enter text..." })
            return
        }
        
        $startLine = $self.ScrollOffset
        $endLine = [Math]::Min($displayLines.Count - 1, $startLine + $innerHeight - 1)
        
        for ($i = $startLine; $i -le $endLine; $i++) {
            $y = $self.Y + 1 + ($i - $startLine)
            $line = $displayLines[$i]
            Write-BufferString -X ($self.X + 2) -Y $y -Text $line
        }
        
        if ($self.IsFocused -and $self.CursorY -ge $startLine -and $self.CursorY -le $endLine) {
            $cursorScreenY = $self.Y + 1 + ($self.CursorY - $startLine)
            $cursorX = [Math]::Min($self.CursorX, $displayLines[$self.CursorY].Length)
            Write-BufferString -X ($self.X + 2 + $cursorX) -Y $cursorScreenY -Text "_" -BackgroundColor (Get-ThemeColor "Accent")
        }
        
        if ($displayLines.Count -gt $innerHeight) {
            $scrollbarHeight = $innerHeight
            $scrollPosition = [Math]::Floor(($self.ScrollOffset / ($displayLines.Count - $innerHeight)) * ($scrollbarHeight - 1))
            for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                $char = if ($i -eq $scrollPosition) { "█" } else { "│" }
                $color = if ($i -eq $scrollPosition) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Subtle" }
                Write-BufferString -X ($self.X + $self.Width - 2) -Y ($self.Y + 1 + $i) -Text $char -ForegroundColor $color
            }
        }
    }
    
    $component.HandleInput = {
        # This is a complex handler. The implementation from tui-components - Copy.txt is used.
        # For brevity, the logic is assumed to be correct as provided in the source file.
        # It handles cursor movement, text insertion, deletion, and line breaks.
        # It correctly calls OnChange and Request-TuiRefresh.
        # (Full implementation from source file goes here)
        param($self, $Key)
        $lines = $self.Lines
        $cursorY = $self.CursorY
        $cursorX = $self.CursorX
        $innerHeight = $self.Height - 2
        
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($cursorY -gt 0) {
                    $cursorY--
                    $cursorX = [Math]::Min($cursorX, $lines[$cursorY].Length)
                    if ($cursorY -lt $self.ScrollOffset) { $self.ScrollOffset = $cursorY }
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($cursorY -lt $lines.Count - 1) {
                    $cursorY++
                    $cursorX = [Math]::Min($cursorX, $lines[$cursorY].Length)
                    if ($cursorY -ge $self.ScrollOffset + $innerHeight) { $self.ScrollOffset = $cursorY - $innerHeight + 1 }
                }
            }
            ([ConsoleKey]::LeftArrow) {
                if ($cursorX -gt 0) { $cursorX-- } 
                elseif ($cursorY -gt 0) { $cursorY--; $cursorX = $lines[$cursorY].Length }
            }
            ([ConsoleKey]::RightArrow) {
                if ($cursorX -lt $lines[$cursorY].Length) { $cursorX++ } 
                elseif ($cursorY -lt $lines.Count - 1) { $cursorY++; $cursorX = 0 }
            }
            ([ConsoleKey]::Home) { $cursorX = 0 }
            ([ConsoleKey]::End) { $cursorX = $lines[$cursorY].Length }
            ([ConsoleKey]::Enter) {
                $currentLine = $lines[$cursorY]
                $beforeCursor = $currentLine.Substring(0, $cursorX)
                $afterCursor = $currentLine.Substring($cursorX)
                $lines[$cursorY] = $beforeCursor
                $lines = @($lines[0..$cursorY]) + @($afterCursor) + @($lines[($cursorY + 1)..($lines.Count - 1)])
                $cursorY++; $cursorX = 0
                if ($cursorY -ge $self.ScrollOffset + $innerHeight) { $self.ScrollOffset = $cursorY - $innerHeight + 1 }
            }
            ([ConsoleKey]::Backspace) {
                if ($cursorX -gt 0) { $lines[$cursorY] = $lines[$cursorY].Remove($cursorX - 1, 1); $cursorX-- } 
                elseif ($cursorY -gt 0) {
                    $prevLineLength = $lines[$cursorY - 1].Length
                    $lines[$cursorY - 1] += $lines[$cursorY]
                    $newLines = @(); for ($i = 0; $i -lt $lines.Count; $i++) { if ($i -ne $cursorY) { $newLines += $lines[$i] } }; $lines = $newLines
                    $cursorY--; $cursorX = $prevLineLength
                }
            }
            ([ConsoleKey]::Delete) {
                if ($cursorX -lt $lines[$cursorY].Length) { $lines[$cursorY] = $lines[$cursorY].Remove($cursorX, 1) } 
                elseif ($cursorY -lt $lines.Count - 1) {
                    $lines[$cursorY] += $lines[$cursorY + 1]
                    $newLines = @(); for ($i = 0; $i -lt $lines.Count; $i++) { if ($i -ne ($cursorY + 1)) { $newLines += $lines[$i] } }; $lines = $newLines
                }
            }
            default {
                if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                    $lines[$cursorY] = $lines[$cursorY].Insert($cursorX, $Key.KeyChar)
                    $cursorX++
                } else { return $false }
            }
        }
        
        $self.Lines = $lines; $self.CursorX = $cursorX; $self.CursorY = $cursorY
        $self.Text = $lines -join "`n"
        if ($self.OnChange) { & $self.OnChange -NewText $self.Text -Lines $self.Lines -CursorX $cursorX -CursorY $cursorY }
        Request-TuiRefresh
        return $true
    }
    
    return $component
}

#endregion

#region DateTime Components

function global:New-TuiDatePicker {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "DatePicker"
    $component.IsFocusable = $true
    $component.Height = 3
    $component.Value = if ($Props.Value) { $Props.Value } else { Get-Date }
    $component.Format = if ($Props.Format) { $Props.Format } else { "yyyy-MM-dd" }
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        $dateStr = $self.Value.ToString($self.Format)
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $dateStr
        if ($self.IsFocused) { Write-BufferString -X ($self.X + $self.Width - 4) -Y ($self.Y + 1) -Text "📅" -ForegroundColor $borderColor }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        $date = $self.Value; $handled = $true
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow)   { $date = $date.AddDays(1) }
            ([ConsoleKey]::DownArrow) { $date = $date.AddDays(-1) }
            ([ConsoleKey]::PageUp)    { $date = $date.AddMonths(1) }
            ([ConsoleKey]::PageDown)  { $date = $date.AddMonths(-1) }
            ([ConsoleKey]::Home)      { $date = Get-Date }
            ([ConsoleKey]::T) { if ($Key.Modifiers -band [ConsoleModifiers]::Control) { $date = Get-Date } else { $handled = $false } }
            default { $handled = $false }
        }
        if ($handled -and $self.OnChange) { & $self.OnChange -NewValue $date }
        return $handled
    }
    
    return $component
}

function global:New-TuiTimePicker {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "TimePicker"
    $component.IsFocusable = $true
    $component.Height = 3
    $component.Hour = if ($null -ne $Props.Hour) { $Props.Hour } else { 0 }
    $component.Minute = if ($null -ne $Props.Minute) { $Props.Minute } else { 0 }
    $component.Format24H = if ($null -ne $Props.Format24H) { $Props.Format24H } else { $true }
    
    $component.Render = {
        param($self)
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height 3 -BorderColor $borderColor
        if ($self.Format24H) { $timeStr = "{0:D2}:{1:D2}" -f $self.Hour, $self.Minute } 
        else {
            $displayHour = if ($self.Hour -eq 0) { 12 } elseif ($self.Hour -gt 12) { $self.Hour - 12 } else { $self.Hour }
            $ampm = if ($self.Hour -lt 12) { "AM" } else { "PM" }
            $timeStr = "{0:D2}:{1:D2} {2}" -f $displayHour, $self.Minute, $ampm
        }
        Write-BufferString -X ($self.X + 2) -Y ($self.Y + 1) -Text $timeStr
        if ($self.IsFocused) { Write-BufferString -X ($self.X + $self.Width - 4) -Y ($self.Y + 1) -Text "⏰" -ForegroundColor $borderColor }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        $handled = $true; $hour = $self.Hour; $minute = $self.Minute
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow)    { $minute = ($minute + 15) % 60; if ($minute -eq 0) { $hour = ($hour + 1) % 24 } }
            ([ConsoleKey]::DownArrow)  { $minute = ($minute - 15 + 60) % 60; if ($minute -eq 45) { $hour = ($hour - 1 + 24) % 24 } }
            ([ConsoleKey]::LeftArrow)  { $hour = ($hour - 1 + 24) % 24 }
            ([ConsoleKey]::RightArrow) { $hour = ($hour + 1) % 24 }
            default { $handled = $false }
        }
        if ($handled -and $self.OnChange) { & $self.OnChange -NewHour $hour -NewMinute $minute }
        return $handled
    }
    
    return $component
}

#endregion

#region Data Display Components

function global:New-TuiTable {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Table"
    $component.IsFocusable = $true
    $component.Columns = if ($Props.Columns) { $Props.Columns } else { @() }
    $component.Rows = if ($Props.Rows) { $Props.Rows } else { @() }
    $component.SelectedRow = 0
    $component.ScrollOffset = 0
    $component.SortColumn = $null
    $component.SortAscending = $true
    
    $component.Render = {
        param($self)
        if ($self.Columns.Count -eq 0) { return }
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Secondary" }
        Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor
        
        $totalWidth = $self.Width - 4; $colWidth = [Math]::Floor($totalWidth / $self.Columns.Count)
        $headerY = $self.Y + 1; $currentX = $self.X + 2
        foreach ($col in $self.Columns) {
            $header = $col.Header; if ($col.Name -eq $self.SortColumn) { $arrow = if ($self.SortAscending) { "▲" } else { "▼" }; $header = "$header $arrow" }
            if ($header.Length -gt $colWidth - 1) { $header = $header.Substring(0, $colWidth - 4) + "..." }
            Write-BufferString -X $currentX -Y $headerY -Text $header -ForegroundColor (Get-ThemeColor "Header"); $currentX += $colWidth
        }
        Write-BufferString -X ($self.X + 1) -Y ($headerY + 1) -Text ("─" * ($self.Width - 2)) -ForegroundColor $borderColor
        
        $visibleRows = $self.Height - 5; $startIdx = $self.ScrollOffset; $endIdx = [Math]::Min($self.Rows.Count - 1, $startIdx + $visibleRows - 1)
        for ($i = $startIdx; $i -le $endIdx; $i++) {
            $row = $self.Rows[$i]; $rowY = ($headerY + 2) + ($i - $startIdx); $currentX = $self.X + 2
            $isSelected = ($i -eq $self.SelectedRow -and $self.IsFocused)
            $bgColor = if ($isSelected) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Background" }
            $fgColor = if ($isSelected) { Get-ThemeColor "Background" } else { Get-ThemeColor "Primary" }
            if ($isSelected) { Write-BufferString -X ($self.X + 1) -Y $rowY -Text (" " * ($self.Width - 2)) -BackgroundColor $bgColor }
            foreach ($col in $self.Columns) {
                $value = $row.($col.Name); if ($null -eq $value) { $value = "" }; $text = $value.ToString()
                if ($text.Length -gt $colWidth - 1) { $text = $text.Substring(0, $colWidth - 4) + "..." }
                Write-BufferString -X $currentX -Y $rowY -Text $text -ForegroundColor $fgColor -BackgroundColor $bgColor; $currentX += $colWidth
            }
        }
        
        if ($self.Rows.Count -gt $visibleRows) {
            $scrollbarHeight = $visibleRows; $scrollPosition = [Math]::Floor(($self.ScrollOffset / ($self.Rows.Count - $visibleRows)) * ($scrollbarHeight - 1))
            for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                $char = if ($i -eq $scrollPosition) { "█" } else { "│" }; $color = if ($i -eq $scrollPosition) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Subtle" }
                Write-BufferString -X ($self.X + $self.Width - 2) -Y ($headerY + 2 + $i) -Text $char -ForegroundColor $color
            }
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        if ($self.Rows.Count -eq 0) { return $false }
        $visibleRows = $self.Height - 5; $handled = $true
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow)   { if ($self.SelectedRow -gt 0) { $self.SelectedRow--; if ($self.SelectedRow -lt $self.ScrollOffset) { $self.ScrollOffset = $self.SelectedRow }; Request-TuiRefresh } }
            ([ConsoleKey]::DownArrow) { if ($self.SelectedRow -lt $self.Rows.Count - 1) { $self.SelectedRow++; if ($self.SelectedRow -ge $self.ScrollOffset + $visibleRows) { $self.ScrollOffset = $self.SelectedRow - $visibleRows + 1 }; Request-TuiRefresh } }
            ([ConsoleKey]::PageUp)    { $self.SelectedRow = [Math]::Max(0, $self.SelectedRow - $visibleRows); $self.ScrollOffset = [Math]::Max(0, $self.ScrollOffset - $visibleRows); Request-TuiRefresh }
            ([ConsoleKey]::PageDown)  { $self.SelectedRow = [Math]::Min($self.Rows.Count - 1, $self.SelectedRow + $visibleRows); $maxScroll = [Math]::Max(0, $self.Rows.Count - $visibleRows); $self.ScrollOffset = [Math]::Min($maxScroll, $self.ScrollOffset + $visibleRows); Request-TuiRefresh }
            ([ConsoleKey]::Home)      { $self.SelectedRow = 0; $self.ScrollOffset = 0; Request-TuiRefresh }
            ([ConsoleKey]::End)       { $self.SelectedRow = $self.Rows.Count - 1; $self.ScrollOffset = [Math]::Max(0, $self.Rows.Count - $visibleRows); Request-TuiRefresh }
            ([ConsoleKey]::Enter)     { if ($self.OnRowSelect) { & $self.OnRowSelect -Row $self.Rows[$self.SelectedRow] -Index $self.SelectedRow } }
            default {
                if ($Key.KeyChar -match '\d') {
                    $colIndex = [int]$Key.KeyChar.ToString() - 1
                    if ($colIndex -ge 0 -and $colIndex -lt $self.Columns.Count) {
                        $colName = $self.Columns[$colIndex].Name
                        if ($self.SortColumn -eq $colName) { $self.SortAscending = -not $self.SortAscending } else { $self.SortColumn = $colName; $self.SortAscending = $true }
                        $self.Rows = $self.Rows | Sort-Object -Property $colName -Descending:(-not $self.SortAscending); Request-TuiRefresh
                    }
                } else { $handled = $false }
            }
        }
        return $handled
    }
    
    return $component
}

function global:New-TuiChart {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Chart"
    $component.ChartType = if ($Props.ChartType) { $Props.ChartType } else { "Bar" }
    $component.Data = if ($Props.Data) { $Props.Data } else { @() }
    $component.ShowValues = if ($null -ne $Props.ShowValues) { $Props.ShowValues } else { $true }
    
    $component.Render = {
        param($self)
        if ($self.Data.Count -eq 0) { return }
        switch ($self.ChartType) {
            "Bar" {
                $maxValue = ($self.Data | Measure-Object -Property Value -Maximum).Maximum; if ($maxValue -eq 0) { $maxValue = 1 }
                $chartHeight = $self.Height - 2; $barWidth = [Math]::Floor(($self.Width - 4) / $self.Data.Count)
                for ($i = 0; $i -lt $self.Data.Count; $i++) {
                    $item = $self.Data[$i]; $barHeight = [Math]::Floor(($item.Value / $maxValue) * $chartHeight); $barX = $self.X + 2 + ($i * $barWidth)
                    for ($y = 0; $y -lt $barHeight; $y++) { $barY = $self.Y + $self.Height - 2 - $y; Write-BufferString -X $barX -Y $barY -Text ("█" * ($barWidth - 1)) -ForegroundColor (Get-ThemeColor "Accent") }
                    if ($item.Label -and $barWidth -gt 3) { $label = $item.Label; if ($label.Length -gt $barWidth - 1) { $label = $label.Substring(0, $barWidth - 2) }; Write-BufferString -X $barX -Y ($self.Y + $self.Height - 1) -Text $label -ForegroundColor (Get-ThemeColor "Subtle") }
                    if ($self.ShowValues -and $barHeight -gt 0) { $valueText = $item.Value.ToString(); Write-BufferString -X $barX -Y ($self.Y + $self.Height - 3 - $barHeight) -Text $valueText -ForegroundColor (Get-ThemeColor "Primary") }
                }
            }
            "Sparkline" {
                $width = $self.Width - 2; $height = $self.Height - 1; $maxValue = ($self.Data | Measure-Object -Maximum).Maximum; if ($maxValue -eq 0) { $maxValue = 1 }
                $sparkChars = @(" ", " ", "▂", "▃", "▄", "▅", "▆", "▇", "█"); $sparkline = ""
                foreach ($value in $self.Data) { $normalized = ($value / $maxValue); $charIndex = [Math]::Floor($normalized * ($sparkChars.Count - 1)); $sparkline += $sparkChars[$charIndex] }
                if ($sparkline.Length -gt $width) { $sparkline = $sparkline.Substring($sparkline.Length - $width) } else { $sparkline = $sparkline.PadLeft($width) }
                Write-BufferString -X ($self.X + 1) -Y ($self.Y + [Math]::Floor($height / 2)) -Text $sparkline -ForegroundColor (Get-ThemeColor "Accent")
            }
        }
    }
    
    return $component
}

#endregion

#region Notification Components

function global:New-TuiToast {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Toast"
    $component.Message = if ($Props.Message) { $Props.Message } else { "" }
    $component.ToastType = if ($Props.ToastType) { $Props.ToastType } else { "Info" }
    $component.Duration = if ($Props.Duration) { $Props.Duration } else { 3000 }
    $component.Position = if ($Props.Position) { $Props.Position } else { "TopRight" }
    
    $component.Render = {
        param($self)
        if ([string]::IsNullOrEmpty($self.Message)) { return }
        $width = [Math]::Min($self.Message.Length + 6, 50); $height = 5
        switch ($self.Position) {
            "TopLeft"     { $x = 2; $y = 1 }
            "TopRight"    { $x = $script:TuiState.BufferWidth - $width - 2; $y = 1 }
            "BottomLeft"  { $x = 2; $y = $script:TuiState.BufferHeight - $height - 2 }
            "BottomRight" { $x = $script:TuiState.BufferWidth - $width - 2; $y = $script:TuiState.BufferHeight - $height - 2 }
            "Center"      { $x = [Math]::Floor(($script:TuiState.BufferWidth - $width) / 2); $y = [Math]::Floor(($script:TuiState.BufferHeight - $height) / 2) }
        }
        $colors = switch ($self.ToastType) {
            "Success" { @{ Border = "Green"; Icon = "✓" } }
            "Error"   { @{ Border = "Red"; Icon = "✗" } }
            "Warning" { @{ Border = "Yellow"; Icon = "⚠" } }
            "Info"    { @{ Border = "Cyan"; Icon = "ℹ" } }
            default   { @{ Border = "White"; Icon = "•" } }
        }
        for ($sy = 1; $sy -lt $height; $sy++) { for ($sx = 1; $sx -lt $width; $sx++) { Write-BufferString -X ($x + $sx + 1) -Y ($y + $sy + 1) -Text " " -BackgroundColor [ConsoleColor]::Black } }
        Write-BufferBox -X $x -Y $y -Width $width -Height $height -BorderStyle "Rounded" -BorderColor (Get-ThemeColor $colors.Border)
        Write-BufferString -X ($x + 3) -Y ($y + 2) -Text "$($colors.Icon) $($self.Message)" -ForegroundColor (Get-ThemeColor $colors.Border)
    }
    
    return $component
}

function global:New-TuiDialog {
    param([hashtable]$Props = @{})
    $component = New-TuiComponent -Props $Props
    $component.Type = "Dialog"
    $component.Title = if ($Props.Title) { $Props.Title } else { "Dialog" }
    $component.Message = if ($Props.Message) { $Props.Message } else { "" }
    $component.Buttons = if ($Props.Buttons) { $Props.Buttons } else { @("OK") }
    $component.SelectedButton = 0
    $component.Width = if ($Props.Width) { $Props.Width } else { 50 }
    $component.Height = if ($Props.Height) { $Props.Height } else { 10 }
    
    $component.Render = {
        param($self)
        $x = [Math]::Floor(($script:TuiState.BufferWidth - $self.Width) / 2); $y = [Math]::Floor(($script:TuiState.BufferHeight - $self.Height) / 2)
        for ($sy = 1; $sy -lt $self.Height; $sy++) { for ($sx = 1; $sx -lt $self.Width; $sx++) { Write-BufferString -X ($x + $sx + 1) -Y ($y + $sy + 1) -Text " " -BackgroundColor [ConsoleColor]::Black } }
        Write-BufferBox -X $x -Y $y -Width $self.Width -Height $self.Height -BorderStyle "Double" -BorderColor (Get-ThemeColor "Accent") -Title " $($self.Title) "
        
        $messageLines = $self.Message -split "`n"; $messageY = $y + 2
        foreach ($line in $messageLines) {
            $lineClipped = if ($line.Length -gt $self.Width - 4) { $line.Substring(0, $self.Width - 7) + "..." } else { $line }
            $messageX = $x + [Math]::Floor(($self.Width - $lineClipped.Length) / 2)
            Write-BufferString -X $messageX -Y $messageY -Text $lineClipped; $messageY++
        }
        
        $buttonY = $y + $self.Height - 3
        $totalButtonWidth = ($self.Buttons | ForEach-Object { $_.Length + 4 }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $spacing = [Math]::Floor(($self.Width - $totalButtonWidth) / ($self.Buttons.Count + 1)); $currentX = $x + $spacing
        for ($i = 0; $i -lt $self.Buttons.Count; $i++) {
            $button = $self.Buttons[$i]; $buttonWidth = $button.Length + 4
            if ($i -eq $self.SelectedButton) { Write-BufferString -X $currentX -Y $buttonY -Text "[ $button ]" -ForegroundColor (Get-ThemeColor "Background") -BackgroundColor (Get-ThemeColor "Accent") } 
            else { Write-BufferString -X $currentX -Y $buttonY -Text "[ $button ]" -ForegroundColor (Get-ThemeColor "Secondary") }
            $currentX += $buttonWidth + $spacing
        }
    }
    
    $component.HandleInput = {
        param($self, $Key)
        switch ($Key.Key) {
            ([ConsoleKey]::LeftArrow)  { if ($self.SelectedButton -gt 0) { $self.SelectedButton--; Request-TuiRefresh }; return $true }
            ([ConsoleKey]::RightArrow) { if ($self.SelectedButton -lt $self.Buttons.Count - 1) { $self.SelectedButton++; Request-TuiRefresh }; return $true }
            ([ConsoleKey]::Tab)        { $self.SelectedButton = ($self.SelectedButton + 1) % $self.Buttons.Count; Request-TuiRefresh; return $true }
            ([ConsoleKey]::Enter)      { if ($self.OnButtonClick) { & $self.OnButtonClick -Button $self.Buttons[$self.SelectedButton] -Index $self.SelectedButton }; return $true }
            ([ConsoleKey]::Escape)     { if ($self.OnCancel) { & $self.OnCancel }; return $true }
        }
        return $false
    }
    
    return $component
}

#endregion

Export-ModuleMember -Function @(
    # Base
    'New-TuiComponent',
    'New-TuiForm',
    # Basic Components
    'New-TuiLabel',
    'New-TuiButton',
    'New-TuiTextBox',
    'New-TuiCheckBox',
    'New-TuiDropdown',
    'New-TuiProgressBar',
    'New-TuiTextArea',
    # DateTime Components
    'New-TuiDatePicker',
    'New-TuiTimePicker',
    # Data Display Components
    'New-TuiTable',
    'New-TuiChart',
    # Notification Components
    'New-TuiToast',
    'New-TuiDialog'
)