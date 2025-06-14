# Debug Log Screen - View application logs
# Compliant with new programmatic architecture

function global:Get-DebugLogScreen {
    $screen = @{
        Name = "DebugLogScreen"
        
        # State
        State = @{
            Logs = @()
            FilterLevel = "All"
            ScrollOffset = 0
            MaxDisplayLines = 20
            LogFilePath = ""
        }
        
        # Components
        Components = @{}
        
        # Initialize
        Init = {
            param($self)
            
            Write-Log -Level Debug -Message "Debug Log Screen initialized"
            
            # Get log file path
            if (Get-Command Get-LogFilePath -ErrorAction SilentlyContinue) {
                $self.State.LogFilePath = Get-LogFilePath
            } else {
                $self.State.LogFilePath = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\tui-debug.log"
            }
            
            # Refresh logs
            $self.RefreshLogs = {
                param($s)
                
                try {
                    if (Get-Command Get-Logs -ErrorAction SilentlyContinue) {
                        $allLogs = Get-Logs -Count 500
                        
                        # Filter by level if needed
                        if ($s.State.FilterLevel -ne "All") {
                            $s.State.Logs = $allLogs | Where-Object { $_.Level -eq $s.State.FilterLevel }
                        } else {
                            $s.State.Logs = $allLogs
                        }
                    } else {
                        $s.State.Logs = @()
                    }
                } catch {
                    $s.State.Logs = @(@{
                        Timestamp = (Get-Date -Format "HH:mm:ss")
                        Level = "Error"
                        Message = "Failed to retrieve logs: $_"
                    })
                }
            }
            
            # Initial load
            & $self.RefreshLogs -s $self
        }
        
        # Render
        Render = {
            param($self)
            
            # Header
            Write-BufferBox -X 1 -Y 1 -Width ($global:TuiState.BufferWidth - 2) -Height 3 -Title " Debug Log Viewer " -BorderColor (Get-ThemeColor "Info")
            Write-BufferString -X 3 -Y 2 -Text "Filter: $($self.State.FilterLevel) | Logs: $($self.State.Logs.Count) | File: $($self.State.LogFilePath)" -ForegroundColor (Get-ThemeColor "Subtle")
            
            # Log display area
            $logBoxY = 5
            $logBoxHeight = $global:TuiState.BufferHeight - 9
            Write-BufferBox -X 1 -Y $logBoxY -Width ($global:TuiState.BufferWidth - 2) -Height $logBoxHeight -Title " Logs " -BorderColor (Get-ThemeColor "Border")
            
            # Display logs
            $startY = $logBoxY + 1
            $endY = $logBoxY + $logBoxHeight - 2
            $displayableLines = $endY - $startY + 1
            
            if ($self.State.Logs.Count -eq 0) {
                Write-BufferString -X 3 -Y ($startY + 2) -Text "No logs to display" -ForegroundColor (Get-ThemeColor "Subtle")
            } else {
                $startIndex = $self.State.ScrollOffset
                $endIndex = [Math]::Min($startIndex + $displayableLines - 1, $self.State.Logs.Count - 1)
                
                for ($i = $startIndex; $i -le $endIndex; $i++) {
                    $log = $self.State.Logs[$i]
                    $y = $startY + ($i - $startIndex)
                    
                    # Color based on level
                    $color = switch ($log.Level) {
                        "Error" { "Red" }
                        "Warning" { "Yellow" }
                        "Info" { "Cyan" }
                        "Debug" { "Gray" }
                        "Verbose" { "DarkGray" }
                        default { "White" }
                    }
                    
                    # Format log line
                    $logLine = "[$($log.Timestamp)] [$($log.Level.PadRight(7))] $($log.Message)"
                    if ($logLine.Length -gt ($global:TuiState.BufferWidth - 6)) {
                        $logLine = $logLine.Substring(0, $global:TuiState.BufferWidth - 9) + "..."
                    }
                    
                    Write-BufferString -X 3 -Y $y -Text $logLine -ForegroundColor $color
                }
                
                # Scroll indicator
                if ($self.State.Logs.Count -gt $displayableLines) {
                    $scrollPercent = if ($self.State.Logs.Count -gt $displayableLines) {
                        [Math]::Round(($self.State.ScrollOffset / ($self.State.Logs.Count - $displayableLines)) * 100)
                    } else { 0 }
                    $scrollText = "[$scrollPercent%]"
                    Write-BufferString -X ($global:TuiState.BufferWidth - $scrollText.Length - 3) -Y $logBoxY -Text $scrollText -ForegroundColor (Get-ThemeColor "Accent")
                }
            }
            
            # Help bar
            $helpY = $global:TuiState.BufferHeight - 2
            Write-BufferString -X 2 -Y $helpY -Text "↑/↓: Scroll | PgUp/PgDn: Page | F: Filter | R: Refresh | C: Clear | O: Open File | Esc: Back" -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        # Handle Input
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::Escape) { 
                    Pop-Screen
                    return $true 
                }
                
                ([ConsoleKey]::UpArrow) {
                    if ($self.State.ScrollOffset -gt 0) {
                        $self.State.ScrollOffset--
                        Request-TuiRefresh
                    }
                    return $true
                }
                
                ([ConsoleKey]::DownArrow) {
                    $maxScroll = [Math]::Max(0, $self.State.Logs.Count - ($global:TuiState.BufferHeight - 9))
                    if ($self.State.ScrollOffset -lt $maxScroll) {
                        $self.State.ScrollOffset++
                        Request-TuiRefresh
                    }
                    return $true
                }
                
                ([ConsoleKey]::PageUp) {
                    $pageSize = $global:TuiState.BufferHeight - 10
                    $self.State.ScrollOffset = [Math]::Max(0, $self.State.ScrollOffset - $pageSize)
                    Request-TuiRefresh
                    return $true
                }
                
                ([ConsoleKey]::PageDown) {
                    $pageSize = $global:TuiState.BufferHeight - 10
                    $maxScroll = [Math]::Max(0, $self.State.Logs.Count - ($global:TuiState.BufferHeight - 9))
                    $self.State.ScrollOffset = [Math]::Min($maxScroll, $self.State.ScrollOffset + $pageSize)
                    Request-TuiRefresh
                    return $true
                }
                
                ([ConsoleKey]::R) {
                    # Refresh logs
                    & $self.RefreshLogs -s $self
                    $self.State.ScrollOffset = 0
                    Request-TuiRefresh
                    return $true
                }
                
                ([ConsoleKey]::F) {
                    # Cycle filter
                    $filters = @("All", "Error", "Warning", "Info", "Debug", "Verbose")
                    $currentIndex = [array]::IndexOf($filters, $self.State.FilterLevel)
                    $self.State.FilterLevel = $filters[($currentIndex + 1) % $filters.Count]
                    & $self.RefreshLogs -s $self
                    $self.State.ScrollOffset = 0
                    Request-TuiRefresh
                    return $true
                }
                
                ([ConsoleKey]::C) {
                    # Clear logs
                    if (Get-Command Clear-Logs -ErrorAction SilentlyContinue) {
                        Clear-Logs
                        & $self.RefreshLogs -s $self
                        $self.State.ScrollOffset = 0
                        Request-TuiRefresh
                    }
                    return $true
                }
                
                ([ConsoleKey]::O) {
                    # Open log file in default editor
                    if (Test-Path $self.State.LogFilePath) {
                        Start-Process $self.State.LogFilePath
                    }
                    return $true
                }
            }
            
            return $false
        }
    }
    
    return $screen
}

Export-ModuleMember -Function Get-DebugLogScreen