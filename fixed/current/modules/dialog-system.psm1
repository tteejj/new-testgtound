# Dialog System Module - Modal dialogs and notifications

# Initialize dialog state
$script:DialogState = @{
    DialogStack = [System.Collections.Stack]::new()
    CurrentDialog = $null
    ToastQueue = [System.Collections.Queue]::new()
    ActiveToasts = @()
}

function global:Initialize-DialogSystem {
    # Subscribe to dialog events
    Subscribe-Event -EventName "Dialog.Show" -Handler {
        param($EventData)
        Show-Dialog -DialogData $EventData.Data
    }
    
    Subscribe-Event -EventName "Notification.Show" -Handler {
        param($EventData)
        Show-NotificationToast -Data $EventData.Data
    }
    
    Subscribe-Event -EventName "Confirm.Request" -Handler {
        param($EventData)
        Show-ConfirmDialog -Data $EventData.Data
    }
}

function global:Show-NotificationToast {
    param($Data)
    
    $toast = @{
        Type = "Toast"
        Text = $Data.Text
        NotificationType = $Data.Type ?? "Info"
        Duration = $Data.Duration ?? 3000
        StartTime = [DateTime]::Now
        Id = [System.Guid]::NewGuid().ToString()
        
        Render = {
            param($self)
            
            $toastWidth = [Math]::Min(50, $self.Text.Length + 8)
            $toastHeight = 4
            $toastX = $script:TuiState.BufferWidth - $toastWidth - 2
            
            # Stack toasts vertically
            $toastIndex = $script:DialogState.ActiveToasts.IndexOf($self)
            $toastY = 2 + ($toastIndex * ($toastHeight + 1))
            
            $bgColor = switch ($self.NotificationType) {
                "Success" { Get-ThemeColor "Success" }
                "Error" { Get-ThemeColor "Error" }
                "Warning" { Get-ThemeColor "Warning" }
                default { Get-ThemeColor "Info" }
            }
            
            # Toast background
            Write-BufferBox -X $toastX -Y $toastY -Width $toastWidth -Height $toastHeight -BorderColor $bgColor
            
            # Icon and text
            $icon = switch ($self.NotificationType) {
                "Success" { "✓" }
                "Error" { "✗" }
                "Warning" { "⚠" }
                default { "ℹ" }
            }
            
            Write-BufferString -X ($toastX + 2) -Y ($toastY + 1) -Text "$icon $($self.Text)" -ForegroundColor $bgColor
            
            # Progress bar for duration
            $elapsed = ([DateTime]::Now - $self.StartTime).TotalMilliseconds
            $progress = [Math]::Min(1.0, $elapsed / $self.Duration)
            $progressWidth = [Math]::Floor(($toastWidth - 4) * (1 - $progress))
            
            if ($progressWidth -gt 0) {
                $progressBar = "█" * $progressWidth
                Write-BufferString -X ($toastX + 2) -Y ($toastY + 2) -Text $progressBar -ForegroundColor $bgColor
            }
        }
        
        ShouldClose = {
            $elapsed = ([DateTime]::Now - $this.StartTime).TotalMilliseconds
            return $elapsed -gt $this.Duration
        }
    }
    
    # Add to active toasts
    $script:DialogState.ActiveToasts += $toast
    
    # Request UI refresh
    if (Get-Command -Name "Request-TuiRefresh" -ErrorAction SilentlyContinue) {
        Request-TuiRefresh
    }
}

function global:Show-ConfirmDialog {
    param($Data)
    
    $confirmDialog = @{
        Type = "Confirm"
        Title = $Data.Title ?? "Confirm"
        Message = $Data.Message
        OnConfirm = $Data.OnConfirm
        OnCancel = $Data.OnCancel
        SelectedButton = 0  # 0 = Yes, 1 = No
        
        Render = {
            param($self)
            
            # Calculate dialog dimensions
            $dialogWidth = [Math]::Max(40, $self.Message.Length + 8)
            $dialogHeight = 8
            $dialogX = [Math]::Floor(($script:TuiState.BufferWidth - $dialogWidth) / 2)
            $dialogY = [Math]::Floor(($script:TuiState.BufferHeight - $dialogHeight) / 2)
            
            # Draw semi-transparent overlay
            for ($y = 0; $y -lt $script:TuiState.BufferHeight; $y++) {
                for ($x = 0; $x -lt $script:TuiState.BufferWidth; $x++) {
                    if ($y -ge $dialogY -and $y -lt ($dialogY + $dialogHeight) -and 
                        $x -ge $dialogX -and $x -lt ($dialogX + $dialogWidth)) {
                        continue
                    }
                    # Dim background
                    $char = $script:TuiState.Buffer[$y][$x].Char
                    if ($char -ne ' ') {
                        Write-BufferChar -X $x -Y $y -Char $char -ForegroundColor "DarkGray"
                    }
                }
            }
            
            # Dialog box
            Write-BufferBox -X $dialogX -Y $dialogY -Width $dialogWidth -Height $dialogHeight -Title " $($self.Title) " -BorderColor (Get-ThemeColor "Warning")
            
            # Clear dialog interior
            for ($y = $dialogY + 1; $y -lt ($dialogY + $dialogHeight - 1); $y++) {
                Write-BufferString -X ($dialogX + 1) -Y $y -Text (" " * ($dialogWidth - 2)) -BackgroundColor "Black"
            }
            
            # Message
            $messageY = $dialogY + 2
            $messageLines = $self.Message -split "`n"
            foreach ($line in $messageLines) {
                $centeredX = $dialogX + [Math]::Floor(($dialogWidth - $line.Length) / 2)
                Write-BufferString -X $centeredX -Y $messageY -Text $line -ForegroundColor (Get-ThemeColor "Primary")
                $messageY++
            }
            
            # Buttons
            $buttonY = $dialogY + $dialogHeight - 3
            $buttonSpacing = 10
            $buttonsWidth = 13 # "Yes" + "No" + spacing
            $buttonsX = $dialogX + [Math]::Floor(($dialogWidth - $buttonsWidth) / 2)
            
            $yesColor = if ($self.SelectedButton -eq 0) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
            $noColor = if ($self.SelectedButton -eq 1) { Get-ThemeColor "Warning" } else { Get-ThemeColor "Primary" }
            
            $yesText = if ($self.SelectedButton -eq 0) { "[Yes]" } else { " Yes " }
            $noText = if ($self.SelectedButton -eq 1) { "[No]" } else { " No " }
            
            Write-BufferString -X $buttonsX -Y $buttonY -Text $yesText -ForegroundColor $yesColor
            Write-BufferString -X ($buttonsX + $buttonSpacing) -Y $buttonY -Text $noText -ForegroundColor $noColor
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::LeftArrow) { 
                    $self.SelectedButton = 0
                    return $true 
                }
                ([ConsoleKey]::RightArrow) { 
                    $self.SelectedButton = 1
                    return $true 
                }
                ([ConsoleKey]::Tab) { 
                    $self.SelectedButton = 1 - $self.SelectedButton
                    return $true 
                }
                ([ConsoleKey]::Enter) {
                    if ($self.SelectedButton -eq 0 -and $self.OnConfirm) {
                        & $self.OnConfirm
                    } elseif ($self.SelectedButton -eq 1 -and $self.OnCancel) {
                        & $self.OnCancel
                    }
                    Close-Dialog
                    return $true
                }
                ([ConsoleKey]::Y) {
                    if ($self.OnConfirm) { & $self.OnConfirm }
                    Close-Dialog
                    return $true
                }
                ([ConsoleKey]::N) {
                    if ($self.OnCancel) { & $self.OnCancel }
                    Close-Dialog
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    if ($self.OnCancel) { & $self.OnCancel }
                    Close-Dialog
                    return $true
                }
            }
            return $false
        }
    }
    
    Push-Dialog -Dialog $confirmDialog
}

function global:Show-InputDialog {
    param($Data)
    
    $inputDialog = @{
        Type = "Input"
        Title = $Data.Title ?? "Input"
        Prompt = $Data.Prompt
        Value = $Data.DefaultValue ?? ""
        MaxLength = $Data.MaxLength ?? 50
        OnSubmit = $Data.OnSubmit
        OnCancel = $Data.OnCancel
        CursorPosition = 0
        
        Render = {
            param($self)
            
            $dialogWidth = [Math]::Max(60, $self.Prompt.Length + 4)
            $dialogHeight = 10
            $dialogX = [Math]::Floor(($script:TuiState.BufferWidth - $dialogWidth) / 2)
            $dialogY = [Math]::Floor(($script:TuiState.BufferHeight - $dialogHeight) / 2)
            
            # Dialog box
            Write-BufferBox -X $dialogX -Y $dialogY -Width $dialogWidth -Height $dialogHeight -Title " $($self.Title) " -BorderColor (Get-ThemeColor "Accent")
            
            # Prompt
            Write-BufferString -X ($dialogX + 2) -Y ($dialogY + 2) -Text $self.Prompt -ForegroundColor (Get-ThemeColor "Primary")
            
            # Input field
            $inputY = $dialogY + 4
            $inputWidth = $dialogWidth - 6
            Write-BufferString -X ($dialogX + 2) -Y $inputY -Text "[" -ForegroundColor (Get-ThemeColor "Accent")
            Write-BufferString -X ($dialogX + 3) -Y $inputY -Text $self.Value.PadRight($inputWidth) -ForegroundColor (Get-ThemeColor "Warning")
            Write-BufferString -X ($dialogX + 3 + $inputWidth) -Y $inputY -Text "]" -ForegroundColor (Get-ThemeColor "Accent")
            
            # Cursor
            if ($self.CursorPosition -lt $inputWidth) {
                $cursorX = $dialogX + 3 + $self.CursorPosition
                Write-BufferChar -X $cursorX -Y $inputY -Char "_" -ForegroundColor (Get-ThemeColor "Warning") -BackgroundColor "DarkGray"
            }
            
            # Instructions
            Write-BufferString -X ($dialogX + 2) -Y ($dialogY + $dialogHeight - 2) -Text "Enter: Submit • Esc: Cancel" -ForegroundColor (Get-ThemeColor "Subtle")
        }
        
        HandleInput = {
            param($self, $Key)
            
            switch ($Key.Key) {
                ([ConsoleKey]::Enter) {
                    if ($self.OnSubmit) {
                        & $self.OnSubmit $self.Value
                    }
                    Close-Dialog
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    if ($self.OnCancel) {
                        & $self.OnCancel
                    }
                    Close-Dialog
                    return $true
                }
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
                    if ($Key.KeyChar -and -not [char]::IsControl($Key.KeyChar) -and $self.Value.Length -lt $self.MaxLength) {
                        $self.Value = $self.Value.Insert($self.CursorPosition, $Key.KeyChar)
                        $self.CursorPosition++
                        return $true
                    }
                }
            }
            return $false
        }
    }
    
    Push-Dialog -Dialog $inputDialog
}

function Push-Dialog {
    param($Dialog)
    
    $script:DialogState.DialogStack.Push($Dialog)
    $script:DialogState.CurrentDialog = $Dialog
    
    if (Get-Command -Name "Request-TuiRefresh" -ErrorAction SilentlyContinue) {
        Request-TuiRefresh
    }
}

function Close-Dialog {
    if ($script:DialogState.DialogStack.Count -gt 0) {
        $script:DialogState.DialogStack.Pop() | Out-Null
        
        if ($script:DialogState.DialogStack.Count -gt 0) {
            $script:DialogState.CurrentDialog = $script:DialogState.DialogStack.Peek()
        } else {
            $script:DialogState.CurrentDialog = $null
        }
        
        if (Get-Command -Name "Request-TuiRefresh" -ErrorAction SilentlyContinue) {
            Request-TuiRefresh
        }
    }
}

function global:Update-DialogSystem {
    # Remove expired toasts
    $script:DialogState.ActiveToasts = @($script:DialogState.ActiveToasts | Where-Object {
        -not $_.ShouldClose.Invoke()
    })
}

function global:Render-Dialogs {
    # Render active toasts
    foreach ($toast in $script:DialogState.ActiveToasts) {
        if ($toast.Render) {
            & $toast.Render -self $toast
        }
    }
    
    # Render current modal dialog
    if ($script:DialogState.CurrentDialog -and $script:DialogState.CurrentDialog.Render) {
        & $script:DialogState.CurrentDialog.Render -self $script:DialogState.CurrentDialog
    }
}

function global:Handle-DialogInput {
    param($Key)
    
    # Modal dialogs take input priority
    if ($script:DialogState.CurrentDialog -and $script:DialogState.CurrentDialog.HandleInput) {
        return & $script:DialogState.CurrentDialog.HandleInput -self $script:DialogState.CurrentDialog -Key $Key
    }
    
    return $false
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-DialogSystem',
    'Show-NotificationToast',
    'Show-ConfirmDialog',
    'Show-InputDialog',
    'Update-DialogSystem',
    'Render-Dialogs',
    'Handle-DialogInput'
)