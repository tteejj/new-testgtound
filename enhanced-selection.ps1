# Enhanced Selection System
# Provides arrow key navigation, numbered lists, and visual highlighting for selections

function global:Show-EnhancedSelection {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Items,                    # Array of items to select from
        [string]$Title = "Select Item",   # Title to display
        [string]$DisplayProperty = "",    # Property to display (for objects)
        [string]$ValueProperty = "",      # Property to return (for objects)
        [switch]$AllowMultiple,           # Allow multiple selections
        [switch]$ShowDetails,             # Show additional details
        [hashtable]$DetailProperties = @{}, # Properties to show as details
        [int]$PageSize = 15,              # Items per page
        [switch]$ReturnIndex              # Return index instead of item
    )
    
    if ($Items.Count -eq 0) {
        Write-Warning "No items to select from."
        return $null
    }
    
    # Initialize variables
    $selectedIndex = 0
    $selectedItems = @()
    $pageStart = 0
    $searchFilter = ""
    
    while ($true) {
        Clear-Host
        Write-Header $Title
        
        # Show search filter if active
        if ($searchFilter) {
            Write-Host "Filter: " -NoNewline -ForegroundColor Yellow
            Write-Host $searchFilter -ForegroundColor Cyan
            Write-Host ""
        }
        
        # Filter items based on search
        $filteredItems = if ($searchFilter) {
            $Items | Where-Object {
                $displayText = if ($DisplayProperty -and $_ -is [PSObject]) {
                    $_.$DisplayProperty
                } else {
                    $_.ToString()
                }
                $displayText -like "*$searchFilter*"
            }
        } else {
            $Items
        }
        
        if ($filteredItems.Count -eq 0) {
            Write-Host "  No items match the filter." -ForegroundColor Gray
            Write-Host "`n[ESC] Clear filter | [BACKSPACE] Edit filter"
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            switch ($key.VirtualKeyCode) {
                27 { $searchFilter = ""; $selectedIndex = 0 } # ESC
                8 { # Backspace
                    if ($searchFilter.Length -gt 0) {
                        $searchFilter = $searchFilter.Substring(0, $searchFilter.Length - 1)
                    }
                }
            }
            continue
        }
        
        # Calculate page boundaries
        $totalItems = $filteredItems.Count
        $pageEnd = [Math]::Min($pageStart + $PageSize, $totalItems) - 1
        
        # Ensure selected index is within bounds
        if ($selectedIndex -ge $totalItems) {
            $selectedIndex = $totalItems - 1
        }
        
        # Adjust page if selected item is outside current page
        if ($selectedIndex -lt $pageStart) {
            $pageStart = $selectedIndex
            $pageEnd = [Math]::Min($pageStart + $PageSize, $totalItems) - 1
        }
        elseif ($selectedIndex -gt $pageEnd) {
            $pageEnd = $selectedIndex
            $pageStart = [Math]::Max(0, $pageEnd - $PageSize + 1)
        }
        
        # Display items
        for ($i = $pageStart; $i -le $pageEnd; $i++) {
            $item = $filteredItems[$i]
            $displayText = if ($DisplayProperty -and $item -is [PSObject]) {
                $item.$DisplayProperty
            } else {
                $item.ToString()
            }
            
            # Number for quick selection (1-9, then a-z)
            $quickKey = if ($i - $pageStart -lt 9) {
                ($i - $pageStart + 1).ToString()
            } elseif ($i - $pageStart -lt 35) {
                [char](97 + ($i - $pageStart - 9))
            } else {
                " "
            }
            
            # Selection indicator
            if ($AllowMultiple) {
                $isSelected = $selectedItems -contains $i
                $indicator = if ($isSelected) { "[✓]" } else { "[ ]" }
                $indicatorColor = if ($isSelected) { "Green" } else { "DarkGray" }
                Write-Host "  " -NoNewline
                Write-Host $indicator -ForegroundColor $indicatorColor -NoNewline
            } else {
                $indicator = if ($i -eq $selectedIndex) { "→" } else { " " }
                $indicatorColor = if ($i -eq $selectedIndex) { "Cyan" } else { "DarkGray" }
                Write-Host " " -NoNewline
                Write-Host $indicator -ForegroundColor $indicatorColor -NoNewline
            }
            
            # Quick selection key
            Write-Host " [$quickKey]" -ForegroundColor DarkCyan -NoNewline
            
            # Item text
            $itemColor = if ($i -eq $selectedIndex) { "White" } else { "Gray" }
            Write-Host " $displayText" -ForegroundColor $itemColor
            
            # Show details if requested
            if ($ShowDetails -and $DetailProperties.Count -gt 0 -and $i -eq $selectedIndex) {
                foreach ($detailKey in $DetailProperties.Keys) {
                    $detailValue = if ($item -is [PSObject] -and $item.PSObject.Properties[$DetailProperties[$detailKey]]) {
                        $item.($DetailProperties[$detailKey])
                    } else { "" }
                    if ($detailValue) {
                        Write-Host "       $detailKey`: $detailValue" -ForegroundColor DarkGray
                    }
                }
            }
        }
        
        # Show page info if multiple pages
        if ($totalItems -gt $PageSize) {
            Write-Host "`n  Page $([Math]::Floor($selectedIndex / $PageSize) + 1) of $([Math]::Ceiling($totalItems / $PageSize))" -ForegroundColor DarkGray
            Write-Host "  ↑↓ Navigate | PgUp/PgDn Change page" -ForegroundColor DarkGray
        }
        
        # Show controls
        Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        
        if ($AllowMultiple) {
            Write-Host "  [SPACE] Toggle | [A] All | [N] None | [ENTER] Confirm | [ESC] Cancel" -ForegroundColor Yellow
        } else {
            Write-Host "  [ENTER] Select | [ESC] Cancel | [1-9,a-z] Quick select" -ForegroundColor Yellow
        }
        Write-Host "  [/] Search filter | [BACKSPACE] Clear character" -ForegroundColor DarkGray
        
        # Get user input
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Handle input
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                if ($selectedIndex -gt 0) { $selectedIndex-- }
                else { $selectedIndex = $totalItems - 1 } # Wrap to bottom
            }
            40 { # Down arrow
                if ($selectedIndex -lt $totalItems - 1) { $selectedIndex++ }
                else { $selectedIndex = 0 } # Wrap to top
            }
            33 { # Page Up
                $selectedIndex = [Math]::Max(0, $selectedIndex - $PageSize)
            }
            34 { # Page Down
                $selectedIndex = [Math]::Min($totalItems - 1, $selectedIndex + $PageSize)
            }
            36 { # Home
                $selectedIndex = 0
            }
            35 { # End
                $selectedIndex = $totalItems - 1
            }
            32 { # Space (toggle in multi-select)
                if ($AllowMultiple) {
                    if ($selectedItems -contains $selectedIndex) {
                        $selectedItems = $selectedItems | Where-Object { $_ -ne $selectedIndex }
                    } else {
                        $selectedItems += $selectedIndex
                    }
                }
            }
            13 { # Enter
                if ($AllowMultiple) {
                    if ($selectedItems.Count -eq 0) {
                        Write-Warning "`nNo items selected."
                        Start-Sleep -Seconds 1
                        continue
                    }
                    $result = @()
                    foreach ($idx in $selectedItems) {
                        $item = $filteredItems[$idx]
                        if ($ReturnIndex) {
                            $result += $idx
                        } elseif ($ValueProperty -and $item -is [PSObject]) {
                            $result += $item.$ValueProperty
                        } else {
                            $result += $item
                        }
                    }
                    return $result
                } else {
                    $item = $filteredItems[$selectedIndex]
                    if ($ReturnIndex) {
                        return $selectedIndex
                    } elseif ($ValueProperty -and $item -is [PSObject]) {
                        return $item.$ValueProperty
                    } else {
                        return $item
                    }
                }
            }
            27 { # Escape
                if ($searchFilter) {
                    $searchFilter = ""
                    $selectedIndex = 0
                } else {
                    return $null
                }
            }
            8 { # Backspace
                if ($searchFilter.Length -gt 0) {
                    $searchFilter = $searchFilter.Substring(0, $searchFilter.Length - 1)
                }
            }
            65 { # A (select all in multi-select)
                if ($AllowMultiple -and $key.Character -eq 'A') {
                    $selectedItems = 0..($totalItems - 1)
                }
            }
            78 { # N (select none in multi-select)
                if ($AllowMultiple -and $key.Character -eq 'N') {
                    $selectedItems = @()
                }
            }
            191 { # Forward slash (search)
                $searchFilter = ""
                Write-Host "`n  Start typing to filter..." -ForegroundColor Gray
            }
            default {
                # Check for quick select keys (1-9)
                if ($key.Character -ge '1' -and $key.Character -le '9') {
                    $quickIndex = [int]$key.Character.ToString() - 1 + $pageStart
                    if ($quickIndex -lt $totalItems) {
                        if ($AllowMultiple) {
                            if ($selectedItems -contains $quickIndex) {
                                $selectedItems = $selectedItems | Where-Object { $_ -ne $quickIndex }
                            } else {
                                $selectedItems += $quickIndex
                            }
                        } else {
                            $selectedIndex = $quickIndex
                            # Auto-select if not multiple
                            $item = $filteredItems[$selectedIndex]
                            if ($ReturnIndex) {
                                return $selectedIndex
                            } elseif ($ValueProperty -and $item -is [PSObject]) {
                                return $item.$ValueProperty
                            } else {
                                return $item
                            }
                        }
                    }
                }
                # Check for quick select keys (a-z)
                elseif ($key.Character -ge 'a' -and $key.Character -le 'z') {
                    $quickIndex = [int]($key.Character - 'a') + 9 + $pageStart
                    if ($quickIndex -lt $totalItems) {
                        if ($AllowMultiple) {
                            if ($selectedItems -contains $quickIndex) {
                                $selectedItems = $selectedItems | Where-Object { $_ -ne $quickIndex }
                            } else {
                                $selectedItems += $quickIndex
                            }
                        } else {
                            $selectedIndex = $quickIndex
                            # Auto-select if not multiple
                            $item = $filteredItems[$selectedIndex]
                            if ($ReturnIndex) {
                                return $selectedIndex
                            } elseif ($ValueProperty -and $item -is [PSObject]) {
                                return $item.$ValueProperty
                            } else {
                                return $item
                            }
                        }
                    }
                }
                # Add to search filter if printable character
                elseif ($key.Character -and -not [char]::IsControl($key.Character) -and $key.Character -ne "`0") {
                    $searchFilter += $key.Character
                }
            }
        }
    }
}

# Enhanced project/template selector
function global:Select-ProjectOrTemplate {
    param(
        [string]$Title = "Select Project or Template",
        [switch]$IncludeNone,
        [switch]$ProjectsOnly,
        [switch]$TemplatesOnly
    )
    
    $items = @()
    
    if ($IncludeNone) {
        $items += [PSCustomObject]@{
            Key = $null
            Name = "[None - No Project]"
            Type = "None"
            Client = ""
            Status = ""
        }
    }
    
    # Add projects
    if (-not $TemplatesOnly -and $script:Data.Projects -and $script:Data.Projects.Count -gt 0) {
        foreach ($proj in $script:Data.Projects.GetEnumerator() | Sort-Object {$_.Value.Name}) {
            $items += [PSCustomObject]@{
                Key = $proj.Key
                Name = "$($proj.Value.Name) [$($proj.Key)]"
                Type = "Project"
                Client = if ($proj.Value.Client) { $proj.Value.Client } else { "-" }
                Status = $proj.Value.Status
            }
        }
    }
    
    # Add templates
    if (-not $ProjectsOnly -and $script:Data.Settings.TimeTrackerTemplates -and $script:Data.Settings.TimeTrackerTemplates.Count -gt 0) {
        foreach ($tmpl in $script:Data.Settings.TimeTrackerTemplates.GetEnumerator()) {
            $items += [PSCustomObject]@{
                Key = $tmpl.Key
                Name = "$($tmpl.Value.Name) [$($tmpl.Key)]"
                Type = "Template"
                Client = if ($tmpl.Value.Client) { $tmpl.Value.Client } else { "-" }
                Status = "Template"
            }
        }
    }
    
    if ($items.Count -eq 0) {
        Write-Warning "No projects or templates available."
        return $null
    }
    
    $result = Show-EnhancedSelection `
        -Items $items `
        -Title $Title `
        -DisplayProperty "Name" `
        -ValueProperty "Key" `
        -ShowDetails `
        -DetailProperties @{
            "Type" = "Type"
            "Client" = "Client"
            "Status" = "Status"
        }
    
    return $result
}

# Enhanced task selector
function global:Select-Task {
    param(
        [string]$Title = "Select Task",
        [switch]$AllowMultiple,
        [switch]$ActiveOnly,
        [switch]$IncludeCompleted,
        [string]$ProjectFilter = ""
    )
    
    $tasks = $script:Data.Tasks | Where-Object { $_.IsCommand -ne $true }
    
    if ($ActiveOnly) {
        $tasks = $tasks | Where-Object { -not $_.Completed }
    } elseif (-not $IncludeCompleted) {
        $cutoffDate = [datetime]::Today.AddDays(-$script:Data.Settings.ShowCompletedDays)
        $tasks = $tasks | Where-Object {
            (-not $_.Completed) -or
            ((-not [string]::IsNullOrEmpty($_.CompletedDate)) -and ([datetime]::Parse($_.CompletedDate).Date -ge $cutoffDate.Date))
        }
    }
    
    if ($ProjectFilter) {
        $tasks = $tasks | Where-Object { $_.ProjectKey -eq $ProjectFilter }
    }
    
    if ($tasks.Count -eq 0) {
        Write-Warning "No tasks available for selection."
        return $null
    }
    
    # Create display objects
    $items = @()
    foreach ($task in $tasks | Sort-Object @{Expression={$_.Completed}}, @{Expression={Get-TaskStatus $_}}, Priority, Description) {
        $status = Get-TaskStatus $task
        $priorityInfo = Get-PriorityInfo $task.Priority
        $project = if ($task.ProjectKey) { Get-ProjectOrTemplate $task.ProjectKey } else { $null }
        
        $displayName = "$($priorityInfo.Icon) $($task.Description)"
        if ($task.Completed) {
            $displayName = "✓ $displayName"
        }
        
        $items += [PSCustomObject]@{
            Id = $task.Id
            DisplayName = $displayName
            Status = $status
            Priority = $task.Priority
            Project = if ($project) { $project.Name } else { "-" }
            Due = if ($task.DueDate) { Format-TodoDate $task.DueDate } else { "-" }
            Progress = "$($task.Progress)%"
        }
    }
    
    $result = Show-EnhancedSelection `
        -Items $items `
        -Title $Title `
        -DisplayProperty "DisplayName" `
        -ValueProperty "Id" `
        -AllowMultiple:$AllowMultiple `
        -ShowDetails `
        -DetailProperties @{
            "Status" = "Status"
            "Project" = "Project"
            "Due" = "Due"
            "Progress" = "Progress"
        }
    
    return $result
}

# Enhanced menu selector (replaces Show-MenuSelection)
function global:Show-EnhancedMenu {
    param(
        [string]$Title,
        [array]$MenuItems, # Array of @{Key="1"; Label="Option 1"; Action={ScriptBlock}}
        [string]$BackLabel = "Back",
        [switch]$NoBack
    )
    
    $items = @()
    foreach ($menuItem in $MenuItems) {
        $items += [PSCustomObject]@{
            Key = $menuItem.Key
            Label = $menuItem.Label
            Action = $menuItem.Action
            DisplayText = "[$($menuItem.Key)] $($menuItem.Label)"
        }
    }
    
    if (-not $NoBack) {
        $items += [PSCustomObject]@{
            Key = "B"
            Label = $BackLabel
            Action = { return $true }
            DisplayText = "[B] $BackLabel"
        }
    }
    
    $selected = Show-EnhancedSelection `
        -Items $items `
        -Title $Title `
        -DisplayProperty "DisplayText" `
        -ReturnIndex
    
    if ($null -eq $selected) {
        return $false
    }
    
    $selectedItem = $items[$selected]
    if ($selectedItem.Action) {
        & $selectedItem.Action
    }
    
    return ($selectedItem.Key -eq "B")
}

# Quick selector for Yes/No choices
function global:Get-EnhancedConfirmation {
    param(
        [string]$Message,
        [string]$Title = "Confirm",
        [switch]$DefaultNo
    )
    
    $options = @(
        [PSCustomObject]@{ Value = $true; Display = "Yes" },
        [PSCustomObject]@{ Value = $false; Display = "No" }
    )
    
    # Set default selection
    $defaultIndex = if ($DefaultNo) { 1 } else { 0 }
    
    Clear-Host
    Write-Header $Title
    Write-Host $Message -ForegroundColor Yellow
    Write-Host ""
    
    for ($i = 0; $i -lt $options.Count; $i++) {
        $indicator = if ($i -eq $defaultIndex) { "→" } else { " " }
        $color = if ($i -eq $defaultIndex) { "White" } else { "Gray" }
        Write-Host "$indicator [$($i + 1)] $($options[$i].Display)" -ForegroundColor $color
    }
    
    Write-Host "`n[ENTER] Select default | [Y/N] Quick select | [ESC] Cancel"
    
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    switch ($key.VirtualKeyCode) {
        13 { return $options[$defaultIndex].Value } # Enter
        27 { return $false } # Escape
        89 { return $true }  # Y
        78 { return $false } # N
        49 { return $true }  # 1
        50 { return $false } # 2
        default { return $options[$defaultIndex].Value }
    }
}

Write-Host "Enhanced Selection System loaded. Use Show-EnhancedSelection for improved list selection." -ForegroundColor Green
