# Advanced Data Components Module
# Enhanced data display components with sorting, filtering, and pagination

#region Advanced Table Component

function global:New-TuiDataTable {
    param([hashtable]$Props = @{})
    
    $component = @{
        Type = "DataTable"
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 80
        Height = $Props.Height ?? 20
        Title = $Props.Title
        ShowBorder = $Props.ShowBorder ?? $true  # <-- NEW: Controls whether component draws its own border
        Data = $Props.Data ?? @()
        Columns = $Props.Columns ?? @()
        SelectedRow = 0
        ScrollOffset = 0
        SortColumn = $null
        SortDirection = "Ascending"
        FilterText = ""
        FilterColumn = $null
        PageSize = 0  # 0 = auto-calculate
        CurrentPage = 0
        ShowHeader = $Props.ShowHeader ?? $true
        ShowFooter = $Props.ShowFooter ?? $true
        ShowRowNumbers = $Props.ShowRowNumbers ?? $false
        AllowSort = $Props.AllowSort ?? $true
        AllowFilter = $Props.AllowFilter ?? $true
        AllowSelection = $Props.AllowSelection ?? $true
        MultiSelect = $Props.MultiSelect ?? $false
        SelectedRows = @()
        IsFocusable = $Props.IsFocusable ?? $true
        Visible = $Props.Visible ?? $true
        Name = $Props.Name
        FilteredData = @()
        ProcessedData = @()
        
        # Event handlers from Props
        OnRowSelect = $Props.OnRowSelect
        OnSelectionChange = $Props.OnSelectionChange
        
        # Column configuration example:
        # @{
        #     Name = "PropertyName"
        #     Header = "Display Header"
        #     Width = 20
        #     Align = "Left"  # Left, Right, Center
        #     Format = { param($value) $value.ToString("N2") }
        #     Sortable = $true
        #     Filterable = $true
        #     Color = { param($value, $row) if ($value -lt 0) { "Red" } else { "Green" } }
        # }
        
        ProcessData = {
            param($self)
            # Filter data
            if ([string]::IsNullOrWhiteSpace($self.FilterText)) {
                $self.FilteredData = $self.Data
            } else {
                if ($self.FilterColumn) {
                    # Filter specific column
                    $self.FilteredData = @($self.Data | Where-Object {
                        $value = $_."$($self.FilterColumn)"
                        $value -and $value.ToString() -like "*$($self.FilterText)*"
                    })
                } else {
                    # Filter all columns
                    $self.FilteredData = @($self.Data | Where-Object {
                        $row = $_
                        $matched = $false
                        foreach ($col in $self.Columns) {
                            if ($col.Filterable -ne $false) {
                                $value = $row."$($col.Name)"
                                if ($value -and $value.ToString() -like "*$($self.FilterText)*") {
                                    $matched = $true
                                    break
                                }
                            }
                        }
                        $matched
                    })
                }
            }
            
            # Sort data
            if ($self.SortColumn -and $self.AllowSort) {
                $self.ProcessedData = $self.FilteredData | Sort-Object -Property $self.SortColumn -Descending:($self.SortDirection -eq "Descending")
            } else {
                $self.ProcessedData = $self.FilteredData
            }
            
            # Reset selection if needed
            if ($self.SelectedRow -ge $self.ProcessedData.Count) {
                $self.SelectedRow = [Math]::Max(0, $self.ProcessedData.Count - 1)
            }
            
            # Calculate page size if auto
            if ($self.PageSize -eq 0) {
                $headerLines = if ($self.ShowHeader) { 3 } else { 0 }
                $footerLines = if ($self.ShowFooter) { 2 } else { 0 }
                $filterLines = if ($self.AllowFilter) { 2 } else { 0 }
                $borderAdjust = if ($self.ShowBorder) { 2 } else { 0 }
                $self.PageSize = $self.Height - $headerLines - $footerLines - $filterLines - $borderAdjust
            }
            
            # Adjust current page
            $totalPages = [Math]::Ceiling($self.ProcessedData.Count / [Math]::Max(1, $self.PageSize))
            if ($self.CurrentPage -ge $totalPages) {
                $self.CurrentPage = [Math]::Max(0, $totalPages - 1)
            }
        }
        
        Render = {
            param($self)
            
            # CRITICAL: Check if component is visible
            if ($self.Visible -eq $false) { return }
            
            # Debug: Check data state for Quick Actions
            if ($self.Title -eq "Quick Actions") {
                Write-Log -Level Debug -Message "Rendering Quick Actions DataTable:"
                Write-Log -Level Debug -Message "  Data count: $($self.Data.Count)"
                Write-Log -Level Debug -Message "  ProcessedData count: $($self.ProcessedData.Count)"
                if ($self.ProcessedData.Count -gt 0) {
                    Write-Log -Level Debug -Message "  First row: $($self.ProcessedData[0] | ConvertTo-Json -Compress)"
                }
                $colInfo = $self.Columns | ForEach-Object { "$($_.Name):$($_.CalculatedWidth)" }
                Write-Log -Level Debug -Message "  Columns: $($colInfo -join ', ')"
            }
            
            # Process data first
            & $self.ProcessData -self $self
            
            # Only draw border if ShowBorder is true
            $contentX = $self.X
            $contentY = $self.Y
            $contentWidth = $self.Width
            $contentHeight = $self.Height
            
            if ($self.ShowBorder) {
                $borderColor = if ($self.IsFocusable -and $self.IsFocused) { 
                    Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan)
                } else { 
                    Get-ThemeColor "Border" -Default ([ConsoleColor]::DarkGray)
                }
                
                Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
                    -BorderColor $borderColor -Title " $($self.Title ?? 'Data Table') "
                
                # Adjust content area for border
                $contentX = $self.X + 1
                $contentY = $self.Y + 1
                $contentWidth = $self.Width - 2
                $contentHeight = $self.Height - 2
            }
            
            $currentY = $contentY
            $innerWidth = $contentWidth
            
            # Filter bar
            if ($self.AllowFilter) {
                $filterBg = if ($self.FilterText) { Get-ThemeColor "Warning" -Default ([ConsoleColor]::Yellow) } else { Get-ThemeColor "Background" -Default ([ConsoleColor]::Black) }
                $filterFg = if ($self.FilterText) { Get-ThemeColor "Background" -Default ([ConsoleColor]::Black) } else { Get-ThemeColor "Subtle" -Default ([ConsoleColor]::DarkGray) }
                
                Write-BufferString -X ($contentX + 1) -Y $currentY -Text "Filter: " -ForegroundColor (Get-ThemeColor "Primary" -Default ([ConsoleColor]::White))
                
                $filterDisplayText = if ($self.FilterText) { $self.FilterText } else { "Type to filter..." }
                Write-BufferString -X ($contentX + 9) -Y $currentY -Text $filterDisplayText `
                    -ForegroundColor $filterFg -BackgroundColor $filterBg
                
                if ($self.FilterColumn) {
                    $colName = ($self.Columns | Where-Object { $_.Name -eq $self.FilterColumn }).Header ?? $self.FilterColumn
                    Write-BufferString -X ($contentX + $contentWidth - 19) -Y $currentY `
                        -Text "Column: $colName" -ForegroundColor (Get-ThemeColor "Info" -Default ([ConsoleColor]::Blue))
                }
                
                $currentY += 2
            }
            
            # Calculate column widths - FIXED VERSION
            $totalDefinedWidth = ($self.Columns | Where-Object { $_.Width } | Measure-Object -Property Width -Sum).Sum ?? 0
            $flexColumns = @($self.Columns | Where-Object { -not $_.Width })
            $columnSeparators = if ($self.Columns.Count -gt 1) { $self.Columns.Count - 1 } else { 0 }  # Only add separators if multiple columns
            $remainingWidth = $innerWidth - $totalDefinedWidth - ($self.ShowRowNumbers ? 5 : 0) - $columnSeparators
            
            # CRITICAL FIX: Ensure flex columns get adequate width, especially for single-column tables
            if ($flexColumns.Count -eq 1 -and $self.Columns.Count -eq 1) {
                # Single flex column should use full available width
                $flexWidth = $remainingWidth
            } elseif ($flexColumns.Count -gt 0) {
                $flexWidth = [Math]::Floor($remainingWidth / $flexColumns.Count)
            } else {
                $flexWidth = 0
            }
            
            # Assign calculated widths
            foreach ($col in $self.Columns) {
                if ($col.Width) {
                    $col.CalculatedWidth = $col.Width
                } else {
                    # For the Quick Actions single column, ensure it gets proper width
                    if ($self.Title -eq "Quick Actions" -and $self.Columns.Count -eq 1) {
                        # Table width 35, minus 2 for borders if ShowBorder=false (but content area already adjusted)
                        $col.CalculatedWidth = $innerWidth - 1  # Leave 1 space for safety
                    } else {
                        $col.CalculatedWidth = [Math]::Max(5, $flexWidth)
                    }
                }
            }
            
            # Header
            if ($self.ShowHeader) {
                $headerX = $contentX
                
                # Row number header
                if ($self.ShowRowNumbers) {
                    Write-BufferString -X $headerX -Y $currentY -Text "#".PadRight(4) `
                        -ForegroundColor (Get-ThemeColor "Header" -Default ([ConsoleColor]::Cyan))
                    $headerX += 5
                }
                
                # Column headers
                foreach ($col in $self.Columns) {
                    $headerText = $col.Header ?? $col.Name
                    $width = $col.CalculatedWidth
                    
                    # Add sort indicator
                    if ($self.AllowSort -and $col.Sortable -ne $false -and $col.Name -eq $self.SortColumn) {
                        $sortIndicator = if ($self.SortDirection -eq "Ascending") { "▲" } else { "▼" }
                        $headerText = "$headerText $sortIndicator"
                    }
                    
                    # Truncate if needed
                    if ($headerText.Length -gt $width) {
                        # FIX: Robust substring
                        $maxLength = [Math]::Max(0, $width - 3)
                        $headerText = $headerText.Substring(0, $maxLength) + "..."
                    }
                    
                    # Align header
                    $alignedText = switch ($col.Align) {
                        "Right" { $headerText.PadLeft($width) }
                        "Center" { 
                            $padding = $width - $headerText.Length
                            $leftPad = [Math]::Floor($padding / 2)
                            $rightPad = $padding - $leftPad
                            " " * $leftPad + $headerText + " " * $rightPad
                        }
                        default { $headerText.PadRight($width) }
                    }
                    
                    Write-BufferString -X $headerX -Y $currentY -Text $alignedText `
                        -ForegroundColor (Get-ThemeColor "Header" -Default ([ConsoleColor]::Cyan))
                    
                    $headerX += $width + 1
                }
                
                $currentY++
                
                # Header separator
                $separatorColor = Get-ThemeColor "Border" -Default ([ConsoleColor]::DarkGray)
                Write-BufferString -X $contentX -Y $currentY `
                    -Text ("─" * $contentWidth) -ForegroundColor $separatorColor
                $currentY++
            }
            
            # Data rows
            $startIdx = $self.CurrentPage * $self.PageSize
            $endIdx = [Math]::Min($startIdx + $self.PageSize - 1, $self.ProcessedData.Count - 1)
            
            for ($i = $startIdx; $i -le $endIdx; $i++) {
                $row = $self.ProcessedData[$i]
                $rowX = $contentX
                
                # Selection highlighting
                $isSelected = if ($self.MultiSelect) {
                    $self.SelectedRows -contains $i
                } else {
                    $i -eq $self.SelectedRow
                }
                
                $rowBg = if ($isSelected) { Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan) } else { Get-ThemeColor "Background" -Default ([ConsoleColor]::Black) }
                $rowFg = if ($isSelected) { Get-ThemeColor "Background" -Default ([ConsoleColor]::Black) } else { Get-ThemeColor "Primary" -Default ([ConsoleColor]::White) }
                
                # Clear row background if selected
                if ($isSelected) {
                    Write-BufferString -X $rowX -Y $currentY -Text (" " * $contentWidth) `
                        -BackgroundColor $rowBg
                }
                
                # Row number
                if ($self.ShowRowNumbers) {
                    Write-BufferString -X $rowX -Y $currentY -Text ($i + 1).ToString().PadRight(4) `
                        -ForegroundColor (Get-ThemeColor "Subtle" -Default ([ConsoleColor]::DarkGray)) -BackgroundColor $rowBg
                    $rowX += 5
                }
                
                # Cell data
                foreach ($col in $self.Columns) {
                    $value = $row."$($col.Name)"
                    $width = $col.CalculatedWidth
                    
                    # Format value
                    $displayValue = if ($col.Format -and $value -ne $null) {
                        & $col.Format $value
                    } elseif ($value -ne $null) {
                        $value.ToString()
                    } else {
                        ""
                    }
                    
                    # Truncate if needed
                    if ($displayValue.Length -gt $width) {
                        # FIX: Robust substring
                        $maxLength = [Math]::Max(0, $width - 3)
                        if ($maxLength -le 0) {
                            Write-Log -Level Warning -Message "DataTable '$($self.Title)' column '$($col.Name)' width too small: $width (max length: $maxLength)"
                            $displayValue = "..."
                        } else {
                            $displayValue = $displayValue.Substring(0, $maxLength) + "..."
                        }
                    }
                    
                    
                    # Align value
                    $alignedValue = switch ($col.Align) {
                        "Right" { $displayValue.PadLeft($width) }
                        "Center" { 
                            $padding = $width - $displayValue.Length
                            $leftPad = [Math]::Floor($padding / 2)
                            $rightPad = $padding - $leftPad
                            " " * $leftPad + $displayValue + " " * $rightPad
                        }
                        default { $displayValue.PadRight($width) }
                    }
                    
                    # Determine color
                    $cellFg = if ($col.Color -and -not $isSelected) {
                        $colorName = & $col.Color $value $row
                        Get-ThemeColor $colorName -Default ([ConsoleColor]::White)
                    } else {
                        $rowFg
                    }
                    
                    Write-BufferString -X $rowX -Y $currentY -Text $alignedValue `
                        -ForegroundColor $cellFg -BackgroundColor $rowBg
                    
                    $rowX += $width + 1
                }
                
                $currentY++
            }
            
            # Empty state
            if ($self.ProcessedData.Count -eq 0) {
                $emptyMessage = if ($self.FilterText) {
                    "No results match the filter"
                } else {
                    "No data to display"
                }
                $msgX = $contentX + [Math]::Floor(($contentWidth - $emptyMessage.Length) / 2)
                $msgY = $contentY + [Math]::Floor($contentHeight / 2)
                Write-BufferString -X $msgX -Y $msgY -Text $emptyMessage `
                    -ForegroundColor (Get-ThemeColor "Subtle" -Default ([ConsoleColor]::DarkGray))
            }
            
            # Footer
            if ($self.ShowFooter) {
                $footerY = $contentY + $contentHeight - 1
                
                # Status
                $statusText = "$($self.ProcessedData.Count) rows"
                if ($self.FilterText) {
                    $statusText += " (filtered from $($self.Data.Count))"
                }
                if ($self.MultiSelect) {
                    $statusText += " | $($self.SelectedRows.Count) selected"
                }
                Write-BufferString -X ($contentX + 1) -Y $footerY -Text $statusText `
                    -ForegroundColor (Get-ThemeColor "Subtle" -Default ([ConsoleColor]::DarkGray))
                
                # Pagination
                if ($self.ProcessedData.Count -gt $self.PageSize) {
                    $totalPages = [Math]::Ceiling($self.ProcessedData.Count / [Math]::Max(1, $self.PageSize))
                    $pageText = "Page $($self.CurrentPage + 1)/$totalPages"
                    Write-BufferString -X ($contentX + $contentWidth - $pageText.Length - 1) -Y $footerY `
                        -Text $pageText -ForegroundColor (Get-ThemeColor "Info" -Default ([ConsoleColor]::Blue))
                }
                
                # Scrollbar
                if ($self.ProcessedData.Count -gt $self.PageSize) {
                    $scrollHeight = $contentHeight - 4 - (if ($self.ShowHeader) { 2 } else { 0 }) - (if ($self.AllowFilter) { 2 } else { 0 })
                    $scrollPos = [Math]::Floor(($self.SelectedRow / ($self.ProcessedData.Count - 1)) * ($scrollHeight - 1))
                    $scrollX = $contentX + $contentWidth - 1
                    
                    for ($i = 0; $i -lt $scrollHeight; $i++) {
                        $scrollY = $currentY - $scrollHeight + $i
                        $char = if ($i -eq $scrollPos) { "█" } else { "│" }
                        $color = if ($i -eq $scrollPos) { Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan) } else { Get-ThemeColor "Subtle" -Default ([ConsoleColor]::DarkGray) }
                        Write-BufferString -X $scrollX -Y $scrollY -Text $char -ForegroundColor $color
                    }
                }
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            # Filter mode
            if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
                switch ($Key.Key) {
                    ([ConsoleKey]::F) {
                        # Toggle filter focus
                        $self.FilterMode = -not $self.FilterMode
                        Request-TuiRefresh
                        return $true
                    }
                    ([ConsoleKey]::S) {
                        # Cycle sort column
                        if ($self.AllowSort) {
                            $sortableCols = @($self.Columns | Where-Object { $_.Sortable -ne $false })
                            if ($sortableCols.Count -gt 0) {
                                $currentIdx = [array]::IndexOf($sortableCols.Name, $self.SortColumn)
                                $nextIdx = ($currentIdx + 1) % $sortableCols.Count
                                $self.SortColumn = $sortableCols[$nextIdx].Name
                                & $self.ProcessData -self $self
                                Request-TuiRefresh
                            }
                        }
                        return $true
                    }
                    ([ConsoleKey]::A) {
                        # Select all (if multi-select)
                        if ($self.MultiSelect) {
                            if ($self.SelectedRows.Count -eq $self.ProcessedData.Count) {
                                $self.SelectedRows = @()
                            } else {
                                $self.SelectedRows = @(0..($self.ProcessedData.Count - 1))
                            }
                            if ($self.OnSelectionChange) {
                                & $self.OnSelectionChange -SelectedRows $self.SelectedRows
                            }
                            Request-TuiRefresh
                        }
                        return $true
                    }
                }
            }
            
            # Filter text input
            if ($self.FilterMode) {
                switch ($Key.Key) {
                    ([ConsoleKey]::Escape) {
                        $self.FilterMode = $false
                        Request-TuiRefresh
                        return $true
                    }
                    ([ConsoleKey]::Enter) {
                        $self.FilterMode = $false
                        & $self.ProcessData -self $self
                        Request-TuiRefresh
                        return $true
                    }
                    ([ConsoleKey]::Backspace) {
                        if ($self.FilterText.Length -gt 0) {
                            $self.FilterText = $self.FilterText.Substring(0, $self.FilterText.Length - 1)
                            & $self.ProcessData -self $self
                            Request-TuiRefresh
                        }
                        return $true
                    }
                    default {
                        if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar)) {
                            $self.FilterText += $Key.KeyChar
                            & $self.ProcessData -self $self
                            Request-TuiRefresh
                            return $true
                        }
                    }
                }
                return $false
            }
            
            # Normal navigation
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($self.SelectedRow -gt 0) {
                        $self.SelectedRow--
                        
                        # Adjust page if needed
                        if ($self.SelectedRow -lt ($self.CurrentPage * $self.PageSize)) {
                            $self.CurrentPage--
                        }
                        
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($self.SelectedRow -lt ($self.ProcessedData.Count - 1)) {
                        $self.SelectedRow++
                        
                        # Adjust page if needed
                        if ($self.SelectedRow -ge (($self.CurrentPage + 1) * $self.PageSize)) {
                            $self.CurrentPage++
                        }
                        
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::PageUp) {
                    if ($self.CurrentPage -gt 0) {
                        $self.CurrentPage--
                        $self.SelectedRow = $self.CurrentPage * $self.PageSize
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::PageDown) {
                    $totalPages = [Math]::Ceiling($self.ProcessedData.Count / [Math]::Max(1, $self.PageSize))
                    if ($self.CurrentPage -lt ($totalPages - 1)) {
                        $self.CurrentPage++
                        $self.SelectedRow = $self.CurrentPage * $self.PageSize
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $self.SelectedRow = 0
                    $self.CurrentPage = 0
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::End) {
                    $self.SelectedRow = $self.ProcessedData.Count - 1
                    $self.CurrentPage = [Math]::Floor($self.SelectedRow / [Math]::Max(1, $self.PageSize))
                    Request-TuiRefresh
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    if ($self.MultiSelect) {
                        if ($self.SelectedRows -contains $self.SelectedRow) {
                            $self.SelectedRows = @($self.SelectedRows | Where-Object { $_ -ne $self.SelectedRow })
                        } else {
                            $self.SelectedRows += $self.SelectedRow
                        }
                        if ($self.OnSelectionChange) {
                            & $self.OnSelectionChange -SelectedRows $self.SelectedRows
                        }
                        Request-TuiRefresh
                    } elseif ($self.AllowSort) {
                        # Toggle sort direction
                        if ($self.SortDirection -eq "Ascending") {
                            $self.SortDirection = "Descending"
                        } else {
                            $self.SortDirection = "Ascending"
                        }
                        & $self.ProcessData -self $self
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($self.OnRowSelect -and $self.ProcessedData.Count -gt 0) {
                        $selectedData = if ($self.MultiSelect) {
                            @($self.SelectedRows | ForEach-Object { $self.ProcessedData[$_] })
                        } else {
                            $self.ProcessedData[$self.SelectedRow]
                        }
                        & $self.OnRowSelect -SelectedData $selectedData -SelectedIndex $self.SelectedRow
                    }
                    return $true
                }
                ([ConsoleKey]::F) {
                    if ($self.AllowFilter) {
                        $self.FilterMode = $true
                        Request-TuiRefresh
                    }
                    return $true
                }
                default {
                    # Number keys for column sorting
                    if ($Key.KeyChar -match '\d' -and $self.AllowSort) {
                        $colIndex = [int]$Key.KeyChar.ToString() - 1
                        if ($colIndex -ge 0 -and $colIndex -lt $self.Columns.Count) {
                            $col = $self.Columns[$colIndex]
                            if ($col.Sortable -ne $false) {
                                if ($self.SortColumn -eq $col.Name) {
                                    # Toggle direction
                                    $self.SortDirection = if ($self.SortDirection -eq "Ascending") { "Descending" } else { "Ascending" }
                                } else {
                                    $self.SortColumn = $col.Name
                                    $self.SortDirection = "Ascending"
                                }
                                & $self.ProcessData -self $self
                                Request-TuiRefresh
                            }
                        }
                        return $true
                    }
                }
            }
            
            return $false
        }
        
        # Public methods
        RefreshData = {
            param($self)
            & $self.ProcessData -self $self
            Request-TuiRefresh
        }
        
        SetFilter = {
            param($self, $FilterText, $FilterColumn)
            $self.FilterText = $FilterText
            $self.FilterColumn = $FilterColumn
            & $self.ProcessData -self $self
            Request-TuiRefresh
        }
        
        ExportData = {
            param($self, $Format = "CSV", $FilePath)
            
            $exportData = if ($self.FilterText) { $self.ProcessedData } else { $self.Data }
            
            switch ($Format.ToUpper()) {
                "CSV" {
                    $exportData | Export-Csv -Path $FilePath -NoTypeInformation
                }
                "JSON" {
                    $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath
                }
                "HTML" {
                    # Simple HTML table export
                    $html = "<table border='1'><tr>"
                    foreach ($col in $self.Columns) {
                        $html += "<th>$($col.Header ?? $col.Name)</th>"
                    }
                    $html += "</tr>"
                    
                    foreach ($row in $exportData) {
                        $html += "<tr>"
                        foreach ($col in $self.Columns) {
                            $value = $row."$($col.Name)"
                            $html += "<td>$value</td>"
                        }
                        $html += "</tr>"
                    }
                    $html += "</table>"
                    
                    $html | Set-Content -Path $FilePath
                }
            }
        }
    }
    
    # Initialize data processing after component is created
    & $component.ProcessData -self $component
    
    return $component
}

#endregion

#region Tree View Component

function global:New-TuiTreeView {
    param([hashtable]$Props = @{})
    
    $component = @{
        Type = "TreeView"
        X = $Props.X ?? 0
        Y = $Props.Y ?? 0
        Width = $Props.Width ?? 40
        Height = $Props.Height ?? 20
        RootNode = $Props.RootNode ?? @{ Name = "Root"; Children = @(); Expanded = $true }
        SelectedNode = $null
        SelectedPath = @()
        FlattenedNodes = @()
        ScrollOffset = 0
        ShowRoot = $Props.ShowRoot ?? $true
        IsFocusable = $true
        Visible = $Props.Visible ?? $true
        Name = $Props.Name
        
        # Node structure:
        # @{
        #     Name = "Node Name"
        #     Data = @{}  # Custom data
        #     Children = @()
        #     Expanded = $false
        #     Icon = "📁"  # Optional
        #     Parent = $null  # Set automatically
        # }
        
        FlattenTree = {
            param($self)
            $flattened = @()
            
            $processNode = {
                param($Node, $Level, $Parent)
                
                $node.Parent = $Parent
                $node.Level = $Level
                
                if ($self.ShowRoot -or $Level -gt 0) {
                    $flattened += $Node
                }
                
                if ($Node.Expanded -and $Node.Children) {
                    foreach ($child in $Node.Children) {
                        & $processNode $child ($Level + 1) $Node
                    }
                }
            }
            
            & $processNode $self.RootNode 0 $null
            $self.FlattenedNodes = $flattened
        }
        
        Render = {
            param($self)
            
            # Check if component is visible
            if ($self.Visible -eq $false) { return }
            
            # Flatten tree first
            & $self.FlattenTree -self $self
            
            $borderColor = if ($self.IsFocused) { 
                Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan)
            } else { 
                Get-ThemeColor "Border" -Default ([ConsoleColor]::DarkGray)
            }
            
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
                -BorderColor $borderColor -Title " Tree View "
            
            $visibleHeight = $self.Height - 2
            $startIdx = $self.ScrollOffset
            $endIdx = [Math]::Min($self.FlattenedNodes.Count - 1, $startIdx + $visibleHeight - 1)
            
            $currentY = $self.Y + 1
            
            for ($i = $startIdx; $i -le $endIdx; $i++) {
                $node = $self.FlattenedNodes[$i]
                $isSelected = ($node -eq $self.SelectedNode)
                
                # Indentation
                $indent = "  " * $node.Level
                
                # Expand/collapse indicator
                $expandIcon = if ($node.Children -and $node.Children.Count -gt 0) {
                    if ($node.Expanded) { "▼" } else { "▶" }
                } else {
                    " "
                }
                
                # Node icon
                $nodeIcon = if ($node.Icon) { 
                    $node.Icon 
                } elseif ($node.Children -and $node.Children.Count -gt 0) {
                    if ($node.Expanded) { "📂" } else { "📁" }
                } else {
                    "📄"
                }
                
                # Colors
                $fg = if ($isSelected) { Get-ThemeColor "Background" -Default ([ConsoleColor]::Black) } else { Get-ThemeColor "Primary" -Default ([ConsoleColor]::White) }
                $bg = if ($isSelected) { Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan) } else { Get-ThemeColor "Background" -Default ([ConsoleColor]::Black) }
                
                # Clear line if selected
                if ($isSelected) {
                    Write-BufferString -X ($self.X + 1) -Y $currentY -Text (" " * ($self.Width - 2)) `
                        -BackgroundColor $bg
                }
                
                # Render node
                $nodeText = "$indent$expandIcon $nodeIcon $($node.Name)"
                if ($nodeText.Length -gt ($self.Width - 3)) {
                    $nodeText = $nodeText.Substring(0, $self.Width - 6) + "..."
                }
                
                Write-BufferString -X ($self.X + 1) -Y $currentY -Text $nodeText `
                    -ForegroundColor $fg -BackgroundColor $bg
                
                $currentY++
            }
            
            # Scrollbar
            if ($self.FlattenedNodes.Count -gt $visibleHeight) {
                $scrollHeight = $visibleHeight
                $scrollPos = if ($self.FlattenedNodes.Count -gt 1) {
                    $selectedIdx = [array]::IndexOf($self.FlattenedNodes, $self.SelectedNode)
                    [Math]::Floor(($selectedIdx / ($self.FlattenedNodes.Count - 1)) * ($scrollHeight - 1))
                } else { 0 }
                
                for ($i = 0; $i -lt $scrollHeight; $i++) {
                    $char = if ($i -eq $scrollPos) { "█" } else { "│" }
                    $color = if ($i -eq $scrollPos) { Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan) } else { Get-ThemeColor "Subtle" -Default ([ConsoleColor]::DarkGray) }
                    Write-BufferString -X ($self.X + $self.Width - 2) -Y ($self.Y + 1 + $i) `
                        -Text $char -ForegroundColor $color
                }
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            if ($self.FlattenedNodes.Count -eq 0) { return $false }
            
            $currentIdx = if ($self.SelectedNode) {
                [array]::IndexOf($self.FlattenedNodes, $self.SelectedNode)
            } else { 0 }
            
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($currentIdx -gt 0) {
                        $currentIdx--
                        $self.SelectedNode = $self.FlattenedNodes[$currentIdx]
                        
                        # Adjust scroll
                        if ($currentIdx -lt $self.ScrollOffset) {
                            $self.ScrollOffset = $currentIdx
                        }
                        
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($currentIdx -lt ($self.FlattenedNodes.Count - 1)) {
                        $currentIdx++
                        $self.SelectedNode = $self.FlattenedNodes[$currentIdx]
                        
                        # Adjust scroll
                        $visibleHeight = $self.Height - 2
                        if ($currentIdx -ge ($self.ScrollOffset + $visibleHeight)) {
                            $self.ScrollOffset = $currentIdx - $visibleHeight + 1
                        }
                        
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($self.SelectedNode) {
                        if ($self.SelectedNode.Expanded -and $self.SelectedNode.Children) {
                            # Collapse
                            $self.SelectedNode.Expanded = $false
                            Request-TuiRefresh
                        } elseif ($self.SelectedNode.Parent) {
                            # Move to parent
                            $self.SelectedNode = $self.SelectedNode.Parent
                            Request-TuiRefresh
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    if ($self.SelectedNode -and $self.SelectedNode.Children -and $self.SelectedNode.Children.Count -gt 0) {
                        if (-not $self.SelectedNode.Expanded) {
                            # Expand
                            $self.SelectedNode.Expanded = $true
                            Request-TuiRefresh
                        } else {
                            # Move to first child
                            $self.SelectedNode = $self.SelectedNode.Children[0]
                            Request-TuiRefresh
                        }
                    }
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    if ($self.SelectedNode -and $self.SelectedNode.Children -and $self.SelectedNode.Children.Count -gt 0) {
                        $self.SelectedNode.Expanded = -not $self.SelectedNode.Expanded
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($self.OnNodeSelect -and $self.SelectedNode) {
                        # Build path
                        $path = @()
                        $current = $self.SelectedNode
                        while ($current) {
                            $path = @($current.Name) + $path
                            $current = $current.Parent
                        }
                        
                        & $self.OnNodeSelect -Node $self.SelectedNode -Path $path
                    }
                    return $true
                }
                ([ConsoleKey]::Home) {
                    if ($self.FlattenedNodes.Count -gt 0) {
                        $self.SelectedNode = $self.FlattenedNodes[0]
                        $self.ScrollOffset = 0
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::End) {
                    if ($self.FlattenedNodes.Count -gt 0) {
                        $self.SelectedNode = $self.FlattenedNodes[-1]
                        $visibleHeight = $self.Height - 2
                        $self.ScrollOffset = [Math]::Max(0, $self.FlattenedNodes.Count - $visibleHeight)
                        Request-TuiRefresh
                    }
                    return $true
                }
                { $_ -in @([ConsoleKey]::Add, [ConsoleKey]::OemPlus) } {
                    # Expand all
                    $expandAll = {
                        param($Node)
                        $Node.Expanded = $true
                        foreach ($child in $Node.Children) {
                            & $expandAll $child
                        }
                    }
                    & $expandAll $self.RootNode
                    Request-TuiRefresh
                    return $true
                }
                { $_ -in @([ConsoleKey]::Subtract, [ConsoleKey]::OemMinus) } {
                    # Collapse all
                    $collapseAll = {
                        param($Node)
                        $Node.Expanded = $false
                        foreach ($child in $Node.Children) {
                            & $collapseAll $child
                        }
                    }
                    & $collapseAll $self.RootNode
                    $self.RootNode.Expanded = $true  # Keep root expanded
                    Request-TuiRefresh
                    return $true
                }
            }
            
            return $false
        }
        
        # Public methods
        AddNode = {
            param($self, $ParentNode, $NewNode)
            if (-not $ParentNode.Children) {
                $ParentNode.Children = @()
            }
            $ParentNode.Children += $NewNode
            $NewNode.Parent = $ParentNode
            Request-TuiRefresh
        }
        
        RemoveNode = {
            param($self, $Node)
            if ($Node.Parent) {
                $Node.Parent.Children = @($Node.Parent.Children | Where-Object { $_ -ne $Node })
                if ($self.SelectedNode -eq $Node) {
                    $self.SelectedNode = $Node.Parent
                }
                Request-TuiRefresh
            }
        }
        
        FindNode = {
            param($self, $Predicate)
            
            $find = {
                param($Node)
                if (& $Predicate $Node) { return $Node }
                foreach ($child in $Node.Children) {
                    $found = & $find $child
                    if ($found) { return $found }
                }
                return $null
            }
            
            return & $find $self.RootNode
        }
    }
    
    return $component
}

#endregion

Export-ModuleMember -Function @(
    'New-TuiDataTable',
    'New-TuiTreeView'
)