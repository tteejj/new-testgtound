# Theme Manager Module - Advanced theming system for TUI

# Initialize theme state
$script:Themes = @{
    Default = @{
        Name = "Default"
        Colors = @{
            Background = "Black"
            Primary = "White"
            Secondary = "Gray"
            Accent = "Cyan"
            Header = "Yellow"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Info = "Blue"
            Subtle = "DarkGray"
            Border = "DarkCyan"
            Selected = "Yellow"
            Highlight = "Magenta"
        }
        Borders = @{
            Style = "Single"  # Single, Double, Rounded, ASCII
            Characters = @{
                TopLeft = "┌"
                TopRight = "┐"
                BottomLeft = "└"
                BottomRight = "┘"
                Horizontal = "─"
                Vertical = "│"
                Cross = "┼"
                TeeLeft = "├"
                TeeRight = "┤"
                TeeTop = "┬"
                TeeBottom = "┴"
            }
        }
    }
    
    Dark = @{
        Name = "Dark"
        Colors = @{
            Background = "Black"
            Primary = "Gray"
            Secondary = "DarkGray"
            Accent = "DarkCyan"
            Header = "DarkYellow"
            Success = "DarkGreen"
            Warning = "DarkYellow"
            Error = "DarkRed"
            Info = "DarkBlue"
            Subtle = "DarkGray"
            Border = "DarkGray"
            Selected = "Yellow"
            Highlight = "DarkMagenta"
        }
        Borders = @{
            Style = "Single"
            Characters = @{
                TopLeft = "┌"
                TopRight = "┐"
                BottomLeft = "└"
                BottomRight = "┘"
                Horizontal = "─"
                Vertical = "│"
                Cross = "┼"
                TeeLeft = "├"
                TeeRight = "┤"
                TeeTop = "┬"
                TeeBottom = "┴"
            }
        }
    }
    
    Light = @{
        Name = "Light"
        Colors = @{
            Background = "White"
            Primary = "Black"
            Secondary = "DarkGray"
            Accent = "Blue"
            Header = "DarkBlue"
            Success = "DarkGreen"
            Warning = "DarkYellow"
            Error = "Red"
            Info = "Blue"
            Subtle = "Gray"
            Border = "DarkBlue"
            Selected = "Blue"
            Highlight = "Magenta"
        }
        Borders = @{
            Style = "Double"
            Characters = @{
                TopLeft = "╔"
                TopRight = "╗"
                BottomLeft = "╚"
                BottomRight = "╝"
                Horizontal = "═"
                Vertical = "║"
                Cross = "╬"
                TeeLeft = "╠"
                TeeRight = "╣"
                TeeTop = "╦"
                TeeBottom = "╩"
            }
        }
    }
    
    Matrix = @{
        Name = "Matrix"
        Colors = @{
            Background = "Black"
            Primary = "Green"
            Secondary = "DarkGreen"
            Accent = "Green"
            Header = "Green"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Info = "Green"
            Subtle = "DarkGreen"
            Border = "DarkGreen"
            Selected = "White"
            Highlight = "Green"
        }
        Borders = @{
            Style = "ASCII"
            Characters = @{
                TopLeft = "+"
                TopRight = "+"
                BottomLeft = "+"
                BottomRight = "+"
                Horizontal = "-"
                Vertical = "|"
                Cross = "+"
                TeeLeft = "+"
                TeeRight = "+"
                TeeTop = "+"
                TeeBottom = "+"
            }
        }
    }
    
    Neon = @{
        Name = "Neon"
        Colors = @{
            Background = "Black"
            Primary = "Cyan"
            Secondary = "Blue"
            Accent = "Magenta"
            Header = "Yellow"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Info = "Cyan"
            Subtle = "DarkBlue"
            Border = "Magenta"
            Selected = "Yellow"
            Highlight = "White"
        }
        Borders = @{
            Style = "Rounded"
            Characters = @{
                TopLeft = "╭"
                TopRight = "╮"
                BottomLeft = "╰"
                BottomRight = "╯"
                Horizontal = "─"
                Vertical = "│"
                Cross = "┼"
                TeeLeft = "├"
                TeeRight = "┤"
                TeeTop = "┬"
                TeeBottom = "┴"
            }
        }
    }
}

# Current theme
$script:CurrentTheme = "Default"

function global:Initialize-ThemeManager {
    # Load theme preference from settings if available
    if ($script:Data -and $script:Data.Settings -and $script:Data.Settings.Theme) {
        $themeName = $script:Data.Settings.Theme
        if ($script:Themes.ContainsKey($themeName)) {
            $script:CurrentTheme = $themeName
        }
    }
    
    # Subscribe to theme change events
    Subscribe-Event -EventName "Theme.Change" -Handler {
        param($EventData)
        Set-Theme -ThemeName $EventData.Data.ThemeName
    }
}

function global:Get-ThemeColor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ColorType
    )
    
    $theme = $script:Themes[$script:CurrentTheme]
    if ($theme.Colors.ContainsKey($ColorType)) {
        return $theme.Colors[$ColorType]
    }
    
    # Fallback to primary color
    return $theme.Colors.Primary
}

function global:Get-BorderCharacter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CharacterType
    )
    
    $theme = $script:Themes[$script:CurrentTheme]
    if ($theme.Borders.Characters.ContainsKey($CharacterType)) {
        return $theme.Borders.Characters[$CharacterType]
    }
    
    # Fallback to basic ASCII
    switch ($CharacterType) {
        "TopLeft" { return "+" }
        "TopRight" { return "+" }
        "BottomLeft" { return "+" }
        "BottomRight" { return "+" }
        "Horizontal" { return "-" }
        "Vertical" { return "|" }
        default { return "+" }
    }
}

function global:Set-Theme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThemeName
    )
    
    if ($script:Themes.ContainsKey($ThemeName)) {
        $script:CurrentTheme = $ThemeName
        
        # Save preference
        if ($script:Data -and $script:Data.Settings) {
            $script:Data.Settings.Theme = $ThemeName
            Save-UnifiedData
        }
        
        # Notify UI to refresh
        if (Get-Command -Name "Request-TuiRefresh" -ErrorAction SilentlyContinue) {
            Request-TuiRefresh
        }
        
        Publish-Event -EventName "Notification.Show" -Data @{ 
            Text = "Theme changed to: $ThemeName"
            Type = "Success" 
        }
    }
    else {
        Publish-Event -EventName "Notification.Show" -Data @{ 
            Text = "Unknown theme: $ThemeName"
            Type = "Error" 
        }
    }
}

function global:Get-AvailableThemes {
    return $script:Themes.Keys | Sort-Object
}

function global:Get-CurrentTheme {
    return $script:CurrentTheme
}

function global:Add-CustomTheme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThemeName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$ThemeDefinition
    )
    
    # Validate theme definition
    $requiredColors = @("Background", "Primary", "Secondary", "Accent")
    foreach ($color in $requiredColors) {
        if (-not $ThemeDefinition.Colors.ContainsKey($color)) {
            throw "Theme definition must include color: $color"
        }
    }
    
    # Add theme
    $script:Themes[$ThemeName] = $ThemeDefinition
    
    Publish-Event -EventName "Notification.Show" -Data @{ 
        Text = "Custom theme added: $ThemeName"
        Type = "Success" 
    }
}

function global:Export-Theme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThemeName,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if ($script:Themes.ContainsKey($ThemeName)) {
        $theme = $script:Themes[$ThemeName]
        $theme | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        
        Publish-Event -EventName "Notification.Show" -Data @{ 
            Text = "Theme exported to: $Path"
            Type = "Success" 
        }
    }
    else {
        throw "Theme not found: $ThemeName"
    }
}

function global:Import-Theme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (Test-Path $Path) {
        $themeData = Get-Content $Path -Raw | ConvertFrom-Json
        $themeName = $themeData.Name ?? [System.IO.Path]::GetFileNameWithoutExtension($Path)
        
        Add-CustomTheme -ThemeName $themeName -ThemeDefinition $themeData
    }
    else {
        throw "Theme file not found: $Path"
    }
}

# Color utility functions
function global:Get-AnsiColor {
    param(
        [string]$ColorName,
        [switch]$Background
    )
    
    $ansiColors = @{
        Black = 30
        Red = 31
        Green = 32
        Yellow = 33
        Blue = 34
        Magenta = 35
        Cyan = 36
        White = 37
        Gray = 37
        DarkGray = 90
        DarkRed = 91
        DarkGreen = 92
        DarkYellow = 93
        DarkBlue = 94
        DarkMagenta = 95
        DarkCyan = 96
    }
    
    $colorCode = $ansiColors[$ColorName] ?? 37
    if ($Background) {
        $colorCode += 10
    }
    
    return "`e[${colorCode}m"
}

function global:Reset-AnsiColor {
    return "`e[0m"
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-ThemeManager',
    'Get-ThemeColor',
    'Get-BorderCharacter',
    'Set-Theme',
    'Get-AvailableThemes',
    'Get-CurrentTheme',
    'Add-CustomTheme',
    'Export-Theme',
    'Import-Theme',
    'Get-AnsiColor',
    'Reset-AnsiColor'
)