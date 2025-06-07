# Task Cleanup Solution
# Run this to investigate and clean up the 18 tasks issue

function Show-AllTasks {
    Write-Host "=== ALL TASKS IN SYSTEM ===" -ForegroundColor Yellow
    
    if (-not $script:Data.Tasks -or $script:Data.Tasks.Count -eq 0) {
        Write-Host "No tasks found in system." -ForegroundColor Green
        return
    }
    
    Write-Host "Total tasks in system: $($script:Data.Tasks.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($task in $script:Data.Tasks) {
        $status = if ($task.Completed) { "✅ DONE" } else { "⏳ ACTIVE" }
        $priority = if ($task.Priority) { $task.Priority } else { "None" }
        $created = if ($task.CreatedDate) { $task.CreatedDate.Substring(0,10) } else { "Unknown" }
        
        Write-Host "[$($task.Id.Substring(0,6))] $status [$priority] $($task.Description)" -ForegroundColor White
        Write-Host "    Created: $created | Category: $($task.Category)" -ForegroundColor Gray
        
        if ($task.IsCommand -eq $true) {
            Write-Host "    TYPE: Command Snippet" -ForegroundColor Magenta
        }
        Write-Host ""
    }
}

function Clear-AllTasks {
    param([switch]$ConfirmClear)
    
    if (-not $ConfirmClear) {
        Write-Host "This will DELETE ALL TASKS from the system." -ForegroundColor Red
        $confirm = Read-Host "Type 'DELETE ALL TASKS' to confirm"
        if ($confirm -ne "DELETE ALL TASKS") {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    # Backup first
    Backup-Data
    Write-Host "Backup created before clearing tasks." -ForegroundColor Green
    
    # Clear tasks and archived tasks
    $script:Data.Tasks = @()
    $script:Data.ArchivedTasks = @()
    
    # Save the changes
    Save-UnifiedData
    
    Write-Host "ALL TASKS CLEARED. System now has 0 tasks." -ForegroundColor Green
    Write-Host "Backup was created in case you need to restore." -ForegroundColor Yellow
}

function Clear-OnlyTestTasks {
    if (-not $script:Data.Tasks) {
        Write-Host "No tasks to clean." -ForegroundColor Green
        return
    }
    
    $beforeCount = $script:Data.Tasks.Count
    
    # Remove tasks that look like test data
    $script:Data.Tasks = $script:Data.Tasks | Where-Object {
        $_.Description -notlike "*test*" -and
        $_.Description -ne "test_task" -and
        $_.Category -ne "test"
    }
    
    $afterCount = $script:Data.Tasks.Count
    $removed = $beforeCount - $afterCount
    
    if ($removed -gt 0) {
        Save-UnifiedData
        Write-Host "Removed $removed test tasks. $afterCount tasks remain." -ForegroundColor Green
    } else {
        Write-Host "No test tasks found to remove." -ForegroundColor Yellow
    }
}

# Instructions
Write-Host @"
TASK CLEANUP COMMANDS:
======================

1. Show-AllTasks          - See what all 18 tasks are
2. Clear-OnlyTestTasks    - Remove tasks with 'test' in name/category  
3. Clear-AllTasks         - NUCLEAR option: delete everything

Usage:
  . .\TASK_CLEANUP_SOLUTION.ps1
  Show-AllTasks
  
Then decide if you want to:
  Clear-OnlyTestTasks      # Safe option
  Clear-AllTasks           # Nuclear option

"@ -ForegroundColor Cyan
