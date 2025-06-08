# Migration Guide: Upgrading to Rock-Solid TUI Engine v2

## Overview

This guide helps you migrate from the original TUI engine to the new rock-solid v2 engine with enhanced error handling, event system, and form components.

## What's New

### 1. **Rock-Solid TUI Engine v2**
- Comprehensive error handling and recovery
- Resource cleanup and disposal
- Event system integration
- Theme support
- Component base classes
- Layout managers
- Performance optimizations

### 2. **Event System**
- Decoupled component communication
- Publish/subscribe pattern
- Event history tracking
- Async event support

### 3. **Form Components**
- Reusable input components
- Built-in validation
- Consistent styling
- Keyboard navigation

### 4. **Enhanced Screens**
- Timer management with live updates
- Task management with CRUD operations
- Advanced filtering and sorting
- Multiple view modes

## Migration Steps

### Step 1: Update Module Imports

**Old:**
```powershell
. "$script:ModuleRoot\tui-engine.ps1"
. "$script:ModuleRoot\enhanced-components.ps1"
```

**New:**
```powershell
. "$script:ModuleRoot\tui-engine-v2.ps1"
. "$script:ModuleRoot\event-system.ps1"
. "$script:ModuleRoot\form-components.ps1"
. "$script:ModuleRoot\timer-management.ps1"
. "$script:ModuleRoot\task-management.ps1"
```

### Step 2: Update Screen Definitions

**Old Screen Pattern:**
```powershell
$script:MyScreen = @{
    Name = "MyScreen"
    State = @{ }
    
    Init = { }
    
    Render = {
        # Direct rendering
        Write-BufferString -X 10 -Y 10 -Text "Hello"
    }
    
    HandleInput = {
        param($Key)
        # Basic input handling
    }
}
```

**New Screen Pattern:**
```powershell
$script:MyScreen = @{
    Name = "MyScreen"
    State = @{ }
    
    Init = {
        # Subscribe to events
        Subscribe-Event -EventName "Data.Changed" -Handler {
            param($EventData)
            # React to changes
        }
    }
    
    OnExit = {
        # Cleanup subscriptions
        Clear-EventSubscriptions -EventName "Data.Changed"
    }
    
    OnResume = {
        # Called when returning to screen
    }
    
    Render = {
        # Use theme colors
        Write-BufferString -X 10 -Y 10 -Text "Hello" `
            -ForegroundColor (Get-ThemeColor "Primary")
    }
    
    HandleInput = {
        param($Key)
        # Return navigation commands
        if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
    }
}
```

### Step 3: Replace Manual Forms with Form Components

**Old Manual Form:**
```powershell
# In Render
Write-BufferString -X 10 -Y 10 -Text "Name: "
Write-BufferBox -X 16 -Y 9 -Width 30 -Height 3
Write-BufferString -X 18 -Y 10 -Text $State.NameValue

# In HandleInput
if ($State.EditingName) {
    # Manual character handling
    switch ($Key.Key) {
        ([ConsoleKey]::Backspace) { 
            # Manual backspace logic
        }
        # ... etc
    }
}
```

**New Form Component:**
```powershell
# In Init
$nameField = New-TextField -Props @{
    Label = "Name"
    IsRequired = $true
    Validators = @($script:Validators.Required)
}

$form = New-Form -Title "User Form" -Fields @($nameField) -OnSubmit {
    param($Form, $Data)
    # Handle form submission
    Write-StatusLine -Text " Saved!" -BackgroundColor (Get-ThemeColor "Success")
}

# In Render
& $form.Render -self $form -X 10 -Y 5 -Width 60 -Height 20

# In HandleInput
$result = & $form.HandleInput -self $form -key $Key
if ($result -eq "Cancel") { return "Back" }
```

### Step 4: Use Event System for Data Updates

**Old Direct Update:**
```powershell
# Direct manipulation
$script:Data.Tasks += $newTask
Save-UnifiedData

# Manual screen refresh
Refresh-TaskList
```

**New Event-Based Update:**
```powershell
# Create task and publish event
$task = @{
    Id = "TSK-" + (Get-Random -Maximum 999999).ToString("D6")
    Description = "New Task"
    # ... other properties
}

$script:Data.Tasks += $task
Save-UnifiedData

# Publish event - subscribers will react
Publish-Event -EventName "Task.Created" -Data @{
    Task = $task
}
```

### Step 5: Error Handling

**Old No Error Handling:**
```powershell
function Render-Something {
    # Risky operation
    $data = Get-SomeData
    Write-BufferString -X 10 -Y 10 -Text $data.Value
}
```

**New With Error Recovery:**
```powershell
function Render-Something {
    try {
        # Risky operation
        $data = Get-SomeData
        if ($data -and $data.Value) {
            Write-BufferString -X 10 -Y 10 -Text $data.Value
        }
    }
    catch {
        Write-TuiLog "Error rendering: $_" -Level Error
        Write-BufferString -X 10 -Y 10 -Text "Error loading data" `
            -ForegroundColor (Get-ThemeColor "Error")
    }
}
```

### Step 6: Update Main Entry Point

**Old:**
```powershell
function Start-PMCTerminalTUI {
    Initialize-TuiEngine
    Push-Screen -Screen $script:MainDashboardScreen
    Start-TuiLoop -InitialScreen $script:MainDashboardScreen
}
```

**New:**
```powershell
function Start-PMCTerminalTUI {
    try {
        # Initialize systems
        Initialize-TuiEngine
        Initialize-EventSystem
        
        # Start enhanced loop
        Start-TuiLoop -InitialScreen $script:MainDashboardScreen
    }
    catch {
        Write-Error "TUI Error: $_"
        Write-Error $_.ScriptStackTrace
        
        # Show error report if available
        $errorReport = Get-TuiErrorReport
        if ($errorReport) {
            Write-Host "`nError Report:`n$errorReport" -ForegroundColor Red
        }
    }
}
```

## Component Migration Examples

### TextField Migration

**Old Custom Input:**
```powershell
$State.EditBuffer = ""
$State.CursorPos = 0

# Manual rendering
Write-BufferString -X $x -Y $y -Text ($State.EditBuffer + "_")

# Manual input handling
if ($Key.KeyChar) {
    $State.EditBuffer += $Key.KeyChar
}
```

**New TextField:**
```powershell
$textField = New-TextField -Props @{
    Label = "Enter Text"
    Value = ""
    OnChange = {
        param($Component, $OldValue, $NewValue)
        # React to changes
    }
}

# Automatic rendering and input handling
& $textField.Render -self $textField
$result = & $textField.HandleInput -self $textField -key $Key
```

### Dropdown Migration

**Old Manual Dropdown:**
```powershell
# Complex manual implementation
# with custom rendering and selection logic
```

**New Dropdown:**
```powershell
$dropdown = New-Dropdown -Props @{
    Label = "Select Option"
    Options = @(
        @{ Value = "1"; Display = "Option 1" }
        @{ Value = "2"; Display = "Option 2" }
    )
    AllowSearch = $true
}
```

## Best Practices

### 1. **Always Clean Up Resources**
```powershell
$script:MyScreen = @{
    Name = "MyScreen"
    
    Init = {
        $script:MyTimer = Subscribe-Event -EventName "Timer.Tick" -Handler { }
    }
    
    OnExit = {
        Unsubscribe-Event -EventName "Timer.Tick" -SubscriberId $script:MyTimer
    }
}
```

### 2. **Use Theme Colors**
```powershell
# Don't hardcode colors
Write-BufferString -X 10 -Y 10 -Text "Error!" -ForegroundColor Red  # ❌

# Use theme system
Write-BufferString -X 10 -Y 10 -Text "Error!" `
    -ForegroundColor (Get-ThemeColor "Error")  # ✅
```

### 3. **Handle Errors Gracefully**
```powershell
try {
    $data = Get-RiskyData
    Render-Data $data
}
catch {
    Write-TuiLog "Failed to get data: $_" -Level Error
    Render-ErrorMessage "Unable to load data"
}
```

### 4. **Use Events for Cross-Component Communication**
```powershell
# Don't directly call other components
$script:OtherComponent.Refresh()  # ❌

# Publish events instead
Publish-Event -EventName "DataChanged" -Data @{ Type = "Refresh" }  # ✅
```

### 5. **Leverage Form Validation**
```powershell
$emailField = New-TextField -Props @{
    Label = "Email"
    Validators = @(
        $script:Validators.Required,
        $script:Validators.Email
    )
}
```

## Testing Your Migration

1. **Test Error Recovery**
   - Simulate errors and ensure graceful handling
   - Check resource cleanup on unexpected exit

2. **Test Performance**
   - Monitor CPU usage during idle
   - Check memory usage over time
   - Verify smooth rendering at 60 FPS

3. **Test Navigation**
   - Ensure all screens load properly
   - Verify back navigation works
   - Check state preservation

4. **Test Data Updates**
   - Verify events propagate correctly
   - Check data persistence
   - Ensure UI updates reflect data changes

## Troubleshooting

### Common Issues

1. **Screen doesn't update**
   - Check event subscriptions
   - Verify Render method is called
   - Look for errors in TUI log

2. **Input lag**
   - Check for blocking operations in render
   - Verify input queue isn't full
   - Look for infinite loops

3. **Memory leaks**
   - Ensure event unsubscription
   - Check for circular references
   - Verify resource disposal

### Debug Tools

```powershell
# Show debug screen
Push-Screen -Screen (Get-DebugScreen)

# Get error report
$errors = Get-TuiErrorReport
Write-Host $errors

# Check TUI state
$script:TuiState | ConvertTo-Json -Depth 3
```

## Conclusion

The new TUI engine provides a solid foundation for building robust terminal applications. By following this migration guide and best practices, you'll have a more maintainable and reliable application.

For questions or issues, check the error logs and use the debug tools to diagnose problems.
