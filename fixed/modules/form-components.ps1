# Enhanced Form Components for PMC Terminal TUI
# Reusable input components with validation and state management

#region Base Input Component

$script:InputComponentBase = @{
    # Properties
    X = 0
    Y = 0
    Width = 20
    Height = 3
    Label = ""
    Value = ""
    Placeholder = ""
    IsRequired = $false
    IsReadOnly = $false
    IsFocused = $false
    IsValid = $true
    ValidationMessage = ""
    MaxLength = 100
    
    # Validation
    Validators = @()
    
    # Events
    OnChange = $null
    OnFocus = $null
    OnBlur = $null
    OnValidate = $null
    
    # Methods
    Validate = {
        param($self)
        
        $self.IsValid = $true
        $self.ValidationMessage = ""
        
        # Check required
        if ($self.IsRequired -and [string]::IsNullOrWhiteSpace($self.Value)) {
            $self.IsValid = $false
            $self.ValidationMessage = "$($self.Label) is required"
            return $false
        }
        
        # Run validators
        foreach ($validator in $self.Validators) {
            $result = & $validator -Value $self.Value -Component $self
            if ($result -is [string]) {
                $self.IsValid = $false
                $self.ValidationMessage = $result
                return $false
            } elseif ($result -eq $false) {
                $self.IsValid = $false
                $self.ValidationMessage = "Validation failed"
                return $false
            }
        }
        
        return $true
    }
    
    SetValue = {
        param($self, $newValue)
        
        $oldValue = $self.Value
        $self.Value = $newValue
        
        # Trigger validation
        & $self.Validate -self $self
        
        # Trigger change event
        if ($self.OnChange) {
            & $self.OnChange -Component $self -OldValue $oldValue -NewValue $newValue
        }
        
        # Publish event
        Publish-Event -EventName "Component.ValueChanged" -Data @{
            Component = $self
            OldValue = $oldValue
            NewValue = $newValue
        }
    }
}

#endregion

#region TextField Component

function New-TextField {
    param(
        [hashtable]$Props = @{}
    )
    
    $textField = $script:InputComponentBase.Clone()
    $textField.Type = "TextField"
    $textField.EditBuffer = ""
    $textField.CursorPosition = 0
    $textField.ScrollOffset = 0
    
    # Override properties
    foreach ($key in $Props.Keys) {
        $textField[$key] = $Props[$key]
    }
    
    # TextField specific render
    $textField.Render = {
        param($self)
        
        # Label
        if ($self.Label) {
            $labelColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
            Write-BufferString -X $self.X -Y $self.Y -Text "$($self.Label):" -ForegroundColor $labelColor
        }
        
        # Input box
        $boxY = if ($self.Label) { $self.Y + 1 } else { $self.Y }
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" }
                       elseif (-not $self.IsValid) { Get-ThemeColor "Error" }
                       else { Get-ThemeColor "Secondary" }
        
        Write-BufferBox -X $self.X -Y $boxY -Width $self.Width -Height 3 -BorderColor $borderColor
        
        # Value or placeholder
        $displayValue = if ($self.IsFocused -and -not $self.IsReadOnly) {
            $self.EditBuffer
        } else {
            $self.Value
        }
        
        if ([string]::IsNullOrEmpty($displayValue) -and $self.Placeholder) {
            Write-BufferString -X ($self.X + 2) -Y ($boxY + 1) `
                -Text $self.Placeholder `
                -ForegroundColor (Get-ThemeColor "Subtle")
        } else {
            # Handle scrolling for long text
            $visibleWidth = $self.Width - 4
            if ($displayValue.Length -gt $visibleWidth) {
                if ($self.IsFocused) {
                    # Scroll to show cursor
                    $start = [Math]::Max(0, $self.CursorPosition - $visibleWidth + 1)
                    $displayText = $displayValue.Substring($start, [Math]::Min($visibleWidth, $displayValue.Length - $start))
                } else {
                    $displayText = $displayValue.Substring(0, $visibleWidth - 3) + "..."
                }
            } else {
                $displayText = $displayValue
            }
            
            Write-BufferString -X ($self.X + 2) -Y ($boxY + 1) `
                -Text $displayText `
                -ForegroundColor (Get-ThemeColor "Primary")
            
            # Cursor
            if ($self.IsFocused -and -not $self.IsReadOnly) {
                $cursorX = ($self.X + 2) + [Math]::Min($self.CursorPosition, $visibleWidth - 1)
                Write-BufferString -X $cursorX -Y ($boxY + 1) -Text "_" `
                    -ForegroundColor (Get-ThemeColor "Accent")
            }
        }
        
        # Validation message
        if (-not $self.IsValid -and $self.ValidationMessage) {
            $msgY = $boxY + 3
            Write-BufferString -X $self.X -Y $msgY `
                -Text $self.ValidationMessage `
                -ForegroundColor (Get-ThemeColor "Error")
        }
    }
    
    # TextField input handling
    $textField.HandleInput = {
        param($self, $key)
        
        if ($self.IsReadOnly) { return $null }
        
        switch ($key.Key) {
            ([ConsoleKey]::Enter) {
                & $self.SetValue -self $self -newValue $self.EditBuffer
                return "Next"
            }
            ([ConsoleKey]::Tab) {
                & $self.SetValue -self $self -newValue $self.EditBuffer
                return "Next"
            }
            ([ConsoleKey]::Escape) {
                $self.EditBuffer = $self.Value
                $self.CursorPosition = $self.EditBuffer.Length
                return "Cancel"
            }
            ([ConsoleKey]::Backspace) {
                if ($self.CursorPosition -gt 0) {
                    $self.EditBuffer = $self.EditBuffer.Remove($self.CursorPosition - 1, 1)
                    $self.CursorPosition--
                }
            }
            ([ConsoleKey]::Delete) {
                if ($self.CursorPosition -lt $self.EditBuffer.Length) {
                    $self.EditBuffer = $self.EditBuffer.Remove($self.CursorPosition, 1)
                }
            }
            ([ConsoleKey]::LeftArrow) {
                if ($self.CursorPosition -gt 0) {
                    $self.CursorPosition--
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($self.CursorPosition -lt $self.EditBuffer.Length) {
                    $self.CursorPosition++
                }
            }
            ([ConsoleKey]::Home) {
                $self.CursorPosition = 0
            }
            ([ConsoleKey]::End) {
                $self.CursorPosition = $self.EditBuffer.Length
            }
            default {
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    if ($self.EditBuffer.Length -lt $self.MaxLength) {
                        $self.EditBuffer = $self.EditBuffer.Insert($self.CursorPosition, $key.KeyChar)
                        $self.CursorPosition++
                    }
                }
            }
        }
        
        return $null
    }
    
    # Focus/Blur handlers
    $textField.Focus = {
        param($self)
        
        $self.IsFocused = $true
        $self.EditBuffer = $self.Value
        $self.CursorPosition = $self.EditBuffer.Length
        
        if ($self.OnFocus) {
            & $self.OnFocus -Component $self
        }
    }
    
    $textField.Blur = {
        param($self)
        
        $self.IsFocused = $false
        
        # Save value on blur
        if ($self.EditBuffer -ne $self.Value) {
            & $self.SetValue -self $self -newValue $self.EditBuffer
        }
        
        if ($self.OnBlur) {
            & $self.OnBlur -Component $self
        }
    }
    
    return $textField
}

#endregion

#region NumberField Component

function New-NumberField {
    param(
        [hashtable]$Props = @{}
    )
    
    $numberField = New-TextField -Props $Props
    $numberField.Type = "NumberField"
    $numberField.Min = $null
    $numberField.Max = $null
    $numberField.DecimalPlaces = 2
    $numberField.AllowNegative = $true
    
    # Override properties
    foreach ($key in $Props.Keys) {
        $numberField[$key] = $Props[$key]
    }
    
    # Add number validation
    $numberField.Validators += {
        param($Value, $Component)
        
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $true  # Empty is valid unless required
        }
        
        $number = 0
        if (-not [double]::TryParse($Value, [ref]$number)) {
            return "Must be a valid number"
        }
        
        if ($Component.Min -ne $null -and $number -lt $Component.Min) {
            return "Must be at least $($Component.Min)"
        }
        
        if ($Component.Max -ne $null -and $number -gt $Component.Max) {
            return "Must be at most $($Component.Max)"
        }
        
        if (-not $Component.AllowNegative -and $number -lt 0) {
            return "Must be positive"
        }
        
        return $true
    }
    
    # Override input handling for numbers
    $baseHandleInput = $numberField.HandleInput
    $numberField.HandleInput = {
        param($self, $key)
        
        # Allow only number-related characters
        if ($key.KeyChar) {
            $char = $key.KeyChar
            if (-not ([char]::IsDigit($char) -or 
                     $char -eq '.' -or 
                     ($char -eq '-' -and $self.AllowNegative -and $self.CursorPosition -eq 0))) {
                return $null
            }
        }
        
        return & $baseHandleInput -self $self -key $key
    }
    
    return $numberField
}

#endregion

#region DatePicker Component

function New-DatePicker {
    param(
        [hashtable]$Props = @{}
    )
    
    $datePicker = $script:InputComponentBase.Clone()
    $datePicker.Type = "DatePicker"
    $datePicker.Value = (Get-Date).Date
    $datePicker.Format = "yyyy-MM-dd"
    $datePicker.MinDate = $null
    $datePicker.MaxDate = $null
    $datePicker.ShowCalendar = $false
    $datePicker.SelectedPart = 0  # 0=Year, 1=Month, 2=Day
    
    # Override properties
    foreach ($key in $Props.Keys) {
        $datePicker[$key] = $Props[$key]
    }
    
    $datePicker.Render = {
        param($self)
        
        # Label
        if ($self.Label) {
            $labelColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
            Write-BufferString -X $self.X -Y $self.Y -Text "$($self.Label):" -ForegroundColor $labelColor
        }
        
        # Date display
        $boxY = if ($self.Label) { $self.Y + 1 } else { $self.Y }
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" }
                       elseif (-not $self.IsValid) { Get-ThemeColor "Error" }
                       else { Get-ThemeColor "Secondary" }
        
        Write-BufferBox -X $self.X -Y $boxY -Width $self.Width -Height 3 -BorderColor $borderColor
        
        # Format date
        $dateStr = $self.Value.ToString($self.Format)
        $parts = $dateStr -split '-'
        
        # Highlight selected part
        $x = $self.X + 2
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $color = if ($self.IsFocused -and $i -eq $self.SelectedPart) { 
                Get-ThemeColor "Accent" 
            } else { 
                Get-ThemeColor "Primary" 
            }
            
            Write-BufferString -X $x -Y ($boxY + 1) -Text $parts[$i] -ForegroundColor $color
            $x += $parts[$i].Length
            
            if ($i -lt $parts.Count - 1) {
                Write-BufferString -X $x -Y ($boxY + 1) -Text "-" -ForegroundColor (Get-ThemeColor "Secondary")
                $x += 1
            }
        }
        
        # Calendar icon hint
        if ($self.IsFocused) {
            Write-BufferString -X ($self.X + $self.Width - 4) -Y ($boxY + 1) -Text "[↓]" `
                -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        # Mini calendar if requested
        if ($self.ShowCalendar -and $self.IsFocused) {
            Render-MiniCalendar -X $self.X -Y ($boxY + 3) -Date $self.Value
        }
    }
    
    $datePicker.HandleInput = {
        param($self, $key)
        
        $currentDate = $self.Value
        
        switch ($key.Key) {
            ([ConsoleKey]::LeftArrow) {
                if ($self.SelectedPart -gt 0) {
                    $self.SelectedPart--
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($self.SelectedPart -lt 2) {
                    $self.SelectedPart++
                }
            }
            ([ConsoleKey]::UpArrow) {
                switch ($self.SelectedPart) {
                    0 { $currentDate = $currentDate.AddYears(1) }
                    1 { $currentDate = $currentDate.AddMonths(1) }
                    2 { $currentDate = $currentDate.AddDays(1) }
                }
            }
            ([ConsoleKey]::DownArrow) {
                switch ($self.SelectedPart) {
                    0 { $currentDate = $currentDate.AddYears(-1) }
                    1 { $currentDate = $currentDate.AddMonths(-1) }
                    2 { $currentDate = $currentDate.AddDays(-1) }
                }
            }
            ([ConsoleKey]::PageUp) {
                $currentDate = $currentDate.AddMonths(1)
            }
            ([ConsoleKey]::PageDown) {
                $currentDate = $currentDate.AddMonths(-1)
            }
            ([ConsoleKey]::Spacebar) {
                $self.ShowCalendar = -not $self.ShowCalendar
            }
            ([ConsoleKey]::T) {
                # Today shortcut
                $currentDate = (Get-Date).Date
            }
            ([ConsoleKey]::Enter) {
                $self.ShowCalendar = $false
                return "Next"
            }
            ([ConsoleKey]::Tab) {
                $self.ShowCalendar = $false
                return "Next"
            }
            ([ConsoleKey]::Escape) {
                $self.ShowCalendar = $false
                return "Cancel"
            }
            default {
                # Allow number input for direct year entry
                if ($key.KeyChar -and [char]::IsDigit($key.KeyChar) -and $self.SelectedPart -eq 0) {
                    # Simple year input logic
                }
            }
        }
        
        # Validate date range
        if ($self.MinDate -and $currentDate -lt $self.MinDate) {
            $currentDate = $self.MinDate
        }
        if ($self.MaxDate -and $currentDate -gt $self.MaxDate) {
            $currentDate = $self.MaxDate
        }
        
        & $self.SetValue -self $self -newValue $currentDate
        return $null
    }
    
    # Focus handler
    $datePicker.Focus = {
        param($self)
        $self.IsFocused = $true
        $self.SelectedPart = 0
        
        if ($self.OnFocus) {
            & $self.OnFocus -Component $self
        }
    }
    
    $datePicker.Blur = {
        param($self)
        $self.IsFocused = $false
        $self.ShowCalendar = $false
        
        if ($self.OnBlur) {
            & $self.OnBlur -Component $self
        }
    }
    
    return $datePicker
}

function Render-MiniCalendar {
    param(
        [int]$X,
        [int]$Y,
        [DateTime]$Date
    )
    
    $firstDay = Get-Date -Year $Date.Year -Month $Date.Month -Day 1
    $daysInMonth = [DateTime]::DaysInMonth($Date.Year, $Date.Month)
    $startDayOfWeek = [int]$firstDay.DayOfWeek
    
    # Calendar box
    Write-BufferBox -X $X -Y $Y -Width 22 -Height 10 -BorderStyle "Single" `
        -BorderColor (Get-ThemeColor "Secondary")
    
    # Month/Year header
    $header = $Date.ToString("MMMM yyyy")
    Write-BufferString -X ($X + 11 - ($header.Length / 2)) -Y $Y -Text $header `
        -ForegroundColor (Get-ThemeColor "Accent")
    
    # Day headers
    $days = @("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
    $dayX = $X + 1
    foreach ($day in $days) {
        Write-BufferString -X $dayX -Y ($Y + 2) -Text $day `
            -ForegroundColor (Get-ThemeColor "Secondary")
        $dayX += 3
    }
    
    # Calendar days
    $currentDay = 1
    $weekY = $Y + 3
    
    for ($week = 0; $week -lt 6; $week++) {
        if ($currentDay -gt $daysInMonth) { break }
        
        for ($dayOfWeek = 0; $dayOfWeek -lt 7; $dayOfWeek++) {
            if ($week -eq 0 -and $dayOfWeek -lt $startDayOfWeek) {
                continue
            }
            
            if ($currentDay -le $daysInMonth) {
                $dayX = $X + 1 + ($dayOfWeek * 3)
                $dayStr = $currentDay.ToString().PadLeft(2)
                
                $color = if ($currentDay -eq $Date.Day) { Get-ThemeColor "Accent" }
                        elseif ($dayOfWeek -eq 0 -or $dayOfWeek -eq 6) { Get-ThemeColor "Secondary" }
                        else { Get-ThemeColor "Primary" }
                
                $bgColor = if ($currentDay -eq $Date.Day) { Get-ThemeColor "Secondary" } 
                          else { Get-ThemeColor "Background" }
                
                Write-BufferString -X $dayX -Y $weekY -Text $dayStr `
                    -ForegroundColor $color -BackgroundColor $bgColor
                
                $currentDay++
            }
        }
        $weekY++
    }
}

#endregion

#region Dropdown Component

function New-Dropdown {
    param(
        [hashtable]$Props = @{}
    )
    
    $dropdown = $script:InputComponentBase.Clone()
    $dropdown.Type = "Dropdown"
    $dropdown.Options = @()  # Array of @{Value=""; Display=""; Group=""}
    $dropdown.SelectedIndex = -1
    $dropdown.IsOpen = $false
    $dropdown.MaxDisplayItems = 5
    $dropdown.AllowSearch = $true
    $dropdown.SearchText = ""
    $dropdown.FilteredOptions = @()
    $dropdown.HighlightedIndex = 0
    
    # Override properties
    foreach ($key in $Props.Keys) {
        $dropdown[$key] = $Props[$key]
    }
    
    # Initialize
    $dropdown.FilteredOptions = $dropdown.Options
    
    $dropdown.Render = {
        param($self)
        
        # Label
        if ($self.Label) {
            $labelColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
            Write-BufferString -X $self.X -Y $self.Y -Text "$($self.Label):" -ForegroundColor $labelColor
        }
        
        # Dropdown box
        $boxY = if ($self.Label) { $self.Y + 1 } else { $self.Y }
        $borderColor = if ($self.IsFocused) { Get-ThemeColor "Accent" }
                       elseif (-not $self.IsValid) { Get-ThemeColor "Error" }
                       else { Get-ThemeColor "Secondary" }
        
        Write-BufferBox -X $self.X -Y $boxY -Width $self.Width -Height 3 -BorderColor $borderColor
        
        # Display selected value or placeholder
        $displayText = ""
        if ($self.SelectedIndex -ge 0 -and $self.SelectedIndex -lt $self.Options.Count) {
            $displayText = $self.Options[$self.SelectedIndex].Display
        } elseif ($self.Placeholder) {
            $displayText = $self.Placeholder
        }
        
        if ($self.IsOpen -and $self.AllowSearch) {
            # Show search text
            Write-BufferString -X ($self.X + 2) -Y ($boxY + 1) `
                -Text ($self.SearchText + "_") `
                -ForegroundColor (Get-ThemeColor "Accent")
        } else {
            # Show selected value
            $textColor = if ($displayText -eq $self.Placeholder) { Get-ThemeColor "Subtle" } 
                        else { Get-ThemeColor "Primary" }
            
            $maxLen = $self.Width - 5
            if ($displayText.Length -gt $maxLen) {
                $displayText = $displayText.Substring(0, $maxLen - 3) + "..."
            }
            
            Write-BufferString -X ($self.X + 2) -Y ($boxY + 1) -Text $displayText -ForegroundColor $textColor
        }
        
        # Dropdown arrow
        $arrow = if ($self.IsOpen) { "▲" } else { "▼" }
        Write-BufferString -X ($self.X + $self.Width - 3) -Y ($boxY + 1) -Text $arrow `
            -ForegroundColor (Get-ThemeColor "Secondary")
        
        # Options list
        if ($self.IsOpen -and $self.FilteredOptions.Count -gt 0) {
            $listHeight = [Math]::Min($self.MaxDisplayItems, $self.FilteredOptions.Count) + 2
            $listY = $boxY + 3
            
            Write-BufferBox -X $self.X -Y $listY -Width $self.Width -Height $listHeight `
                -BorderColor (Get-ThemeColor "Accent") -BackgroundColor (Get-ThemeColor "Background")
            
            # Render visible options
            $startIndex = [Math]::Max(0, $self.HighlightedIndex - $self.MaxDisplayItems + 1)
            $endIndex = [Math]::Min($self.FilteredOptions.Count, $startIndex + $self.MaxDisplayItems)
            
            $optionY = $listY + 1
            for ($i = $startIndex; $i -lt $endIndex; $i++) {
                $option = $self.FilteredOptions[$i]
                $isHighlighted = $i -eq $self.HighlightedIndex
                
                if ($isHighlighted) {
                    # Highlight bar
                    for ($x = ($self.X + 1); $x -lt ($self.X + $self.Width - 1); $x++) {
                        Write-BufferString -X $x -Y $optionY -Text " " `
                            -BackgroundColor (Get-ThemeColor "Secondary")
                    }
                }
                
                $optionText = $option.Display
                if ($optionText.Length -gt ($self.Width - 4)) {
                    $optionText = $optionText.Substring(0, $self.Width - 7) + "..."
                }
                
                Write-BufferString -X ($self.X + 2) -Y $optionY -Text $optionText `
                    -ForegroundColor (if ($isHighlighted) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }) `
                    -BackgroundColor (if ($isHighlighted) { Get-ThemeColor "Secondary" } else { Get-ThemeColor "Background" })
                
                $optionY++
            }
            
            # Scroll indicators
            if ($startIndex -gt 0) {
                Write-BufferString -X ($self.X + $self.Width - 3) -Y ($listY + 1) -Text "↑" `
                    -ForegroundColor (Get-ThemeColor "Subtle")
            }
            if ($endIndex -lt $self.FilteredOptions.Count) {
                Write-BufferString -X ($self.X + $self.Width - 3) -Y ($listY + $listHeight - 2) -Text "↓" `
                    -ForegroundColor (Get-ThemeColor "Subtle")
            }
        }
    }
    
    $dropdown.HandleInput = {
        param($self, $key)
        
        if (-not $self.IsOpen) {
            switch ($key.Key) {
                ([ConsoleKey]::Enter) { 
                    $self.IsOpen = $true
                    $self.SearchText = ""
                    $self.FilteredOptions = $self.Options
                    $self.HighlightedIndex = [Math]::Max(0, $self.SelectedIndex)
                }
                ([ConsoleKey]::Spacebar) { 
                    $self.IsOpen = $true
                    $self.SearchText = ""
                    $self.FilteredOptions = $self.Options
                    $self.HighlightedIndex = [Math]::Max(0, $self.SelectedIndex)
                }
                ([ConsoleKey]::DownArrow) { 
                    $self.IsOpen = $true
                    $self.SearchText = ""
                    $self.FilteredOptions = $self.Options
                    $self.HighlightedIndex = [Math]::Max(0, $self.SelectedIndex)
                }
                ([ConsoleKey]::Tab) { return "Next" }
                ([ConsoleKey]::Escape) { return "Cancel" }
            }
        } else {
            # Open dropdown handling
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.HighlightedIndex -gt 0) {
                        $self.HighlightedIndex--
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.HighlightedIndex -lt ($self.FilteredOptions.Count - 1)) {
                        $self.HighlightedIndex++
                    }
                }
                ([ConsoleKey]::PageUp) {
                    $self.HighlightedIndex = [Math]::Max(0, $self.HighlightedIndex - $self.MaxDisplayItems)
                }
                ([ConsoleKey]::PageDown) {
                    $self.HighlightedIndex = [Math]::Min($self.FilteredOptions.Count - 1, 
                                                         $self.HighlightedIndex + $self.MaxDisplayItems)
                }
                ([ConsoleKey]::Home) {
                    $self.HighlightedIndex = 0
                }
                ([ConsoleKey]::End) {
                    $self.HighlightedIndex = $self.FilteredOptions.Count - 1
                }
                ([ConsoleKey]::Enter) {
                    if ($self.FilteredOptions.Count -gt 0) {
                        $selectedOption = $self.FilteredOptions[$self.HighlightedIndex]
                        $self.SelectedIndex = $self.Options.IndexOf($selectedOption)
                        & $self.SetValue -self $self -newValue $selectedOption.Value
                    }
                    $self.IsOpen = $false
                    return "Next"
                }
                ([ConsoleKey]::Tab) {
                    if ($self.FilteredOptions.Count -gt 0) {
                        $selectedOption = $self.FilteredOptions[$self.HighlightedIndex]
                        $self.SelectedIndex = $self.Options.IndexOf($selectedOption)
                        & $self.SetValue -self $self -newValue $selectedOption.Value
                    }
                    $self.IsOpen = $false
                    return "Next"
                }
                ([ConsoleKey]::Escape) {
                    $self.IsOpen = $false
                    $self.SearchText = ""
                    $self.FilteredOptions = $self.Options
                }
                ([ConsoleKey]::Backspace) {
                    if ($self.AllowSearch -and $self.SearchText.Length -gt 0) {
                        $self.SearchText = $self.SearchText.Substring(0, $self.SearchText.Length - 1)
                        Filter-DropdownOptions -Dropdown $self
                    }
                }
                default {
                    if ($self.AllowSearch -and $key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar)) {
                        $self.SearchText += $key.KeyChar
                        Filter-DropdownOptions -Dropdown $self
                    }
                }
            }
        }
        
        return $null
    }
    
    # Focus handlers
    $dropdown.Focus = {
        param($self)
        $self.IsFocused = $true
        if ($self.OnFocus) {
            & $self.OnFocus -Component $self
        }
    }
    
    $dropdown.Blur = {
        param($self)
        $self.IsFocused = $false
        $self.IsOpen = $false
        $self.SearchText = ""
        $self.FilteredOptions = $self.Options
        
        if ($self.OnBlur) {
            & $self.OnBlur -Component $self
        }
    }
    
    return $dropdown
}

function Filter-DropdownOptions {
    param($Dropdown)
    
    if ([string]::IsNullOrWhiteSpace($Dropdown.SearchText)) {
        $Dropdown.FilteredOptions = $Dropdown.Options
    } else {
        $Dropdown.FilteredOptions = @($Dropdown.Options | Where-Object {
            $_.Display -like "*$($Dropdown.SearchText)*" -or
            $_.Value -like "*$($Dropdown.SearchText)*"
        })
    }
    
    $Dropdown.HighlightedIndex = 0
}

#endregion

#region Checkbox Component

function New-Checkbox {
    param(
        [hashtable]$Props = @{}
    )
    
    $checkbox = $script:InputComponentBase.Clone()
    $checkbox.Type = "Checkbox"
    $checkbox.Value = $false
    $checkbox.Height = 1
    
    # Override properties
    foreach ($key in $Props.Keys) {
        $checkbox[$key] = $Props[$key]
    }
    
    $checkbox.Render = {
        param($self)
        
        # Checkbox
        $checkChar = if ($self.Value) { "☑" } else { "☐" }
        $color = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
        
        Write-BufferString -X $self.X -Y $self.Y -Text $checkChar -ForegroundColor $color
        
        # Label
        if ($self.Label) {
            Write-BufferString -X ($self.X + 2) -Y $self.Y -Text $self.Label -ForegroundColor $color
        }
    }
    
    $checkbox.HandleInput = {
        param($self, $key)
        
        switch ($key.Key) {
            ([ConsoleKey]::Spacebar) {
                & $self.SetValue -self $self -newValue (-not $self.Value)
            }
            ([ConsoleKey]::Enter) {
                & $self.SetValue -self $self -newValue (-not $self.Value)
                return "Next"
            }
            ([ConsoleKey]::Tab) { return "Next" }
            ([ConsoleKey]::Escape) { return "Cancel" }
        }
        
        return $null
    }
    
    return $checkbox
}

#endregion

#region RadioButton Component

function New-RadioGroup {
    param(
        [hashtable]$Props = @{}
    )
    
    $radioGroup = $script:InputComponentBase.Clone()
    $radioGroup.Type = "RadioGroup"
    $radioGroup.Options = @()  # Array of @{Value=""; Display=""}
    $radioGroup.SelectedIndex = -1
    $radioGroup.Orientation = "Vertical"  # or "Horizontal"
    $radioGroup.HighlightedOption = 0
    
    # Override properties
    foreach ($key in $Props.Keys) {
        $radioGroup[$key] = $Props[$key]
    }
    
    # Calculate height based on options
    if ($radioGroup.Orientation -eq "Vertical") {
        $radioGroup.Height = $radioGroup.Options.Count + (if ($radioGroup.Label) { 1 } else { 0 })
    }
    
    $radioGroup.Render = {
        param($self)
        
        $y = $self.Y
        $x = $self.X
        
        # Label
        if ($self.Label) {
            $labelColor = if ($self.IsFocused) { Get-ThemeColor "Accent" } else { Get-ThemeColor "Primary" }
            Write-BufferString -X $x -Y $y -Text "$($self.Label):" -ForegroundColor $labelColor
            $y++
        }
        
        # Options
        for ($i = 0; $i -lt $self.Options.Count; $i++) {
            $option = $self.Options[$i]
            $isSelected = $i -eq $self.SelectedIndex
            $radioChar = if ($isSelected) { "◉" } else { "○" }
            
            $color = if ($self.IsFocused -and $i -eq $self.HighlightedOption) { 
                Get-ThemeColor "Accent" 
            } else { 
                Get-ThemeColor "Primary" 
            }
            
            Write-BufferString -X $x -Y $y -Text $radioChar -ForegroundColor $color
            Write-BufferString -X ($x + 2) -Y $y -Text $option.Display -ForegroundColor $color
            
            if ($self.Orientation -eq "Vertical") {
                $y++
            } else {
                $x += $option.Display.Length + 4
            }
        }
    }
    
    $radioGroup.HandleInput = {
        param($self, $key)
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($self.Orientation -eq "Vertical" -and $self.HighlightedOption -gt 0) {
                    $self.HighlightedOption--
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($self.Orientation -eq "Vertical" -and $self.HighlightedOption -lt ($self.Options.Count - 1)) {
                    $self.HighlightedOption++
                }
            }
            ([ConsoleKey]::LeftArrow) {
                if ($self.Orientation -eq "Horizontal" -and $self.HighlightedOption -gt 0) {
                    $self.HighlightedOption--
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($self.Orientation -eq "Horizontal" -and $self.HighlightedOption -lt ($self.Options.Count - 1)) {
                    $self.HighlightedOption++
                }
            }
            ([ConsoleKey]::Spacebar) {
                $self.SelectedIndex = $self.HighlightedOption
                & $self.SetValue -self $self -newValue $self.Options[$self.SelectedIndex].Value
            }
            ([ConsoleKey]::Enter) {
                $self.SelectedIndex = $self.HighlightedOption
                & $self.SetValue -self $self -newValue $self.Options[$self.SelectedIndex].Value
                return "Next"
            }
            ([ConsoleKey]::Tab) { return "Next" }
            ([ConsoleKey]::Escape) { return "Cancel" }
            default {
                # Number shortcuts
                if ($key.KeyChar -and [char]::IsDigit($key.KeyChar)) {
                    $num = [int]::Parse($key.KeyChar.ToString())
                    if ($num -gt 0 -and $num -le $self.Options.Count) {
                        $self.SelectedIndex = $num - 1
                        $self.HighlightedOption = $self.SelectedIndex
                        & $self.SetValue -self $self -newValue $self.Options[$self.SelectedIndex].Value
                    }
                }
            }
        }
        
        return $null
    }
    
    $radioGroup.Focus = {
        param($self)
        $self.IsFocused = $true
        $self.HighlightedOption = [Math]::Max(0, $self.SelectedIndex)
        
        if ($self.OnFocus) {
            & $self.OnFocus -Component $self
        }
    }
    
    return $radioGroup
}

#endregion

#region Form Manager

function New-Form {
    param(
        [string]$Title = "Form",
        [array]$Fields = @(),
        [scriptblock]$OnSubmit = $null,
        [scriptblock]$OnCancel = $null
    )
    
    $form = @{
        Title = $Title
        Fields = $Fields
        CurrentFieldIndex = 0
        IsValid = $true
        Errors = @{}
        OnSubmit = $OnSubmit
        OnCancel = $OnCancel
        
        Render = {
            param($self, $X, $Y, $Width, $Height)
            
            # Form box
            Write-BufferBox -X $X -Y $Y -Width $Width -Height $Height `
                -Title $self.Title -BorderColor (Get-ThemeColor "Accent")
            
            # Render fields
            $fieldY = $Y + 2
            foreach ($field in $self.Fields) {
                # Calculate field position
                $field.X = $X + 2
                $field.Y = $fieldY
                $field.Width = $Width - 4
                
                # Render field
                & $field.Render -self $field
                
                # Move to next field position
                $fieldY += $field.Height + 1
                if ($field.ValidationMessage) {
                    $fieldY += 1
                }
            }
            
            # Form buttons
            $buttonY = $Y + $Height - 3
            $submitColor = if ($self.CurrentFieldIndex -eq $self.Fields.Count) { 
                Get-ThemeColor "Success" 
            } else { 
                Get-ThemeColor "Secondary" 
            }
            $cancelColor = if ($self.CurrentFieldIndex -eq ($self.Fields.Count + 1)) { 
                Get-ThemeColor "Error" 
            } else { 
                Get-ThemeColor "Secondary" 
            }
            
            Write-BufferString -X ($X + 10) -Y $buttonY -Text "[Submit]" -ForegroundColor $submitColor
            Write-BufferString -X ($X + 25) -Y $buttonY -Text "[Cancel]" -ForegroundColor $cancelColor
        }
        
        HandleInput = {
            param($self, $key)
            
            # Handle field navigation
            if ($self.CurrentFieldIndex -lt $self.Fields.Count) {
                $currentField = $self.Fields[$self.CurrentFieldIndex]
                $result = & $currentField.HandleInput -self $currentField -key $key
                
                switch ($result) {
                    "Next" {
                        # Validate current field
                        if (& $currentField.Validate -self $currentField) {
                            # Blur current field
                            if ($currentField.Blur) {
                                & $currentField.Blur -self $currentField
                            }
                            
                            # Move to next field
                            $self.CurrentFieldIndex++
                            
                            # Focus next field
                            if ($self.CurrentFieldIndex -lt $self.Fields.Count) {
                                $nextField = $self.Fields[$self.CurrentFieldIndex]
                                if ($nextField.Focus) {
                                    & $nextField.Focus -self $nextField
                                }
                            }
                        }
                    }
                    "Cancel" {
                        if ($self.OnCancel) {
                            & $self.OnCancel -Form $self
                        }
                        return "Cancel"
                    }
                }
            } else {
                # Handle button navigation
                switch ($key.Key) {
                    ([ConsoleKey]::LeftArrow) {
                        if ($self.CurrentFieldIndex -eq ($self.Fields.Count + 1)) {
                            $self.CurrentFieldIndex--
                        }
                    }
                    ([ConsoleKey]::RightArrow) {
                        if ($self.CurrentFieldIndex -eq $self.Fields.Count) {
                            $self.CurrentFieldIndex++
                        }
                    }
                    ([ConsoleKey]::Tab) {
                        if ($self.CurrentFieldIndex -eq $self.Fields.Count) {
                            $self.CurrentFieldIndex++
                        } else {
                            $self.CurrentFieldIndex = 0
                            if ($self.Fields.Count -gt 0) {
                                & $self.Fields[0].Focus -self $self.Fields[0]
                            }
                        }
                    }
                    ([ConsoleKey]::Enter) {
                        if ($self.CurrentFieldIndex -eq $self.Fields.Count) {
                            # Submit
                            if (& $self.ValidateAll -self $self) {
                                if ($self.OnSubmit) {
                                    $data = @{}
                                    foreach ($field in $self.Fields) {
                                        $data[$field.Name ?? $field.Label] = $field.Value
                                    }
                                    & $self.OnSubmit -Form $self -Data $data
                                }
                                return "Submit"
                            }
                        } else {
                            # Cancel
                            if ($self.OnCancel) {
                                & $self.OnCancel -Form $self
                            }
                            return "Cancel"
                        }
                    }
                    ([ConsoleKey]::Escape) {
                        if ($self.OnCancel) {
                            & $self.OnCancel -Form $self
                        }
                        return "Cancel"
                    }
                }
            }
            
            return $null
        }
        
        ValidateAll = {
            param($self)
            
            $isValid = $true
            foreach ($field in $self.Fields) {
                if (-not (& $field.Validate -self $field)) {
                    $isValid = $false
                }
            }
            
            $self.IsValid = $isValid
            return $isValid
        }
        
        Focus = {
            param($self)
            
            $self.CurrentFieldIndex = 0
            if ($self.Fields.Count -gt 0) {
                & $self.Fields[0].Focus -self $self.Fields[0]
            }
        }
    }
    
    # Set field names if not set
    for ($i = 0; $i -lt $form.Fields.Count; $i++) {
        if (-not $form.Fields[$i].Name) {
            $form.Fields[$i].Name = "Field$i"
        }
    }
    
    return $form
}

#endregion

#region Validation Helpers

$script:Validators = @{
    Required = {
        param($Value, $Component)
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return "$($Component.Label) is required"
        }
        return $true
    }
    
    Email = {
        param($Value, $Component)
        if ($Value -notmatch '^[\w\.-]+@[\w\.-]+\.\w+$') {
            return "Invalid email format"
        }
        return $true
    }
    
    MinLength = {
        param($Value, $Component, $MinLength = 3)
        if ($Value.Length -lt $MinLength) {
            return "Must be at least $MinLength characters"
        }
        return $true
    }
    
    MaxLength = {
        param($Value, $Component, $MaxLength = 100)
        if ($Value.Length -gt $MaxLength) {
            return "Must be at most $MaxLength characters"
        }
        return $true
    }
    
    Pattern = {
        param($Value, $Component, $Pattern)
        if ($Value -notmatch $Pattern) {
            return "Invalid format"
        }
        return $true
    }
    
    Custom = {
        param($Value, $Component, $ValidationScript)
        return & $ValidationScript -Value $Value -Component $Component
    }
}

#endregion
