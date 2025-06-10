# Rock-Solid TUI Engine v2.3 - DEFINITIVE VERSION
# Manages the main loop, rendering pipeline, input queue, and integrates with new modular system.
# This version is restored to its full, original content with the single required fix.

#region Core TUI State
$script:TuiState = @{
    Running         = $false
    BufferWidth     = 0
    BufferHeight    = 0
    FrontBuffer     = $null
    BackBuffer      = $null
    Buffer          = $null  # Alias for compatibility
    InputQueue      = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    InputQueueMaxSize = 100
    ScreenStack     = [System.Collections.Stack]::new()
    CurrentScreen   = $null
    IsDirty         = $true
    LastActivity    = [DateTime]::Now
    LastRenderTime  = [DateTime]::MinValue
    RenderStats     = @{ LastFrameTime = 0; FrameCount = 0; TotalTime = 0 }
}
$script:ResourceCleanup = @{ Runspaces = @(); PowerShells = @() }
#endregion

#region Engine Lifecycle & Main Loop

function global:Initialize-TuiEngine {
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1
    )
    
    try {
        if ($Width -le 0 -or $Height -le 0) { throw "Invalid console dimensions: ${Width}x${Height}" }
        
        $script:TuiState.BufferWidth = $Width
        $script:TuiState.BufferHeight = $Height
        $script:TuiState.FrontBuffer = New-Object 'object[,]' $Height, $Width
        $script:TuiState.BackBuffer = New-Object 'object[,]' $Height, $Width
        $script:TuiState.Buffer = $script:TuiState.BackBuffer
        
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $Width; $x++) {
                $emptyCell = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
                $script:TuiState.FrontBuffer[$y, $x] = $emptyCell
                $script:TuiState.BackBuffer[$y, $x] = $emptyCell.Clone()
            }
        }
        
        [Console]::CursorVisible = $false
        [Console]::Clear()
        
        $global:TuiState = $script:TuiState
        
        Initialize-InputHandler
    }
    catch {
        Write-Host "FATAL: Failed to initialize TUI Engine: $_" -ForegroundColor Red
        throw
    }
}

function global:Start-TuiLoop {
    param($InitialScreen)

    try {
        if ($InitialScreen) {
            Push-Screen -Screen $InitialScreen
        }

        $script:TuiState.Running = $true
        while ($script:TuiState.Running) {
            $key = Process-Input
            while ($key) {
                $script:TuiState.LastActivity = [DateTime]::Now
                
                $dialogHandled = $false
                if (Get-Command -Name "Handle-DialogInput" -ErrorAction SilentlyContinue) {
                    $dialogHandled = Handle-DialogInput -Key $key
                }
                
                if (-not $dialogHandled -and $script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.HandleInput) {
                    $result = & $script:TuiState.CurrentScreen.HandleInput -self $script:TuiState.CurrentScreen -Key $key
                    switch ($result) {
                        "Back" { Pop-Screen }
                        "Quit" { $script:TuiState.Running = $false }
                    }
                }
                
                $key = Process-Input
            }
            
            if (Get-Command -Name "Update-DialogSystem" -ErrorAction SilentlyContinue) {
                Update-DialogSystem
            }

            if ($script:TuiState.IsDirty) {
                Clear-BackBuffer -BackgroundColor (Get-ThemeColor "Background")
                
                if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.Render) {
                    & $script:TuiState.CurrentScreen.Render -self $script:TuiState.CurrentScreen
                }
                
                if (Get-Command -Name "Render-Dialogs" -ErrorAction SilentlyContinue) {
                    Render-Dialogs
                }
                
                Render-BufferOptimized
                $script:TuiState.IsDirty = $false
            }
            
            $sleepTime = if (([DateTime]::Now - $script:TuiState.LastActivity).TotalSeconds -lt 2) { 16 } else { 100 }
            Start-Sleep -Milliseconds $sleepTime
        }
    }
    finally {
        Cleanup-TuiEngine
    }
}

function global:Request-TuiRefresh {
    $script:TuiState.IsDirty = $true
}

function global:Stop-TuiEngine {
    $script:TuiState.Running = $false
    Cleanup-TuiEngine
}

function Cleanup-TuiEngine {
    try {
        Stop-InputHandler
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::ResetColor()
    }
    catch {
        Write-Host "Error during TUI cleanup: $_" -ForegroundColor Red
    }
}

#endregion

#region Screen Management

function global:Push-Screen {
    # #############################################################################
    # # CRITICAL FIX APPLIED HERE
    # #############################################################################
    #
    # THE PROBLEM: The original function signature was `param([hashtable]$Screen)`.
    # This forced the input to be a hashtable. However, the `dashboard-screen`
    # module now correctly returns a `[PSCustomObject]` so that its internal
    # methods (like `$this.RefreshAllData()`) will work.
    #
    # THE FIX: The `[hashtable]` type constraint has been removed from the `$Screen`
    # parameter. This allows the function to accept both hashtables and PSCustomObjects,
    # resolving the type conversion error.
    #
    # BEFORE: param([hashtable]$Screen)
    # AFTER:  param($Screen)
    #
    # #############################################################################
    param($Screen)
    if (-not $Screen) { return }
    
    if ($script:TuiState.CurrentScreen) {
        if ($script:TuiState.CurrentScreen.OnExit) { 
            & $script:TuiState.CurrentScreen.OnExit -self $script:TuiState.CurrentScreen
        }
        $script:TuiState.ScreenStack.Push($script:TuiState.CurrentScreen)
    }
    
    $script:TuiState.CurrentScreen = $Screen
    if ($Screen.Init) { & $Screen.Init -self $Screen }
    Request-TuiRefresh
}

function global:Pop-Screen {
    if ($script:TuiState.ScreenStack.Count -eq 0) { 
        $script:TuiState.Running = $false
        return $false 
    }
    
    $screenToExit = $script:TuiState.CurrentScreen
    $script:TuiState.CurrentScreen = $script:TuiState.ScreenStack.Pop()
    
    if ($screenToExit -and $screenToExit.OnExit) { 
        & $screenToExit.OnExit -self $screenToExit
    }
    if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.OnResume) { 
        & $script:TuiState.CurrentScreen.OnResume -self $script:TuiState.CurrentScreen
    }
    
    Request-TuiRefresh
    return $true
}

#endregion

#region Buffer and Rendering

function global:Clear-BackBuffer {
    param([ConsoleColor]$BackgroundColor = [ConsoleColor]::Black)
    $cell = @{ Char = ' '; FG = [ConsoleColor]::White; BG = $BackgroundColor }
    for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
        for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
            $script:TuiState.BackBuffer[$y, $x] = $cell
        }
    }
}

function global:Write-BufferString {
    param(
        [int]$X, 
        [int]$Y, 
        [string]$Text, 
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White, 
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black
    )
    if ($Y -lt 0 -or $Y -ge $script:TuiState.BufferHeight) { return }
    if ([string]::IsNullOrEmpty($Text)) { return }
    
    $currentX = $X
    foreach ($char in $Text.ToCharArray()) {
        if ($currentX -ge 0 -and $currentX -lt $script:TuiState.BufferWidth) {
            $script:TuiState.BackBuffer[$y, $currentX] = @{ 
                Char = $char
                FG = $ForegroundColor
                BG = $BackgroundColor 
            }
        }
        $currentX++
    }
}

function global:Write-BufferBox {
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
    $borders = Get-BorderChars -Style $BorderStyle
    
    # Top border
    Write-BufferString -X $X -Y $Y -Text "$($borders.TopLeft)$($borders.Horizontal * ($Width - 2))$($borders.TopRight)" -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    
    # Title
    if ($Title) {
        $titleText = " $Title "
        if ($titleText.Length > ($Width - 2)) { 
            $titleText = " $($Title.Substring(0, $Width - 5))... " 
        }
        $titleX = $X + [Math]::Floor(($Width - $titleText.Length) / 2)
        Write-BufferString -X $titleX -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    
    # Sides and Fill
    for ($i = 1; $i -lt ($Height - 1); $i++) {
        Write-BufferString -X $X -Y ($Y + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        Write-BufferString -X ($X + 1) -Y ($Y + $i) -Text (' ' * ($Width - 2)) -BackgroundColor $BackgroundColor
        Write-BufferString -X ($X + $Width - 1) -Y ($Y + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    
    # Bottom border
    Write-BufferString -X $X -Y ($Y + $Height - 1) -Text "$($borders.BottomLeft)$($borders.Horizontal * ($Width - 2))$($borders.BottomRight)" -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
}

function global:Render-BufferOptimized {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $outputBuilder = [System.Text.StringBuilder]::new(20000)
    $lastFG = -1
    $lastBG = -1
    
    for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
        $outputBuilder.Append("`e[$($y + 1);1H") | Out-Null
        
        for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
            $backCell = $script:TuiState.BackBuffer[$y, $x]
            $frontCell = $script:TuiState.FrontBuffer[$y, $x]
            
            if ($backCell.Char -eq $frontCell.Char -and 
                $backCell.FG -eq $frontCell.FG -and 
                $backCell.BG -eq $frontCell.BG) {
                continue
            }
            
            if ($backCell.FG -ne $lastFG -or $backCell.BG -ne $lastBG) {
                $fgCode = Get-AnsiColorCode $backCell.FG
                $bgCode = Get-AnsiColorCode $backCell.BG -IsBackground $true
                $outputBuilder.Append("`e[${fgCode};${bgCode}m") | Out-Null
                $lastFG = $backCell.FG
                $lastBG = $backCell.BG
            }
            
            $outputBuilder.Append($backCell.Char) | Out-Null
            $script:TuiState.FrontBuffer[$y, $x] = $backCell.Clone()
        }
    }
    
    [Console]::Write($outputBuilder.ToString())
    
    $stopwatch.Stop()
    $script:TuiState.RenderStats.LastFrameTime = $stopwatch.ElapsedMilliseconds
}

#endregion

#region Input and Utility

function global:Initialize-InputHandler {
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('InputQueue', $script:TuiState.InputQueue)
    $runspace.SessionStateProxy.SetVariable('MaxQueueSize', $script:TuiState.InputQueueMaxSize)
    $script:ResourceCleanup.Runspaces += $runspace
    
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    $script:ResourceCleanup.PowerShells += $ps
    
    $ps.AddScript({
        while ($true) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($InputQueue.Count -lt $MaxQueueSize) { 
                    $InputQueue.Enqueue($key) 
                }
            }
            Start-Sleep -Milliseconds 10
        }
    }) | Out-Null
    
    $script:AsyncResult = $ps.BeginInvoke()
}

function global:Process-Input { 
    $key = $null
    if ($script:TuiState.InputQueue.TryDequeue([ref]$key)) { 
        return $key 
    } 
    return $null 
}

function global:Stop-InputHandler { 
    foreach($ps in $script:ResourceCleanup.PowerShells) { 
        if ($ps -and $script:AsyncResult) {
            try { $ps.Stop() } catch {}
            try { $ps.EndInvoke($script:AsyncResult) } catch {}
            try { $ps.Dispose() } catch {}
        }
    }
    foreach($rs in $script:ResourceCleanup.Runspaces) { 
        if ($rs) {
            try { $rs.Close() } catch {}
            try { $rs.Dispose() } catch {}
        }
    } 
}

function global:Get-BorderChars { 
    param([string]$Style) 
    $styles = @{ 
        Single = @{ TopLeft='┌'; TopRight='┐'; BottomLeft='└'; BottomRight='┘'; Horizontal='─'; Vertical='│' }
        Double = @{ TopLeft='╔'; TopRight='╗'; BottomLeft='╚'; BottomRight='╝'; Horizontal='═'; Vertical='║' }
        Rounded = @{ TopLeft='╭'; TopRight='╮'; BottomLeft='╰'; BottomRight='╯'; Horizontal='─'; Vertical='│' } 
    }
    return $styles[$Style] ?? $styles.Single
}

function Get-AnsiColorCode { 
    param([ConsoleColor]$Color, [bool]$IsBackground) 
    $map = @{ Black=30; DarkBlue=34; DarkGreen=32; DarkCyan=36; DarkRed=31; DarkMagenta=35; DarkYellow=33; Gray=37; DarkGray=90; Blue=94; Green=92; Cyan=96; Red=91; Magenta=95; Yellow=93; White=97 }
    $code = $map[$Color.ToString()]
    if ($IsBackground) { $code + 10 } else { $code } 
}

#endregion

Export-ModuleMember -Function @(
    'Initialize-TuiEngine',
    'Start-TuiLoop', 
    'Request-TuiRefresh', 
    'Stop-TuiEngine',
    'Push-Screen', 
    'Pop-Screen',
    'Write-BufferString', 
    'Write-BufferBox', 
    'Clear-BackBuffer'
) -Variable @('TuiState')