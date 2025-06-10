# Rock-Solid TUI Engine v3.0 - Restored with Architectural Upgrades
# Full restoration of OG functionality plus component system and layout management

#region Core TUI State
$script:TuiState = @{
    Running         = $false
    BufferWidth     = 0
    BufferHeight    = 0
    FrontBuffer     = $null
    BackBuffer      = $null
    InputQueue      = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    InputQueueMaxSize = 100
    ScreenStack     = [System.Collections.Stack]::new()
    CurrentScreen   = $null
    IsDirty         = $true
    LastActivity    = [DateTime]::Now
    LastRenderTime  = [DateTime]::MinValue
    RenderStats     = @{ LastFrameTime = 0; FrameCount = 0; TotalTime = 0 }
    Components      = @()  # Component registry
    Layouts         = @{}  # Layout engines
    FocusedComponent = $null
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
        
        # Initialize buffers with empty cells
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $Width; $x++) {
                $emptyCell = @{ Char = ' '; FG = [ConsoleColor]::White; BG = [ConsoleColor]::Black }
                $script:TuiState.FrontBuffer[$y, $x] = $emptyCell
                $script:TuiState.BackBuffer[$y, $x] = $emptyCell.Clone()
            }
        }
        
        [Console]::CursorVisible = $false
        [Console]::Clear()
        
        # Initialize subsystems
        Initialize-LayoutEngines
        Initialize-ComponentSystem
        Initialize-InputHandler
        
        # Initialize external modules if available
        if (Get-Command -Name "Initialize-ThemeManager" -ErrorAction SilentlyContinue) {
            Initialize-ThemeManager
        }
        if (Get-Command -Name "Initialize-EventSystem" -ErrorAction SilentlyContinue) {
            Initialize-EventSystem
        }
        
        # Publish initialization event
        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
            Publish-Event -EventName "System.EngineInitialized" -Data @{ Width = $Width; Height = $Height }
        }
        
        # Export TuiState for global access
        $global:TuiState = $script:TuiState
    }
    catch {
        Write-Host "FATAL: Failed to initialize TUI Engine: $_" -ForegroundColor Red
        throw
    }
}

function global:Start-TuiLoop {
    param([hashtable]$InitialScreen)

    try {
        Initialize-TuiEngine
        
        if ($InitialScreen) {
            Push-Screen -Screen $InitialScreen
        }

        $script:TuiState.Running = $true
        while ($script:TuiState.Running) {
            # Process input queue
            $key = Process-Input
            while ($key) {
                $script:TuiState.LastActivity = [DateTime]::Now
                
                # Dialog system gets first chance at input
                $dialogHandled = $false
                if (Get-Command -Name "Handle-DialogInput" -ErrorAction SilentlyContinue) {
                    $dialogHandled = Handle-DialogInput -Key $key
                }
                
                # If not handled by dialog, pass to current screen/component
                if (-not $dialogHandled) {
                    # Component focus handling
                    if ($script:TuiState.FocusedComponent -and $script:TuiState.FocusedComponent.HandleInput) {
                        $componentResult = & $script:TuiState.FocusedComponent.HandleInput -self $script:TuiState.FocusedComponent -Key $key
                        if ($componentResult -eq $true) {
                            $key = Process-Input
                            continue
                        }
                    }
                    
                    # Screen handling
                    if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.HandleInput) {
                        $result = & $script:TuiState.CurrentScreen.HandleInput -self $script:TuiState.CurrentScreen -Key $key
                        switch ($result) {
                            "Back" { Pop-Screen }
                            "Quit" { $script:TuiState.Running = $false }
                        }
                    }
                }
                
                $key = Process-Input
            }
            
            # Update dialog system if available
            if (Get-Command -Name "Update-DialogSystem" -ErrorAction SilentlyContinue) {
                Update-DialogSystem
            }

            # Render if dirty
            if ($script:TuiState.IsDirty) {
                $bgColor = if (Get-Command -Name "Get-ThemeColor" -ErrorAction SilentlyContinue) {
                    Get-ThemeColor "Background"
                } else {
                    [ConsoleColor]::Black
                }
                
                Clear-BackBuffer -BackgroundColor $bgColor
                
                # Render current screen
                if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.Render) {
                    & $script:TuiState.CurrentScreen.Render -self $script:TuiState.CurrentScreen
                }
                
                # Render dialogs on top
                if (Get-Command -Name "Render-Dialogs" -ErrorAction SilentlyContinue) {
                    Render-Dialogs
                }
                
                # Perform optimized render
                Render-BufferOptimized
                $script:TuiState.IsDirty = $false
            }
            
            # Adaptive sleep based on activity
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

function Cleanup-TuiEngine {
    try {
        Stop-InputHandler
        [Console]::CursorVisible = $true
        [Console]::Clear()
        [Console]::ResetColor()
        
        # Publish cleanup event
        if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
            Publish-Event -EventName "System.EngineCleanup"
        }
    }
    catch {
        Write-Host "Error during TUI cleanup: $_" -ForegroundColor Red
    }
}

#endregion

#region Screen Management

function global:Push-Screen {
    param([hashtable]$Screen)
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
    
    if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
        Publish-Event -EventName "Screen.Pushed" -Data @{ ScreenName = $Screen.Name }
    }
}

function global:Pop-Screen {
    if ($script:TuiState.ScreenStack.Count -eq 0) { return $false }
    
    # Store the screen to exit before changing CurrentScreen
    $screenToExit = $script:TuiState.CurrentScreen
    
    # Pop the new screen from the stack
    $script:TuiState.CurrentScreen = $script:TuiState.ScreenStack.Pop()
    
    # Call lifecycle hooks in correct order
    if ($screenToExit -and $screenToExit.OnExit) { 
        & $screenToExit.OnExit -self $screenToExit
    }
    if ($script:TuiState.CurrentScreen -and $script:TuiState.CurrentScreen.OnResume) { 
        & $script:TuiState.CurrentScreen.OnResume -self $script:TuiState.CurrentScreen
    }
    
    Request-TuiRefresh
    
    if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
        Publish-Event -EventName "Screen.Popped" -Data @{ ScreenName = $script:TuiState.CurrentScreen.Name }
    }
    
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
            $script:TuiState.BackBuffer[$Y, $currentX] = @{ 
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
    
    # Build ANSI output with change detection
    for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
        # Position cursor at start of line
        $outputBuilder.Append("`e[$($y + 1);1H") | Out-Null
        
        for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
            $backCell = $script:TuiState.BackBuffer[$y, $x]
            $frontCell = $script:TuiState.FrontBuffer[$y, $x]
            
            # Skip if cell hasn't changed
            if ($backCell.Char -eq $frontCell.Char -and 
                $backCell.FG -eq $frontCell.FG -and 
                $backCell.BG -eq $frontCell.BG) {
                continue
            }
            
            # Position cursor if we skipped cells
            if ($x -gt 0 -and $outputBuilder.Length -gt 0) {
                $outputBuilder.Append("`e[$($y + 1);$($x + 1)H") | Out-Null
            }
            
            # Update colors if changed
            if ($backCell.FG -ne $lastFG -or $backCell.BG -ne $lastBG) {
                $fgCode = Get-AnsiColorCode $backCell.FG
                $bgCode = Get-AnsiColorCode $backCell.BG -IsBackground $true
                $outputBuilder.Append("`e[${fgCode};${bgCode}m") | Out-Null
                $lastFG = $backCell.FG
                $lastBG = $backCell.BG
            }
            
            # Append character
            $outputBuilder.Append($backCell.Char) | Out-Null
            
            # Update front buffer
            $script:TuiState.FrontBuffer[$y, $x] = $backCell.Clone()
        }
    }
    
    # Write to console using ANSI sequences
    if ($outputBuilder.Length -gt 0) {
        [Console]::Write($outputBuilder.ToString())
    }
    
    # Update stats
    $stopwatch.Stop()
    $script:TuiState.RenderStats.LastFrameTime = $stopwatch.ElapsedMilliseconds
    $script:TuiState.RenderStats.FrameCount++
    $script:TuiState.RenderStats.TotalTime += $stopwatch.ElapsedMilliseconds
}

#endregion

#region Input Handling

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
            $ps.Stop()
            $ps.EndInvoke($script:AsyncResult)
            $ps.Dispose() 
        }
    }
    foreach($rs in $script:ResourceCleanup.Runspaces) { 
        if ($rs) {
            $rs.Close()
            $rs.Dispose() 
        }
    } 
}

#endregion

#region Component System

function Initialize-ComponentSystem {
    $script:TuiState.Components = @()
    $script:TuiState.FocusedComponent = $null
}

function global:Register-Component {
    param([hashtable]$Component)
    
    # Add to component registry
    $script:TuiState.Components += $Component
    
    # Initialize component
    if ($Component.Init) {
        & $Component.Init -self $Component
    }
    
    return $Component
}

function global:Set-ComponentFocus {
    param([hashtable]$Component)
    
    # Blur previous component
    if ($script:TuiState.FocusedComponent -and $script:TuiState.FocusedComponent.OnBlur) {
        & $script:TuiState.FocusedComponent.OnBlur -self $script:TuiState.FocusedComponent
    }
    
    # Focus new component
    $script:TuiState.FocusedComponent = $Component
    if ($Component -and $Component.OnFocus) {
        & $Component.OnFocus -self $Component
    }
    
    Request-TuiRefresh
}

function global:New-Component {
    param(
        [string]$Type = "Base",
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 10,
        [int]$Height = 1,
        [hashtable]$Props = @{}
    )
    
    $component = @{
        Type = $Type
        X = $X
        Y = $Y
        Width = $Width
        Height = $Height
        Visible = $true
        Focused = $false
        Parent = $null
        Children = @()
        Props = $Props
        State = @{}
        
        # Lifecycle methods
        Init = { param($self) }
        Render = { param($self) }
        HandleInput = { param($self, $Key) return $false }
        OnFocus = { param($self) $self.Focused = $true }
        OnBlur = { param($self) $self.Focused = $false }
        Dispose = { param($self) }
    }
    
    # Merge with type-specific properties
    switch ($Type) {
        "TextInput" { $component = Merge-Hashtables $component (Get-TextInputComponent) }
        "Button" { $component = Merge-Hashtables $component (Get-ButtonComponent) }
        "List" { $component = Merge-Hashtables $component (Get-ListComponent) }
        "Table" { $component = Merge-Hashtables $component (Get-TableComponent) }
    }
    
    return $component
}

function Merge-Hashtables {
    param($Base, $Override)
    $result = $Base.Clone()
    foreach ($key in $Override.Keys) {
        $result[$key] = $Override[$key]
    }
    return $result
}

#endregion

#region Layout Management

function Initialize-LayoutEngines {
    $script:TuiState.Layouts = @{
        Grid = Get-GridLayout
        Stack = Get-StackLayout
        Dock = Get-DockLayout
    }
}

function global:Apply-Layout {
    param(
        [string]$LayoutType,
        [hashtable[]]$Components,
        [hashtable]$Options = @{}
    )
    
    if ($script:TuiState.Layouts.ContainsKey($LayoutType)) {
        $layout = $script:TuiState.Layouts[$LayoutType]
        & $layout.Apply -Components $Components -Options $Options
    }
}

function Get-GridLayout {
    return @{
        Apply = {
            param($Components, $Options)
            $cols = $Options.Columns ?? 2
            $rows = [Math]::Ceiling($Components.Count / $cols)
            $cellWidth = [Math]::Floor($script:TuiState.BufferWidth / $cols)
            $cellHeight = [Math]::Floor($script:TuiState.BufferHeight / $rows)
            
            for ($i = 0; $i -lt $Components.Count; $i++) {
                $col = $i % $cols
                $row = [Math]::Floor($i / $cols)
                $Components[$i].X = $col * $cellWidth
                $Components[$i].Y = $row * $cellHeight
                $Components[$i].Width = $cellWidth - 1
                $Components[$i].Height = $cellHeight - 1
            }
        }
    }
}

function Get-StackLayout {
    return @{
        Apply = {
            param($Components, $Options)
            $orientation = $Options.Orientation ?? "Vertical"
            $spacing = $Options.Spacing ?? 1
            $x = $Options.X ?? 0
            $y = $Options.Y ?? 0
            
            foreach ($component in $Components) {
                $component.X = $x
                $component.Y = $y
                
                if ($orientation -eq "Vertical") {
                    $y += $component.Height + $spacing
                } else {
                    $x += $component.Width + $spacing
                }
            }
        }
    }
}

function Get-DockLayout {
    return @{
        Apply = {
            param($Components, $Options)
            # Implementation for dock layout (Top, Bottom, Left, Right, Fill)
            # This is a placeholder for the full implementation
        }
    }
}

#endregion

#region Utility Functions

function global:Get-BorderChars { 
    param([string]$Style) 
    $styles = @{ 
        Single = @{ 
            TopLeft='┌'; TopRight='┐'; BottomLeft='└'; BottomRight='┘'
            Horizontal='─'; Vertical='│' 
        }
        Double = @{ 
            TopLeft='╔'; TopRight='╗'; BottomLeft='╚'; BottomRight='╝'
            Horizontal='═'; Vertical='║' 
        }
        Rounded = @{ 
            TopLeft='╭'; TopRight='╮'; BottomLeft='╰'; BottomRight='╯'
            Horizontal='─'; Vertical='│' 
        } 
    }
    return $styles[$Style] ?? $styles.Single
}

function Get-AnsiColorCode { 
    param([ConsoleColor]$Color, [bool]$IsBackground) 
    $map = @{ 
        Black=30; DarkBlue=34; DarkGreen=32; DarkCyan=36
        DarkRed=31; DarkMagenta=35; DarkYellow=33; Gray=37
        DarkGray=90; Blue=94; Green=92; Cyan=96
        Red=91; Magenta=95; Yellow=93; White=97 
    }
    $code = $map[$Color.ToString()]
    if ($IsBackground) { $code + 10 } else { $code } 
}

function global:Write-StatusLine { 
    param(
        [string]$Text, 
        [ConsoleColor]$ForegroundColor = 'White', 
        [ConsoleColor]$BackgroundColor = 'DarkBlue'
    ) 
    try { 
        $y = $script:TuiState.BufferHeight
        [Console]::SetCursorPosition(0, $y)
        [Console]::ForegroundColor = $ForegroundColor
        [Console]::BackgroundColor = $BackgroundColor
        [Console]::Write($Text.PadRight([Console]::WindowWidth))
        [Console]::ResetColor() 
    } catch {} 
}

#endregion

#region Component Definitions

function Get-TextInputComponent {
    return @{
        # State
        Value = ""
        CursorPosition = 0
        MaxLength = 50
        
        # Methods
        Render = {
            param($self)
            $borderColor = if ($self.Focused) { 
                Get-ThemeColor "Accent" -Default ([ConsoleColor]::Cyan)
            } else { 
                Get-ThemeColor "Border" -Default ([ConsoleColor]::DarkGray)
            }
            
            # Draw input box
            Write-BufferBox -X $self.X -Y $self.Y -Width $self.Width -Height $self.Height `
                -BorderColor $borderColor -BackgroundColor ([ConsoleColor]::Black)
            
            # Draw text
            $displayText = $self.Value
            if ($displayText.Length > ($self.Width - 3)) {
                $displayText = $displayText.Substring($displayText.Length - ($self.Width - 3))
            }
            Write-BufferString -X ($self.X + 1) -Y ($self.Y + 1) -Text $displayText
            
            # Draw cursor if focused
            if ($self.Focused -and $self.CursorPosition -lt ($self.Width - 3)) {
                Write-BufferString -X ($self.X + 1 + $self.CursorPosition) -Y ($self.Y + 1) `
                    -Text "_" -ForegroundColor ([ConsoleColor]::Yellow)
            }
        }
        
        HandleInput = {
            param($self, $Key)
            switch ($Key.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($self.Value.Length -gt 0 -and $self.CursorPosition -gt 0) {
                        $self.Value = $self.Value.Remove($self.CursorPosition - 1, 1)
                        $self.CursorPosition--
                    }
                    return $true
                }
                ([ConsoleKey]::Delete) {
                    if ($self.CursorPosition -lt $self.Value.Length) {
                        $self.Value = $self.Value.Remove($self.CursorPosition, 1)
                    }
                    return $true
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($self.CursorPosition -gt 0) {
                        $self.CursorPosition--
                    }
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    if ($self.CursorPosition -lt $self.Value.Length) {
                        $self.CursorPosition++
                    }
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $self.CursorPosition = 0
                    return $true
                }
                ([ConsoleKey]::End) {
                    $self.CursorPosition = $self.Value.Length
                    return $true
                }
                default {
                    if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar) -and 
                        $self.Value.Length -lt $self.MaxLength) {
                        $self.Value = $self.Value.Insert($self.CursorPosition, $Key.KeyChar)
                        $self.CursorPosition++
                        return $true
                    }
                }
            }
            return $false
        }
    }
}

function Get-ButtonComponent {
    return @{
        # State
        Text = "Button"
        
        # Methods
        Render = {
            param($self)
            $bgColor = if ($self.Focused) { 
                Get-ThemeColor "Accent" -Default ([ConsoleColor]::DarkCyan)
            } else { 
                Get-ThemeColor "Primary" -Default ([ConsoleColor]::DarkGray)
            }
            
            $text = " $($self.Text) "
            if ($text.Length > $self.Width) {
                $text = $text.Substring(0, $self.Width)
            }
            
            $x = $self.X + [Math]::Floor(($self.Width - $text.Length) / 2)
            Write-BufferString -X $x -Y $self.Y -Text $text `
                -ForegroundColor ([ConsoleColor]::White) -BackgroundColor $bgColor
        }
        
        HandleInput = {
            param($self, $Key)
            if ($Key.Key -eq [ConsoleKey]::Enter -or $Key.Key -eq [ConsoleKey]::Spacebar) {
                if ($self.OnClick) {
                    & $self.OnClick -self $self
                }
                return $true
            }
            return $false
        }
    }
}

function Get-TableComponent {
    return @{
        # State
        Data = @()
        Columns = @()
        SelectedRow = 0
        ScrollOffset = 0
        
        # Methods
        Render = {
            param($self)
            # Simplified table rendering
            $y = $self.Y
            
            # Header
            $headerText = ""
            foreach ($col in $self.Columns) {
                $headerText += $col.Name.PadRight($col.Width)
            }
            Write-BufferString -X $self.X -Y $y -Text $headerText `
                -ForegroundColor (Get-ThemeColor "Header" -Default ([ConsoleColor]::Cyan))
            $y++
            
            # Data rows
            $visibleRows = $self.Data | Select-Object -Skip $self.ScrollOffset -First ($self.Height - 1)
            $rowIndex = $self.ScrollOffset
            foreach ($row in $visibleRows) {
                $rowText = ""
                foreach ($col in $self.Columns) {
                    $value = $row.($col.Property) ?? ""
                    $rowText += $value.ToString().PadRight($col.Width)
                }
                
                $fg = if ($rowIndex -eq $self.SelectedRow) {
                    Get-ThemeColor "Selection" -Default ([ConsoleColor]::Yellow)
                } else {
                    Get-ThemeColor "Primary" -Default ([ConsoleColor]::White)
                }
                
                Write-BufferString -X $self.X -Y $y -Text $rowText -ForegroundColor $fg
                $y++
                $rowIndex++
            }
        }
    }
}

#endregion

Export-ModuleMember -Function @(
    'Start-TuiLoop', 'Request-TuiRefresh', 'Push-Screen', 'Pop-Screen',
    'Write-BufferString', 'Write-BufferBox', 'Clear-BackBuffer',
    'Write-StatusLine', 'Get-BorderChars',
    'Register-Component', 'Set-ComponentFocus', 'New-Component', 'Apply-Layout'
) -Variable @('TuiState')
