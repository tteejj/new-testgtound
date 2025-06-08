# Enhanced Theme System Module
# Advanced theming with gradients, effects, and visual styles

#region Theme Presets

$script:ThemePresets = @{
    "Cyberpunk" = @{
        Name = "Cyberpunk"
        Description = "Neon-lit dystopian future"
        Palette = @{
            PrimaryFG = "#FF00FF"
            SecondaryFG = "#00FFFF"
            AccentFG = "#FF1493"
            SuccessFG = "#00FF00"
            ErrorFG = "#FF0040"
            WarningFG = "#FFFF00"
            InfoFG = "#00BFFF"
            HeaderFG = "#FF00FF"
            SubtleFG = "#8B008B"
            Background = "#0D0D0D"
            
            # Data Table Colors for compatibility
            DataTable = @{
                Header = @{ FG = "#FF00FF"; BG = "#0D0D0D" }
                DataRow = @{ FG = "#00FFFF"; BG = "#0D0D0D" }
                AltRow = @{ FG = "#FF1493"; BG = "#1A1A1A" }
                Border = "#FF00FF"
            }
        }
        Effects = @{
            GlowEffect = $true
            AnimatedText = $true
            NeonBorders = $true
        }
    }
    "Matrix" = @{
        Name = "Matrix"
        Description = "Follow the white rabbit"
        Palette = @{
            PrimaryFG = "#00FF00"
            SecondaryFG = "#008F00"
            AccentFG = "#00FF00"
            SuccessFG = "#00FF00"
            ErrorFG = "#FF0000"
            WarningFG = "#FFFF00"
            InfoFG = "#00FF00"
            HeaderFG = "#00FF00"
            SubtleFG = "#004F00"
            Background = "#000000"
            
            DataTable = @{
                Header = @{ FG = "#00FF00"; BG = "#000000" }
                DataRow = @{ FG = "#00FF00"; BG = "#000000" }
                AltRow = @{ FG = "#008F00"; BG = "#111111" }
                Border = "#00FF00"
            }
        }
        Effects = @{
            MatrixRain = $true
            GreenGlow = $true
            MonoChrome = $true
        }
    }
    "Synthwave" = @{
        Name = "Synthwave"
        Description = "80s retro-futuristic vibes"
        Palette = @{
            PrimaryFG = "#FF6EC7"
            SecondaryFG = "#B967FF"
            AccentFG = "#01CDFE"
            SuccessFG = "#05FFA1"
            ErrorFG = "#FF71CE"
            WarningFG = "#FFFB96"
            InfoFG = "#01CDFE"
            HeaderFG = "#FF6EC7"
            SubtleFG = "#8B5A8F"
            Background = "#1A0033"
            
            DataTable = @{
                Header = @{ FG = "#FF6EC7"; BG = "#1A0033" }
                DataRow = @{ FG = "#01CDFE"; BG = "#1A0033" }
                AltRow = @{ FG = "#B967FF"; BG = "#2A0055" }
                Border = "#01CDFE"
            }
        }
        Effects = @{
            ChromaticAberration = $true
            RetroGrid = $true
            NeonGlow = $true
        }
    }
    "Nord" = @{
        Name = "Nord"
        Description = "Arctic, north-bluish clean and elegant"
        Palette = @{
            PrimaryFG = "#D8DEE9"
            SecondaryFG = "#E5E9F0"
            AccentFG = "#88C0D0"
            SuccessFG = "#A3BE8C"
            ErrorFG = "#BF616A"
            WarningFG = "#EBCB8B"
            InfoFG = "#81A1C1"
            HeaderFG = "#5E81AC"
            SubtleFG = "#4C566A"
            Background = "#2E3440"
            
            DataTable = @{
                Header = @{ FG = "#5E81AC"; BG = "#2E3440" }
                DataRow = @{ FG = "#D8DEE9"; BG = "#2E3440" }
                AltRow = @{ FG = "#E5E9F0"; BG = "#3B4252" }
                Border = "#88C0D0"
            }
        }
        Effects = @{
            SoftShadows = $true
            MinimalBorders = $true
            CleanDesign = $true
        }
    }
    "Dracula" = @{
        Name = "Dracula"
        Description = "Dark theme for the creatures of the night"
        Palette = @{
            PrimaryFG = "#F8F8F2"
            SecondaryFG = "#6272A4"
            AccentFG = "#BD93F9"
            SuccessFG = "#50FA7B"
            ErrorFG = "#FF5555"
            WarningFG = "#F1FA8C"
            InfoFG = "#8BE9FD"
            HeaderFG = "#FF79C6"
            SubtleFG = "#44475A"
            Background = "#282A36"
            
            DataTable = @{
                Header = @{ FG = "#FF79C6"; BG = "#282A36" }
                DataRow = @{ FG = "#F8F8F2"; BG = "#282A36" }
                AltRow = @{ FG = "#6272A4"; BG = "#44475A" }
                Border = "#BD93F9"
            }
        }
        Effects = @{
            VampireMode = $true
            PurpleAccents = $true
            DarkContrast = $true
        }
    }
    "Legacy" = @{
        Name = "Legacy"
        Description = "Classic console colors for maximum compatibility"
        Palette = @{
            PrimaryFG = "White"
            SecondaryFG = "Gray"
            AccentFG = "Magenta"
            SuccessFG = "Green"
            ErrorFG = "Red"
            WarningFG = "Yellow"
            InfoFG = "Blue"
            HeaderFG = "Cyan"
            SubtleFG = "DarkGray"
            Background = "Black"
            
            DataTable = @{
                Header = @{ FG = "Cyan"; BG = "Black" }
                DataRow = @{ FG = "White"; BG = "Black" }
                AltRow = @{ FG = "Gray"; BG = "Black" }
                Border = "Cyan"
            }
        }
        Effects = @{
            Bold = $false
            Italic = $false
            Underline = $false
            Blink = $false
        }
    }
}

# Current active theme
$script:CurrentTheme = $null

#endregion

#region Gradient Support

function global:Get-GradientText {
    param(
        [string]$Text,
        [string]$StartColor,
        [string]$EndColor,
        [switch]$Bold
    )
    
    if ($Text.Length -eq 0) { return "" }
    
    # Parse hex colors
    $startR = [Convert]::ToInt32($StartColor.Substring(1,2), 16)
    $startG = [Convert]::ToInt32($StartColor.Substring(3,2), 16)
    $startB = [Convert]::ToInt32($StartColor.Substring(5,2), 16)
    
    $endR = [Convert]::ToInt32($EndColor.Substring(1,2), 16)
    $endG = [Convert]::ToInt32($EndColor.Substring(3,2), 16)
    $endB = [Convert]::ToInt32($EndColor.Substring(5,2), 16)
    
    $result = ""
    $boldCode = if ($Bold) { "`e[1m" } else { "" }
    
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $progress = $i / [Math]::Max(1, $Text.Length - 1)
        
        $r = [Math]::Round($startR + ($endR - $startR) * $progress)
        $g = [Math]::Round($startG + ($endG - $startG) * $progress)
        $b = [Math]::Round($startB + ($endB - $startB) * $progress)
        
        $result += "${boldCode}`e[38;2;${r};${g};${b}m$($Text[$i])"
    }
    
    return $result + "`e[0m"
}

#endregion

#region Visual Effects

function global:Show-TypewriterText {
    param(
        [string]$Text,
        [int]$Delay = 50,
        [string]$Color = "#FFFFFF"
    )
    
    foreach ($char in $Text.ToCharArray()) {
        Write-Host (Apply-PSStyle -Text $char -FG $Color) -NoNewline
        Start-Sleep -Milliseconds $Delay
    }
    Write-Host
}

function global:Show-GlowText {
    param(
        [string]$Text,
        [string]$GlowColor = "#00FFFF",
        [int]$GlowIntensity = 3
    )
    
    # Simulate glow with layered text
    $r = [Convert]::ToInt32($GlowColor.Substring(1,2), 16)
    $g = [Convert]::ToInt32($GlowColor.Substring(3,2), 16)
    $b = [Convert]::ToInt32($GlowColor.Substring(5,2), 16)
    
    # Create dimmer glow layers
    for ($i = $GlowIntensity; $i -gt 0; $i--) {
        $intensity = 0.3 * ($i / $GlowIntensity)
        $dimR = [Math]::Round($r * $intensity)
        $dimG = [Math]::Round($g * $intensity)
        $dimB = [Math]::Round($b * $intensity)
        
        $glowLayer = "`e[38;2;${dimR};${dimG};${dimB}m"
        
        # Position cursor for overlay effect (simplified)
        Write-Host "${glowLayer}$Text`e[0m"
    }
    
    # Write main text
    Write-Host (Apply-PSStyle -Text $Text -FG $GlowColor -Bold)
}

function global:Show-MatrixRain {
    param(
        [int]$Duration = 5,
        [int]$Columns = 10
    )
    
    $chars = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789".ToCharArray()
    $rain = @{}
    
    for ($i = 0; $i -lt $Columns; $i++) {
        $rain[$i] = @{
            Position = Get-Random -Minimum 0 -Maximum 20
            Speed = Get-Random -Minimum 1 -Maximum 3
        }
    }
    
    $endTime = (Get-Date).AddSeconds($Duration)
    
    while ((Get-Date) -lt $endTime) {
        Clear-Host
        
        for ($row = 0; $row -lt 20; $row++) {
            for ($col = 0; $col -lt $Columns; $col++) {
                if ($rain[$col].Position -eq $row) {
                    $char = $chars | Get-Random
                    Write-Host (Apply-PSStyle -Text $char -FG "#00FF00" -Bold) -NoNewline
                } elseif ($rain[$col].Position - 1 -eq $row) {
                    $char = $chars | Get-Random
                    Write-Host (Apply-PSStyle -Text $char -FG "#00AA00") -NoNewline
                } elseif ($rain[$col].Position - 2 -eq $row) {
                    $char = $chars | Get-Random
                    Write-Host (Apply-PSStyle -Text $char -FG "#005500") -NoNewline
                } else {
                    Write-Host " " -NoNewline
                }
                Write-Host " " -NoNewline
            }
            Write-Host
        }
        
        # Update positions
        foreach ($col in $rain.Keys) {
            $rain[$col].Position += $rain[$col].Speed
            if ($rain[$col].Position -gt 25) {
                $rain[$col].Position = -2
                $rain[$col].Speed = Get-Random -Minimum 1 -Maximum 3
            }
        }
        
        Start-Sleep -Milliseconds 100
    }
}

#endregion

#region Enhanced Border Styles

function global:Draw-NeonBorder {
    param(
        [int]$Width,
        [int]$Height,
        [string]$Color = "#FF00FF",
        [string]$Title = ""
    )
    
    $neonChars = @{
        TopLeft = "╔"
        TopRight = "╗"
        BottomLeft = "╚"
        BottomRight = "╝"
        Horizontal = "═"
        Vertical = "║"
    }
    
    # Top border with optional title
    Write-Host (Apply-PSStyle -Text $neonChars.TopLeft -FG $Color) -NoNewline
    
    if ($Title) {
        $titleLength = $Title.Length + 4
        $leftPad = [Math]::Floor(($Width - $titleLength) / 2)
        $rightPad = $Width - $titleLength - $leftPad
        
        Write-Host (Apply-PSStyle -Text ($neonChars.Horizontal * $leftPad) -FG $Color) -NoNewline
        Write-Host (Apply-PSStyle -Text "[ $Title ]" -FG $Color -Bold) -NoNewline
        Write-Host (Apply-PSStyle -Text ($neonChars.Horizontal * $rightPad) -FG $Color) -NoNewline
    } else {
        Write-Host (Apply-PSStyle -Text ($neonChars.Horizontal * $Width) -FG $Color) -NoNewline
    }
    
    Write-Host (Apply-PSStyle -Text $neonChars.TopRight -FG $Color)
    
    # Side borders
    for ($i = 0; $i -lt $Height; $i++) {
        Write-Host (Apply-PSStyle -Text $neonChars.Vertical -FG $Color) -NoNewline
        Write-Host (" " * $Width) -NoNewline
        Write-Host (Apply-PSStyle -Text $neonChars.Vertical -FG $Color)
    }
    
    # Bottom border
    Write-Host (Apply-PSStyle -Text $neonChars.BottomLeft -FG $Color) -NoNewline
    Write-Host (Apply-PSStyle -Text ($neonChars.Horizontal * $Width) -FG $Color) -NoNewline
    Write-Host (Apply-PSStyle -Text $neonChars.BottomRight -FG $Color)
}

#endregion

#region Theme System Functions

function global:Initialize-ThemeSystem {
    # Set default theme based on terminal capabilities
    $defaultThemeName = "Legacy" # Safe default
    
    # Try to detect terminal capabilities
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            # PowerShell 7+ has better ANSI support
            $defaultThemeName = "Cyberpunk"
        } elseif ($env:WT_SESSION -or $env:TERM_PROGRAM -eq "vscode") {
            # Windows Terminal or VS Code
            $defaultThemeName = "Nord"
        }
    } catch {
        # Fallback to legacy if detection fails
        $defaultThemeName = "Legacy"
    }
    
    # Load theme from settings or use default (with null checks)
    $themeName = $defaultThemeName
    if ($script:Data -and $script:Data.Settings -and $script:Data.Settings.CurrentTheme) { 
        $themeName = $script:Data.Settings.CurrentTheme
    }
    
    Apply-Theme -ThemeName $themeName
}

function global:Apply-Theme {
    param(
        [string]$ThemeName
    )
    
    # Ensure theme presets are initialized
    if (-not $script:ThemePresets -or $script:ThemePresets.Count -eq 0) {
        Write-Warning "Theme presets not initialized. Using Legacy theme."
        $ThemeName = "Legacy"
    }
    
    if (-not $script:ThemePresets.ContainsKey($ThemeName)) {
        Write-Warning "Theme '$ThemeName' not found. Available themes: $($script:ThemePresets.Keys -join ', '). Using Legacy."
        $ThemeName = "Legacy"
    }
    
    $script:CurrentTheme = $script:ThemePresets[$ThemeName]
    
    # Apply theme effects
    if ($script:CurrentTheme.Effects.MatrixRain) {
        Write-Host "`nActivating Matrix mode..." -ForegroundColor Green
        Show-MatrixRain -Duration 2 -Columns 20
    }
    
    if ($script:CurrentTheme.Effects.NeonGlow) {
        Show-GlowText -Text "Theme '$ThemeName' Activated!" -GlowColor $script:CurrentTheme.Palette.AccentFG
    } else {
        Write-Success "Theme '$ThemeName' applied successfully!"
    }
    
    # Update legacy theme settings if they exist
    if ($script:Data -and $script:Data.Settings) {
        # Map new theme colors to legacy ConsoleColor names (simplified)
        $colorMap = @{
            "#FF00FF" = "Magenta"
            "#00FFFF" = "Cyan"
            "#00FF00" = "Green"
            "#FF0000" = "Red"
            "#FFFF00" = "Yellow"
            "#0000FF" = "Blue"
            "#FFFFFF" = "White"
            "#808080" = "Gray"
        }
        
        # Update legacy theme structure
        $script:Data.Settings.Theme = @{
            Header = Get-LegacyColor $script:CurrentTheme.Palette.HeaderFG
            Success = Get-LegacyColor $script:CurrentTheme.Palette.SuccessFG
            Warning = Get-LegacyColor $script:CurrentTheme.Palette.WarningFG
            Error = Get-LegacyColor $script:CurrentTheme.Palette.ErrorFG
            Info = Get-LegacyColor $script:CurrentTheme.Palette.InfoFG
            Accent = Get-LegacyColor $script:CurrentTheme.Palette.AccentFG
            Subtle = Get-LegacyColor $script:CurrentTheme.Palette.SubtleFG
        }
        
        $script:Data.Settings.CurrentTheme = $ThemeName
        Save-UnifiedData
    }
}

function global:Get-ThemeProperty {
    param([string]$Path)
    
    if (-not $script:CurrentTheme) {
        # Fallback to legacy colors
        switch ($Path) {
            "Palette.HeaderFG" { return "Cyan" }
            "Palette.SuccessFG" { return "Green" }
            "Palette.ErrorFG" { return "Red" }
            "Palette.WarningFG" { return "Yellow" }
            "Palette.InfoFG" { return "Blue" }
            "Palette.AccentFG" { return "Magenta" }
            "Palette.SubtleFG" { return "DarkGray" }
            "Palette.PrimaryFG" { return "White" }
            "Palette.SecondaryFG" { return "Gray" }
            "DataTable.Header.FG" { return "Cyan" }
            "DataTable.DataRow.FG" { return "White" }
            "DataTable.AltRow.FG" { return "Gray" }
            "DataTable.DataRow.BG" { return $null }
            "DataTable.AltRow.BG" { return $null }
            default { return "White" }
        }
    }
    
    # Navigate the theme structure using the path
    $parts = $Path -split '\.'
    $current = $script:CurrentTheme
    
    foreach ($part in $parts) {
        if ($current -is [hashtable] -and $current.ContainsKey($part)) {
            $current = $current[$part]
        } else {
            # Return a sensible fallback
            return "White"
        }
    }
    
    return $current
}

function global:Get-LegacyColor {
    param([string]$Color)
    
    # Convert hex colors to nearest console color
    if ($Color -match '^#[0-9A-Fa-f]{6}$') {
        $colorMappings = @{
            # Reds
            '#FF073A' = 'Red'
            '#DC143C' = 'Red'
            '#FF6347' = 'Red'
            '#FF0040' = 'Red'
            '#FF5555' = 'Red'
            '#FF71CE' = 'Red'
            '#BF616A' = 'Red'
            
            # Greens  
            '#00FF00' = 'Green'
            '#39FF14' = 'Green'
            '#32CD32' = 'Green'
            '#228B22' = 'Green'
            '#05FFA1' = 'Green'
            '#50FA7B' = 'Green'
            '#A3BE8C' = 'Green'
            
            # Blues
            '#00FFFF' = 'Cyan'
            '#1E90FF' = 'Blue'
            '#4169E1' = 'Blue'
            '#4682B4' = 'Blue'
            '#00BFFF' = 'Blue'
            '#01CDFE' = 'Cyan'
            '#8BE9FD' = 'Cyan'
            '#81A1C1' = 'Blue'
            '#88C0D0' = 'Cyan'
            '#5E81AC' = 'Blue'
            
            # Yellows/Oranges
            '#FFFF00' = 'Yellow'
            '#FFD700' = 'Yellow'
            '#FF8C00' = 'Yellow'
            '#FF6D00' = 'Yellow'
            '#FFFB96' = 'Yellow'
            '#F1FA8C' = 'Yellow'
            '#EBCB8B' = 'Yellow'
            
            # Purples/Magentas
            '#FF1493' = 'Magenta'
            '#FF00FF' = 'Magenta'
            '#BD93F9' = 'Magenta'
            '#B967FF' = 'Magenta'
            '#FF6EC7' = 'Magenta'
            '#FF79C6' = 'Magenta'
            
            # Grays
            '#666666' = 'DarkGray'
            '#708090' = 'DarkGray'
            '#696969' = 'DarkGray'
            '#8B008B' = 'DarkMagenta'
            '#4C566A' = 'DarkGray'
            '#44475A' = 'DarkGray'
            '#6272A4' = 'DarkGray'
            
            # Whites
            '#E0F6FF' = 'White'
            '#F5DEB3' = 'White'
            '#F8F8F2' = 'White'
            '#D8DEE9' = 'White'
            '#E5E9F0' = 'White'
            '#87CEEB' = 'Gray'
            '#DEB887' = 'Gray'
        }
        
        if ($colorMappings.ContainsKey($Color)) { 
            return $colorMappings[$Color] 
        } else { 
            return 'White' 
        }
    }
    
    # If it's already a console color name, return as-is
    return $Color
}

function global:Apply-PSStyle {
    param(
        [string]$Text,
        [string]$FG,
        [string]$BG,
        [switch]$Bold,
        [switch]$Italic,
        [switch]$Underline,
        [switch]$Blink
    )
    
    # Check if we can use ANSI escape sequences
    if ($PSVersionTable.PSVersion.Major -ge 7 -and $script:CurrentTheme.Name -ne "Legacy") {
        try {
            # Use PSStyle for PowerShell 7+
            $styledText = $Text
            
            if ($FG -and $FG -match '^#[0-9A-Fa-f]{6}$') {
                $styledText = "$($PSStyle.Foreground.FromRgb($FG))$styledText"
            } elseif ($FG) {
                # Use ANSI color codes for named colors
                $ansiCode = Get-AnsiColor -Color $FG -Foreground
                if ($ansiCode) {
                    $styledText = "$ansiCode$styledText"
                }
            }
            
            if ($BG -and $BG -match '^#[0-9A-Fa-f]{6}$') {
                $styledText = "$($PSStyle.Background.FromRgb($BG))$styledText"
            } elseif ($BG) {
                $ansiCode = Get-AnsiColor -Color $BG -Background
                if ($ansiCode) {
                    $styledText = "$ansiCode$styledText"
                }
            }
            
            if ($Bold) { $styledText = "$($PSStyle.Bold)$styledText" }
            if ($Italic) { $styledText = "$($PSStyle.Italic)$styledText" }
            if ($Underline) { $styledText = "$($PSStyle.Underline)$styledText" }
            if ($Blink) { $styledText = "$($PSStyle.Blink)$styledText" }
            
            # Add reset at the end
            $styledText = "$styledText$($PSStyle.Reset)"
            
            return $styledText
        } catch {
            # Fallback to plain text if PSStyle fails
            return $Text
        }
    } else {
        # Fallback for older PowerShell or Legacy theme
        return $Text
    }
}

function global:Get-AnsiColor {
    param(
        [string]$Color,
        [switch]$Foreground,
        [switch]$Background
    )
    
    $colorCodes = @{
        'Black' = '0'
        'Red' = '1'
        'Green' = '2'
        'Yellow' = '3'
        'Blue' = '4'
        'Magenta' = '5'
        'Cyan' = '6'
        'White' = '7'
        'DarkGray' = '8'
        'Gray' = '8'
    }
    
    $code = $colorCodes[$Color]
    if (-not $code) { return $null }
    
    $prefix = if ($Foreground) { '3' } else { '4' }
    return "`e[${prefix}${code}m"
}

function global:Get-BorderStyleChars {
    param([string]$Style = "Single")
    
    # Enhanced border styles
    $borderStyles = @{
        Single = @{
            TopLeft = "┌"; TopRight = "┐"; BottomLeft = "└"; BottomRight = "┘"
            Horizontal = "─"; Vertical = "│"; Cross = "┼"; TLeft = "├"; TRight = "┤"
            TTop = "┬"; TBottom = "┴"
        }
        Double = @{
            TopLeft = "╔"; TopRight = "╗"; BottomLeft = "╚"; BottomRight = "╝"
            Horizontal = "═"; Vertical = "║"; Cross = "╬"; TLeft = "╠"; TRight = "╣"
            TTop = "╦"; TBottom = "╩"
        }
        Rounded = @{
            TopLeft = "╭"; TopRight = "╮"; BottomLeft = "╰"; BottomRight = "╯"
            Horizontal = "─"; Vertical = "│"; Cross = "┼"; TLeft = "├"; TRight = "┤"
            TTop = "┬"; TBottom = "┴"
        }
        Heavy = @{
            TopLeft = "┏"; TopRight = "┓"; BottomLeft = "┗"; BottomRight = "┛"
            Horizontal = "━"; Vertical = "┃"; Cross = "╋"; TLeft = "┣"; TRight = "┫"
            TTop = "┳"; TBottom = "┻"
        }
        Shadow = @{
            TopLeft = "┏"; TopRight = "┓"; BottomLeft = "┗"; BottomRight = "┛"
            Horizontal = "━"; Vertical = "┃"; Cross = "╋"; TLeft = "┣"; TRight = "┫"
            TTop = "┳"; TBottom = "┻"; Shadow = "░"
        }
        ASCII = @{
            TopLeft = "+"; TopRight = "+"; BottomLeft = "+"; BottomRight = "+"
            Horizontal = "-"; Vertical = "|"; Cross = "+"; TLeft = "+"; TRight = "+"
            TTop = "+"; TBottom = "+"
        }
    }
    
    if ($borderStyles.ContainsKey($Style)) {
        return $borderStyles[$Style]
    }
    return $borderStyles.Single
}

#endregion

#region Theme Selection UI

function global:Select-Theme {
    Write-Header "Theme Gallery"
    
    Write-Host (Get-GradientText -Text "Choose your visual style:" -StartColor "#FF00FF" -EndColor "#00FFFF" -Bold)
    Write-Host
    
    $themes = @()
    foreach ($themeName in $script:ThemePresets.Keys) {
        $theme = $script:ThemePresets[$themeName]
        $themes += @{
            Name = $themeName
            Preview = {
                Draw-NeonBorder -Width 40 -Height 3 -Color $theme.Palette.AccentFG -Title $theme.Name
                [Console]::SetCursorPosition(2, [Console]::CursorTop - 3)
                Write-Host $theme.Description
                [Console]::SetCursorPosition(2, [Console]::CursorTop + 1)
                Write-Host "Primary: " -NoNewline
                Write-Host "████" -ForegroundColor White -BackgroundColor Black -NoNewline
                Write-Host " Accent: " -NoNewline
                Write-Host "████" -ForegroundColor White -BackgroundColor Black
                [Console]::SetCursorPosition(0, [Console]::CursorTop + 1)
            }
        }
    }
    
    for ($i = 0; $i -lt $themes.Count; $i++) {
        Write-Host "`n[$($i + 1)] " -NoNewline -ForegroundColor Yellow
        & $themes[$i].Preview
    }
    
    Write-Host "`n[C] Create Custom Theme"
    Write-Host "[R] Reset to Default"
    Write-Host "[B] Back to Settings"
    
    $choice = Read-Host "`nSelect theme"
    
    if ($choice -match '^\d+$') {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $themes.Count) {
            Apply-Theme -ThemeName $themes[$index].Name
        }
    } elseif ($choice -eq 'R') {
        Apply-Theme -ThemeName "Legacy"
    }
}

#endregion

#region Status Badges

function global:Get-StatusBadge {
    param(
        [string]$Status,
        [switch]$Animated
    )
    
    $badges = @{
        "Active" = @{ Text = "● ACTIVE"; Color = "#00FF00"; Blink = $true }
        "Paused" = @{ Text = "‖ PAUSED"; Color = "#FFFF00"; Blink = $false }
        "Completed" = @{ Text = "✓ DONE"; Color = "#808080"; Blink = $false }
        "Overdue" = @{ Text = "⚠ OVERDUE"; Color = "#FF0000"; Blink = $true }
        "InProgress" = @{ Text = "▶ RUNNING"; Color = "#00BFFF"; Blink = $true }
        "Scheduled" = @{ Text = "◷ SCHEDULED"; Color = "#B967FF"; Blink = $false }
    }
    
    if ($badges.ContainsKey($Status)) {
        $badge = $badges[$Status]
        if ($Animated -and $badge.Blink) {
            # Blinking effect
            return "`e[5m$(Apply-PSStyle -Text $badge.Text -FG $badge.Color -Bold)`e[25m"
        } else {
            return Apply-PSStyle -Text $badge.Text -FG $badge.Color -Bold
        }
    }
    
    return $Status
}

#endregion

#region ASCII Art Headers

function global:Show-AsciiLogo {
    param(
        [string]$Style = "3D"
    )
    
    $logos = @{
        "3D" = @"
    ╔═╗╦═╗╔═╗╔╦╗╦ ╦╔═╗╔╦╗╦╦  ╦╦╔╦╗╦ ╦
    ╠═╝╠╦╝║ ║ ║║║ ║║   ║ ║╚╗╔╝║ ║ ╚╦╝
    ╩  ╩╚═╚═╝═╩╝╚═╝╚═╝ ╩ ╩ ╚╝ ╩ ╩  ╩ 
"@
        "Fire" = @"
     (  (                    )   (      )  
     )\))(   '   (       ( /(   )\ ) ( /(  
    ((_)()\ )  ( )\  (   )\()) (()/(  )\()) 
    _(())\_)() )((_) )\ (_))/   /(_))(_))/  
    \ \((_)/ /((_)_ ((_)| |_   (_))  | |_   
     \ \/\/ / / _` |(_-<|  _|  / -_) |  _|  
      \_/\_/  \__,_|/__/ \__|  \___|  \__|  
"@
        "Digital" = @"
    01110000 01110010 01101111 01100100
    01110101 01100011 01110100 01101001
    01110110 01101001 01110100 01111001
"@
    }
    
    if ($logos.ContainsKey($Style)) {
        $lines = $logos[$Style] -split "`n"
        foreach ($line in $lines) {
            Write-Host (Get-GradientText -Text $line -StartColor "#FF00FF" -EndColor "#00FFFF")
        }
    }
}

#endregion

#region Legacy Support Functions

function global:Write-Header {
    param([string]$Text)
    
    $headerColor = Get-LegacyColor (Get-ThemeProperty "Palette.HeaderFG")
    Write-Host "`n$Text" -ForegroundColor $headerColor
    Write-Host ("=" * $Text.Length) -ForegroundColor $headerColor
}

function global:Write-Success {
    param([string]$Text)
    
    $successColor = Get-LegacyColor (Get-ThemeProperty "Palette.SuccessFG")
    Write-Host "✓ $Text" -ForegroundColor $successColor
}

function global:Write-Warning {
    param([string]$Text)
    
    $warningColor = Get-LegacyColor (Get-ThemeProperty "Palette.WarningFG")
    Write-Host "⚠ $Text" -ForegroundColor $warningColor
}

function global:Write-Error {
    param([string]$Text)
    
    $errorColor = Get-LegacyColor (Get-ThemeProperty "Palette.ErrorFG")
    Write-Host "✗ $Text" -ForegroundColor $errorColor
}

function global:Write-Info {
    param([string]$Text)
    
    $infoColor = Get-LegacyColor (Get-ThemeProperty "Palette.InfoFG")
    Write-Host "ℹ $Text" -ForegroundColor $infoColor
}

#endregion

#region Theme Management Functions

function global:Show-ThemeSelector {
    Write-Header "Theme Selection"
    
    Write-Host "Available Themes:" -ForegroundColor Yellow
    $themeNames = $script:ThemePresets.Keys | Sort-Object
    
    for ($i = 0; $i -lt $themeNames.Count; $i++) {
        $themeName = $themeNames[$i]
        $theme = $script:ThemePresets[$themeName]
        $current = if ($script:CurrentTheme.Name -eq $themeName) { " (Current)" } else { "" }
        Write-Host "  [$($i + 1)] $themeName$current" -ForegroundColor (Get-LegacyColor $theme.Palette.AccentFG)
        Write-Host "      $($theme.Description)" -ForegroundColor DarkGray
    }
    
    Write-Host "`n[T] Test Current Theme  [R] Reset to Default  [B] Back" -ForegroundColor Yellow
    
    $choice = Read-Host "`nSelect theme number or option"
    
    if ($choice.ToUpper() -eq 'T') {
        Test-CurrentTheme
    } elseif ($choice.ToUpper() -eq 'R') {
        Apply-Theme -ThemeName "Legacy"
    } elseif ($choice.ToUpper() -eq 'B') {
        return
    } elseif ($choice -match '^\d+$') {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $themeNames.Count) {
            Apply-Theme -ThemeName $themeNames[$index]
            Test-CurrentTheme
        } else {
            Write-Warning "Invalid selection."
        }
    } else {
        Write-Warning "Invalid choice."
    }
}

function global:Test-CurrentTheme {
    Write-Header "Theme Test - $($script:CurrentTheme.Name)"
    
    Write-Host "Primary Text" -ForegroundColor (Get-LegacyColor (Get-ThemeProperty "Palette.PrimaryFG"))
    Write-Host "Secondary Text" -ForegroundColor (Get-LegacyColor (Get-ThemeProperty "Palette.SecondaryFG"))
    Write-Host "Accent Text" -ForegroundColor (Get-LegacyColor (Get-ThemeProperty "Palette.AccentFG"))
    Write-Host ""
    
    Write-Success "Success message"
    Write-Error "Error message"
    Write-Warning "Warning message"
    Write-Info "Info message"
    
    Write-Host "`nSample Table:" -ForegroundColor (Get-LegacyColor (Get-ThemeProperty "Palette.HeaderFG"))
    
    # Test table rendering
    $sampleData = @(
        [PSCustomObject]@{ Name = "Project Alpha"; Status = "Active"; Progress = 75 }
        [PSCustomObject]@{ Name = "Project Beta"; Status = "Completed"; Progress = 100 }
        [PSCustomObject]@{ Name = "Project Gamma"; Status = "Pending"; Progress = 25 }
    )
    
    $sampleData | Format-TableUnicode -Title "Sample Projects"
    
    Write-Host "`nPress any key to continue..." -ForegroundColor (Get-LegacyColor (Get-ThemeProperty "Palette.SubtleFG"))
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function global:Edit-ThemeSettings {
    Write-Header "Theme Settings"
    
    if (-not $script:Data.Settings.Theme) {
        $script:Data.Settings.Theme = @{
            Header = "Cyan"; Success = "Green"; Warning = "Yellow"
            Error = "Red"; Info = "Blue"; Accent = "Magenta"; Subtle = "DarkGray"
        }
    }
    
    Write-Host "Current Theme: $($script:CurrentTheme.Name)" -ForegroundColor Yellow
    Write-Host "`nTheme Management Options:" -ForegroundColor Yellow
    Write-Host "[1] Change Theme"
    Write-Host "[2] Test Current Theme" 
    Write-Host "[3] Reset to Default Theme"
    Write-Host "[4] View Theme Details"
    Write-Host "[B] Back"
    
    $choice = Read-Host "`nChoice"
    
    switch ($choice.ToUpper()) {
        "1" { Show-ThemeSelector }
        "2" { Test-CurrentTheme }
        "3" { Apply-Theme -ThemeName "Legacy" }
        "4" { Show-ThemeDetails }
        "B" { return }
        default { Write-Warning "Invalid choice." }
    }
    
    Save-UnifiedData
}

function global:Show-ThemeDetails {
    Write-Header "Theme Details - $($script:CurrentTheme.Name)"
    
    Write-Host $script:CurrentTheme.Description -ForegroundColor Gray
    Write-Host "`nColor Palette:" -ForegroundColor Yellow
    
    foreach ($colorKey in $script:CurrentTheme.Palette.Keys) {
        if ($colorKey -ne "DataTable") {
            $color = $script:CurrentTheme.Palette[$colorKey]
            $legacyColor = Get-LegacyColor $color
            Write-Host "  $colorKey`: $color" -ForegroundColor $legacyColor
        }
    }
    
    Write-Host "`nEffects:" -ForegroundColor Yellow
    foreach ($effectKey in $script:CurrentTheme.Effects.Keys) {
        $enabled = if ($script:CurrentTheme.Effects[$effectKey]) { "Enabled" } else { "Disabled" }
        Write-Host "  $effectKey`: $enabled"
    }
    
    Write-Host "`nPress any key to continue..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

#endregion