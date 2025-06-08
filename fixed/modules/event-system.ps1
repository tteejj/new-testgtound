# Event System Implementation for PMC Terminal TUI
# Provides decoupled communication between components

#region Event Bus Core

$script:EventSystem = @{
    Bus = @{
        Subscribers = @{}
        History = [System.Collections.Generic.Queue[object]]::new()
        MaxHistorySize = 100
    }
    
    # Common event names
    Events = @{
        # Screen events
        ScreenPushed = "Screen.Pushed"
        ScreenPopped = "Screen.Popped"
        ScreenInitialized = "Screen.Initialized"
        
        # Data events
        DataChanged = "Data.Changed"
        DataLoaded = "Data.Loaded"
        DataSaved = "Data.Saved"
        TimerTick = "Timer.Tick"
        TimerStarted = "Timer.Started"
        TimerStopped = "Timer.Stopped"
        TaskCreated = "Task.Created"
        TaskUpdated = "Task.Updated"
        TaskDeleted = "Task.Deleted"
        TimeEntryCreated = "TimeEntry.Created"
        TimeEntryUpdated = "TimeEntry.Updated"
        
        # UI events
        ThemeChanged = "UI.ThemeChanged"
        ComponentFocused = "UI.ComponentFocused"
        ComponentBlurred = "UI.ComponentBlurred"
        
        # System events
        EngineInitialized = "System.EngineInitialized"
        EngineShutdown = "System.EngineShutdown"
        ErrorOccurred = "System.ErrorOccurred"
        AppExit = "App.Exit"
    }
}

#endregion

#region Event Management Functions

function Subscribe-Event {
    param(
        [string]$EventName,
        [scriptblock]$Handler,
        [string]$SubscriberId = [Guid]::NewGuid().ToString(),
        [int]$Priority = 0,
        [switch]$Once
    )
    
    if (-not $script:EventSystem.Bus.Subscribers.ContainsKey($EventName)) {
        $script:EventSystem.Bus.Subscribers[$EventName] = @{}
    }
    
    $subscription = @{
        Handler = $Handler
        Priority = $Priority
        Once = $Once.IsPresent
        SubscriberId = $SubscriberId
        CreatedAt = [DateTime]::Now
    }
    
    $script:EventSystem.Bus.Subscribers[$EventName][$SubscriberId] = $subscription
    
    # Log subscription
    if (Get-Command Write-TuiLog -ErrorAction SilentlyContinue) {
        Write-TuiLog "Event subscribed: $EventName by $SubscriberId" -Level Debug
    }
    
    return $SubscriberId
}

function Unsubscribe-Event {
    param(
        [string]$EventName,
        [string]$SubscriberId
    )
    
    if ($script:EventSystem.Bus.Subscribers.ContainsKey($EventName)) {
        if ($script:EventSystem.Bus.Subscribers[$EventName].Remove($SubscriberId)) {
            if (Get-Command Write-TuiLog -ErrorAction SilentlyContinue) {
                Write-TuiLog "Event unsubscribed: $EventName by $SubscriberId" -Level Debug
            }
            return $true
        }
    }
    return $false
}

function Publish-Event {
    param(
        [string]$EventName,
        [object]$Data = $null,
        [switch]$Async
    )
    
    # Record event in history
    $eventRecord = @{
        Name = $EventName
        Data = $Data
        Timestamp = [DateTime]::Now
    }
    
    $script:EventSystem.Bus.History.Enqueue($eventRecord)
    
    # Trim history if needed
    while ($script:EventSystem.Bus.History.Count -gt $script:EventSystem.Bus.MaxHistorySize) {
        $script:EventSystem.Bus.History.Dequeue() | Out-Null
    }
    
    # Get subscribers
    if (-not $script:EventSystem.Bus.Subscribers.ContainsKey($EventName)) {
        return
    }
    
    $subscribers = $script:EventSystem.Bus.Subscribers[$EventName].Values | 
        Sort-Object -Property Priority -Descending
    
    $handlersToRemove = @()
    
    foreach ($sub in $subscribers) {
        try {
            if ($Async) {
                # Run async in background runspace
                $runspace = [runspacefactory]::CreateRunspace()
                $runspace.Open()
                $ps = [powershell]::Create()
                $ps.Runspace = $runspace
                $ps.AddScript($sub.Handler).AddArgument(@{
                    EventName = $EventName
                    Data = $Data
                    Timestamp = $eventRecord.Timestamp
                })
                $ps.BeginInvoke() | Out-Null
            } else {
                # Run synchronously
                & $sub.Handler @{
                    EventName = $EventName
                    Data = $Data
                    Timestamp = $eventRecord.Timestamp
                }
            }
            
            # Remove if one-time subscription
            if ($sub.Once) {
                $handlersToRemove += $sub.SubscriberId
            }
        }
        catch {
            if (Get-Command Write-TuiLog -ErrorAction SilentlyContinue) {
                Write-TuiLog "Event handler error for '$EventName': $_" -Level Error
            }
        }
    }
    
    # Remove one-time handlers
    foreach ($id in $handlersToRemove) {
        Unsubscribe-Event -EventName $EventName -SubscriberId $id
    }
}

function Clear-EventSubscriptions {
    param(
        [string]$EventName = $null
    )
    
    if ($EventName) {
        if ($script:EventSystem.Bus.Subscribers.ContainsKey($EventName)) {
            $script:EventSystem.Bus.Subscribers[$EventName].Clear()
        }
    } else {
        $script:EventSystem.Bus.Subscribers.Clear()
    }
}

function Get-EventHistory {
    param(
        [string]$EventName = $null,
        [int]$Count = 10
    )
    
    $history = $script:EventSystem.Bus.History.ToArray()
    
    if ($EventName) {
        $history = $history | Where-Object { $_.Name -eq $EventName }
    }
    
    return $history | Select-Object -Last $Count
}

#endregion

#region Event Helpers

function Wait-Event {
    param(
        [string]$EventName,
        [int]$TimeoutMs = 5000
    )
    
    $received = $false
    $result = $null
    
    $handlerId = Subscribe-Event -EventName $EventName -Once -Handler {
        param($EventData)
        $received = $true
        $result = $EventData
    }
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    while (-not $received -and $stopwatch.ElapsedMilliseconds -lt $TimeoutMs) {
        Start-Sleep -Milliseconds 10
    }
    
    $stopwatch.Stop()
    
    if (-not $received) {
        Unsubscribe-Event -EventName $EventName -SubscriberId $handlerId
    }
    
    return $result
}

function Create-EventEmitter {
    param(
        [string]$ComponentName
    )
    
    return @{
        ComponentName = $ComponentName
        
        Emit = {
            param(
                [string]$EventName,
                [object]$Data = $null
            )
            
            $fullEventName = "$($this.ComponentName).$EventName"
            Publish-Event -EventName $fullEventName -Data $Data
        }
        
        On = {
            param(
                [string]$EventName,
                [scriptblock]$Handler
            )
            
            $fullEventName = "$($this.ComponentName).$EventName"
            return Subscribe-Event -EventName $fullEventName -Handler $Handler
        }
        
        Off = {
            param(
                [string]$EventName,
                [string]$SubscriberId
            )
            
            $fullEventName = "$($this.ComponentName).$EventName"
            return Unsubscribe-Event -EventName $fullEventName -SubscriberId $SubscriberId
        }
    }
}

#endregion

#region Data Binding with Events

function Create-ObservableProperty {
    param(
        [string]$Name,
        [object]$InitialValue = $null,
        [scriptblock]$Validator = $null
    )
    
    $property = @{
        Name = $Name
        Value = $InitialValue
        Validator = $Validator
        Subscribers = @()
    }
    
    $property.Get = {
        return $this.Value
    }
    
    $property.Set = {
        param($NewValue)
        
        # Validate if validator provided
        if ($this.Validator) {
            $isValid = & $this.Validator -Value $NewValue
            if (-not $isValid) {
                throw "Validation failed for property '$($this.Name)'"
            }
        }
        
        $oldValue = $this.Value
        $this.Value = $NewValue
        
        # Notify subscribers
        Publish-Event -EventName "Property.$($this.Name).Changed" -Data @{
            Property = $this.Name
            OldValue = $oldValue
            NewValue = $NewValue
        }
    }
    
    $property.Subscribe = {
        param([scriptblock]$Handler)
        
        return Subscribe-Event -EventName "Property.$($this.Name).Changed" -Handler $Handler
    }
    
    return $property
}

#endregion

#region State Management with Events

$script:StateManager = @{
    States = @{}
    CurrentState = $null
    History = [System.Collections.Stack]::new()
}

function Register-State {
    param(
        [string]$Name,
        [hashtable]$State
    )
    
    $script:StateManager.States[$Name] = $State
}

function Set-State {
    param(
        [string]$Name,
        [hashtable]$Updates = @{}
    )
    
    if (-not $script:StateManager.States.ContainsKey($Name)) {
        throw "State '$Name' not registered"
    }
    
    $state = $script:StateManager.States[$Name]
    $oldState = $state.Clone()
    
    # Apply updates
    foreach ($key in $Updates.Keys) {
        $state[$key] = $Updates[$key]
    }
    
    # Save to history
    $script:StateManager.History.Push(@{
        Name = $Name
        State = $oldState
        Timestamp = [DateTime]::Now
    })
    
    # Publish state change event
    Publish-Event -EventName "State.$Name.Changed" -Data @{
        StateName = $Name
        OldState = $oldState
        NewState = $state
        Changes = $Updates
    }
}

function Get-State {
    param(
        [string]$Name
    )
    
    if ($script:StateManager.States.ContainsKey($Name)) {
        return $script:StateManager.States[$Name]
    }
    return $null
}

function Undo-State {
    param(
        [string]$Name
    )
    
    if ($script:StateManager.History.Count -eq 0) {
        return $false
    }
    
    $previous = $script:StateManager.History.Pop()
    if ($previous.Name -eq $Name) {
        $script:StateManager.States[$Name] = $previous.State
        
        Publish-Event -EventName "State.$Name.Restored" -Data @{
            StateName = $Name
            RestoredState = $previous.State
            Timestamp = $previous.Timestamp
        }
        
        return $true
    }
    
    # Put it back if wrong state
    $script:StateManager.History.Push($previous)
    return $false
}

#endregion

#region Integration with TUI Engine

function Initialize-EventSystem {
    if (Get-Command Write-TuiLog -ErrorAction SilentlyContinue) {
        Write-TuiLog "Initializing Event System" -Level Info
    }
    
    # Subscribe to TUI engine events
    Subscribe-Event -EventName "EngineInitialized" -Handler {
        param($EventData)
        if (Get-Command Write-TuiLog -ErrorAction SilentlyContinue) {
            Write-TuiLog "Event System connected to TUI Engine" -Level Info
        }
    }
    
    # Subscribe to error events for centralized handling
    Subscribe-Event -EventName "ErrorOccurred" -Priority 100 -Handler {
        param($EventData)
        if (Get-Command Write-TuiLog -ErrorAction SilentlyContinue) {
            Write-TuiLog "Error Event: $($EventData.Data.Message)" -Level Error
        }
        
        # Could show error dialog or status message
        if (Get-Command Write-StatusLine -ErrorAction SilentlyContinue) {
            Write-StatusLine -Text " Error: $($EventData.Data.Message)" -BackgroundColor Red
        }
    }
    
    # Data change notifications
    Subscribe-Event -EventName "DataChanged" -Handler {
        param($EventData)
        
        # Mark affected regions as dirty for re-render
        if ($EventData.Data.AffectedRegions -and (Get-Command Add-DirtyRegion -ErrorAction SilentlyContinue)) {
            foreach ($region in $EventData.Data.AffectedRegions) {
                Add-DirtyRegion @region
            }
        }
    }
}

#endregion
