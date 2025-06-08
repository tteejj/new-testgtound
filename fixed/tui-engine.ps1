# Non-Blocking TUI Engine Module
# Provides buffer management, non-blocking input, and screen management

#region Core TUI State
$script:TuiState = @{
    Running = $false
    BufferWidth = 0
    BufferHeight = 0
    FrontBuffer = $null
    BackBuffer = $null
    InputQueue = [System.Collections.Queue]::new()
    LastRenderTime = [DateTime]::MinValue
    RenderInterval = 16 # ~60 FPS
    CurrentScreen = $null
    ScreenStack = [System.Collections.Stack]::new()
    FocusedView = $null
    ViewStates = @{}
}

#endregion

#region Buffer Management

function global:New-ConsoleCell {
    param(
        [char]$Character = ' ',
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black
    )
    return @{
        Char = $Character
        FG = $ForegroundColor
        BG = $BackgroundColor
    }
}

function global:Initialize-TuiEngine {
    param(
        [int]$Width = [Console]::WindowWidth,
        [int]$Height = [Console]::WindowHeight - 1  # Leave one line for status
    )
    
    Write-Host "Initializing TUI Engine: ${Width}x${Height}" -ForegroundColor Cyan
    
    # Initialize buffers
    $script:TuiState.BufferWidth = $Width
    $script:TuiState.BufferHeight = $Height
    $script:TuiState.FrontBuffer = New-Object 'object[,]' $Height, $Width
    $script:TuiState.BackBuffer = New-Object 'object[,]' $Height, $Width
    
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
    
    # Initialize input handler
    Initialize-InputHandler
}

function global:Clear-BackBuffer {
    param(
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::Black
    )
    
    for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
        for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
            $script:TuiState.BackBuffer[$y, $x] = New-ConsoleCell -BackgroundColor $BackgroundColor
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
    
    $currentX = $X
    foreach ($char in $Text.ToCharArray()) {
        if ($currentX -ge 0 -and $currentX -lt $script:TuiState.BufferWidth) {
            $script:TuiState.BackBuffer[$Y, $currentX] = New-ConsoleCell `
                -Character $char `
                -ForegroundColor $ForegroundColor `
                -BackgroundColor $BackgroundColor
        }
        $currentX++
        if ($currentX -ge $script:TuiState.BufferWidth) { break }
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
    Write-BufferString -X $X -Y $Y -Text $borders.TopLeft -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    for ($i = 1; $i -lt ($Width - 1); $i++) {
        Write-BufferString -X ($X + $i) -Y $Y -Text $borders.Horizontal -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    Write-BufferString -X ($X + $Width - 1) -Y $Y -Text $borders.TopRight -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    
    # Title if provided
    if ($Title) {
        $titleText = " $Title "
        $titleX = $X + [Math]::Max(1, ($Width - $titleText.Length) / 2)
        Write-BufferString -X $titleX -Y $Y -Text $titleText -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    
    # Sides
    for ($i = 1; $i -lt ($Height - 1); $i++) {
        Write-BufferString -X $X -Y ($Y + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        Write-BufferString -X ($X + $Width - 1) -Y ($Y + $i) -Text $borders.Vertical -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
        
        # Fill interior
        for ($j = 1; $j -lt ($Width - 1); $j++) {
            Write-BufferString -X ($X + $j) -Y ($Y + $i) -Text " " -BackgroundColor $BackgroundColor
        }
    }
    
    # Bottom border
    Write-BufferString -X $X -Y ($Y + $Height - 1) -Text $borders.BottomLeft -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    for ($i = 1; $i -lt ($Width - 1); $i++) {
        Write-BufferString -X ($X + $i) -Y ($Y + $Height - 1) -Text $borders.Horizontal -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
    }
    Write-BufferString -X ($X + $Width - 1) -Y ($Y + $Height - 1) -Text $borders.BottomRight -ForegroundColor $BorderColor -BackgroundColor $BackgroundColor
}

function global:Render-Buffer {
    # Only render if enough time has passed
    $now = [DateTime]::Now
    if (($now - $script:TuiState.LastRenderTime).TotalMilliseconds -lt $script:TuiState.RenderInterval) {
        return
    }
    
    $script:TuiState.LastRenderTime = $now
    
    # Compare buffers and only update changed cells
    $output = [System.Text.StringBuilder]::new()
    $lastX = -1
    $lastY = -1
    
    for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
        for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
            $backCell = $script:TuiState.BackBuffer[$y, $x]
            $frontCell = $script:TuiState.FrontBuffer[$y, $x]
            
            if ($backCell.Char -ne $frontCell.Char -or 
                $backCell.FG -ne $frontCell.FG -or 
                $backCell.BG -ne $frontCell.BG) {
                
                # Move cursor if needed
                if ($lastX -ne ($x - 1) -or $lastY -ne $y) {
                    [Console]::SetCursorPosition($x, $y)
                }
                
                # Write the character
                [Console]::ForegroundColor = $backCell.FG
                [Console]::BackgroundColor = $backCell.BG
                [Console]::Write($backCell.Char)
                
                # Update front buffer
                $script:TuiState.FrontBuffer[$y, $x] = @{
                    Char = $backCell.Char
                    FG = $backCell.FG
                    BG = $backCell.BG
                }
                
                $lastX = $x
                $lastY = $y
            }
        }
    }
    
    # Reset console colors
    [Console]::ResetColor()
}

#endregion

#region Border Styles

function global:Get-BorderChars {
    param(
        [string]$Style = "Single"
    )
    
    switch ($Style) {
        "Single" {
            return @{
                TopLeft = "┌"
                TopRight = "┐"
                BottomLeft = "└"
                BottomRight = "┘"
                Horizontal = "─"
                Vertical = "│"
                Cross = "┼"
                TTop = "┬"
                TBottom = "┴"
                TLeft = "├"
                TRight = "┤"
            }
        }
        "Double" {
            return @{
                TopLeft = "╔"
                TopRight = "╗"
                BottomLeft = "╚"
                BottomRight = "╝"
                Horizontal = "═"
                Vertical = "║"
                Cross = "╬"
                TTop = "╦"
                TBottom = "╩"
                TLeft = "╠"
                TRight = "╣"
            }
        }
        "Rounded" {
            return @{
                TopLeft = "╭"
                TopRight = "╮"
                BottomLeft = "╰"
                BottomRight = "╯"
                Horizontal = "─"
                Vertical = "│"
                Cross = "┼"
                TTop = "┬"
                TBottom = "┴"
                TLeft = "├"
                TRight = "┤"
            }
        }
        default {
            return @{
                TopLeft = "+"
                TopRight = "+"
                BottomLeft = "+"
                BottomRight = "+"
                Horizontal = "-"
                Vertical = "|"
                Cross = "+"
                TTop = "+"
                TBottom = "+"
                TLeft = "+"
                TRight = "+"
            }
        }
    }
}

#endregion

#region Non-Blocking Input

function global:Initialize-InputHandler {
    # Create a runspace for non-blocking input
    $script:InputRunspace = [runspacefactory]::CreateRunspace()
    $script:InputRunspace.Open()
    $script:InputRunspace.SessionStateProxy.SetVariable('InputQueue', $script:TuiState.InputQueue)
    
    $script:InputPowerShell = [powershell]::Create()
    $script:InputPowerShell.Runspace = $script:InputRunspace
    
    $script:InputPowerShell.AddScript({
        while ($true) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $InputQueue.Enqueue($key)
            }
            Start-Sleep -Milliseconds 10
        }
    })
    
    $script:InputHandle = $script:InputPowerShell.BeginInvoke()
}

function global:Process-Input {
    if ($script:TuiState.InputQueue.Count -eq 0) { return $null }
    return $script:TuiState.InputQueue.Dequeue()
}

function global:Stop-InputHandler {
    if ($script:InputPowerShell) {
        $script:InputPowerShell.Stop()
        $script:InputPowerShell.Dispose()
    }
    if ($script:InputRunspace) {
        $script:InputRunspace.Close()
        $script:InputRunspace.Dispose()
    }
}

#endregion

#region Screen Management

function global:Push-Screen {
    param(
        [hashtable]$Screen
    )
    
    if ($script:TuiState.CurrentScreen) {
        $script:TuiState.ScreenStack.Push($script:TuiState.CurrentScreen)
    }
    
    $script:TuiState.CurrentScreen = $Screen
    
    # Initialize screen if it has an Init method
    if ($Screen.Init) {
        & $Screen.Init
    }
}

function global:Pop-Screen {
    if ($script:TuiState.ScreenStack.Count -gt 0) {
        $script:TuiState.CurrentScreen = $script:TuiState.ScreenStack.Pop()
        return $true
    }
    return $false
}

function global:Update-CurrentScreen {
    if (-not $script:TuiState.CurrentScreen) { return }
    
    # Clear the back buffer
    Clear-BackBuffer
    
    # Render the screen
    if ($script:TuiState.CurrentScreen.Render) {
        & $script:TuiState.CurrentScreen.Render
    }
    
    # Render to console
    Render-Buffer
}

function global:Handle-ScreenInput {
    param($Key)
    
    if (-not $script:TuiState.CurrentScreen) { return }
    
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

#endregion

#region Main TUI Loop

function global:Start-TuiLoop {
    param(
        [hashtable]$InitialScreen
    )
    
    try {
        # Initialize the engine
        Initialize-TuiEngine
        
        # Set initial screen
        Push-Screen -Screen $InitialScreen
        
        # Start the main loop
        $script:TuiState.Running = $true
        
        while ($script:TuiState.Running) {
            # Process input
            $key = Process-Input
            if ($key) {
                Handle-ScreenInput -Key $key
            }
            
            # Update current screen
            Update-CurrentScreen
            
            # Small delay to prevent CPU spinning
            Start-Sleep -Milliseconds 10
        }
    }
    finally {
        # Cleanup
        Stop-InputHandler
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::ResetColor()
    }
}

#endregion

#region Utility Functions

function global:Get-ThemeColor {
    param(
        [string]$ColorName
    )
    
    # Map theme colors to console colors
    $colorMap = @{
        "Primary" = [ConsoleColor]::White
        "Secondary" = [ConsoleColor]::Gray
        "Accent" = [ConsoleColor]::Cyan
        "Success" = [ConsoleColor]::Green
        "Warning" = [ConsoleColor]::Yellow
        "Error" = [ConsoleColor]::Red
        "Info" = [ConsoleColor]::Blue
        "Header" = [ConsoleColor]::Cyan
        "Subtle" = [ConsoleColor]::DarkGray
        "Background" = [ConsoleColor]::Black
    }
    
    if ($colorMap.ContainsKey($ColorName)) {
        return $colorMap[$ColorName]
    }
    
    return [ConsoleColor]::White
}

function global:Write-StatusLine {
    param(
        [string]$Text,
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [ConsoleColor]$BackgroundColor = [ConsoleColor]::DarkBlue
    )
    
    $y = $script:TuiState.BufferHeight
    [Console]::SetCursorPosition(0, $y)
    [Console]::ForegroundColor = $ForegroundColor
    [Console]::BackgroundColor = $BackgroundColor
    
    $paddedText = $Text.PadRight([Console]::WindowWidth)
    [Console]::Write($paddedText)
    
    [Console]::ResetColor()
}

#endregion
