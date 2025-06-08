# PMC Terminal TUI Upgrade Analysis & Roadmap

## Current State Analysis

### ✅ What's Working
1. **Core TUI Engine** - Non-blocking input, double buffering, screen management
2. **Basic Navigation** - Dashboard, menu system, screen stack
3. **Foundation Components** - Boxes, strings, status line
4. **Data Layer** - Existing data structures are compatible

### ❌ What's Missing
1. **Input Forms** - Only basic implementation, needs validation, dropdowns, date pickers
2. **Data Visualization** - Charts, graphs, sparklines for analytics
3. **Notifications** - Toast messages, alerts, confirmations
4. **Keyboard Shortcuts** - Global hotkeys, command mode
5. **File Browser Integration** - Terminal file browser in TUI mode
6. **Excel Integration** - Viewing/editing Excel files in TUI
7. **Multi-pane Layouts** - Split views, resizable panes
8. **Context Menus** - Right-click or key-activated menus
9. **Help System** - Context-sensitive help overlay
10. **Undo/Redo System** - For data modifications

## Architecture Gaps

### 1. **Event System**
Current: Direct key handling
Needed: Event bus for decoupled components

```powershell
$script:EventBus = @{
    Subscribers = @{}
    
    Subscribe = {
        param($Event, $Handler)
        if (-not $script:EventBus.Subscribers[$Event]) {
            $script:EventBus.Subscribers[$Event] = @()
        }
        $script:EventBus.Subscribers[$Event] += $Handler
    }
    
    Publish = {
        param($Event, $Data)
        foreach ($handler in $script:EventBus.Subscribers[$Event]) {
            & $handler -Data $Data
        }
    }
}
```

### 2. **Component System**
Current: Monolithic screens
Needed: Reusable components

```powershell
# Component base class pattern
$script:Component = @{
    X = 0
    Y = 0
    Width = 10
    Height = 5
    Visible = $true
    Focused = $false
    Parent = $null
    Children = @()
    
    Render = { }
    HandleInput = { }
    OnFocus = { }
    OnBlur = { }
}
```

### 3. **Layout Management**
Current: Manual positioning
Needed: Layout engines (Grid, Stack, Dock)

### 4. **State Management**
Current: Direct manipulation
Needed: Redux-style state with actions

## Migration Roadmap

### Phase 1: Foundation (Week 1-2)
- [x] Non-blocking TUI engine
- [x] Basic screen management
- [ ] Event system implementation
- [ ] Component base classes
- [ ] Layout managers

### Phase 2: Core Features (Week 3-4)
- [ ] Enhanced input forms
  - [ ] Text fields with validation
  - [ ] Dropdown/combo boxes
  - [ ] Date/time pickers
  - [ ] Multi-line text areas
- [ ] Timer management screen
- [ ] Task management with full CRUD
- [ ] Project management interface

### Phase 3: Data Entry & Visualization (Week 5-6)
- [ ] Time entry workflow
  - [ ] Quick entry mode
  - [ ] Timer controls
  - [ ] Batch editing
- [ ] Data visualization
  - [ ] Bar charts for time tracking
  - [ ] Sparklines for trends
  - [ ] Progress indicators
- [ ] Report generation screens

### Phase 4: Advanced Features (Week 7-8)
- [ ] Command palette with fuzzy search
- [ ] File browser integration
- [ ] Excel viewer/editor
- [ ] Multi-pane layouts
- [ ] Context menus

### Phase 5: Polish & Integration (Week 9-10)
- [ ] Help system
- [ ] Keyboard shortcut manager
- [ ] Settings UI
- [ ] Theme editor
- [ ] Performance optimization

## Integration Patterns

### 1. **Gradual Screen Migration**

```powershell
# Wrapper for old functions
function Convert-LegacyFunction {
    param($FunctionName, $ScreenDefinition)
    
    return @{
        Name = $FunctionName
        Init = { }
        Render = {
            # Capture output of legacy function
            $output = & $FunctionName | Out-String
            # Parse and render to buffer
            Render-LegacyOutput $output
        }
        HandleInput = {
            # Bridge to legacy input handling
        }
    }
}
```

### 2. **Data Layer Adapter**

```powershell
# Keep existing data structure, add reactive layer
$script:ReactiveData = @{
    Inner = $script:Data
    Subscribers = @()
    
    Get = {
        param($Path)
        # Get value from path like "Projects.PROJ1.Name"
    }
    
    Set = {
        param($Path, $Value)
        # Set value and notify subscribers
    }
}
```

### 3. **Command Migration**

```powershell
# Map old menu items to new screens
$script:MenuMigration = @{
    "Add-ManualTimeEntry" = {
        Push-Screen -Screen $script:TimeEntryFormScreen
    }
    "Start-Timer" = {
        Push-Screen -Screen $script:TimerStartScreen
    }
    # ... etc
}
```

## Specific Component Implementations Needed

### 1. **DateTime Picker**
```powershell
$script:DateTimePicker = @{
    Value = Get-Date
    Mode = "Date" # Date, Time, DateTime
    
    Render = {
        # Calendar grid for date
        # Hour/minute spinners for time
    }
    
    HandleInput = {
        # Arrow keys navigate
        # +/- adjust values
        # Enter confirms
    }
}
```

### 2. **Dropdown Component**
```powershell
$script:Dropdown = @{
    Items = @()
    SelectedIndex = 0
    IsOpen = $false
    MaxDisplayItems = 5
    
    Render = {
        # Closed: Show selected item with ▼
        # Open: Show scrollable list
    }
}
```

### 3. **Chart Component**
```powershell
$script:BarChart = @{
    Data = @()
    BarChar = "█"
    EmptyChar = "░"
    ShowValues = $true
    
    Render = {
        # Scale data to fit
        # Draw bars with labels
    }
}
```

### 4. **Table Component with Sorting/Filtering**
```powershell
$script:DataTable = @{
    Columns = @()
    Rows = @()
    SortColumn = 0
    SortAscending = $true
    Filter = ""
    SelectedRow = 0
    
    Render = {
        # Header with sort indicators
        # Filtered, sorted rows
        # Selection highlight
    }
}
```

## Performance Considerations

### 1. **Render Optimization**
- Implement dirty region tracking
- Component-level caching
- Viewport culling for large lists

### 2. **Memory Management**
- Weak references for event handlers
- Dispose pattern for screens/components
- Buffer pooling for large operations

### 3. **Async Operations**
- Background data loading
- Progress indicators
- Cancelable operations

## Testing Strategy

### 1. **Unit Tests**
- Component rendering
- Input handling
- State management

### 2. **Integration Tests**
- Screen navigation
- Data flow
- Event handling

### 3. **Performance Tests**
- Render benchmarks
- Memory usage
- Input latency

## Next Immediate Steps

1. **Implement Event System** (2 days)
   - Event bus
   - Component lifecycle events
   - Data change notifications

2. **Create Form Components** (3 days)
   - TextField
   - Dropdown
   - DatePicker
   - Validation framework

3. **Build Timer Screen** (2 days)
   - Live timer display
   - Start/stop controls
   - Project selection

4. **Enhance Task List** (2 days)
   - Inline editing
   - Bulk operations
   - Keyboard shortcuts

5. **Create Report Screens** (3 days)
   - Time charts
   - Project summaries
   - Export functionality

## Success Metrics

- **Performance**: <50ms input latency, 60 FPS rendering
- **Memory**: <50MB for typical session
- **Usability**: All functions accessible via keyboard
- **Compatibility**: Works on PS 5.0+, all terminals
- **Migration**: 100% feature parity with old UI

## Conclusion

The TUI framework is solid but needs significant component development and integration work. The modular architecture allows gradual migration while maintaining the existing functionality. Focus should be on high-use features first (time entry, timers, task management) before moving to advanced features.
