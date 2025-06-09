# Placeholder screens for menu items not yet implemented

function Get-ReportsMenuScreen {
    return @{
        Name = "ReportsMenuScreen"
        Render = {
            Write-BufferBox -X 10 -Y 5 -Width 60 -Height 15 `
                -Title " Reports " -BorderColor (Get-ThemeColor "Accent")
            Write-BufferString -X 25 -Y 10 -Text "Reports - Coming Soon!"
            Write-BufferString -X 20 -Y 12 -Text "Press ESC to return to main menu"
        }
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
            return $false
        }
    }
}

function Get-SettingsScreen {
    return @{
        Name = "SettingsScreen"
        Render = {
            Write-BufferBox -X 10 -Y 5 -Width 60 -Height 15 `
                -Title " Settings " -BorderColor (Get-ThemeColor "Accent")
            Write-BufferString -X 25 -Y 10 -Text "Settings - Coming Soon!"
            Write-BufferString -X 20 -Y 12 -Text "Press ESC to return to main menu"
        }
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
            return $false
        }
    }
}

function Get-TimeEntriesListScreen {
    param([string]$Filter = "Today")
    
    return @{
        Name = "TimeEntriesListScreen"
        State = @{ Filter = $Filter }
        Render = {
            param($self)
            Write-BufferBox -X 5 -Y 2 -Width ($script:TuiState.BufferWidth - 10) -Height ($script:TuiState.BufferHeight - 4) `
                -Title " Time Entries - $($self.State.Filter) " -BorderColor (Get-ThemeColor "Accent")
            
            # Get entries based on filter
            $entries = @()
            $today = (Get-Date).Date
            
            switch ($self.State.Filter) {
                "Today" {
                    $entries = @($script:Data.TimeEntries | Where-Object {
                        [DateTime]::Parse($_.Date).Date -eq $today
                    })
                }
                "Week" {
                    $weekStart = $today.AddDays(-[int]$today.DayOfWeek)
                    $entries = @($script:Data.TimeEntries | Where-Object {
                        [DateTime]::Parse($_.Date) -ge $weekStart
                    })
                }
            }
            
            if ($entries.Count -eq 0) {
                Write-BufferString -X 20 -Y 10 -Text "No time entries found for $($self.State.Filter.ToLower())"
            } else {
                $y = 4
                Write-BufferString -X 7 -Y $y -Text "Date        Project              Hours  Description"
                Write-BufferString -X 7 -Y ($y + 1) -Text ("-" * 60)
                
                $y += 2
                foreach ($entry in $entries | Select-Object -First 10) {
                    $project = Get-ProjectOrTemplate $entry.ProjectKey
                    $line = "{0,-12} {1,-20} {2,5}  {3}" -f `
                        $entry.Date, 
                        $project.Name.Substring(0, [Math]::Min(20, $project.Name.Length)),
                        $entry.Hours.ToString("0.0"),
                        $entry.Description.Substring(0, [Math]::Min(30, $entry.Description.Length))
                    
                    Write-BufferString -X 7 -Y $y -Text $line
                    $y++
                }
                
                # Total
                $totalHours = ($entries | Measure-Object -Property Hours -Sum).Sum
                Write-BufferString -X 7 -Y ($y + 1) -Text ("-" * 60)
                Write-BufferString -X 7 -Y ($y + 2) -Text "Total Hours: $($totalHours.ToString('0.0'))"
            }
            
            Write-BufferString -X 7 -Y ($script:TuiState.BufferHeight - 3) -Text "Press ESC to return"
        }
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
            return $false
        }
    }
}

Export-ModuleMember -Function @(
    'Get-ReportsMenuScreen', 'Get-SettingsScreen', 'Get-TimeEntriesListScreen'
)
