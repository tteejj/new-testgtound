# FILE: layout/panels.psm1
# PURPOSE: Provides a suite of specialized layout panels for declarative UI construction.

function private:New-BasePanel {
    param([hashtable]$Props)
    
    $panel = @{
        Type = "Panel"
        Name = $Props.Name ?? "Panel_$([Guid]::NewGuid().ToString('N').Substring(0,8))"
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 40
        Height = $Props.Height ?? 20
        Visible = $Props.Visible ?? $true
        IsFocusable = $Props.IsFocusable ?? $false
        Children = @()
        Parent = $null
        LayoutProps = $Props.LayoutProps ?? @{}
        ShowBorder = $Props.ShowBorder ?? $false
        BorderStyle = $Props.BorderStyle ?? "Single"  # Single, Double, Rounded
        Title = $Props.Title
        Padding = $Props.Padding ?? 0
        Margin = $Props.Margin ?? 0
        BackgroundColor = $Props.BackgroundColor
        ForegroundColor = $Props.ForegroundColor
        _isDirty = $true
        _cachedLayout = $null
        
        AddChild = { 
            param($self, $Child, [hashtable]$LayoutProps = @{})
            
            if (-not $Child) {
                throw "Cannot add null child to panel"
            }
            
            $Child.Parent = $self
            $Child.LayoutProps = $LayoutProps
            $self.Children += $Child
            $self._isDirty = $true
            
            # Propagate visibility
            if (-not $self.Visible) {
                $Child.Visible = $false
            }
        }
        
        RemoveChild = {
            param($self, $Child)
            
            $self.Children = $self.Children | Where-Object { $_ -ne $Child }
            if ($Child.Parent -eq $self) {
                $Child.Parent = $null
            }
            $self._isDirty = $true
        }
        
        ClearChildren = {
            param($self)
            
            foreach ($child in $self.Children) {
                $child.Parent = $null
            }
            $self.Children = @()
            $self._isDirty = $true
        }
        
        Show = { 
            param($self)
            
            $self.Visible = $true
            foreach ($child in $self.Children) { 
                if ($child.Show) { 
                    & $child.Show -self $child
                } else { 
                    $child.Visible = $true
                }
            }
            
            # Request refresh if we have access to the function
            if (Get-Command -Name "Request-TuiRefresh" -ErrorAction SilentlyContinue) {
                Request-TuiRefresh
            }
        }
        
        Hide = { 
            param($self)
            
            $self.Visible = $false
            foreach ($child in $self.Children) { 
                if ($child.Hide) { 
                    & $child.Hide -self $child
                } else { 
                    $child.Visible = $false
                }
            }
            
            # Request refresh if we have access to the function
            if (Get-Command -Name "Request-TuiRefresh" -ErrorAction SilentlyContinue) {
                Request-TuiRefresh
            }
        }
        
        HandleInput = { 
            param($self, $Key)
            
            # Panels typically don't handle input directly
            # but can be overridden for special behavior
            return $false
        }
        
        GetContentBounds = {
            param($self)
            
            $borderOffset = if ($self.ShowBorder) { 1 } else { 0 }
            
            return @{
                X = $self.X + $self.Padding + $borderOffset + $self.Margin
                Y = $self.Y + $self.Padding + $borderOffset + $self.Margin
                Width = $self.Width - (2 * ($self.Padding + $borderOffset + $self.Margin))
                Height = $self.Height - (2 * ($self.Padding + $borderOffset + $self.Margin))
            }
        }
        
        InvalidateLayout = {
            param($self)
            
            $self._isDirty = $true
            
            # Propagate to parent
            if ($self.Parent -and $self.Parent.InvalidateLayout) {
                & $self.Parent.InvalidateLayout -self $self.Parent
            }
        }
    }
    
    return $panel
}

function global:New-TuiStackPanel {
    param([hashtable]$Props = @{})
    
    $panel = New-BasePanel -Props $Props
    $panel.Type = "StackPanel"
    $panel.Layout = 'Stack'
    $panel.Orientation = $Props.Orientation ?? 'Vertical'
    $panel.Spacing = $Props.Spacing ?? 1
    $panel.HorizontalAlignment = $Props.HorizontalAlignment ?? 'Stretch'  # Left, Center, Right, Stretch
    $panel.VerticalAlignment = $Props.VerticalAlignment ?? 'Stretch'      # Top, Middle, Bottom, Stretch
    
    $panel.CalculateLayout = {
        param($self)
        
        if (-not $self._isDirty) {
            return $self._cachedLayout
        }
        
        $bounds = & $self.GetContentBounds -self $self
        $layout = @{
            Children = @()
        }
        
        $currentX = $bounds.X
        $currentY = $bounds.Y
        $totalChildWidth = 0
        $totalChildHeight = 0
        $visibleChildren = $self.Children | Where-Object { $_.Visible }
        
        # Calculate total size needed
        foreach ($child in $visibleChildren) {
            if ($self.Orientation -eq 'Vertical') {
                $totalChildHeight += $child.Height
                $totalChildWidth = [Math]::Max($totalChildWidth, $child.Width)
            } else {
                $totalChildWidth += $child.Width
                $totalChildHeight = [Math]::Max($totalChildHeight, $child.Height)
            }
        }
        
        # Add spacing
        if ($visibleChildren.Count -gt 1) {
            if ($self.Orientation -eq 'Vertical') {
                $totalChildHeight += ($visibleChildren.Count - 1) * $self.Spacing
            } else {
                $totalChildWidth += ($visibleChildren.Count - 1) * $self.Spacing
            }
        }
        
        # Calculate starting position based on alignment
        if ($self.Orientation -eq 'Vertical') {
            switch ($self.VerticalAlignment) {
                'Top' { $currentY = $bounds.Y }
                'Middle' { $currentY = $bounds.Y + [Math]::Floor(($bounds.Height - $totalChildHeight) / 2) }
                'Bottom' { $currentY = $bounds.Y + $bounds.Height - $totalChildHeight }
                'Stretch' { $currentY = $bounds.Y }
            }
        } else {
            switch ($self.HorizontalAlignment) {
                'Left' { $currentX = $bounds.X }
                'Center' { $currentX = $bounds.X + [Math]::Floor(($bounds.Width - $totalChildWidth) / 2) }
                'Right' { $currentX = $bounds.X + $bounds.Width - $totalChildWidth }
                'Stretch' { $currentX = $bounds.X }
            }
        }
        
        # Layout children
        foreach ($child in $visibleChildren) {
            $childLayout = @{
                Component = $child
                X = $currentX
                Y = $currentY
                Width = $child.Width
                Height = $child.Height
            }
            
            # Apply stretch behavior
            if ($self.Orientation -eq 'Vertical' -and $self.HorizontalAlignment -eq 'Stretch') {
                $childLayout.Width = $bounds.Width
            }
            elseif ($self.Orientation -eq 'Horizontal' -and $self.VerticalAlignment -eq 'Stretch') {
                $childLayout.Height = $bounds.Height
            }
            
            # Handle horizontal alignment for vertical stacks
            if ($self.Orientation -eq 'Vertical' -and $self.HorizontalAlignment -ne 'Stretch') {
                switch ($self.HorizontalAlignment) {
                    'Center' { $childLayout.X = $bounds.X + [Math]::Floor(($bounds.Width - $child.Width) / 2) }
                    'Right' { $childLayout.X = $bounds.X + $bounds.Width - $child.Width }
                }
            }
            
            # Handle vertical alignment for horizontal stacks
            if ($self.Orientation -eq 'Horizontal' -and $self.VerticalAlignment -ne 'Stretch') {
                switch ($self.VerticalAlignment) {
                    'Middle' { $childLayout.Y = $bounds.Y + [Math]::Floor(($bounds.Height - $child.Height) / 2) }
                    'Bottom' { $childLayout.Y = $bounds.Y + $bounds.Height - $child.Height }
                }
            }
            
            $layout.Children += $childLayout
            
            # Move to next position
            if ($self.Orientation -eq 'Vertical') {
                $currentY += $childLayout.Height + $self.Spacing
            } else {
                $currentX += $childLayout.Width + $self.Spacing
            }
        }
        
        $self._cachedLayout = $layout
        $self._isDirty = $false
        return $layout
    }
    
    $panel.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        # Clear background if color specified
        if ($self.BackgroundColor -and (Get-Command -Name "Write-BufferBox" -ErrorAction SilentlyContinue)) {
            for ($y = $self.Y; $y -lt ($self.Y + $self.Height); $y++) {
                Write-BufferString -X $self.X -Y $y -Text (' ' * $self.Width) -BackgroundColor $self.BackgroundColor
            }
        }
        
        # Draw border if requested
        if ($self.ShowBorder -and (Get-Command -Name "Write-BufferBox" -ErrorAction SilentlyContinue)) {
            $borderColor = if ($self.ForegroundColor) { $self.ForegroundColor } else { Get-ThemeColor "Border" -Default Gray }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor -Title $self.Title
        }
        
        # Calculate and apply layout
        $layout = & $self.CalculateLayout -self $self
        
        foreach ($childLayout in $layout.Children) {
            $child = $childLayout.Component
            
            # Apply calculated position
            $child.X = $childLayout.X
            $child.Y = $childLayout.Y
            
            # Apply calculated size if child supports it
            if ($childLayout.Width -ne $child.Width -and $child.PSObject.Properties['Width'].IsSettable) {
                $child.Width = $childLayout.Width
            }
            if ($childLayout.Height -ne $child.Height -and $child.PSObject.Properties['Height'].IsSettable) {
                $child.Height = $childLayout.Height
            }
            
            # Render child
            if ($child.Render) {
                & $child.Render -self $child
            }
        }
    }
    
    return $panel
}

function global:New-TuiGridPanel {
    param([hashtable]$Props = @{})
    
    $panel = New-BasePanel -Props $Props
    $panel.Type = "GridPanel"
    $panel.Layout = 'Grid'
    $panel.RowDefinitions = $Props.RowDefinitions ?? @("1*")
    $panel.ColumnDefinitions = $Props.ColumnDefinitions ?? @("1*")
    $panel.ShowGridLines = $Props.ShowGridLines ?? $false
    $panel.GridLineColor = $Props.GridLineColor ?? (Get-ThemeColor "BorderDim" -Default DarkGray)
    
    $panel._CalculateGridSizes = {
        param($self, $definitions, $totalSize)
        
        # Parse definitions and calculate sizes
        $parsedDefs = @()
        $totalFixed = 0
        $totalStars = 0
        
        foreach ($def in $definitions) {
            if ($def -match '^(\d+)$') {
                # Fixed size
                $size = [int]$Matches[1]
                $parsedDefs += @{ Type = 'Fixed'; Value = $size }
                $totalFixed += $size
            }
            elseif ($def -match '^(\d*\.?\d*)\*$') {
                # Star size
                $stars = if ($Matches[1]) { [double]$Matches[1] } else { 1.0 }
                $parsedDefs += @{ Type = 'Star'; Value = $stars }
                $totalStars += $stars
            }
            elseif ($def -eq 'Auto') {
                # Auto size (not implemented yet, treat as 1*)
                $parsedDefs += @{ Type = 'Star'; Value = 1.0 }
                $totalStars += 1.0
            }
            else {
                throw "Invalid grid definition: $def"
            }
        }
        
        # Calculate actual sizes
        $remainingSize = [Math]::Max(0, $totalSize - $totalFixed)
        $sizes = @()
        
        foreach ($def in $parsedDefs) {
            if ($def.Type -eq 'Fixed') {
                $sizes += $def.Value
            }
            else {
                # Star sizing
                if ($totalStars -gt 0) {
                    $size = [Math]::Floor($remainingSize * ($def.Value / $totalStars))
                    $sizes += $size
                } else {
                    $sizes += 0
                }
            }
        }
        
        # Adjust last cell to account for rounding
        if ($sizes.Count -gt 0) {
            $totalAllocated = ($sizes | Measure-Object -Sum).Sum
            $difference = $totalSize - $totalAllocated
            if ($difference -gt 0 -and $sizes[-1] -gt 0) {
                $sizes[-1] += $difference
            }
        }
        
        return $sizes
    }
    
    $panel.CalculateLayout = {
        param($self)
        
        if (-not $self._isDirty) {
            return $self._cachedLayout
        }
        
        $bounds = & $self.GetContentBounds -self $self
        
        # Calculate row and column sizes
        $rowHeights = & $self._CalculateGridSizes -self $self -definitions $self.RowDefinitions -totalSize $bounds.Height
        $colWidths = & $self._CalculateGridSizes -self $self -definitions $self.ColumnDefinitions -totalSize $bounds.Width
        
        # Calculate offsets
        $rowOffsets = @(0)
        $colOffsets = @(0)
        
        for ($i = 0; $i -lt $rowHeights.Count - 1; $i++) {
            $rowOffsets += ($rowOffsets[-1] + $rowHeights[$i])
        }
        
        for ($i = 0; $i -lt $colWidths.Count - 1; $i++) {
            $colOffsets += ($colOffsets[-1] + $colWidths[$i])
        }
        
        # Layout children
        $layout = @{
            Children = @()
            Rows = $rowHeights
            Columns = $colWidths
            RowOffsets = $rowOffsets
            ColumnOffsets = $colOffsets
        }
        
        foreach ($child in $self.Children) {
            if (-not $child.Visible) { continue }
            
            # Get grid position
            $row = [Math]::Max(0, [Math]::Min($rowHeights.Count - 1, [int]($child.LayoutProps."Grid.Row" ?? 0)))
            $col = [Math]::Max(0, [Math]::Min($colWidths.Count - 1, [int]($child.LayoutProps."Grid.Column" ?? 0)))
            $rowSpan = [Math]::Max(1, [Math]::Min($rowHeights.Count - $row, [int]($child.LayoutProps."Grid.RowSpan" ?? 1)))
            $colSpan = [Math]::Max(1, [Math]::Min($colWidths.Count - $col, [int]($child.LayoutProps."Grid.ColumnSpan" ?? 1)))
            
            # Calculate cell bounds
            $cellX = $bounds.X + $colOffsets[$col]
            $cellY = $bounds.Y + $rowOffsets[$row]
            $cellWidth = 0
            $cellHeight = 0
            
            for ($i = 0; $i -lt $colSpan; $i++) {
                if (($col + $i) -lt $colWidths.Count) {
                    $cellWidth += $colWidths[$col + $i]
                }
            }
            
            for ($i = 0; $i -lt $rowSpan; $i++) {
                if (($row + $i) -lt $rowHeights.Count) {
                    $cellHeight += $rowHeights[$row + $i]
                }
            }
            
            # Apply alignment within cell
            $childX = $cellX
            $childY = $cellY
            $childWidth = [Math]::Min($child.Width, $cellWidth)
            $childHeight = [Math]::Min($child.Height, $cellHeight)
            
            # Horizontal alignment
            $hAlign = $child.LayoutProps."Grid.HorizontalAlignment" ?? "Stretch"
            switch ($hAlign) {
                "Center" { $childX = $cellX + [Math]::Floor(($cellWidth - $childWidth) / 2) }
                "Right" { $childX = $cellX + $cellWidth - $childWidth }
                "Stretch" { $childWidth = $cellWidth }
            }
            
            # Vertical alignment
            $vAlign = $child.LayoutProps."Grid.VerticalAlignment" ?? "Stretch"
            switch ($vAlign) {
                "Middle" { $childY = $cellY + [Math]::Floor(($cellHeight - $childHeight) / 2) }
                "Bottom" { $childY = $cellY + $cellHeight - $childHeight }
                "Stretch" { $childHeight = $cellHeight }
            }
            
            $layout.Children += @{
                Component = $child
                X = $childX
                Y = $childY
                Width = $childWidth
                Height = $childHeight
                Row = $row
                Column = $col
                RowSpan = $rowSpan
                ColumnSpan = $colSpan
            }
        }
        
        $self._cachedLayout = $layout
        $self._isDirty = $false
        return $layout
    }
    
    $panel.Render = {
        param($self)
        
        if (-not $self.Visible) { return }
        
        # Clear background if color specified
        if ($self.BackgroundColor -and (Get-Command -Name "Write-BufferBox" -ErrorAction SilentlyContinue)) {
            for ($y = $self.Y; $y -lt ($self.Y + $self.Height); $y++) {
                Write-BufferString -X $self.X -Y $y -Text (' ' * $self.Width) -BackgroundColor $self.BackgroundColor
            }
        }
        
        # Draw border if requested
        if ($self.ShowBorder -and (Get-Command -Name "Write-BufferBox" -ErrorAction SilentlyContinue)) {
            $borderColor = if ($self.ForegroundColor) { $self.ForegroundColor } else { Get-ThemeColor "Border" -Default Gray }
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height -BorderColor $borderColor -Title $self.Title
        }
        
        # Calculate layout
        $layout = & $self.CalculateLayout -self $self
        
        # Draw grid lines if requested
        if ($self.ShowGridLines -and (Get-Command -Name "Write-BufferString" -ErrorAction SilentlyContinue)) {
            $bounds = & $self.GetContentBounds -self $self
            
            # Vertical lines
            foreach ($offset in $layout.ColumnOffsets[1..($layout.ColumnOffsets.Count - 1)]) {
                $x = $bounds.X + $offset - 1
                if ($x -ge $bounds.X -and $x -lt ($bounds.X + $bounds.Width)) {
                    for ($y = $bounds.Y; $y -lt ($bounds.Y + $bounds.Height); $y++) {
                        Write-BufferString -X $x -Y $y -Text "│" -ForegroundColor $self.GridLineColor
                    }
                }
            }
            
            # Horizontal lines
            foreach ($offset in $layout.RowOffsets[1..($layout.RowOffsets.Count - 1)]) {
                $y = $bounds.Y + $offset - 1
                if ($y -ge $bounds.Y -and $y -lt ($bounds.Y + $bounds.Height)) {
                    Write-BufferString -X $bounds.X -Y $y -Text ("─" * $bounds.Width) -ForegroundColor $self.GridLineColor
                }
            }
        }
        
        # Render children
        foreach ($childLayout in $layout.Children) {
            $child = $childLayout.Component
            
            # Apply calculated position and size
            $child.X = $childLayout.X
            $child.Y = $childLayout.Y
            
            # Only update size if property is settable
            if ($child.PSObject.Properties['Width'] -and $child.Width -ne $childLayout.Width) {
                $child.Width = $childLayout.Width
            }
            if ($child.PSObject.Properties['Height'] -and $child.Height -ne $childLayout.Height) {
                $child.Height = $childLayout.Height
            }
            
            # Render child
            if ($child.Render) {
                & $child.Render -self $child
            }
        }
    }
    
    return $panel
}

# Additional layout panel types for future extension
function global:New-TuiDockPanel {
    param([hashtable]$Props = @{})
    
    $panel = New-BasePanel -Props $Props
    $panel.Type = "DockPanel"
    $panel.Layout = 'Dock'
    $panel.LastChildFill = $Props.LastChildFill ?? $true
    
    # DockPanel implementation would go here
    # For now, fallback to StackPanel behavior
    $stackProps = $Props.Clone()
    $stackProps.Orientation = 'Vertical'
    return New-TuiStackPanel -Props $stackProps
}

function global:New-TuiWrapPanel {
    param([hashtable]$Props = @{})
    
    $panel = New-BasePanel -Props $Props
    $panel.Type = "WrapPanel"
    $panel.Layout = 'Wrap'
    $panel.Orientation = $Props.Orientation ?? 'Horizontal'
    $panel.ItemWidth = $Props.ItemWidth
    $panel.ItemHeight = $Props.ItemHeight
    
    # WrapPanel implementation would go here
    # For now, fallback to StackPanel behavior
    return New-TuiStackPanel -Props $Props
}

Export-ModuleMember -Function "New-TuiStackPanel", "New-TuiGridPanel", "New-TuiDockPanel", "New-TuiWrapPanel"
