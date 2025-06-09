# Data Manager Module - Unified data operations with event integration
# This module consolidates all data operations from the current scattered implementation

# Initialize data structure if not exists
if (-not $script:Data) {
    $script:Data = @{
        TimeEntries = @()
        Tasks = @()
        Projects = @{}
        Templates = @{}
        ActiveTimers = @{}
        CommandSnippets = @()
        Settings = @{
            Theme = "Default"
            AutoSave = $true
            BackupRetentionDays = 7
        }
    }
}

# Data file path
$script:DataFilePath = Join-Path $PSScriptRoot "..\data\pmc-data.json"

function global:Load-UnifiedData {
    param(
        [string]$Path = $script:DataFilePath
    )
    
    if (Test-Path $Path) {
        try {
            $jsonContent = Get-Content $Path -Raw | ConvertFrom-Json
            
            # Convert JSON to hashtable structure
            $script:Data = @{
                TimeEntries = @($jsonContent.TimeEntries)
                Tasks = @($jsonContent.Tasks)
                Projects = @{}
                Templates = @{}
                ActiveTimers = @{}
                CommandSnippets = @($jsonContent.CommandSnippets)
                Settings = @{
                    Theme = $jsonContent.Settings.Theme ?? "Default"
                    AutoSave = $jsonContent.Settings.AutoSave ?? $true
                    BackupRetentionDays = $jsonContent.Settings.BackupRetentionDays ?? 7
                }
            }
            
            # Convert projects from array to hashtable
            if ($jsonContent.Projects) {
                foreach ($proj in $jsonContent.Projects.PSObject.Properties) {
                    $script:Data.Projects[$proj.Name] = $proj.Value
                }
            }
            
            # Convert templates from array to hashtable
            if ($jsonContent.Templates) {
                foreach ($tmpl in $jsonContent.Templates.PSObject.Properties) {
                    $script:Data.Templates[$tmpl.Name] = $tmpl.Value
                }
            }
            
            # Convert active timers
            if ($jsonContent.ActiveTimers) {
                foreach ($timer in $jsonContent.ActiveTimers.PSObject.Properties) {
                    $script:Data.ActiveTimers[$timer.Name] = $timer.Value
                }
            }
            
            # Publish event after successful load
            if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
                Publish-Event -EventName "Data.Loaded" -Data $script:Data
            }
            
            Write-Host "Data loaded successfully from $Path" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to load data: $_"
            # Initialize with empty data structure
            Initialize-EmptyData
        }
    }
    else {
        Write-Host "No data file found. Creating new data structure." -ForegroundColor Yellow
        Initialize-EmptyData
        Save-UnifiedData
    }
}

function global:Save-UnifiedData {
    param(
        [string]$Path = $script:DataFilePath,
        [switch]$CreateBackup
    )
    
    try {
        # Ensure directory exists
        $directory = Split-Path $Path -Parent
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        # Create backup if requested or if auto-backup is enabled
        if ($CreateBackup -or $script:Data.Settings.AutoSave) {
            Backup-Data
        }
        
        # Convert hashtables to PSCustomObject for proper JSON serialization
        $dataToSave = [PSCustomObject]@{
            TimeEntries = $script:Data.TimeEntries
            Tasks = $script:Data.Tasks
            Projects = $script:Data.Projects
            Templates = $script:Data.Templates
            ActiveTimers = $script:Data.ActiveTimers
            CommandSnippets = $script:Data.CommandSnippets
            Settings = $script:Data.Settings
            LastSaved = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        # Save to file
        $dataToSave | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        
        # Publish event after successful save
        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
            Publish-Event -EventName "Data.Saved"
        }
        
        Write-Verbose "Data saved successfully to $Path"
    }
    catch {
        Write-Error "Failed to save data: $_"
        throw
    }
}

function global:Initialize-DataEventHandlers {
    # Time Entry Creation
    Subscribe-Event -EventName "Data.Create.TimeEntry" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        # Validation
        if (-not $data.Project) {
            Publish-Event -EventName "Notification.Show" -Data @{ Text = "Project is required"; Type = "Error" }
            return
        }
        
        # Create new entry
        $newEntry = @{
            Id = New-Guid
            ProjectKey = $data.Project
            Hours = [double]$data.Hours
            Description = $data.Description
            Date = $data.Date ?? (Get-Date).ToString("yyyy-MM-dd")
            EnteredAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $script:Data.TimeEntries += $newEntry
        Save-UnifiedData
        
        Publish-Event -EventName "Notification.Show" -Data @{ Text = "Time Entry Saved!"; Type = "Success" }
        Publish-Event -EventName "Navigation.PopScreen"
    }
    
    # Project Creation
    Subscribe-Event -EventName "Data.Create.Project" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        if ($script:Data.Projects.ContainsKey($data.Key)) {
            Publish-Event -EventName "Notification.Show" -Data @{ Text = "Project key already exists"; Type = "Error" }
            return
        }
        
        $script:Data.Projects[$data.Key] = @{
            Name = $data.Name
            Client = $data.Client
            BillingType = $data.BillingType ?? "Billable"
            Rate = [double]($data.Rate ?? 0)
            Budget = [double]($data.Budget ?? 0)
            Id1 = $data.Id1
            Id2 = $data.Id2
            CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        Save-UnifiedData
        Publish-Event -EventName "Notification.Show" -Data @{ Text = "Project Created!"; Type = "Success" }
        Publish-Event -EventName "Navigation.PopScreen"
    }
    
    # Task Creation
    Subscribe-Event -EventName "Data.Create.Task" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        $newTask = @{
            Id = New-Guid
            ProjectKey = $data.ProjectKey
            Description = $data.Description
            Priority = $data.Priority ?? "Medium"
            DueDate = $data.DueDate
            Category = $data.Category
            Completed = $false
            CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $script:Data.Tasks += $newTask
        Save-UnifiedData
        
        Publish-Event -EventName "Notification.Show" -Data @{ Text = "Task Created!"; Type = "Success" }
        Publish-Event -EventName "Navigation.PopScreen"
    }
    
    # Timer Start
    Subscribe-Event -EventName "Data.Timer.Start" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        $timerKey = "$($data.ProjectKey)_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $script:Data.ActiveTimers[$timerKey] = @{
            ProjectKey = $data.ProjectKey
            TaskId = $data.TaskId
            Description = $data.Description
            StartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        Save-UnifiedData
        Publish-Event -EventName "Notification.Show" -Data @{ Text = "Timer Started!"; Type = "Success" }
        Publish-Event -EventName "Data.Timer.Started" -Data @{ TimerKey = $timerKey }
    }
    
    # Timer Stop
    Subscribe-Event -EventName "Data.Timer.Stop" -Handler {
        param($EventData)
        $timerKey = $EventData.Data.TimerKey
        
        if ($script:Data.ActiveTimers.ContainsKey($timerKey)) {
            $timer = $script:Data.ActiveTimers[$timerKey]
            $startTime = [DateTime]::Parse($timer.StartTime)
            $elapsed = (Get-Date) - $startTime
            
            # Create time entry from timer
            $newEntry = @{
                Id = New-Guid
                ProjectKey = $timer.ProjectKey
                Hours = [Math]::Round($elapsed.TotalHours, 2)
                Description = $timer.Description ?? "Timer entry"
                Date = (Get-Date).ToString("yyyy-MM-dd")
                EnteredAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                FromTimer = $true
            }
            
            $script:Data.TimeEntries += $newEntry
            $script:Data.ActiveTimers.Remove($timerKey)
            
            Save-UnifiedData
            Publish-Event -EventName "Notification.Show" -Data @{ Text = "Timer stopped. Time entry created: $($newEntry.Hours)h"; Type = "Success" }
            Publish-Event -EventName "Data.Timer.Stopped" -Data @{ TimerKey = $timerKey; Entry = $newEntry }
        }
    }
    
    # Stop All Timers
    Subscribe-Event -EventName "Data.Timer.StopAll" -Handler {
        $stoppedCount = 0
        $timerKeys = @($script:Data.ActiveTimers.Keys)
        
        foreach ($timerKey in $timerKeys) {
            Publish-Event -EventName "Data.Timer.Stop" -Data @{ TimerKey = $timerKey }
            $stoppedCount++
        }
        
        if ($stoppedCount -gt 0) {
            Publish-Event -EventName "Notification.Show" -Data @{ Text = "Stopped $stoppedCount timer(s)"; Type = "Success" }
        }
    }
    
    # Task Update
    Subscribe-Event -EventName "Data.Update.Task" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        $task = $script:Data.Tasks | Where-Object { $_.Id -eq $data.TaskId } | Select-Object -First 1
        if ($task) {
            # Update properties
            foreach ($prop in $data.Updates.PSObject.Properties) {
                $task.($prop.Name) = $prop.Value
            }
            
            Save-UnifiedData
            Publish-Event -EventName "Notification.Show" -Data @{ Text = "Task Updated!"; Type = "Success" }
        }
    }
    
    # Project Update
    Subscribe-Event -EventName "Data.Update.Project" -Handler {
        param($EventData)
        $data = $EventData.Data
        
        if ($script:Data.Projects.ContainsKey($data.ProjectKey)) {
            $project = $script:Data.Projects[$data.ProjectKey]
            
            # Update properties
            foreach ($prop in $data.Updates.PSObject.Properties) {
                $project[$prop.Name] = $prop.Value
            }
            
            Save-UnifiedData
            Publish-Event -EventName "Notification.Show" -Data @{ Text = "Project Updated!"; Type = "Success" }
        }
    }
}

function Initialize-EmptyData {
    $script:Data = @{
        TimeEntries = @()
        Tasks = @()
        Projects = @{}
        Templates = @{}
        ActiveTimers = @{}
        CommandSnippets = @()
        Settings = @{
            Theme = "Default"
            AutoSave = $true
            BackupRetentionDays = 7
        }
    }
}

function Backup-Data {
    try {
        $backupDir = Join-Path (Split-Path $script:DataFilePath -Parent) "backups"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = Join-Path $backupDir "pmc-data_backup_$timestamp.json"
        
        Copy-Item -Path $script:DataFilePath -Destination $backupPath -Force
        
        # Clean old backups
        $retentionDays = $script:Data.Settings.BackupRetentionDays
        $cutoffDate = (Get-Date).AddDays(-$retentionDays)
        Get-ChildItem -Path $backupDir -Filter "pmc-data_backup_*.json" | 
            Where-Object { $_.CreationTime -lt $cutoffDate } | 
            Remove-Item -Force
            
        Write-Verbose "Backup created: $backupPath"
    }
    catch {
        Write-Warning "Failed to create backup: $_"
    }
}

function global:Get-ProjectOrTemplate {
    param([string]$Key)
    
    if ($script:Data.Projects.ContainsKey($Key)) {
        return $script:Data.Projects[$Key]
    }
    elseif ($script:Data.Templates.ContainsKey($Key)) {
        return $script:Data.Templates[$Key]
    }
    else {
        return $null
    }
}

function global:New-Guid {
    return [System.Guid]::NewGuid().ToString()
}

# Export module members
Export-ModuleMember -Function @(
    'Load-UnifiedData',
    'Save-UnifiedData',
    'Initialize-DataEventHandlers',
    'Get-ProjectOrTemplate',
    'New-Guid'
) -Variable @('Data')