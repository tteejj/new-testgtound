# Data Manager Module - Core data structures and persistence

# Initialize data structure
function Initialize-DataManager {
    Write-TuiLog "Initializing data manager" -Level Info
    
    # Load existing data or create new
    Load-UnifiedData
    
    # Ensure all required data structures exist
    if (-not $script:Data) {
        $script:Data = Get-DefaultDataStructure
    }
    
    # Subscribe to save events
    Subscribe-Event -EventName "Data.Save" -Handler {
        Save-UnifiedData
    }
    
    # Auto-save on critical events
    Subscribe-Event -EventName "Timer.Started" -Handler { Save-UnifiedData }
    Subscribe-Event -EventName "Timer.Stopped" -Handler { Save-UnifiedData }
    Subscribe-Event -EventName "Task.Created" -Handler { Save-UnifiedData }
    Subscribe-Event -EventName "Task.Updated" -Handler { Save-UnifiedData }
    Subscribe-Event -EventName "TimeEntry.Created" -Handler { Save-UnifiedData }
    Subscribe-Event -EventName "TimeEntry.Updated" -Handler { Save-UnifiedData }
}

# Default data structure
function Get-DefaultDataStructure {
    return @{
        Projects = @{}
        Tasks = @()
        TimeEntries = @()
        ActiveTimers = @{}
        ArchivedTasks = @()
        ExcelCopyJobs = @{}
        CurrentWeek = Get-WeekStart (Get-Date)
        Settings = Get-DefaultSettings
    }
}

# Default settings
function Get-DefaultSettings {
    return @{
        # Time tracking
        DefaultRate = 50
        Currency = "USD"
        HoursPerDay = 8
        DaysPerWeek = 5
        
        # Task management
        DefaultPriority = "Medium"
        DefaultCategory = "General"
        ShowCompletedDays = 7
        AutoArchiveDays = 30
        
        # Command snippets
        CommandSnippets = @{
            EnableHotkeys = $false
            AutoCopyToClipboard = $true
            ShowInTaskList = $false
            DefaultCategory = "PowerShell"
        }
        
        # UI preferences
        QuickActionTipShown = $false
        
        # Theme
        Theme = @{
            HeaderColor = "Cyan"
            WarningColor = "Yellow"
            ErrorColor = "Red"
            SuccessColor = "Green"
            InfoColor = "Blue"
            HighlightColor = "Yellow"
            SubtleColor = "DarkGray"
        }
    }
}

# Week calculation
function Get-WeekStart {
    param([DateTime]$Date)
    $dayOfWeek = $Date.DayOfWeek
    $daysToSubtract = if ($dayOfWeek -eq [System.DayOfWeek]::Sunday) { 6 } else { [int]$dayOfWeek - 1 }
    return $Date.Date.AddDays(-$daysToSubtract)
}

function Get-WeekEnd {
    param([DateTime]$Date)
    return (Get-WeekStart $Date).AddDays(6)
}

# Data persistence
function Get-DataPath {
    $appDataPath = [Environment]::GetFolderPath('ApplicationData')
    $dataDir = Join-Path $appDataPath "UnifiedProductivitySuite"
    
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    
    return Join-Path $dataDir "unified_data.json"
}

function Load-UnifiedData {
    $dataPath = Get-DataPath
    
    if (Test-Path $dataPath) {
        try {
            Write-TuiLog "Loading data from $dataPath" -Level Info
            $jsonData = Get-Content -Path $dataPath -Raw
            $script:Data = $jsonData | ConvertFrom-Json -AsHashtable
            
            # Ensure ActiveTimers is a hashtable
            if ($script:Data.ActiveTimers -and $script:Data.ActiveTimers -is [PSCustomObject]) {
                $newHash = @{}
                $script:Data.ActiveTimers.PSObject.Properties | ForEach-Object {
                    $newHash[$_.Name] = $_.Value
                }
                $script:Data.ActiveTimers = $newHash
            }
            
            # Convert arrays if needed
            if ($script:Data.Tasks -is [PSCustomObject]) {
                $script:Data.Tasks = @($script:Data.Tasks)
            }
            if ($script:Data.TimeEntries -is [PSCustomObject]) {
                $script:Data.TimeEntries = @($script:Data.TimeEntries)
            }
            
            # Ensure current week is DateTime
            if ($script:Data.CurrentWeek -is [string]) {
                $script:Data.CurrentWeek = [DateTime]::Parse($script:Data.CurrentWeek)
            }
            
            Write-TuiLog "Data loaded successfully" -Level Info
            Publish-Event -EventName "Data.Loaded" -Data @{ Path = $dataPath }
        }
        catch {
            Write-TuiLog "Error loading data: $_" -Level Error
            $script:Data = Get-DefaultDataStructure
        }
    }
    else {
        Write-TuiLog "No existing data file found, creating new" -Level Info
        $script:Data = Get-DefaultDataStructure
        Save-UnifiedData
    }
}

function Save-UnifiedData {
    try {
        $dataPath = Get-DataPath
        
        # Create backup before saving
        if (Test-Path $dataPath) {
            $backupPath = "$dataPath.backup"
            Copy-Item -Path $dataPath -Destination $backupPath -Force
        }
        
        # Convert to JSON and save
        $jsonData = $script:Data | ConvertTo-Json -Depth 10 -Compress
        Set-Content -Path $dataPath -Value $jsonData -Encoding UTF8
        
        Write-TuiLog "Data saved successfully" -Level Info
        Publish-Event -EventName "Data.Saved" -Data @{ Path = $dataPath }
    }
    catch {
        Write-TuiLog "Error saving data: $_" -Level Error
        Write-StatusLine -Text " Failed to save data! " -BackgroundColor (Get-ThemeColor "Error")
    }
}

# Project helpers
function Get-ProjectOrTemplate {
    param([string]$Key)
    
    if ([string]::IsNullOrEmpty($Key)) { return $null }
    return $script:Data.Projects[$Key]
}

function Get-AllProjects {
    param([switch]$IncludeTemplates)
    
    $projects = $script:Data.Projects.GetEnumerator() | ForEach-Object { $_.Value }
    
    if (-not $IncludeTemplates) {
        $projects = $projects | Where-Object { -not $_.IsTemplate }
    }
    
    return $projects | Sort-Object Name
}

# Task helpers
function Get-ActiveTasks {
    return $script:Data.Tasks | Where-Object { 
        -not $_.Completed -and 
        -not $_.IsCommand 
    } | Sort-Object Priority, DueDate
}

function Get-OverdueTasks {
    $today = [DateTime]::Today.Date
    return $script:Data.Tasks | Where-Object { 
        -not $_.Completed -and 
        -not $_.IsCommand -and 
        -not [string]::IsNullOrEmpty($_.DueDate) -and 
        [DateTime]::Parse($_.DueDate).Date -lt $today 
    }
}

function Get-TasksDueToday {
    $today = [DateTime]::Today.Date
    return $script:Data.Tasks | Where-Object { 
        -not $_.Completed -and 
        -not $_.IsCommand -and 
        -not [string]::IsNullOrEmpty($_.DueDate) -and 
        [DateTime]::Parse($_.DueDate).Date -eq $today 
    }
}

# Time entry helpers
function Get-TodayTimeEntries {
    $todayStr = (Get-Date).ToString("yyyy-MM-dd")
    return $script:Data.TimeEntries | Where-Object { $_.Date -eq $todayStr }
}

function Get-WeekTimeEntries {
    param([DateTime]$WeekStart = $script:Data.CurrentWeek)
    
    $weekEnd = $WeekStart.AddDays(6)
    $startStr = $WeekStart.ToString("yyyy-MM-dd")
    $endStr = $weekEnd.ToString("yyyy-MM-dd")
    
    return $script:Data.TimeEntries | Where-Object { 
        $_.Date -ge $startStr -and $_.Date -le $endStr 
    }
}

function Get-TotalHoursToday {
    $entries = Get-TodayTimeEntries
    $total = ($entries | Measure-Object -Property Hours -Sum).Sum
    return if ($total) { [Math]::Round($total, 2) } else { 0.0 }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-DataManager',
    'Get-DefaultDataStructure',
    'Get-DefaultSettings',
    'Get-WeekStart',
    'Get-WeekEnd',
    'Get-DataPath',
    'Load-UnifiedData',
    'Save-UnifiedData',
    'Get-ProjectOrTemplate',
    'Get-AllProjects',
    'Get-ActiveTasks',
    'Get-OverdueTasks',
    'Get-TasksDueToday',
    'Get-TodayTimeEntries',
    'Get-WeekTimeEntries',
    'Get-TotalHoursToday'
)
