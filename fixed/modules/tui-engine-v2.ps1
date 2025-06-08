# Rock-Solid TUI Engine v2.0
# Production-ready with comprehensive error handling and extensibility

#region Core TUI State
$script:TuiState = @{
    Running = $false
    BufferWidth = 0
    BufferHeight = 0
    FrontBuffer = $null
    BackBuffer = $null
    InputQueue = [System.Collections.Concurrent.ConcurrentQueue[System.ConsoleKeyInfo]]::new()
    InputQueueMaxSize = 100
    LastRenderTime = [DateTime]::MinValue
    RenderInterval = 16 # ~60 FPS
    CurrentScreen = $null
    ScreenStack = [System.Collections.Stack]::new()
    FocusedView = $null
    ViewStates = @{}
    DirtyRegions = [System.Collections.Generic.List[object]]::new()
    IsDisposed = $false
    LastActivity = [DateTime]::Now
    EventBus = @{
        Subscribers = @{}
    }
    Themes = @{}
    CurrentTheme = "Default"
    Components = @{}
    Width = 0
    Height = 0
    Initialized = $false
}

# Resource cleanup tracker
$script:ResourceCleanup = @{
    Runspaces = @()
    PowerShells = @()
}

#endregion

#region Event System

function Subscribe-TuiEvent {
    param(
        [string]$EventName,
        [scriptblock]$Handler,
        [string]$HandlerId = [Guid]::NewGuid().ToString()
    )
    
    if (-not $script:TuiState.EventBus.Subscribers.ContainsKey($EventName)) {
        $script:TuiState.EventBus.Subscribers[$EventName] = @{}
    }
    
    $script:TuiState.EventBus.Subscribers[$EventName][$HandlerId] = $Handler
    return $HandlerId
}

function Unsubscribe-TuiEvent {
    param(
        [string]$EventName,
        [string]$HandlerId
    )
    
    if ($script:TuiState.EventBus.Subscribers.ContainsKey($EventName)) {
        $script:TuiState.EventBus.Subscribers[$EventName].Remove($HandlerId)
    }
}

function Publish-TuiEvent {
    param(
        [string]$EventName,
        [object]$Data = $null
    )
    
    if ($script:TuiState.EventBus.Subscribers.ContainsKey($EventName)) {
        foreach ($handler in $script:TuiState.EventBus.Subscribers[$EventName].Values) {
            try {
                & $handler -EventData $Data
            }
            catch {
                Write-TuiLog "Event handler error for '$EventName': $_" -Level Error
            }
        }
    }
}

#endregion

#region Logging and Error Handling

$script:TuiLog = @{
    Entries = [System.Collections.Generic.List[object]]::new()
    MaxEntries = 1000
}

function Write-TuiLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $entry = @{
        Timestamp = [DateTime]::Now
        Level = $Level
        Message = $Message
    }
    
    $script:TuiLog.Entries.Add($entry)
    
    # Trim old entries
    if ($script:TuiLog.Entries.Count -gt $script:TuiLog.MaxEntries) {
        $script:TuiLog.Entries.RemoveRange(0, 100)
    }
}

function Get-TuiErrorReport {
    $errors = $script:TuiLog.Entries | Where-Object { $_.Level -eq "Error" } | Select-Object -Last 50
    return $errors | Format-Table -AutoSize | Out-String
}

#endregion

#region Buffer Management

function New-ConsoleCell {
    param(
        [char]$Character = ' ',
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black
    )
    return @{
        Char = $Character
        FG = $ForegroundColor
        BG = $BackgroundColor
        IsDirty = $false
    }
}

function Initialize-TuiEngine {
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1  # Leave one line for status
    )
    
    try {
        Write-Host "Initializing TUI Engine v2.0: ${Width}x${Height}" -ForegroundColor Cyan
        
        # Validate dimensions
        if ($Width -le 0 -or $Height -le 0) {
            throw "Invalid console dimensions: ${Width}x${Height}"
        }
        
        # Initialize dimensions
        $script:TuiState.BufferWidth = $Width
        $script:TuiState.BufferHeight = $Height
        $script:TuiState.Width = $Width
        $script:TuiState.Height = $Height
        
        try {
            $script:TuiState.FrontBuffer = New-Object 'object[,]' $Height, $Width
            $script:TuiState.BackBuffer = New-Object 'object[,]' $Height, $Width
        }
        catch {
            throw "Failed to allocate buffers: $_"
        }
        
        # Fill buffers with empty cells
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $Width; $x++) {
                $emptyCell = New-ConsoleCell
                $script:TuiState.FrontBuffer[$y, $x] = $emptyCell
                $script:TuiState.BackBuffer[$y, $x] = $emptyCell.Clone()
            }
        }
        
        # Setup console
        [Console]::CursorVisible = $false
        [Console]::Clear()
        
        # Initialize themes
        Initialize-Themes
        
        # Initialize input handler with error recovery
        Initialize-InputHandler
        
        # Mark as initialized
        $script:TuiState.Initialized = $true
        
        # Publish initialization event
        Publish-TuiEvent -EventName "EngineInitialized" -Data @{ Width = $Width; Height = $Height }
        
        Write-TuiLog "TUI Engine initialized successfully" -Level Info
    }
    catch {
        Write-TuiLog "Failed to initialize TUI Engine: $_" -Level Error
        throw
    }
}

function Clear-BackBuffer {
    param(
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black
    )
    
    if (-not $script:TuiState.BackBuffer) {
        Write-TuiLog "BackBuffer is null in Clear-BackBuffer" -Level Error
        return
    }
    
    try {
        for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
            for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
                $script:TuiState.BackBuffer[$y, $x] = New-ConsoleCell -BackgroundColor $BackgroundColor
            }
        }
        
        # Mark entire screen as dirty
        Add-DirtyRegion -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height $script:TuiState.BufferHeight
    }
    catch {
        Write-TuiLog "Error in Clear-BackBuffer: $_" -Level Error
    }
}

function Write-BufferString {
    param(
        [int]$X,
        [int]$Y,
        [string]$Text,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black
    )
    
    # Comprehensive bounds checking
    if ($Y -lt 0 -or $Y -ge $script:TuiState.BufferHeight) { 
        Write-TuiLog "Y coordinate out of bounds: $Y (Height: $($script:TuiState.BufferHeight))" -Level Warning
        return 
    }
    
    if (-not $script:TuiState.BackBuffer) {
        Write-TuiLog "BackBuffer is null in Write-BufferString" -Level Error
        return
    }
    
    if ([string]::IsNullOrEmpty($Text)) {
        return
    }
    
    try {
        $currentX = $X
        $startX = [Math]::Max(0, $X)
        $dirtyStartX = -1
        
        foreach ($char in $Text.ToCharArray()) {
            if ($currentX -ge 0 -and $currentX -lt $script:TuiState.BufferWidth) {
                $script:TuiState.BackBuffer[$Y, $currentX] = New-ConsoleCell `
                    -Character $char `
                    -ForegroundColor $ForegroundColor `
                    -BackgroundColor $BackgroundColor
                
                if ($dirtyStartX -eq -1) { $dirtyStartX = $currentX }
            }
            $currentX++
            if ($currentX -ge $script:TuiState.BufferWidth) { break }
        }
        
        # Mark dirty region
        if ($dirtyStartX -ge 0) {
            $dirtyWidth = [Math]::Min($currentX, $script:TuiState.BufferWidth) - $dirtyStartX
            Add-DirtyRegion -X $dirtyStartX -Y $Y -Width $dirtyWidth -Height 1
        }
    }
    catch {
        Write-TuiLog "Error in Write-BufferString: $_" -Level Error
    }
}

function Write-BufferBox {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [string]$BorderStyle = "Single",
        [ConsoleColor]$BorderColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black,
        [string]$Title = ""
    )
    
    # Validate parameters
    if ($Width -lt 3 -or $Height -lt 3) {
        Write-TuiLog "Box dimensions too small: ${Width}x${Height}" -Level Warning
        return
    }
    
    # Clip to screen bounds
    $clippedX = [Math]::Max(0, $X)
    $clippedY = [Math]::Max(0, $Y)
    $clippedWidth = [Math]::Min($Width, $script:TuiState.BufferWidth - $clippedX)
    $clippedHeight = [Math]::Min($Height, $script:TuiState.BufferHeight - $clippedY)
    
    if ($clippedWidth -lt 3 -or $clippedHeight -lt 3) {
        return
    }
    
    try {
        $borders = Get-BorderChars -Style $BorderStyle
        
        # Top border
        Write-BufferString -X $clippedX -Y $clippedY -Text $borders.TopLeft -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        for ($i = 1; $i -lt ($clippedWidth - 1); $i++) {
            Write-BufferString -X ($clippedX + $i) -Y $clippedY -Text $borders.Horizontal -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        }
        Write-BufferString -X ($clippedX + $clippedWidth - 1) -Y $clippedY -Text $borders.TopRight -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        
        # Title if provided
        if ($Title -and $Title.Length -gt 0) {
            $titleText = " $Title "
            if ($titleText.Length -gt ($clippedWidth - 4)) {
                $titleText = " " + $Title.Substring(0, $clippedWidth - 7) + "... "
            }
            $titleX = $clippedX + [Math]::Max(1, ($clippedWidth - $titleText.Length) / 2)
            Write-BufferString -X $titleX -Y $clippedY -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        }
        
        # Sides
        for ($i = 1; $i -lt ($clippedHeight - 1); $i++) {
            if (($clippedY + $i) -lt $script:TuiState.BufferHeight) {
                Write-BufferString -X $clippedX -Y ($clippedY + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
                Write-BufferString -X ($clippedX + $clippedWidth - 1) -Y ($clippedY + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
                
                # Fill interior
                for ($j = 1; $j -lt ($clippedWidth - 1); $j++) {
                    Write-BufferString -X ($clippedX + $j) -Y ($clippedY + $i) -Text " " -BackgroundColor $BackgroundColor
                }
            }
        }
        
        # Bottom border
        if (($clippedY + $clippedHeight - 1) -lt $script:TuiState.BufferHeight) {
            Write-BufferString -X $clippedX -Y ($clippedY + $clippedHeight - 1) -Text $borders.BottomLeft -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
            for ($i = 1; $i -lt ($clippedWidth - 1); $i++) {
                Write-BufferString -X ($clippedX + $i) -Y ($clippedY + $clippedHeight - 1) -Text $borders.Horizontal -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
            }
            Write-BufferString -X ($clippedX + $clippedWidth - 1) -Y ($clippedY + $clippedHeight - 1) -Text $borders.BottomRight -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        }
    }
    catch {
        Write-TuiLog "Error in Write-BufferBox: $_" -Level Error
    }
}

#endregion

#region Dirty Region Tracking

function Add-DirtyRegion {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )
    
    if ($Width -le 0 -or $Height -le 0) { return }
    
    $region = @{
        X = [Math]::Max(0, $X)
        Y = [Math]::Max(0, $Y)
        Width = [Math]::Min($Width, $script:TuiState.BufferWidth - $X)
        Height = [Math]::Min($Height, $script:TuiState.BufferHeight - $Y)
    }
    
    # TODO: Merge overlapping regions for efficiency
    $script:TuiState.DirtyRegions.Add($region)
}

function Clear-DirtyRegions {
    $script:TuiState.DirtyRegions.Clear()
}

#endregion

#region Optimized Rendering

function Render-Buffer {
    try {
        # Dynamic frame rate based on activity
        $now = [DateTime]::Now
        $timeSinceLastRender = ($now - $script:TuiState.LastRenderTime).TotalMilliseconds
        $timeSinceActivity = ($now - $script:TuiState.LastActivity).TotalSeconds
        
        # Adjust render interval based on activity
        $targetInterval = if ($timeSinceActivity -lt 1) { 16 } # 60 FPS when active
                         elseif ($timeSinceActivity -lt 5) { 33 } # 30 FPS when semi-active
                         else { 100 } # 10 FPS when idle
        
        if ($timeSinceLastRender -lt $targetInterval) {
            return
        }
        
        $script:TuiState.LastRenderTime = $now
        
        # Use dirty regions if available, otherwise do full scan
        if ($script:TuiState.DirtyRegions.Count -gt 0) {
            Render-DirtyRegions
        } else {
            # Only render if there are actual changes
            $hasChanges = $false
            for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
                for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
                    $backCell = $script:TuiState.BackBuffer[$y, $x]
                    $frontCell = $script:TuiState.FrontBuffer[$y, $x]
                    
                    if ($backCell.Char -ne $frontCell.Char -or 
                        $backCell.FG -ne $frontCell.FG -or 
                        $backCell.BG -ne $frontCell.BG) {
                        $hasChanges = $true
                        break
                    }
                }
                if ($hasChanges) { break }
            }
            
            if ($hasChanges) {
                Render-FullBuffer
            }
        }
        
        Clear-DirtyRegions
    }
    catch {
        Write-TuiLog "Error in Render-Buffer: $_" -Level Error
    }
}

function Render-DirtyRegions {
    foreach ($region in $script:TuiState.DirtyRegions) {
        for ($y = $region.Y; $y -lt ($region.Y + $region.Height); $y++) {
            for ($x = $region.X; $x -lt ($region.X + $region.Width); $x++) {
                if ($y -lt $script:TuiState.BufferHeight -and $x -lt $script:TuiState.BufferWidth) {
                    $backCell = $script:TuiState.BackBuffer[$y, $x]
                    
                    [Console]::SetCursorPosition($x, $y)
                    [Console]::ForegroundColor = $backCell.FG
                    [Console]::BackgroundColor = $backCell.BG
                    [Console]::Write($backCell.Char)
                    
                    # Update front buffer
                    $script:TuiState.FrontBuffer[$y, $x] = @{
                        Char = $backCell.Char
                        FG = $backCell.FG
                        BG = $backCell.BG
                    }
                }
            }
        }
    }
    
    [Console]::ResetColor()
}

function Render-FullBuffer {
    # Batch rendering with string builder for efficiency
    $lastFG = [ConsoleColor]::White
    $lastBG = [ConsoleColor]::Black
    $buffer = [System.Text.StringBuilder]::new()
    
    for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
        [Console]::SetCursorPosition(0, $y)
        $buffer.Clear()
        
        for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
            $backCell = $script:TuiState.BackBuffer[$y, $x]
            $frontCell = $script:TuiState.FrontBuffer[$y, $x]
            
            if ($backCell.Char -ne $frontCell.Char -or 
                $backCell.FG -ne $frontCell.FG -or 
                $backCell.BG -ne $frontCell.BG) {
                
                # Flush buffer if color changes
                if ($backCell.FG -ne $lastFG -or $backCell.BG -ne $lastBG) {
                    if ($buffer.Length -gt 0) {
                        [Console]::Write($buffer.ToString())
                        $buffer.Clear()
                    }
                    [Console]::ForegroundColor = $backCell.FG
                    [Console]::BackgroundColor = $backCell.BG
                    $lastFG = $backCell.FG
                    $lastBG = $backCell.BG
                }
                
                $buffer.Append($backCell.Char)
                
                # Update front buffer
                $script:TuiState.FrontBuffer[$y, $x] = @{
                    Char = $backCell.Char
                    FG = $backCell.FG
                    BG = $backCell.BG
                }
            } else {
                # Flush and skip
                if ($buffer.Length -gt 0) {
                    [Console]::Write($buffer.ToString())
                    $buffer.Clear()
                    [Console]::SetCursorPosition($x + 1, $y)
                }
            }
        }
        
        # Flush remaining
        if ($buffer.Length -gt 0) {
            [Console]::Write($buffer.ToString())
        }
    }
    
    [Console]::ResetColor()
}

function Request-TuiRefresh {
    # Force a full screen refresh on next render
    Add-DirtyRegion -X 0 -Y 0 -Width $script:TuiState.BufferWidth -Height $script:TuiState.BufferHeight
}

#endregion

#region Border Styles

function Get-BorderChars {
    param(
        [string]$Style = "Single"
    )
    
    $borderStyles = @{
        "Single" = @{
            TopLeft = "┌"; TopRight = "┐"; BottomLeft = "└"; BottomRight = "┘"
            Horizontal = "─"; Vertical = "│"; Cross = "┼"
            TTop = "┬"; TBottom = "┴"; TLeft = "├"; TRight = "┤"
        }
        "Double" = @{
            TopLeft = "╔"; TopRight = "╗"; BottomLeft = "╚"; BottomRight = "╝"
            Horizontal = "═"; Vertical = "║"; Cross = "╬"
            TTop = "╦"; TBottom = "╩"; TLeft = "╠"; TRight = "╣"
        }
        "Rounded" = @{
            TopLeft = "╭"; TopRight = "╮"; BottomLeft = "╰"; BottomRight = "╯"
            Horizontal = "─"; Vertical = "│"; Cross = "┼"
            TTop = "┬"; TBottom = "┴"; TLeft = "├"; TRight = "┤"
        }
        "ASCII" = @{
            TopLeft = "+"; TopRight = "+"; BottomLeft = "+"; BottomRight = "+"
            Horizontal = "-"; Vertical = "|"; Cross = "+"
            TTop = "+"; TBottom = "+"; TLeft = "+"; TRight = "+"
        }
    }
    
    return $borderStyles[$Style] ?? $borderStyles["ASCII"]
}

#endregion

#region Enhanced Non-Blocking Input

function Initialize-InputHandler {
    try {
        # Create a runspace for non-blocking input
        $script:InputRunspace = [runspacefactory]::CreateRunspace()
        $script:InputRunspace.Open()
        $script:InputRunspace.SessionStateProxy.SetVariable('InputQueue', $script:TuiState.InputQueue)
        $script:InputRunspace.SessionStateProxy.SetVariable('MaxQueueSize', $script:TuiState.InputQueueMaxSize)
        
        $script:InputPowerShell = [powershell]::Create()
        $script:InputPowerShell.Runspace = $script:InputRunspace
        
        # Track for cleanup
        $script:ResourceCleanup.Runspaces += $script:InputRunspace
        $script:ResourceCleanup.PowerShells += $script:InputPowerShell
        
        $script:InputPowerShell.AddScript({
            $stopRequested = $false
            while (-not $stopRequested) {
                try {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        
                        # Check queue size to prevent overflow
                        if ($InputQueue.Count -lt $MaxQueueSize) {
                            $InputQueue.Enqueue($key)
                        }
                    }
                    
                    # Check for stop signal
                    if ($InputQueue.Count -gt 0) {
                        $peekKey = $null
                        if ($InputQueue.TryPeek([ref]$peekKey)) {
                            if ($peekKey.Key -eq [ConsoleKey]::F12 -and 
                                ($peekKey.Modifiers -band [ConsoleModifiers]::Control)) {
                                $stopRequested = $true
                            }
                        }
                    }
                }
                catch {
                    # Log error but continue
                }
                Start-Sleep -Milliseconds 10
            }
        })
        
        $script:InputHandle = $script:InputPowerShell.BeginInvoke()
        Write-TuiLog "Input handler initialized successfully" -Level Info
    }
    catch {
        Write-TuiLog "Failed to initialize input handler: $_" -Level Error
        throw
    }
}

function Process-Input {
    if ($script:TuiState.InputQueue.Count -eq 0) { return $null }
    
    $key = $null
    if ($script:TuiState.InputQueue.TryDequeue([ref]$key)) {
        $script:TuiState.LastActivity = [DateTime]::Now
        return $key
    }
    return $null
}

function Stop-InputHandler {
    try {
        # Signal stop by enqueueing special key combo
        if ($script:TuiState.InputQueue) {
            $stopKey = New-Object System.ConsoleKeyInfo -ArgumentList ([char]0, [ConsoleKey]::F12, $false, $false, $true)
            $script:TuiState.InputQueue.Enqueue($stopKey)
        }
        
        # Give time for graceful shutdown
        Start-Sleep -Milliseconds 100
        
        # Force stop if needed
        if ($script:InputPowerShell) {
            try {
                $script:InputPowerShell.Stop()
                if ($script:InputHandle) {
                    $script:InputPowerShell.EndInvoke($script:InputHandle)
                }
            }
            catch {
                Write-TuiLog "Error stopping input PowerShell: $_" -Level Warning
            }
        }
        
        # Cleanup all resources
        foreach ($ps in $script:ResourceCleanup.PowerShells) {
            if ($ps) { 
                try { $ps.Dispose() } 
                catch { Write-TuiLog "Error disposing PowerShell: $_" -Level Warning }
            }
        }
        
        foreach ($rs in $script:ResourceCleanup.Runspaces) {
            if ($rs) { 
                try { 
                    $rs.Close()
                    $rs.Dispose() 
                } 
                catch { Write-TuiLog "Error disposing runspace: $_" -Level Warning }
            }
        }
        
        Write-TuiLog "Input handler stopped successfully" -Level Info
    }
    catch {
        Write-TuiLog "Error in Stop-InputHandler: $_" -Level Error
    }
}

#endregion

#region Screen Management with Error Recovery

function Push-Screen {
    param(
        [hashtable]$Screen
    )
    
    if (-not $Screen) {
        Write-TuiLog "Attempted to push null screen" -Level Error
        return
    }
    
    try {
        if ($script:TuiState.CurrentScreen) {
            # Call cleanup on current screen if it exists
            if ($script:TuiState.CurrentScreen.OnExit) {
                & $script:TuiState.CurrentScreen.OnExit
            }
            
            $script:TuiState.ScreenStack.Push($script:TuiState.CurrentScreen)
        }
        
        $script:TuiState.CurrentScreen = $Screen
        
        # Initialize screen if it has an Init method
        if ($Screen.Init) {
            try {
                & $Screen.Init
            }
            catch {
                Write-TuiLog "Screen init failed for $($Screen.Name): $_" -Level Error
                # Recover by popping back
                Pop-Screen
                throw
            }
        }
        
        # Publish event
        Publish-TuiEvent -EventName "ScreenPushed" -Data $Screen
        
        Write-TuiLog "Pushed screen: $($Screen.Name ?? 'Unknown')" -Level Info
    }
    catch {
        Write-TuiLog "Error in Push-Screen: $_" -Level Error
        throw
    }
}

function Pop-Screen {
    try {
        if ($script:TuiState.ScreenStack.Count -gt 0) {
            # Cleanup current screen
            if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.OnExit) {
                & $script:TuiState.CurrentScreen.OnExit
            }
            
            $script:TuiState.CurrentScreen = $script:TuiState.ScreenStack.Pop()
            
            # Re-init popped screen
            if ($script:TuiState.CurrentScreen.OnResume) {
                & $script:TuiState.CurrentScreen.OnResume
            }
            
            Publish-TuiEvent -EventName "ScreenPopped" -Data $script:TuiState.CurrentScreen
            
            Write-TuiLog "Popped to screen: $($script:TuiState.CurrentScreen.Name ?? 'Unknown')" -Level Info
            return $true
        }
        return $false
    }
    catch {
        Write-TuiLog "Error in Pop-Screen: $_" -Level Error
        return $false
    }
}

function Update-CurrentScreen {
    if (-not $script:TuiState.CurrentScreen) { return }
    
    try {
        # Clear the back buffer
        Clear-BackBuffer
        
        # Render the screen with error recovery
        if ($script:TuiState.CurrentScreen.Render) {
            try {
                & $script:TuiState.CurrentScreen.Render
            }
            catch {
                Write-TuiLog "Screen render error: $_" -Level Error
                # Draw error message
                Write-BufferString -X 2 -Y 2 -Text "Screen render error!" -ForegroundColor Red
                Write-BufferString -X 2 -Y 3 -Text $_.ToString() -ForegroundColor Yellow
            }
        }
        
        # Render to console
        Render-Buffer
    }
    catch {
        Write-TuiLog "Critical error in Update-CurrentScreen: $_" -Level Error
    }
}

function Handle-ScreenInput {
    param($Key)
    
    if (-not $script:TuiState.CurrentScreen -or -not $Key) { return }
    
    try {
        # Global key handlers first
        switch ($Key.Key) {
            ([ConsoleKey]::F10) {
                # Emergency exit
                if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
                    $script:TuiState.Running = $false
                    return
                }
            }
            ([ConsoleKey]::F9) {
                # Show debug info
                if ($Key.Modifiers -band [ConsoleModifiers]::Control) {
                    Push-Screen -Screen (Get-DebugScreen)
                    return
                }
            }
        }
        
        # Let the screen handle the input
        if ($script:TuiState.CurrentScreen.HandleInput) {
            $result = & $script:TuiState.CurrentScreen.HandleInput -Key $Key
            
            # Handle navigation commands
            switch ($result) {
                "Back" { Pop-Screen }
                "Quit" { $script:TuiState.Running = $false }
            }
        }
    }
    catch {
        Write-TuiLog "Error in Handle-ScreenInput: $_" -Level Error
        Write-StatusLine -Text " Input error: $($_.Message)" -BackgroundColor Red
    }
}

function Exit-TuiLoop {
    $script:TuiState.Running = $false
}

#endregion

#region Theme System

function Initialize-Themes {
    $script:TuiState.Themes = @{
        "Default" = @{
            Primary = [ConsoleColor]::White
            Secondary = [ConsoleColor]::Gray
            Accent = [ConsoleColor]::Cyan
            Success = [ConsoleColor]::Green
            Warning = [ConsoleColor]::Yellow
            Error = [ConsoleColor]::Red
            Info = [ConsoleColor]::Blue
            Header = [ConsoleColor]::Cyan
            Subtle = [ConsoleColor]::DarkGray
            Background = [ConsoleColor]::Black
        }
        "Dark" = @{
            Primary = [ConsoleColor]::Gray
            Secondary = [ConsoleColor]::DarkGray
            Accent = [ConsoleColor]::DarkCyan
            Success = [ConsoleColor]::DarkGreen
            Warning = [ConsoleColor]::DarkYellow
            Error = [ConsoleColor]::DarkRed
            Info = [ConsoleColor]::DarkBlue
            Header = [ConsoleColor]::DarkCyan
            Subtle = [ConsoleColor]::Black
            Background = [ConsoleColor]::Black
        }
        "Light" = @{
            Primary = [ConsoleColor]::Black
            Secondary = [ConsoleColor]::DarkGray
            Accent = [ConsoleColor]::Blue
            Success = [ConsoleColor]::Green
            Warning = [ConsoleColor]::Yellow
            Error = [ConsoleColor]::Red
            Info = [ConsoleColor]::Cyan
            Header = [ConsoleColor]::Blue
            Subtle = [ConsoleColor]::Gray
            Background = [ConsoleColor]::White
        }
    }
}

function Get-ThemeColor {
    param(
        [string]$ColorName
    )
    
    $theme = $script:TuiState.Themes[$script:TuiState.CurrentTheme]
    if (-not $theme) {
        $theme = $script:TuiState.Themes["Default"]
    }
    
    return $theme[$ColorName] ?? [ConsoleColor]::White
}

function Set-TuiTheme {
    param(
        [string]$ThemeName
    )
    
    if ($script:TuiState.Themes.ContainsKey($ThemeName)) {
        $script:TuiState.CurrentTheme = $ThemeName
        Publish-TuiEvent -EventName "ThemeChanged" -Data $ThemeName
        Write-TuiLog "Theme changed to: $ThemeName" -Level Info
    }
}

#endregion

#region Enhanced Main TUI Loop

function Start-TuiLoop {
    param(
        [hashtable]$InitialScreen
    )
    
    $errorCount = 0
    $maxErrors = 10
    
    try {
        # Set initial screen
        Push-Screen -Screen $InitialScreen
        
        # Start the main loop
        $script:TuiState.Running = $true
        
        while ($script:TuiState.Running) {
            try {
                # Process input
                $key = Process-Input
                if ($key) {
                    Handle-ScreenInput -Key $key
                }
                
                # Update current screen
                Update-CurrentScreen
                
                # Reset error count on successful iteration
                $errorCount = 0
                
                # Dynamic sleep based on activity
                $sleepTime = if (([DateTime]::Now - $script:TuiState.LastActivity).TotalSeconds -lt 1) { 10 }
                            elseif (([DateTime]::Now - $script:TuiState.LastActivity).TotalSeconds -lt 5) { 20 }
                            else { 50 }
                
                Start-Sleep -Milliseconds $sleepTime
            }
            catch {
                $errorCount++
                Write-TuiLog "Main loop error ($errorCount/$maxErrors): $_" -Level Error
                
                if ($errorCount -ge $maxErrors) {
                    Write-TuiLog "Too many errors, shutting down" -Level Error
                    $script:TuiState.Running = $false
                }
                
                # Try to recover
                Start-Sleep -Milliseconds 100
            }
        }
    }
    catch {
        Write-TuiLog "Fatal error in TUI loop: $_" -Level Error
        throw
    }
    finally {
        # Cleanup
        Stop-TuiEngine
    }
}

function Stop-TuiEngine {
    try {
        Write-TuiLog "Starting TUI cleanup" -Level Info
        
        # Mark as disposed to prevent further operations
        $script:TuiState.IsDisposed = $true
        
        # Stop input handler first
        Stop-InputHandler
        
        # Clear screen and reset console
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::ResetColor()
        
        # Clear buffers to free memory
        $script:TuiState.FrontBuffer = $null
        $script:TuiState.BackBuffer = $null
        
        # Clear other collections
        $script:TuiState.DirtyRegions.Clear()
        $script:TuiState.ScreenStack.Clear()
        
        Write-TuiLog "TUI cleanup completed" -Level Info
        
        # Save log if needed
        if ($script:TuiLog.Entries | Where-Object { $_.Level -eq "Error" }) {
            $logPath = Join-Path $env:TEMP "tui-engine-log.txt"
            $script:TuiLog.Entries | ConvertTo-Json | Set-Content $logPath
            Write-Host "Error log saved to: $logPath" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error during TUI cleanup: $_" -ForegroundColor Red
    }
}

#endregion

#region Utility Functions

function Write-StatusLine {
    param(
        [string]$Text,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::DarkBlue
    )
    
    try {
        $y = $script:TuiState.BufferHeight
        [Console]::SetCursorPosition(0, $y)
        [Console]::ForegroundColor = $ForegroundColor
        [Console]::BackgroundColor = $BackgroundColor
        
        $paddedText = $Text.PadRight([Console]::WindowWidth)
        [Console]::Write($paddedText)
        
        [Console]::ResetColor()
    }
    catch {
        Write-TuiLog "Error in Write-StatusLine: $_" -Level Error
    }
}

function Get-DebugScreen {
    return @{
        Name = "Debug"
        Render = {
            Write-BufferBox -X 5 -Y 2 -Width 70 -Height 25 -Title "TUI Debug Info" -BorderColor Yellow
            
            $y = 4
            Write-BufferString -X 7 -Y $y -Text "Buffer Size: $($script:TuiState.BufferWidth)x$($script:TuiState.BufferHeight)" -ForegroundColor Cyan
            $y += 2
            
            Write-BufferString -X 7 -Y $y -Text "Input Queue: $($script:TuiState.InputQueue.Count)/$($script:TuiState.InputQueueMaxSize)" -ForegroundColor Cyan
            $y += 2
            
            Write-BufferString -X 7 -Y $y -Text "Screen Stack: $($script:TuiState.ScreenStack.Count)" -ForegroundColor Cyan
            $y += 2
            
            Write-BufferString -X 7 -Y $y -Text "Theme: $($script:TuiState.CurrentTheme)" -ForegroundColor Cyan
            $y += 2
            
            Write-BufferString -X 7 -Y $y -Text "Recent Errors:" -ForegroundColor Red
            $y++
            
            $errors = $script:TuiLog.Entries | Where-Object { $_.Level -eq "Error" } | Select-Object -Last 5
            foreach ($error in $errors) {
                $errorText = "$($error.Timestamp.ToString('HH:mm:ss')) - $($error.Message)"
                if ($errorText.Length -gt 65) { $errorText = $errorText.Substring(0, 62) + "..." }
                Write-BufferString -X 7 -Y $y -Text $errorText -ForegroundColor Yellow
                $y++
            }
            
            Write-BufferString -X 7 -Y 26 -Text "Press Esc to close" -ForegroundColor DarkGray
        }
        HandleInput = {
            param($Key)
            if ($Key.Key -eq [ConsoleKey]::Escape) { return "Back" }
        }
    }
}

#endregion

#region Component Base Class

$script:ComponentBase = @{
    # Properties
    X = 0
    Y = 0
    Width = 10
    Height = 5
    Visible = $true
    Focused = $false
    Parent = $null
    Children = @()
    State = @{}
    
    # Methods
    Init = { param($self) }
    Render = { param($self) }
    HandleInput = { param($self, $Key) }
    OnFocus = { param($self) }
    OnBlur = { param($self) }
    OnResize = { param($self, $Width, $Height) }
    Dispose = { param($self) }
}

function New-TuiComponent {
    param(
        [hashtable]$Properties = @{}
    )
    
    $component = $script:ComponentBase.Clone()
    foreach ($key in $Properties.Keys) {
        $component[$key] = $Properties[$key]
    }
    
    return $component
}

#endregion

#region Layout Managers

$script:LayoutManagers = @{
    Stack = {
        param($Container, $Orientation = "Vertical")
        
        $x = $Container.X
        $y = $Container.Y
        
        foreach ($child in $Container.Children) {
            if (-not $child.Visible) { continue }
            
            $child.X = $x
            $child.Y = $y
            
            if ($Orientation -eq "Vertical") {
                $y += $child.Height
            } else {
                $x += $child.Width
            }
        }
    }
    
    Grid = {
        param($Container, $Columns = 2, $Rows = 2)
        
        $cellWidth = [Math]::Floor($Container.Width / $Columns)
        $cellHeight = [Math]::Floor($Container.Height / $Rows)
        
        $index = 0
        foreach ($child in $Container.Children) {
            if (-not $child.Visible) { continue }
            
            $col = $index % $Columns
            $row = [Math]::Floor($index / $Columns)
            
            $child.X = $Container.X + ($col * $cellWidth)
            $child.Y = $Container.Y + ($row * $cellHeight)
            $child.Width = $cellWidth
            $child.Height = $cellHeight
            
            $index++
        }
    }
    
    Dock = {
        param($Container)
        
        $remainingX = $Container.X
        $remainingY = $Container.Y
        $remainingWidth = $Container.Width
        $remainingHeight = $Container.Height
        
        foreach ($child in $Container.Children) {
            if (-not $child.Visible) { continue }
            
            switch ($child.Dock) {
                "Top" {
                    $child.X = $remainingX
                    $child.Y = $remainingY
                    $child.Width = $remainingWidth
                    $remainingY += $child.Height
                    $remainingHeight -= $child.Height
                }
                "Bottom" {
                    $child.X = $remainingX
                    $child.Y = $remainingY + $remainingHeight - $child.Height
                    $child.Width = $remainingWidth
                    $remainingHeight -= $child.Height
                }
                "Left" {
                    $child.X = $remainingX
                    $child.Y = $remainingY
                    $child.Height = $remainingHeight
                    $remainingX += $child.Width
                    $remainingWidth -= $child.Width
                }
                "Right" {
                    $child.X = $remainingX + $remainingWidth - $child.Width
                    $child.Y = $remainingY
                    $child.Height = $remainingHeight
                    $remainingWidth -= $child.Width
                }
                "Fill" {
                    $child.X = $remainingX
                    $child.Y = $remainingY
                    $child.Width = $remainingWidth
                    $child.Height = $remainingHeight
                }
            }
        }
    }
}

#endregion
