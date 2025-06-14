# modules/logger.psm1 - File-based Logger

$script:LogFile = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "PMCTerminal\tui-debug.log"
$script:LogEntries = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
$script:MaxLogEntries = 500
$script:LogSessionId = [Guid]::NewGuid().ToString().Split('-')[0]

function global:Initialize-Logger {
    $script:LogEntries.Clear()
    
    # Create directory if needed
    $logDir = Split-Path $script:LogFile -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Start new session in log file
    $sessionHeader = @"
========================================
NEW SESSION: $($script:LogSessionId)
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
PowerShell: $($PSVersionTable.PSVersion)
========================================
"@
    Set-Content -Path $script:LogFile -Value $sessionHeader
    Write-Log -Level Info -Message "Logger initialized. Log file: $($script:LogFile)"
}

function global:Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Info", "Warning", "Error", "Verbose", "Debug")]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [object]$Data = $null
    )

    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $entry = @{
        Timestamp = $timestamp
        Level     = $Level
        Message   = $Message
        Data      = $Data
    }

    # Add to in-memory list
    $script:LogEntries.Insert(0, $entry)
    if ($script:LogEntries.Count -gt $script:MaxLogEntries) {
        $script:LogEntries.RemoveRange($script:MaxLogEntries, $script:LogEntries.Count - $script:MaxLogEntries)
    }

    # Format log line
    $logLine = "[$timestamp] [$($Level.ToUpper().PadRight(7))] $Message"
    
    # Add error details if present
    if ($Data) {
        if ($Data -is [System.Management.Automation.ErrorRecord]) {
            $logLine += "`n    ERROR: $($Data.Exception.Message)"
            $logLine += "`n    SCRIPT: $($Data.InvocationInfo.ScriptName):$($Data.InvocationInfo.ScriptLineNumber)"
            $logLine += "`n    STACK: $($Data.ScriptStackTrace -replace "`n", "`n           ")"
        } else {
            $logLine += "`n    DATA: $($Data | ConvertTo-Json -Compress -Depth 2)"
        }
    }
    
    # Write to file (thread-safe)
    try {
        [System.IO.File]::AppendAllText($script:LogFile, "$logLine`n")
    } catch {
        # Fallback if file is locked
        Start-Sleep -Milliseconds 50
        Add-Content -Path $script:LogFile -Value $logLine
    }
}

function global:Get-Logs {
    param(
        [string]$Level = $null,
        [int]$Count = 50
    )
    
    $logs = $script:LogEntries.ToArray()
    if ($Level) {
        $logs = $logs | Where-Object { $_.Level -eq $Level }
    }
    return $logs | Select-Object -First $Count
}

function global:Export-Logs {
    param([string]$Path)
    
    if (-not $Path) {
        $Path = Join-Path ([Environment]::GetFolderPath("Desktop")) "PMCTerminal_Logs_$(Get-Date -Format 'yyyyMMdd_HHmmss').xml"
    }
    
    $script:LogEntries.ToArray() | Export-Clixml -Path $Path
    Write-Log -Level Info -Message "Logs exported to: $Path"
    return $Path
}

function global:Clear-Logs {
    $script:LogEntries.Clear()
    Write-Log -Level Info -Message "In-memory log entries cleared"
}

function global:Get-LogFilePath {
    return $script:LogFile
}

Export-ModuleMember -Function 'Initialize-Logger', 'Write-Log', 'Get-Logs', 'Export-Logs', 'Clear-Logs', 'Get-LogFilePath'