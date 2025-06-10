# Demo Screen Module - Simplified
# Showcases TUI components

function global:Get-DemoScreen {
    $screen = @{
        Name = "DemoScreen"
        State = @{
            CurrentDemo = 0
            Demos = @("Input", "Table", "Notifications")
            TextValue = "Hello!"
            TableData = @(
                [PSCustomObject]@{ ID = 1; Name = "Alice"; Dept = "IT" }
                [PSCustomObject]@{ ID = 2; Name = "Bob"; Dept = "HR" }
            )
        }
        
        Render = {
            param($self)
            
            # Header
            Write-BufferBox -X 2 -Y 1 -Width 76 -Height 3 -Title " Component Demo "
            Write-BufferString -X 4 -Y 2 -Text "Use ← → to switch demos, Q to quit"
            
            # Demo content
            $demo = $self.State.Demos[$self.State.CurrentDemo]
            Write-BufferString -X 4 -Y 5 -Text "Current: $demo" -ForegroundColor (Get-ThemeColor "Accent")
            
            switch ($demo) {
                "Input" {
                    Write-BufferString -X 4 -Y 7 -Text "TextBox Demo:"
                    Write-BufferBox -X 4 -Y 9 -Width 30 -Height 3
                    Write-BufferString -X 6 -Y 10 -Text $self.State.TextValue
                }
                "Table" {
                    Write-BufferString -X 4 -Y 7 -Text "Simple Table:"
                    Write-BufferBox -X 4 -Y 9 -Width 40 -Height 6
                    Write-BufferString -X 6 -Y 10 -Text "ID  Name   Dept"
                    $y = 11
                    foreach ($row in $self.State.TableData) {
                        Write-BufferString -X 6 -Y $y -Text "$($row.ID)   $($row.Name.PadRight(7)) $($row.Dept)"
                        $y++
                    }
                }
                "Notifications" {
                    Write-BufferString -X 4 -Y 7 -Text "Press N to show notification"
                }
            }
        }
        
        HandleInput = {
            param($self, $Key)
            switch ($Key.Key) {
                ([ConsoleKey]::Q) { return "Quit" }
                ([ConsoleKey]::LeftArrow) {
                    if ($self.State.CurrentDemo -gt 0) {
                        $self.State.CurrentDemo--
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    if ($self.State.CurrentDemo -lt 2) {
                        $self.State.CurrentDemo++
                        Request-TuiRefresh
                    }
                    return $true
                }
                ([ConsoleKey]::N) {
                    if ($self.State.Demos[$self.State.CurrentDemo] -eq "Notifications") {
                        Show-TuiNotification -Message "Demo notification!" -Type "Success"
                    }
                    return $true
                }
            }
            return $false
        }
    }
    
    return $screen
}

Export-ModuleMember -Function 'Get-DemoScreen'
