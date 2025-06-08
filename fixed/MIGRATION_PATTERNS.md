# Migration Patterns for PMC Terminal to TUI

## Pattern 1: Migrating Input Functions

### Old Pattern (Blocking)
```powershell
function Add-ManualTimeEntry {
    Write-Header "Manual Time Entry"
    
    $projectKey = Select-ProjectOrTemplate -Title "Select Project"
    if (-not $projectKey) { return }
    
    $hours = Read-Host "Hours worked"
    if (-not [double]::TryParse($hours, [ref]$null)) {
        Write-Error "Invalid hours format"
        return
    }
    
    $description = Read-Host "Description (optional)"
    $date = Read-Host "Date (YYYY-MM-DD, default: today)"
    
    # ... save logic
}
```

### New Pattern (Non-Blocking TUI)
```powershell
$script:TimeEntryScreen = @{
    Name = "TimeEntry"
    State = @{
        Stage = "ProjectSelect"  # ProjectSelect, DataEntry, Confirm
        SelectedProject = $null
        FormData = @{
            Hours = ""
            Description = ""
            Date = (Get-Date).ToString("yyyy-MM-dd")
        }
    }
    
    Render = {
        switch ($script:TimeEntryScreen.State.Stage) {
            "ProjectSelect" { Render-ProjectSelector }
            "DataEntry" { Render-TimeEntryForm }
            "Confirm" { Render-Confirmation }
        }
    }
    
    HandleInput = {
        param($Key)
        switch ($script:TimeEntryScreen.State.Stage) {
            "ProjectSelect" { Handle-ProjectSelection $Key }
            "DataEntry" { Handle-FormInput $Key }
            "Confirm" { Handle-Confirmation $Key }
        }
    }
}
```

## Pattern 2: Migrating Display Functions

### Old Pattern (Direct Output)
```powershell
function Show-WeekReport {
    $weekData = Get-WeekData
    
    Write-Host "Week Report" -ForegroundColor Cyan
    Write-Host "="*50
    
    foreach ($day in $weekData) {
        Write-Host "$($day.Date): $($day.Hours)h" -ForegroundColor Yellow
        foreach ($entry in $day.Entries) {
            Write-Host "  - $($entry.Project): $($entry.Hours)h"
        }
    }
}
```

### New Pattern (Buffer Rendering)
```powershell
function Render-WeekReport {
    param($X, $Y, $Width, $Height)
    
    $weekData = Get-WeekData
    
    # Draw container
    Write-BufferBox -X $X -Y $Y -Width $Width -Height $Height -Title "Week Report"
    
    # Render data with proper layout
    $currentY = $Y + 2
    foreach ($day in $weekData) {
        # Day header with visual indicator
        $dayBar = Draw-HoursBar -Hours $day.Hours -MaxWidth 20
        Write-BufferString -X ($X + 2) -Y $currentY `
            -Text "$($day.Date.ToString('ddd MM/dd')): " `
            -ForegroundColor [ConsoleColor]::Yellow
        Write-BufferString -X ($X + 15) -Y $currentY `
            -Text $dayBar `
            -ForegroundColor [ConsoleColor]::Green
        Write-BufferString -X ($X + 36) -Y $currentY `
            -Text "$($day.Hours)h" `
            -ForegroundColor [ConsoleColor]::White
        
        $currentY++
    }
}
```

## Pattern 3: Migrating Menu Systems

### Old Pattern (Sequential Menus)
```powershell
function Show-TaskManagementMenu {
    while ($true) {
        Write-Header "Task Management"
        Write-Host "[1] View Active Tasks"
        Write-Host "[2] Add New Task"
        Write-Host "[3] Complete Task"
        Write-Host "[B] Back"
        
        $choice = Read-Host "Choice"
        
        switch ($choice) {
            "1" { Show-TasksView }
            "2" { Add-TodoTask }
            "3" { Complete-Task }
            "B" { return }
        }
    }
}
```

### New Pattern (State-Based Navigation)
```powershell
$script:TaskMenuScreen = @{
    Name = "TaskMenu"
    State = @{
        MenuItems = @(
            @{ Key = "1"; Label = "View Active Tasks"; Action = "ViewTasks" }
            @{ Key = "2"; Label = "Add New Task"; Action = "AddTask" }
            @{ Key = "3"; Label = "Complete Task"; Action = "CompleteTask" }
        )
        SelectedIndex = 0
    }
    
    Render = {
        # Visual menu with selection highlight
        Render-MenuItems -Items $State.MenuItems -Selected $State.SelectedIndex
    }
    
    HandleInput = {
        param($Key)
        switch ($Key.Key) {
            ([ConsoleKey]::UpArrow) { 
                $State.SelectedIndex = ($State.SelectedIndex - 1) % $State.MenuItems.Count 
            }
            ([ConsoleKey]::DownArrow) { 
                $State.SelectedIndex = ($State.SelectedIndex + 1) % $State.MenuItems.Count 
            }
            ([ConsoleKey]::Enter) {
                $action = $State.MenuItems[$State.SelectedIndex].Action
                switch ($action) {
                    "ViewTasks" { Push-Screen -Screen $script:TaskListScreen }
                    "AddTask" { Push-Screen -Screen $script:TaskFormScreen }
                    "CompleteTask" { Push-Screen -Screen $script:TaskCompleteScreen }
                }
            }
            ([ConsoleKey]::Escape) { return "Back" }
        }
    }
}
```

## Pattern 4: Migrating Data Operations

### Old Pattern (Synchronous Operations)
```powershell
function Export-FormattedTimesheet {
    Write-Host "Exporting timesheet..." -ForegroundColor Yellow
    
    $data = Get-TimesheetData
    $csv = ConvertTo-Csv $data
    $csv | Out-File "timesheet.csv"
    
    Write-Host "Export complete!" -ForegroundColor Green
}
```

### New Pattern (Async with Progress)
```powershell
$script:ExportScreen = @{
    Name = "Export"
    State = @{
        Progress = 0
        Status = "Initializing..."
        IsComplete = $false
        ExportJob = $null
    }
    
    Init = {
        # Start async export
        $State.ExportJob = Start-Job -ScriptBlock {
            $data = Get-TimesheetData
            # Report progress via temp file or other mechanism
            $csv = ConvertTo-Csv $data
            $csv | Out-File "timesheet.csv"
        }
    }
    
    Render = {
        # Progress bar
        Write-BufferBox -X 10 -Y 10 -Width 60 -Height 8 -Title "Export Progress"
        
        # Status message
        Write-BufferString -X 12 -Y 12 -Text $State.Status
        
        # Visual progress bar
        $barWidth = 56
        $filled = [int]($barWidth * ($State.Progress / 100))
        $bar = ("█" * $filled) + ("░" * ($barWidth - $filled))
        Write-BufferString -X 12 -Y 14 -Text $bar -ForegroundColor [ConsoleColor]::Green
        Write-BufferString -X 12 -Y 15 -Text "$($State.Progress)%"
        
        if ($State.IsComplete) {
            Write-BufferString -X 12 -Y 17 -Text "Press any key to continue..." `
                -ForegroundColor [ConsoleColor]::Yellow
        }
    }
    
    HandleInput = {
        param($Key)
        if ($State.IsComplete) {
            return "Back"
        }
        if ($Key.Key -eq [ConsoleKey]::Escape) {
            # Cancel operation
            Stop-Job $State.ExportJob
            return "Back"
        }
    }
}
```

## Pattern 5: Integrating Existing Data Functions

### Wrapper Approach
```powershell
# Keep existing function, wrap for TUI
function Invoke-LegacyFunction {
    param(
        [string]$FunctionName,
        [hashtable]$Parameters = @{}
    )
    
    # Capture output
    $output = & $FunctionName @Parameters | Out-String -Width 200
    
    # Convert to TUI screen
    return @{
        Name = "$FunctionName-Output"
        State = @{
            Output = $output
            ScrollOffset = 0
        }
        
        Render = {
            # Parse output and render to buffer
            $lines = $State.Output -split "`n"
            $y = 2
            foreach ($line in $lines | Select-Object -Skip $State.ScrollOffset -First 20) {
                Write-BufferString -X 2 -Y $y -Text $line
                $y++
            }
        }
        
        HandleInput = {
            param($Key)
            switch ($Key.Key) {
                ([ConsoleKey]::UpArrow) { 
                    $State.ScrollOffset = [Math]::Max(0, $State.ScrollOffset - 1) 
                }
                ([ConsoleKey]::DownArrow) { 
                    $State.ScrollOffset++ 
                }
                ([ConsoleKey]::Escape) { return "Back" }
            }
        }
    }
}
```

## Common Migration Helpers

### 1. Input Validation Component
```powershell
$script:InputValidators = @{
    Required = { param($Value) -not [string]::IsNullOrWhiteSpace($Value) }
    
    Number = { 
        param($Value) 
        [double]::TryParse($Value, [ref]$null) 
    }
    
    Date = { 
        param($Value) 
        [DateTime]::TryParse($Value, [ref]$null) 
    }
    
    Range = {
        param($Value, $Min, $Max)
        $num = 0
        if ([double]::TryParse($Value, [ref]$num)) {
            return $num -ge $Min -and $num -le $Max
        }
        return $false
    }
}
```

### 2. Legacy Color Converter
```powershell
function Convert-LegacyColors {
    param($Text)
    
    # Convert Write-Host color parameters to TUI buffer format
    $pattern = 'Write-Host\s+"([^"]+)"\s+-ForegroundColor\s+(\w+)'
    
    $matches = [regex]::Matches($Text, $pattern)
    foreach ($match in $matches) {
        $text = $match.Groups[1].Value
        $color = $match.Groups[2].Value
        
        # Convert to buffer write
        $converted = "Write-BufferString -Text `"$text`" -ForegroundColor [ConsoleColor]::$color"
    }
}
```

### 3. Menu Builder
```powershell
function New-TuiMenu {
    param(
        [string]$Title,
        [hashtable[]]$Items
    )
    
    return @{
        Name = "$Title-Menu"
        State = @{
            Title = $Title
            Items = $Items
            SelectedIndex = 0
        }
        
        Render = {
            Write-BufferBox -X 10 -Y 5 -Width 60 -Height ($State.Items.Count + 6) `
                -Title $State.Title -BorderColor [ConsoleColor]::Cyan
            
            $y = 7
            for ($i = 0; $i -lt $State.Items.Count; $i++) {
                $item = $State.Items[$i]
                $prefix = if ($i -eq $State.SelectedIndex) { "► " } else { "  " }
                $color = if ($i -eq $State.SelectedIndex) { 
                    [ConsoleColor]::Yellow 
                } else { 
                    [ConsoleColor]::White 
                }
                
                Write-BufferString -X 12 -Y $y `
                    -Text "$prefix[$($item.Key)] $($item.Label)" `
                    -ForegroundColor $color
                $y++
            }
        }
        
        HandleInput = {
            # Standard menu navigation
        }
    }
}
```

## Testing Migration

### 1. Side-by-Side Mode
```powershell
# Run both UIs temporarily
$Global:UseTUI = $false

function Invoke-PMCFunction {
    param($Function)
    
    if ($Global:UseTUI) {
        # Use TUI version
        $screen = Get-TUIScreen -For $Function
        Push-Screen -Screen $screen
    } else {
        # Use legacy version
        & $Function
    }
}
```

### 2. Feature Flag Approach
```powershell
$script:FeatureFlags = @{
    TUI_TimeEntry = $true
    TUI_TaskList = $false
    TUI_Reports = $false
}

function Should-UseTUI {
    param($Feature)
    return $script:FeatureFlags["TUI_$Feature"] -eq $true
}
```

## Migration Priority

1. **High-Frequency Operations** (Week 1)
   - Time entry (manual and timer)
   - Task quick-add
   - Active timer display

2. **Core Workflows** (Week 2-3)
   - Task management (CRUD)
   - Project selection
   - Week/day reports

3. **Advanced Features** (Week 4-5)
   - File browser
   - Command palette
   - Excel integration

4. **Nice-to-Have** (Week 6+)
   - Theme editor
   - Settings UI
   - Help system

## Success Criteria

- No loss of functionality
- Improved responsiveness
- Keyboard-only navigation
- Consistent visual design
- Backward compatibility mode
