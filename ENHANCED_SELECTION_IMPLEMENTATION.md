# Implementation Guide for Enhanced Selection System

## Overview
This guide shows how to integrate the enhanced selection system into the existing codebase to replace text-based ID/key entry with arrow key navigation and numbered quick selection.

## Load the Enhanced Selection Module
Add this to main.ps1 after loading other modules:
```powershell
if (Test-Path "$script:ModuleRoot\enhanced-selection.ps1") { . "$script:ModuleRoot\enhanced-selection.ps1" }
```

## Example Function Updates

### 1. Update Show-ProjectDetail
Replace the manual key entry with enhanced selection:

```powershell
function global:Show-ProjectDetail {
    Write-Header "Project Details"
    
    $projectKey = Select-ProjectOrTemplate -Title "Select Project/Template for Details"
    if (-not $projectKey) { 
        Write-Info "Selection cancelled."
        return 
    }
    
    $project = Get-ProjectOrTemplate $projectKey
    if ($project) {
        Clear-Host
        Write-Header "Details for: $($project.Name) (Key: $projectKey)"
        # ... rest of the function remains the same
    }
}
```

### 2. Update Add-ManualTimeEntry
Replace project selection section:

```powershell
# OLD CODE:
# Show-ProjectsAndTemplates -Simple
# $projectKeyInput = Read-Host "`nProject/Template key"

# NEW CODE:
$projectKeyInput = Select-ProjectOrTemplate -Title "Select Project/Template for Time Entry"
if (-not $projectKeyInput) {
    Write-Info "Time entry cancelled."
    return
}
```

### 3. Update Complete-Task
Replace task selection:

```powershell
function global:Complete-Task {
    param([string]$TaskIdInput)
    
    $idToComplete = $TaskIdInput
    if (-not $idToComplete) {
        $idToComplete = Select-Task -Title "Select Task to Complete" -ActiveOnly
        if (-not $idToComplete) {
            Write-Info "Cancelled."
            return
        }
    }
    
    # Rest of function continues with $idToComplete...
}
```

### 4. Update Edit-Project
Replace project selection:

```powershell
function global:Edit-Project {
    $projectKeyToEdit = Select-ProjectOrTemplate `
        -Title "Select Project to Edit" `
        -ProjectsOnly
    
    if (-not $projectKeyToEdit) {
        Write-Info "Edit cancelled."
        return
    }
    
    # Rest of function continues...
}
```

### 5. Update Manage-CommandSnippets Search/Execute
Replace the search results selection:

```powershell
function global:Search-CommandSnippets {
    Write-Header "Search Command Snippets"
    # ... search logic ...
    
    if ($snippets.Count -eq 0) { 
        Write-Host "No snippets found matching your criteria." -ForegroundColor Gray
        return 
    }
    
    # Create selection items
    $items = @()
    foreach ($snippet in $snippets) {
        $items += [PSCustomObject]@{
            Id = $snippet.Id
            DisplayText = "$($snippet.Description) [$($snippet.Category)]"
            Category = $snippet.Category
            Tags = if ($snippet.Tags) { ($snippet.Tags -join ", ") } else { "" }
            Used = $snippet.UseCount
            Hotkey = if ($snippet.Hotkey) { $snippet.Hotkey } else { "-" }
        }
    }
    
    $selectedId = Show-EnhancedSelection `
        -Items $items `
        -Title "Select Command Snippet" `
        -DisplayProperty "DisplayText" `
        -ValueProperty "Id" `
        -ShowDetails `
        -DetailProperties @{
            "Category" = "Category"
            "Tags" = "Tags" 
            "Used" = "Used"
            "Hotkey" = "Hotkey"
        }
    
    if ($selectedId) {
        Execute-CommandSnippet -Id $selectedId
    }
}
```

### 6. Update Menu Systems
Replace Show-Menu with enhanced version:

```powershell
function global:Show-Menu {
    param($MenuConfig)
    
    if ($MenuConfig.Options) {
        $menuItems = $MenuConfig.Options | ForEach-Object {
            @{
                Key = $_.Key
                Label = $_.Label
                Action = $_.Action
            }
        }
        
        return Show-EnhancedMenu `
            -Title $MenuConfig.Header `
            -MenuItems $menuItems `
            -BackLabel "Back to Dashboard"
    }
    # ... handle other cases
}
```

### 7. Add Quick Confirmations
Replace yes/no prompts:

```powershell
# OLD:
# if ((Read-Host "Stop all timers before quitting? (Y/N)").ToUpper() -eq 'Y')

# NEW:
if (Get-EnhancedConfirmation -Message "Stop all timers before quitting?" -Title "Confirm Exit")
```

## Other Poor Input Decisions Found

### 1. **Delete/Archive Confirmations**
- Current: Type 'yes' to confirm
- Better: Use Get-EnhancedConfirmation or require Ctrl+D for destructive actions

### 2. **Date Entry**
- Current: Manual YYYY-MM-DD entry with shortcuts like 'today', '+5'
- Better: Add a date picker function with calendar navigation

### 3. **Multi-line Text Entry** 
- Current: Uses custom Read-MultilineText with complex key handling
- Better: Could be enhanced with better visual feedback and editing capabilities

### 4. **Time Entry Format**
- Current: Requires specific formats like "2.5" or "2:30"
- Better: More flexible parsing, visual feedback for format

### 5. **Priority Selection**
- Current: Type C/H/M/L
- Better: Arrow selection with visual indicators

### 6. **File Browser Navigation**
- Current: Type numbers to navigate
- Better: Arrow keys with preview pane

### 7. **Report Week Navigation**
- Current: Type P/N/T or date
- Better: Calendar widget with arrow navigation

### 8. **Quick Actions**
- Current: Type +command
- Better: Command palette already exists but could be made default

### 9. **Export File Naming**
- Current: Auto-generates to Desktop
- Better: Let user choose location and name with browser

### 10. **Subtask Management**
- Current: Type index numbers
- Better: Visual list with checkboxes and inline editing

## Implementation Priority

1. **High Priority** (Most user-facing):
   - Project/Template selection 
   - Task selection
   - Command snippet selection
   - Main menu navigation

2. **Medium Priority**:
   - Confirmations (delete, archive, etc.)
   - File browser navigation
   - Date selections

3. **Low Priority**:
   - Multi-line text editing
   - Export locations
   - Advanced filtering interfaces

## Testing Considerations

When implementing:
1. Ensure fallback to simple input if terminal doesn't support ReadKey
2. Test with different terminal emulators (Windows Terminal, ConEmu, etc.)
3. Verify performance with large lists (100+ items)
4. Test search/filter functionality
5. Ensure accessibility (screen readers may not work with arrow navigation)

## Migration Strategy

1. Add enhanced-selection.ps1 to the module loading
2. Create wrapper functions that check for capability:
   ```powershell
   function Select-WithFallback {
       param($Items, $Title)
       
       if ($Host.UI.RawUI.KeyAvailable) {
           # Use enhanced selection
           Show-EnhancedSelection -Items $Items -Title $Title
       } else {
           # Fall back to numbered list
           Show-MenuSelection -Title $Title -Options $Items
       }
   }
   ```
3. Gradually replace functions one at a time
4. Keep old input methods as fallback options
5. Add user preference for selection style

## User Documentation

Add to help/documentation:
- Arrow keys: Navigate up/down
- Enter: Select current item
- ESC: Cancel selection
- 1-9, a-z: Quick select by position
- /: Start filtering
- Space: Toggle selection (multi-select)
- Page Up/Down: Navigate pages
- Home/End: Jump to first/last
