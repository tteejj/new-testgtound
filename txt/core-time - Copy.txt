# Core Time Management Module

# Handles time entries, timers, time-based reporting, and time-related settings.

 

#region Time Entry and Timers

 

function global:Add-ManualTimeEntry {

    Write-Header "Manual Time Entry"

  

    Show-ProjectsAndTemplates -Simple

   

    $projectKeyInput = Read-Host "`nProject/Template Key (or Enter to cancel)" # Renamed variable

    if ([string]::IsNullOrWhiteSpace($projectKeyInput)) { Write-Info "Manual time entry cancelled."; return }

    $project = Get-ProjectOrTemplate $projectKeyInput

  

    if (-not $project) { Write-Error "Project or Template '$projectKeyInput' not found."; return }

  

    $dateStr = Read-Host "Date (YYYY-MM-DD, 'today', 'yesterday', or press Enter for today)"

    $entryDate = $null # Renamed variable

    if ([string]::IsNullOrWhiteSpace($dateStr)) {

        $entryDate = (Get-Date).Date

    } else {

        try {

            $entryDate = switch -regex ($dateStr.ToLower()) {

                'today' { [DateTime]::Today }

                'yesterday' { [DateTime]::Today.AddDays(-1) }

                default { [DateTime]::Parse($dateStr) }

            }

        } catch { Write-Error "Invalid date format '$dateStr'."; return }

    }

  

    Write-Host "Enter time as hours (e.g., 2.5) or time range (e.g., 09:00-11:30)"

    $timeInput = Read-Host "Time"

  

    $hours = 0.0

    $startTime = ""

    $endTime = ""

  

    if ($timeInput -match '(\d{1,2}:\d{2})-(\d{1,2}:\d{2})') {

        try {

            $start = [DateTime]::Parse("$($entryDate.ToString("yyyy-MM-dd")) $($Matches[1])")

            $end = [DateTime]::Parse("$($entryDate.ToString("yyyy-MM-dd")) $($Matches[2])")

            if ($end -lt $start) { $end = $end.AddDays(1) } # Handle overnight

            $hours = ($end - $start).TotalHours

            $startTime = $Matches[1]; $endTime = $Matches[2]

            Write-Info "Calculated hours: $([Math]::Round($hours, 2))"

        } catch { Write-Error "Invalid time range format '$timeInput'."; return }

    } else {

        try { $hours = [double]$timeInput }

        catch { Write-Error "Invalid hours format '$timeInput'."; return }

    }

    if ($hours -le 0) { Write-Error "Hours must be greater than zero."; return }

 

    $description = Read-Host "Description (optional)"

  

    $taskId = $null

    if ((Read-Host "`nLink to a task? (Y/N)").ToUpper() -eq 'Y') {

        $projectTasks = $script:Data.Tasks | Where-Object { $_.ProjectKey -eq $projectKeyInput -and (-not $_.Completed) -and ($_.IsCommand -ne $true) } | Sort-Object Description

        if ($projectTasks.Count -gt 0) {

            Write-Host "`nActive tasks for project '$($project.Name)':"

            $projectTasks | ForEach-Object { Write-Host "  [$($_.Id.Substring(0,6))] $($_.Description)" }

            $taskIdInput = Read-Host "`nTask ID (partial ok, or Enter to skip)"

            if(-not [string]::IsNullOrWhiteSpace($taskIdInput)){

                $matchedTask = $script:Data.Tasks | Where-Object { $_.Id -like "$taskIdInput*" -and ($_.IsCommand -ne $true) } | Select-Object -First 1

                if ($matchedTask) {

                    $taskId = $matchedTask.Id

                    $matchedTask.TimeSpent = [Math]::Round($matchedTask.TimeSpent + $hours, 2)

                    Write-Info "Linked to task: $($matchedTask.Description)"

                } else { Write-Warning "Task not found, proceeding without task link." }

            }

        } else { Write-Info "No active tasks for this project to link." }

    }

  

    $entry = @{

        Id = New-TodoId; ProjectKey = $projectKeyInput; TaskId = $taskId; Date = $entryDate.ToString("yyyy-MM-dd");

        Hours = [Math]::Round($hours, 2); Description = $description; StartTime = ""; EndTime = "";

        EnteredAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    }

  

    if ($null -eq $script:Data.TimeEntries) { $script:Data.TimeEntries = @() }

    $script:Data.TimeEntries += $entry

 

    if ($script:Data.Projects.ContainsKey($projectKeyInput)) { Update-ProjectStatistics -ProjectKey $projectKeyInput }

    Save-UnifiedData

  

    Write-Success "Time entry added: $($entry.Hours) hours for $($project.Name) on $($entryDate.ToString('yyyy-MM-dd'))"

    Show-BudgetWarning -ProjectKey $projectKeyInput

}

 

function global:Start-Timer {

    param(

        [string]$ProjectKeyParam, # Renamed to avoid conflict

        [string]$TaskIdParam,     # Renamed to avoid conflict

        [string]$DescriptionParam # Renamed to avoid conflict

    )

  

    $projectKeyForTimer = $ProjectKeyParam # Renamed variable

    $taskIdForTimer = $TaskIdParam       # Renamed variable

    $descriptionForTimer = $DescriptionParam # Renamed variable

 

    if (-not $projectKeyForTimer -and -not $taskIdForTimer) {

        Write-Header "Start Timer"

        $choice = Read-Host "[P] Timer for Project/Template, [T] Timer for Task, or [C]ancel?"

      

        if ($choice.ToUpper() -eq 'T') {

            $activeTasks = $script:Data.Tasks | Where-Object { (-not $_.Completed) -and ($_.IsCommand -ne $true) }

            if ($activeTasks.Count -eq 0) { Write-Warning "No active tasks available."; return }

           

            $groupedTasks = $activeTasks | Group-Object ProjectKey | Sort-Object @{ Expression = { if ([string]::IsNullOrEmpty($_.Name)) { "zzz" } else { (Get-ProjectOrTemplate $_.Name).Name } } } # Renamed variable

            foreach ($group in $groupedTasks) {

                $projectName = if ($group.Name) { (Get-ProjectOrTemplate $group.Name).Name } else { "[No Project]" }

                Write-Host "`n$projectName" -ForegroundColor (Get-ThemeProperty "Palette.AccentFG")

                foreach ($taskItem in $group.Group | Sort-Object @{Expression={@{"Critical"=1;"High"=2;"Medium"=3;"Low"=4}[$_.Priority]}}, Description) {

                    $priorityInfo = Get-PriorityInfo $taskItem.Priority

                    Write-Host "  $(Apply-PSStyle -Text $priorityInfo.Icon -FG $priorityInfo.Color) [$($taskItem.Id.Substring(0,6))] $($taskItem.Description)"

                }

            }

            $taskIdInput = Read-Host "`nTask ID to start timer for (partial ok, or Enter to cancel)"

            if([string]::IsNullOrWhiteSpace($taskIdInput)) { Write-Info "Timer start cancelled."; return}

            $taskForTimer = $script:Data.Tasks | Where-Object { $_.Id -like "$taskIdInput*" -and ($_.IsCommand -ne $true) } | Select-Object -First 1

          

            if (-not $taskForTimer) { Write-Error "Task not found."; return }

            $taskIdForTimer = $taskForTimer.Id

            $projectKeyForTimer = $taskForTimer.ProjectKey

            if (-not $projectKeyForTimer) { Write-Error "Selected task is not linked to a project. Cannot start project-based timer."; return }

        } elseif ($choice.ToUpper() -eq 'P') {

            Show-ProjectsAndTemplates -Simple

            $projectKeyInput = Read-Host "`nProject/Template Key for timer (or Enter to cancel)" # Renamed variable

            if([string]::IsNullOrWhiteSpace($projectKeyInput)) { Write-Info "Timer start cancelled."; return}

            if (-not (Get-ProjectOrTemplate $projectKeyInput)) { Write-Error "Project/Template not found."; return }

            $projectKeyForTimer = $projectKeyInput

        } else { Write-Info "Timer start cancelled."; return }

    }

  

    if (-not $descriptionForTimer) { # Only prompt if not passed as param

        $descriptionForTimer = Read-Host "Timer Description (optional)"

    }

  

    $timerMapKey = if ($taskIdForTimer) { $taskIdForTimer } else { $projectKeyForTimer } # Renamed variable

    if ($script:Data.ActiveTimers.ContainsKey($timerMapKey)) {

        Write-Warning "Timer already running for this item ($timerMapKey)!"

        return

    }

  

    $timer = @{

        StartTime = Get-Date; ProjectKey = $projectKeyForTimer; TaskId = $taskIdForTimer; Description = $descriptionForTimer

    }

  

    $script:Data.ActiveTimers[$timerMapKey] = $timer

    Save-UnifiedData

  

    Write-Success "Timer started!"

    $projectDisplay = Get-ProjectOrTemplate $projectKeyForTimer # Renamed variable

    Write-Host "Project: $($projectDisplay.Name)" -ForegroundColor Gray

    if ($taskIdForTimer) {

        $taskDisplay = $script:Data.Tasks | Where-Object { $_.Id -eq $taskIdForTimer } # Renamed variable

        Write-Host "Task: $($taskDisplay.Description)" -ForegroundColor Gray

    }

    Write-Host "Started at: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray

    if($descriptionForTimer) {Write-Host "Note: $descriptionForTimer" -ForegroundColor Gray}

}

 

function global:Stop-Timer {

    param([string]$TimerKeyInput) # Renamed parameter

  

    if ($script:Data.ActiveTimers.Count -eq 0) { Write-Warning "No active timers."; return }

  

    $keyToStop = $TimerKeyInput # Renamed variable

    if (-not $keyToStop) {

        Show-ActiveTimers

        $keyToStop = Read-Host "`nStop timer (ID/Key, or 'all' to stop all, Enter to cancel)"

        if ([string]::IsNullOrEmpty($keyToStop)) { Write-Info "Stop timer cancelled."; return }

    }

 

    if ($keyToStop.ToLower() -eq 'all') {

        $count = $script:Data.ActiveTimers.Count

        # Iterate over a copy of keys because Stop-SingleTimer modifies the collection

        foreach ($key in @($script:Data.ActiveTimers.Keys)) { Stop-SingleTimer -Key $key -Silent }

        Save-UnifiedData # Save once after all are stopped

        return

    }

  

    $matchedKey = $null

    foreach ($key in $script:Data.ActiveTimers.Keys) {

        if ($key -like "$keyToStop*") { $matchedKey = $key; break }

    }

  

    if (-not $matchedKey) { Write-Error "Timer with key starting '$keyToStop' not found."; return }

  

    Stop-SingleTimer -Key $matchedKey # This will call Save-UnifiedData if not silent

    if ($TimerKeyInput) { Save-UnifiedData } # Ensure save if key was passed as param (non-interactive)

}

 

function global:Stop-SingleTimer {

    param(

        [string]$Key,

        [switch]$Silent

    )

  

    $timer = $script:Data.ActiveTimers[$Key]

    if (-not $timer) {

        if (-not $Silent) {Write-Error "Timer with key '$Key' not found in active timers."}

        return

    }

  

    $endTimeValue = Get-Date # Renamed variable

    $durationHours = ($endTimeValue - [DateTime]$timer.StartTime).TotalHours # Renamed variable

    if ($durationHours -lt (1/60)) { # Less than a minute, maybe ask user?

        if (-not $Silent) {

            Write-Warning "Timer duration is less than 1 minute ($([Math]::Round($durationHours * 3600, 0)) seconds). Still log it? (Y/N)"

            if((Read-Host).ToUpper() -ne 'Y') {

                $script:Data.ActiveTimers.Remove($Key) # Remove without logging

                Save-UnifiedData

                Write-Info "Short timer discarded."

                return

            }

        } else { # If silent and too short, perhaps don't log automatically or log with a note

             # For now, log it. Could add a setting for minimum timer duration.

        }

    }

 

 

    $entry = @{

        Id = New-TodoId; ProjectKey = $timer.ProjectKey; TaskId = $timer.TaskId;

        Date = $endTimeValue.Date.ToString("yyyy-MM-dd"); Hours = [Math]::Round($durationHours, 2);

        StartTime = ([DateTime]$timer.StartTime).ToString("HH:mm"); EndTime = $endTimeValue.ToString("HH:mm");

        Description = $timer.Description; EnteredAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    }

  

    if ($null -eq $script:Data.TimeEntries) { $script:Data.TimeEntries = @() }

    $script:Data.TimeEntries += $entry

  

    if ($timer.TaskId) {

        $task = $script:Data.Tasks | Where-Object { $_.Id -eq $timer.TaskId }

        if ($task) { $task.TimeSpent = [Math]::Round($task.TimeSpent + $durationHours, 2) }

    }

  

    if ($script:Data.Projects.ContainsKey($timer.ProjectKey)) { Update-ProjectStatistics -ProjectKey $timer.ProjectKey }

  

    $script:Data.ActiveTimers.Remove($Key)

    if (-not $Silent) { Save-UnifiedData } # Save if not part of a batch stop

  

    if (-not $Silent) {

        $project = Get-ProjectOrTemplate $timer.ProjectKey

        Write-Success "Timer stopped for: $($project.Name)"

        Write-Host "Duration: $([Math]::Round($durationHours, 2)) hours ($($entry.StartTime) - $($entry.EndTime))"

        Show-BudgetWarning -ProjectKey $timer.ProjectKey

    }

}

 

function global:Show-ActiveTimers {

    Write-Header "Active Timers"

  

    if ($script:Data.ActiveTimers.Count -eq 0) { Write-Host "No active timers." -ForegroundColor Gray; return }

  

    $totalElapsed = [TimeSpan]::Zero

    foreach ($timerEnum in $script:Data.ActiveTimers.GetEnumerator()) {

        $elapsed = (Get-Date) - [DateTime]$timerEnum.Value.StartTime

        $totalElapsed += $elapsed

        $project = Get-ProjectOrTemplate $timerEnum.Value.ProjectKey

      

        Write-Host "`n[$($timerEnum.Key.Substring(0,6))] " -NoNewline -ForegroundColor Yellow

        $displayName = if($project){$project.Name}else{"Unknown Project"}

        $displayClient = if($project){$project.Client}else{"N/A"}

        Write-Host "$displayName ($displayClient)" -NoNewline # Moved project name up

       

        if ($timerEnum.Value.TaskId) {

            $task = $script:Data.Tasks | Where-Object { $_.Id -eq $timerEnum.Value.TaskId }

            if ($task) { Write-Host " - Task: $($task.Description.Substring(0, [Math]::Min($task.Description.Length, 30)))..." } # Show truncated task desc

            else { Write-Host " - Task ID: $($timerEnum.Value.TaskId) (Not Found)"}

        } else { Write-Host } # Newline if no task

      

        Write-Host "  Started: $($timerEnum.Value.StartTime.ToString('HH:mm:ss'))" -ForegroundColor Gray

        Write-Host "  Elapsed: $([Math]::Floor($elapsed.TotalHours)):$($elapsed.ToString('mm\:ss'))" -ForegroundColor Cyan

      

        if ($timerEnum.Value.Description) { Write-Host "  Note: $($timerEnum.Value.Description)" -ForegroundColor Gray }

      

        if ($project -and $project.BillingType -eq "Billable" -and $project.Rate -gt 0) {

            $value = $elapsed.TotalHours * $project.Rate

            Write-Host "  Value: `$$([Math]::Round($value, 2))" -ForegroundColor Green

        }

    }

  

    if ($script:Data.ActiveTimers.Count -gt 1) {

        Write-Host "`nTotal Time (all timers): $([Math]::Floor($totalElapsed.TotalHours)):$($totalElapsed.ToString('mm\:ss'))" -ForegroundColor Cyan

    }

}

 

function global:Quick-TimeEntry {

    param([string]$InputString) # Renamed parameter

   

    if(-not $InputString){

        $InputString = Read-Host "Quick Time Entry (Format: PROJECT_KEY HOURS [DESCRIPTION])"

        if([string]::IsNullOrWhiteSpace($InputString)) { Write-Info "Quick time entry cancelled."; return}

    }

   

    $parts = $InputString -split ' ', 3

    if ($parts.Count -lt 2) { Write-Error "Invalid format. Use: PROJECT_KEY HOURS [DESCRIPTION]"; return }

  

    $projectKey = $parts[0]

    $hours = 0.0; try { $hours = [double]$parts[1] } catch { Write-Error "Invalid hours format: '$($parts[1])'"; return }

    if($hours -le 0) { Write-Error "Hours must be positive."; return}

    $description = if ($parts.Count -eq 3) { $parts[2] } else { "" }

  

    $project = Get-ProjectOrTemplate $projectKey

    if (-not $project) { Write-Error "Unknown project or template: $projectKey"; return }

  

    $entry = @{

        Id = New-TodoId; ProjectKey = $projectKey; TaskId = $null; Date = (Get-Date).Date.ToString("yyyy-MM-dd");

        Hours = [Math]::Round($hours, 2); Description = $description; StartTime = ""; EndTime = "";

        EnteredAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    }

  

    if ($null -eq $script:Data.TimeEntries) { $script:Data.TimeEntries = @() }

    $script:Data.TimeEntries += $entry

 

    if ($script:Data.Projects.ContainsKey($projectKey)) { Update-ProjectStatistics -ProjectKey $projectKey }

    Save-UnifiedData

  

    Write-Success "Quick entry: $hours hours for $($project.Name)"

    Show-BudgetWarning -ProjectKey $projectKey

}

 

function global:Edit-TimeEntry {

    Write-Header "Edit Time Entry"

  

    $entriesToList = $script:Data.TimeEntries | # Renamed variable

        Sort-Object @{Expression = {if ([string]::IsNullOrEmpty($_.Date)) { [DateTime]::MinValue } else { [datetime]$_.Date }}; Descending = $true},

                      @{Expression = {if ([string]::IsNullOrEmpty($_.EnteredAt)) { [DateTime]::MinValue } else { [datetime]$_.EnteredAt }}; Descending = $true} |

        Select-Object -First 20

  

    if ($entriesToList.Count -eq 0) { Write-Warning "No time entries to edit."; return }

 

    Write-Host "Recent entries (select number to edit):"

    for ($i = 0; $i -lt $entriesToList.Count; $i++) {

        $entry = $entriesToList[$i]

        $project = Get-ProjectOrTemplate $entry.ProjectKey

        $projectName = if($project){$project.Name}else{"Unknown"}

        Write-Host "  [$i] $($entry.Date): $($entry.Hours)h - $projectName"

        if ($entry.Description) { Write-Host "      $($entry.Description)" -ForegroundColor Gray }

    }

  

    $indexInput = Read-Host "`nSelect entry number (or Enter to cancel)"

    if([string]::IsNullOrWhiteSpace($indexInput)) { Write-Info "Edit cancelled."; return}

    try {

        $idx = [int]$indexInput

        if ($idx -ge 0 -and $idx -lt $entriesToList.Count) {

            $entryToEditSnapshot = $entriesToList[$idx] # This is a snapshot

            # Find the actual entry in $script:Data.TimeEntries by Id to modify it

            $originalEntry = $script:Data.TimeEntries | Where-Object { $_.Id -eq $entryToEditSnapshot.Id } | Select-Object -First 1

           

            if (-not $originalEntry) { Write-Error "Original entry not found. This should not happen."; return }

 

            Write-Host "`nEditing Entry ID: $($originalEntry.Id.Substring(0,6)) for $($originalEntry.Date)" -ForegroundColor DarkGray

            Write-Host "Leave field empty to keep current value." -ForegroundColor Gray

          

            # Store old hours for stat adjustment

            $oldHours = $originalEntry.Hours

 

            $newHoursStr = Read-Host "Hours (current: $($originalEntry.Hours))"

            if (-not [string]::IsNullOrWhiteSpace($newHoursStr)) {

                try { $originalEntry.Hours = [double]$newHoursStr }

                catch { Write-Warning "Invalid hours format. Hours not changed." }

            }

          

            $newDesc = Read-Host "Description (current: $($originalEntry.Description)) (enter 'clear' to empty)"

            if ($newDesc -ne $null) { # Allow empty string or 'clear'

                $originalEntry.Description = if($newDesc.ToLower() -eq 'clear'){""}else{$newDesc}

            }

          

            $newDateStr = Read-Host "Date (current: $($originalEntry.Date)) (YYYY-MM-DD, today, etc.)"

            if(-not [string]::IsNullOrWhiteSpace($newDateStr)){

                try {

                    $parsedDate = switch -regex ($newDateStr.ToLower()) {

                        'today' { [DateTime]::Today } 'yesterday' { [DateTime]::Today.AddDays(-1) }

                        default { [DateTime]::Parse($newDateStr) }

                    }

                    $originalEntry.Date = $parsedDate.ToString("yyyy-MM-dd")

                } catch { Write-Warning "Invalid date format. Date not changed."}

            }

            # Could add editing for StartTime/EndTime if needed

 

            $originalEntry.LastModified = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

          

            if ($script:Data.Projects.ContainsKey($originalEntry.ProjectKey)) {

                # Update-ProjectStatistics will recalculate total based on all entries

                Update-ProjectStatistics -ProjectKey $originalEntry.ProjectKey

            }

            if($originalEntry.TaskId){

                $task = $script:Data.Tasks | Where-Object {$_.Id -eq $originalEntry.TaskId}

                if($task){

                    # Adjust task time: subtract old, add new

                    $task.TimeSpent = [Math]::Round($task.TimeSpent - $oldHours + $originalEntry.Hours, 2)

                }

            }

          

            Save-UnifiedData

            Write-Success "Entry updated!"

        } else { Write-Error "Invalid selection number." }

    } catch { Write-Error "Invalid selection input: $_" }

}

 

function global:Delete-TimeEntry {

    Write-Header "Delete Time Entry"

  

    $entriesToList = $script:Data.TimeEntries |

        Sort-Object @{Expression = {if ([string]::IsNullOrEmpty($_.Date)) {[DateTime]::MinValue} else {[datetime]$_.Date}}; Descending = $true},

                      @{Expression = {if ([string]::IsNullOrEmpty($_.EnteredAt)) {[DateTime]::MinValue} else {[datetime]$_.EnteredAt}}; Descending = $true} |

        Select-Object -First 20

 

    if ($entriesToList.Count -eq 0) { Write-Warning "No time entries to delete."; return }

  

    Write-Host "Recent entries (select number to delete):"

    for ($i = 0; $i -lt $entriesToList.Count; $i++) {

        $entry = $entriesToList[$i]

        $project = Get-ProjectOrTemplate $entry.ProjectKey

        $projectName = if($project){$project.Name}else{"Unknown"}

        Write-Host "  [$i] $($entry.Date): $($entry.Hours)h - $projectName"

        if ($entry.Description) { Write-Host "      $($entry.Description)" -ForegroundColor Gray }

    }

  

    $indexInput = Read-Host "`nSelect entry number to delete (or Enter to cancel)"

    if([string]::IsNullOrWhiteSpace($indexInput)) { Write-Info "Deletion cancelled."; return}

    try {

        $idx = [int]$indexInput

        if ($idx -ge 0 -and $idx -lt $entriesToList.Count) {

            $entryToDelete = $entriesToList[$idx]

            $projectNameForConfirm = (Get-ProjectOrTemplate $entryToDelete.ProjectKey).Name

            Write-Warning "Delete this entry? ($($entryToDelete.Date): $($entryToDelete.Hours)h for $projectNameForConfirm)"

            if ((Read-Host "Type 'yes' to confirm").ToLower() -eq 'yes') {

                $originalHours = $entryToDelete.Hours

                $originalTaskId = $entryToDelete.TaskId

                $originalProjectKey = $entryToDelete.ProjectKey

 

                $script:Data.TimeEntries = $script:Data.TimeEntries | Where-Object { $_.Id -ne $entryToDelete.Id }

              

                if ($originalTaskId) {

                    $task = $script:Data.Tasks | Where-Object { $_.Id -eq $originalTaskId }

                    if ($task) { $task.TimeSpent = [Math]::Max(0, [Math]::Round($task.TimeSpent - $originalHours, 2)) }

                }

                if ($script:Data.Projects.ContainsKey($originalProjectKey)) { Update-ProjectStatistics -ProjectKey $originalProjectKey }

              

                Save-UnifiedData

                Write-Success "Entry deleted!"

            } else { Write-Info "Deletion cancelled." }

        } else { Write-Error "Invalid selection number." }

    } catch { Write-Error "Invalid selection input: $_" }

}

 

#endregion

 

#region Time Reporting

 

function global:Show-TodayTimeLog {

    Write-Header "Today's Time Log - $((Get-Date).ToString('ddd, MMM dd, yyyy'))"

  

    $todayStr = (Get-Date).ToString("yyyy-MM-dd") # Renamed variable

    $todayEntries = $script:Data.TimeEntries |

        Where-Object { $_.Date -eq $todayStr } |

        Sort-Object @{Expression = {if([string]::IsNullOrWhiteSpace($_.StartTime)){"99:99"}else{$_.StartTime}}}, EnteredAt

   

    if ($todayEntries.Count -eq 0) { Write-Host "No time entries logged for today." -ForegroundColor Gray; return }

  

    $totalHours = 0.0

    foreach ($entry in $todayEntries) {

        $project = Get-ProjectOrTemplate $entry.ProjectKey

        $projectName = if($project){$project.Name}else{"Unknown Project"}

      

        Write-Host "" # Blank line for separation

        $timeDisplay = if ($entry.StartTime -and $entry.EndTime) { "$($entry.StartTime)-$($entry.EndTime)" } else { "[Manual Entry]" }

        Write-Host (Apply-PSStyle -Text $timeDisplay.PadRight(15) -FG Gray) -NoNewline

        Write-Host (Apply-PSStyle -Text "$($entry.Hours)h".PadLeft(6) -FG Cyan) -NoNewline

        Write-Host (Apply-PSStyle -Text " - $projectName" -FG White) -NoNewline

      

        $descOrTask = $entry.Description

        if ($entry.TaskId) {

            $task = $script:Data.Tasks | Where-Object { $_.Id -eq $entry.TaskId }

            if ($task) { $descOrTask = "Task: $($task.Description)" }

            else { $descOrTask = "Task ID: $($entry.TaskId) (not found)"}

        }

        if(-not [string]::IsNullOrWhiteSpace($descOrTask)){ Write-Host (Apply-PSStyle -Text " - $descOrTask" -FG DarkCyan) }

        else { Write-Host } # Just a newline if no further description

      

        $totalHours += $entry.Hours

    }

  

    Write-Host "`n" ("-" * 50) -ForegroundColor DarkGray

    Write-Host "Total Today: $([Math]::Round($totalHours, 2)) hours" -ForegroundColor Green

  

    $targetToday = $script:Data.Settings.HoursPerDay

    if ($targetToday -gt 0) {

        $percent = [Math]::Round(($totalHours / $targetToday) * 100, 0)

        Write-Host "Target: $targetToday hours ($percent% complete)" -ForegroundColor Gray

    } else { Write-Host "Daily target not set." -ForegroundColor Gray }

}

 

function global:Show-WeekReport {

    param([DateTime]$WeekStartDate = $script:Data.CurrentWeek) # Renamed parameter

  

    Write-Header "Week Report: $($WeekStartDate.ToString('yyyy-MM-dd')) to $($WeekStartDate.AddDays(4).ToString('yyyy-MM-dd')) (Tab-Delimited)"

  

    $weekDates = Get-WeekDates $WeekStartDate

    $weekEntries = $script:Data.TimeEntries | Where-Object {

        if ([string]::IsNullOrEmpty($_.Date)) { return $false }

        try {

            $entryDate = [DateTime]::Parse($_.Date).Date

            $entryDate -ge $weekDates[0].Date -and $entryDate -le $weekDates[4].Date

        } catch { $false }

    }

  

    if ($weekEntries.Count -eq 0) { Write-Host "No time entries for this week." -ForegroundColor Gray; return }

 

    $projectHours = @{}

    $dayNames = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")

    $dayDateMap = @{}

    for($i=0; $i -lt $dayNames.Length; $i++){ $dayDateMap[$dayNames[$i]] = $weekDates[$i].Date }

      

    foreach ($entry in $weekEntries) {

        $entryDate = [DateTime]::Parse($entry.Date).Date

        $dayNameForEntry = $dayNames | Where-Object { $dayDateMap[$_] -eq $entryDate } | Select-Object -First 1

        if(-not $dayNameForEntry) { continue } # Should not happen if logic is correct

 

        if (-not $projectHours.ContainsKey($entry.ProjectKey)) {

            $projectHours[$entry.ProjectKey] = @{ Monday = 0.0; Tuesday = 0.0; Wednesday = 0.0; Thursday = 0.0; Friday = 0.0 }

        }

        $projectHours[$entry.ProjectKey][$dayNameForEntry] += $entry.Hours

    }

  

    $outputLines = @("Name`tID1`tID2`t`t`t`tMon`tTue`tWed`tThu`tFri`tTotal`tClient`tDept") # Renamed variable

    $weekTotalHours = 0.0 # Renamed variable

    $billableTotalHours = 0.0 # Renamed variable

  

    foreach ($projEnum in ($projectHours.GetEnumerator() | Sort-Object { (Get-ProjectOrTemplate $_.Key).Name })) {

        $project = Get-ProjectOrTemplate $projEnum.Key

        if (-not $project) { continue }

      

        $formattedId2 = Format-Id2 $project.Id2

        $line = "$($project.Name)`t$($project.Id1)`t$formattedId2`t`t`t`t"

       

        $projectTotalHours = 0.0

        foreach ($day in $dayNames) {

            $hours = $projEnum.Value[$day]

            $line += "$([Math]::Round($hours,2))`t"

            $projectTotalHours += $hours

        }

      

        $weekTotalHours += $projectTotalHours

        if ($project.BillingType -eq "Billable") { $billableTotalHours += $projectTotalHours }

      

        $line += "$([Math]::Round($projectTotalHours,2))`t$($project.Client)`t$($project.Department)"

        $outputLines += $line

    }

  

    Write-Host "`nTab-Delimited Output (for copy/paste):" -ForegroundColor Yellow

    $outputLines | ForEach-Object { Write-Host $_ }

  

    Write-Host "`nWeek Summary:" -ForegroundColor Yellow

    Write-Host "  Total Hours Logged: $([Math]::Round($weekTotalHours, 2))"

    Write-Host "  Billable Hours:     $([Math]::Round($billableTotalHours, 2))"

    Write-Host "  Non-Billable Hours: $([Math]::Round($weekTotalHours - $billableTotalHours, 2))"

  

    if ($billableTotalHours -gt 0) {

        $billableValue = 0.0

        foreach ($projEnum in $projectHours.GetEnumerator()) {

            $project = Get-ProjectOrTemplate $projEnum.Key

            if ($project.BillingType -eq "Billable" -and $project.Rate -gt 0) {

                $currentProjectTotalHours = ($dayNames | ForEach-Object {$projEnum.Value[$_]} | Measure-Object -Sum).Sum

                $billableValue += $currentProjectTotalHours * $project.Rate

            }

        }

        Write-Host "  Estimated Billable Value: `$$([Math]::Round($billableValue, 2))" -ForegroundColor Green

    }

  

    $weekCompletedTasks = $script:Data.Tasks | Where-Object {

        $_.Completed -and (-not [string]::IsNullOrEmpty($_.CompletedDate)) -and

        ([DateTime]::Parse($_.CompletedDate).Date -ge $weekDates[0].Date) -and

        ([DateTime]::Parse($_.CompletedDate).Date -le $weekDates[4].Date)

    }

    if ($weekCompletedTasks.Count -gt 0) { Write-Host "  Tasks Completed This Week: $($weekCompletedTasks.Count)" -ForegroundColor Green }

  

    if ((Read-Host "`nCopy to clipboard? (Y/N)").ToUpper() -eq 'Y') {

        if (Copy-ToClipboard ($outputLines -join "`r`n")) { Write-Success "Report copied to clipboard!"}

    }

}

 

function global:Show-ExtendedReport {

    param([DateTime]$WeekStartDate = $script:Data.CurrentWeek) # Renamed parameter

  

    Write-Header "Extended Week Report: $($WeekStartDate.ToString('MMMM dd, yyyy'))"

  

    $weekDates = Get-WeekDates $WeekStartDate

    $allWeekEntries = $script:Data.TimeEntries | Where-Object { # Renamed variable

        if ([string]::IsNullOrEmpty($_.Date)) { return $false }

        try {

            $entryDate = [DateTime]::Parse($_.Date).Date

            $entryDate -ge $weekDates[0].Date -and $entryDate -le $weekDates[4].Date

        } catch {$false}

    } | Sort-Object @{Expression = {if ([string]::IsNullOrEmpty($_.Date)) {[DateTime]::MinValue} else {[datetime]$_.Date}}}, StartTime

  

    if ($allWeekEntries.Count -eq 0) { Write-Host "No time entries for this week." -ForegroundColor Gray; return }

  

    $entriesByDate = $allWeekEntries | Group-Object Date # Renamed variable

  

    foreach ($dateGroup in $entriesByDate) {

        if ([string]::IsNullOrEmpty($dateGroup.Name)) { continue }

        $currentDate = [DateTime]::Parse($dateGroup.Name) # Renamed variable

        Write-Host "`n$($currentDate.ToString('dddd, MMMM dd'))" -ForegroundColor Yellow

        Write-Host ("-" * ($currentDate.ToString('dddd, MMMM dd').Length)) -ForegroundColor DarkGray

      

        $dayTotalHours = 0.0 # Renamed variable

        foreach ($entry in $dateGroup.Group) {

            $project = Get-ProjectOrTemplate $entry.ProjectKey

            $projectName = if($project){$project.Name}else{"Unknown"}

            $projectClient = if($project){$project.Client}else{"N/A"}

 

            Write-Host "  " -NoNewline

            $timeDisplay = if ($entry.StartTime -and $entry.EndTime) { "$($entry.StartTime)-$($entry.EndTime)".PadRight(12) } else { "[Manual]".PadRight(12) }

            Write-Host (Apply-PSStyle -Text $timeDisplay -FG Gray) -NoNewline

            Write-Host (Apply-PSStyle -Text "$($entry.Hours)h".PadLeft(6) -FG Cyan) -NoNewline

            Write-Host (Apply-PSStyle -Text " - $projectName ($projectClient)" -FG White) -NoNewline

          

            $descOrTask = $entry.Description

            if ($entry.TaskId) {

                $task = $script:Data.Tasks | Where-Object { $_.Id -eq $entry.TaskId }

                if ($task) { $descOrTask = "Task: $($task.Description)" }

                else { $descOrTask = "Task ID: $($entry.TaskId) (not found)"}

            }

            if(-not [string]::IsNullOrWhiteSpace($descOrTask)){ Write-Host (Apply-PSStyle -Text " - $descOrTask" -FG DarkCyan) }

            else { Write-Host }

          

            $dayTotalHours += $entry.Hours

        }

        Write-Host "  " ("-" * 48) -ForegroundColor DarkGray

        Write-Host "  Day Total: $([Math]::Round($dayTotalHours, 2)) hours" -ForegroundColor Green

    }

  

    Write-Host "`n`nWeek Summary by Project:" -ForegroundColor Yellow

    Write-Host ("-" * 50) -ForegroundColor DarkGray

  

    $entriesByProject = $allWeekEntries | Group-Object ProjectKey # Renamed variable

    $grandTotalHours = 0.0; $billableTotalHours = 0.0; $billableTotalValue = 0.0 # Renamed variables

  

    foreach ($projGroup in $entriesByProject | Sort-Object { (Get-ProjectOrTemplate $_.Name).Name }) {

        $project = Get-ProjectOrTemplate $projGroup.Name

        $projTotalHours = ($projGroup.Group | Measure-Object -Property Hours -Sum).Sum

        $projTotalHours = [Math]::Round($projTotalHours, 2)

        $grandTotalHours += $projTotalHours

      

        Write-Host "  $(Apply-PSStyle -Text $project.Name.PadRight(30) -FG White): " -NoNewline

        Write-Host (Apply-PSStyle -Text "$projTotalHours hours".PadRight(15) -FG Cyan) -NoNewline

      

        if ($project.BillingType -eq "Billable" -and $project.Rate -gt 0) {

            $value = $projTotalHours * $project.Rate

            $billableTotalHours += $projTotalHours

            $billableTotalValue += $value

            Write-Host (Apply-PSStyle -Text "(`$$([Math]::Round($value, 2)))" -FG Green)

        } else { Write-Host (Apply-PSStyle -Text "(Non-billable)" -FG Gray) }

      

        $projectTasksWithTime = $projGroup.Group | Where-Object { $_.TaskId } | Group-Object TaskId |

                                Sort-Object { ($script:Data.Tasks | Where-Object {$_.Id -eq $_.Name} | Select -ExpandProperty Description) }

        if ($projectTasksWithTime.Count -gt 0) {

            foreach ($taskGroup in $projectTasksWithTime) {

                $task = $script:Data.Tasks | Where-Object { $_.Id -eq $taskGroup.Name }

                if ($task) {

                    $taskHours = ($taskGroup.Group | Measure-Object -Property Hours -Sum).Sum

                    Write-Host "    → $($task.Description): $([Math]::Round($taskHours, 2))h" -ForegroundColor DarkCyan

                }

            }

        }

    }

  

    Write-Host "`n" ("-" * 50) -ForegroundColor DarkGray

    Write-Host "  Total Hours Logged:  $([Math]::Round($grandTotalHours, 2))" -ForegroundColor White

    Write-Host "  Billable Hours:      $([Math]::Round($billableTotalHours, 2))" -ForegroundColor Cyan

    Write-Host "  Non-Billable Hours:  $([Math]::Round($grandTotalHours - $billableTotalHours, 2))" -ForegroundColor Gray

    Write-Host "  Total Billable Value:$([Math]::Round($billableTotalValue, 2))" -ForegroundColor Green

  

    $targetWeeklyHours = $script:Data.Settings.HoursPerDay * $script:Data.Settings.DaysPerWeek # Renamed variable

    if ($targetWeeklyHours -gt 0) {

        $utilization = ($grandTotalHours / $targetWeeklyHours) * 100

        Write-Host "  Utilization:         $([Math]::Round($utilization, 1))% of $targetWeeklyHours target hours" -ForegroundColor Magenta

    }

  

    $weekTasksActivity = $script:Data.Tasks | Where-Object { # Renamed variable

        ((-not [string]::IsNullOrEmpty($_.CreatedDate)) -and [DateTime]::Parse($_.CreatedDate).Date -ge $weekDates[0].Date -and [DateTime]::Parse($_.CreatedDate).Date -le $weekDates[4].Date) -or

        ((-not [string]::IsNullOrEmpty($_.CompletedDate)) -and [DateTime]::Parse($_.CompletedDate).Date -ge $weekDates[0].Date -and [DateTime]::Parse($_.CompletedDate).Date -le $weekDates[4].Date)

    }

    if ($weekTasksActivity.Count -gt 0) {

        Write-Host "`n  Task Activity This Week:" -ForegroundColor Yellow

        $createdCount = ($weekTasksActivity | Where-Object { (-not [string]::IsNullOrEmpty($_.CreatedDate)) -and [DateTime]::Parse($_.CreatedDate).Date -ge $weekDates[0].Date -and [DateTime]::Parse($_.CreatedDate).Date -le $weekDates[4].Date }).Count

        $completedCount = ($weekTasksActivity | Where-Object { (-not [string]::IsNullOrEmpty($_.CompletedDate)) -and [DateTime]::Parse($_.CompletedDate).Date -ge $weekDates[0].Date -and [DateTime]::Parse($_.CompletedDate).Date -le $weekDates[4].Date }).Count

        Write-Host "    Tasks Created:  $createdCount"

        Write-Host "    Tasks Completed: $completedCount"

    }

}

 

function global:Show-MonthSummary {

    Write-Header "Month Summary"

  

    $monthStartDate = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 # Renamed variable

    $monthEndDate = $monthStartDate.AddMonths(1).AddDays(-1).AddHours(23).AddMinutes(59).AddSeconds(59)

   

    Write-Host "Month: $($monthStartDate.ToString('MMMM yyyy'))" -ForegroundColor Yellow

  

    $monthEntries = $script:Data.TimeEntries | Where-Object {

        if ([string]::IsNullOrEmpty($_.Date)) { return $false }

        try {

            $entryDate = [DateTime]::Parse($_.Date).Date

            $entryDate -ge $monthStartDate.Date -and $entryDate -le $monthEndDate.Date

        } catch {$false}

    }

  

    if ($monthEntries.Count -eq 0) { Write-Host "No time entries for this month." -ForegroundColor Gray; return }

  

    $entriesByProject = $monthEntries | Group-Object ProjectKey # Renamed variable

    Write-Host "`nTime Logged By Project:" -ForegroundColor Yellow

    $monthTotalHours = 0.0 # Renamed variable

  

    foreach ($group in $entriesByProject | Sort-Object { (Get-ProjectOrTemplate $_.Name).Name }) {

        $project = Get-ProjectOrTemplate $group.Name

        $hours = ($group.Group | Measure-Object -Property Hours -Sum).Sum

        $hours = [Math]::Round($hours, 2)

        $monthTotalHours += $hours

        Write-Host "  $($project.Name): $hours hours"

        if ($project.BillingType -eq "Billable" -and $project.Rate -gt 0) {

            $value = $hours * $project.Rate

            Write-Host "    Est. Billable Value: `$$([Math]::Round($value, 2))" -ForegroundColor Green

        }

    }

    Write-Host "`nTotal Hours This Month: $([Math]::Round($monthTotalHours, 2))" -ForegroundColor Green

  

    $monthTasksActivity = $script:Data.Tasks | Where-Object { # Renamed variable

        ((-not [string]::IsNullOrEmpty($_.CreatedDate)) -and [DateTime]::Parse($_.CreatedDate).Date -ge $monthStartDate.Date -and [DateTime]::Parse($_.CreatedDate).Date -le $monthEndDate.Date) -or

        ((-not [string]::IsNullOrEmpty($_.CompletedDate)) -and [DateTime]::Parse($_.CompletedDate).Date -ge $monthStartDate.Date -and [DateTime]::Parse($_.CompletedDate).Date -le $monthEndDate.Date)

    }

    if ($monthTasksActivity.Count -gt 0) {

        Write-Host "`nTask Activity This Month:" -ForegroundColor Yellow

        $createdCount = ($monthTasksActivity | Where-Object { (-not [string]::IsNullOrEmpty($_.CreatedDate)) -and [DateTime]::Parse($_.CreatedDate).Date -ge $monthStartDate.Date -and [DateTime]::Parse($_.CreatedDate).Date -le $monthEndDate.Date }).Count

        $completedCount = ($monthTasksActivity | Where-Object { (-not [string]::IsNullOrEmpty($_.CompletedDate)) -and [DateTime]::Parse($_.CompletedDate).Date -ge $monthStartDate.Date -and [DateTime]::Parse($_.CompletedDate).Date -le $monthEndDate.Date }).Count

        Write-Host "  Tasks Created: $createdCount"

        Write-Host "  Tasks Completed: $completedCount"

    }

}

 

function global:Show-TimeAnalytics {

    Write-Header "Time Analytics"

  

    $monthStartDate = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 # Renamed variable

    $currentMonthEntries = $script:Data.TimeEntries | Where-Object { # Renamed variable

        (-not [string]::IsNullOrEmpty($_.Date)) -and ([DateTime]::Parse($_.Date).Date -ge $monthStartDate.Date)

    }

    $currentMonthHours = ($currentMonthEntries | Measure-Object -Property Hours -Sum).Sum # Renamed variable

    $currentMonthHours = if ($currentMonthHours) { [Math]::Round($currentMonthHours, 2) } else { 0.0 }

    Write-Host "This Month ($($monthStartDate.ToString('MMMM yyyy'))): $currentMonthHours hours" -ForegroundColor Yellow

  

    $thirtyDaysAgo = (Get-Date).AddDays(-30).Date

    $last30DaysEntries = $script:Data.TimeEntries | Where-Object { # Renamed variable

        (-not [string]::IsNullOrEmpty($_.Date)) -and ([DateTime]::Parse($_.Date).Date -ge $thirtyDaysAgo)

    }

    $last30DaysHours = ($last30DaysEntries | Measure-Object -Property Hours -Sum).Sum # Renamed variable

    $last30DaysHours = if ($last30DaysHours) { [Math]::Round($last30DaysHours, 2) } else { 0.0 }

    Write-Host "Last 30 Days: $last30DaysHours hours" -ForegroundColor Yellow

  

    $daysWithEntries = ($last30DaysEntries | Where-Object { -not [string]::IsNullOrEmpty($_.Date) } | Group-Object Date).Count

    if ($daysWithEntries -gt 0) {

        $dailyAvg = [Math]::Round($last30DaysHours / $daysWithEntries, 2)

        Write-Host "Daily Average (logged days): $dailyAvg hours (over $daysWithEntries working days in last 30)" -ForegroundColor Green

    }

  

    Write-Host "`nHours Logged by Day of Week (Last 30 Days):" -ForegroundColor Yellow

    $entriesByDayOfWeek = $last30DaysEntries | Where-Object { -not [string]::IsNullOrEmpty($_.Date) } | Group-Object { [DateTime]::Parse($_.Date).DayOfWeek } | Sort-Object Name # Renamed variable

    foreach ($group in $entriesByDayOfWeek) {

        $hours = [Math]::Round(($group.Group | Measure-Object -Property Hours -Sum).Sum, 2)

        Write-Host "  $([System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.GetDayName($group.Name)): $hours hours"

    }

  

    Write-Host "`nTop 5 Projects (Last 30 Days by Hours):" -ForegroundColor Yellow

    $topProjectsByHours = $last30DaysEntries | Group-Object ProjectKey |  # Renamed variable

        Select-Object @{N="ProjectKey";E={$_.Name}}, @{N="TotalHours";E={($_.Group | Measure-Object Hours -Sum).Sum}} |

        Sort-Object TotalHours -Descending | Select-Object -First 5

    foreach ($projInfo in $topProjectsByHours) { # Renamed variable

        $project = Get-ProjectOrTemplate $projInfo.ProjectKey

        Write-Host "  $($project.Name): $([Math]::Round($projInfo.TotalHours,2)) hours"

    }

}

 

function global:Export-FormattedTimesheet {

    param(

        [DateTime]$WeekStartDate = $script:Data.CurrentWeek, # Renamed parameter

        [string]$OutputFilePath # Renamed parameter

    )

 

    Write-Header "Export Formatted Timesheet for Week Starting $($WeekStartDate.ToString('yyyy-MM-dd'))"

 

    if (-not $OutputFilePath) {

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

        $OutputFilePath = Join-Path ([Environment]::GetFolderPath("Desktop")) "FormattedTimesheet_Export_WeekOf_$($WeekStartDate.ToString('yyyyMMdd'))_$timestamp.csv"

    }

 

    $weekDates = Get-WeekDates $WeekStartDate

    $weekEntries = $script:Data.TimeEntries | Where-Object {

        if ([string]::IsNullOrEmpty($_.Date)) { return $false }

        try {

            $entryDate = [DateTime]::Parse($_.Date).Date

            $entryDate -ge $weekDates[0].Date -and $entryDate -le $weekDates[4].Date

        } catch {$false}

    }

 

    if ($weekEntries.Count -eq 0) { Write-Warning "No time entries for the week. Export cancelled."; return }

 

    $projectHours = @{}

    $dayNames = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")

    $dayDateMap = @{}; for($i=0; $i -lt $dayNames.Length; $i++){ $dayDateMap[$dayNames[$i]] = $weekDates[$i].Date }

 

    foreach ($entry in $weekEntries) {

        $entryDate = [DateTime]::Parse($entry.Date).Date

        $dayNameForEntry = $dayNames | Where-Object { $dayDateMap[$_] -eq $entryDate } | Select-Object -First 1

        if(-not $dayNameForEntry) { continue }

 

        if (-not $projectHours.ContainsKey($entry.ProjectKey)) {

            $project = Get-ProjectOrTemplate $entry.ProjectKey

            $projectHours[$entry.ProjectKey] = @{

                ProjectName = if($project){$project.Name}else{"Unknown"}

                Id1 = if($project){$project.Id1}else{""}

                Id2 = if($project){Format-Id2 $project.Id2}else{Format-Id2 ""}

                Monday = 0.0; Tuesday = 0.0; Wednesday = 0.0; Thursday = 0.0; Friday = 0.0

            }

        }

        $projectHours[$entry.ProjectKey][$dayNameForEntry] += $entry.Hours

    }

 

    $exportData = @()

    foreach ($projKey in ($projectHours.Keys | Sort-Object { $projectHours[$_].ProjectName })) {

        $projData = $projectHours[$projKey]

        $exportData += [PSCustomObject]@{

            ProjectName = $projData.ProjectName

            Id1 = $projData.Id1

            Id2 = $projData.Id2

            Monday = [Math]::Round($projData.Monday, 2)

            Tuesday = [Math]::Round($projData.Tuesday, 2)

            Wednesday = [Math]::Round($projData.Wednesday, 2)

            Thursday = [Math]::Round($projData.Thursday, 2)

            Friday = [Math]::Round($projData.Friday, 2)

            Total = [Math]::Round(($projData.Monday + $projData.Tuesday + $projData.Wednesday + $projData.Thursday + $projData.Friday), 2)

        }

    }

 

    try {

        $exportData | Export-Csv -Path $OutputFilePath -NoTypeInformation -Encoding UTF8

        Write-Success "Formatted timesheet exported to: $OutputFilePath"

        if ((Read-Host "Open file now? (Y/N)").ToUpper() -eq 'Y') {

            try { Start-Process $OutputFilePath } catch { Write-Warning "Could not open file: $_"}

        }

    } catch { Write-Error "Failed to export timesheet: $_" }

}

 

#endregion

 

#region Time Settings and Utilities

 

function global:Edit-TimeTrackingSettings {

    Write-Header "Time Tracking Settings"

    Write-Host "Leave empty to keep current value." -ForegroundColor Gray

  

    $settings = $script:Data.Settings # Alias

   

    $newRateStr = Read-Host "`nDefault hourly rate (current: $($settings.DefaultRate))"

    if (-not [string]::IsNullOrWhiteSpace($newRateStr)) {

        try { $settings.DefaultRate = [double]$newRateStr }

        catch { Write-Warning "Invalid rate format. Not changed." }

    }

  

    $newHoursStr = Read-Host "`nTarget hours per day (current: $($settings.HoursPerDay))"

    if (-not [string]::IsNullOrWhiteSpace($newHoursStr)) {

        try { $settings.HoursPerDay = [double]$newHoursStr } # Allow fractional hours

        catch { Write-Warning "Invalid hours format. Not changed." }

    }

  

    $newDaysStr = Read-Host "`nTarget days per week (current: $($settings.DaysPerWeek))"

    if (-not [string]::IsNullOrWhiteSpace($newDaysStr)) {

        try {

            $days = [int]$newDaysStr

            if($days -ge 1 -and $days -le 7) { $settings.DaysPerWeek = $days }

            else { Write-Warning "Days per week must be between 1 and 7. Not changed."}

        }

        catch { Write-Warning "Invalid days format. Not changed." }

    }

  

    Save-UnifiedData

    Write-Success "Time tracking settings updated!"

}

 

function global:Show-BudgetWarning {

    param([string]$ProjectKey)

  

    if (-not $script:Data.Projects.ContainsKey($ProjectKey)) { return } # Only for actual projects

    $project = Get-ProjectOrTemplate $ProjectKey

   

    if (-not $project -or $project.BillingType -eq "Non-Billable" -or -not $project.Budget -or $project.Budget -le 0) { # Budget must be > 0

        return

    }

  

    Update-ProjectStatistics -ProjectKey $ProjectKey

    $project = $script:Data.Projects[$ProjectKey] # Re-fetch after update for fresh TotalHours

 

    $totalHours = if ($project.TotalHours -is [double] -or $project.TotalHours -is [int]) { $project.TotalHours } else { 0.0 }

    $percentUsed = ($totalHours / $project.Budget) * 100

   

    if ($percentUsed -ge 100) {

        Write-Warning "BUDGET EXCEEDED for $($project.Name): $([Math]::Round($percentUsed, 1))% used. Budget: $($project.Budget)h, Used: $($totalHours)h."

    } elseif ($percentUsed -ge 90) {

        Write-Warning "Budget alert for $($project.Name): $([Math]::Round($percentUsed, 1))% used ($([Math]::Round($project.Budget - $totalHours, 2)) hours remaining)."

    } elseif ($percentUsed -ge 75) {

        Write-Info "Budget notice for $($project.Name): $([Math]::Round($percentUsed, 1))% used."

    }

}

 

#endregion
