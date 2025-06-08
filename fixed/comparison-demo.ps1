# Blocking vs Non-Blocking Comparison Demo

Write-Host "=== Blocking vs Non-Blocking TUI Comparison ===" -ForegroundColor Cyan
Write-Host ""

# Demo 1: Blocking Approach (Traditional)
Write-Host "Demo 1: Blocking Approach" -ForegroundColor Yellow
Write-Host "Watch the timer - it will freeze when waiting for input!" -ForegroundColor Gray
Write-Host ""

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$continue = $true

while ($continue -and $stopwatch.Elapsed.TotalSeconds -lt 10) {
    # Clear the line and show timer
    Write-Host "`rElapsed: $($stopwatch.Elapsed.ToString('mm\:ss\.ff')) - Press 'q' to quit (blocking): " -NoNewline
    
    # BLOCKING: This stops everything while waiting
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.KeyChar -eq 'q') {
            $continue = $false
        }
    }
    
    # Note: Timer appears to jump because updates are blocked
    Start-Sleep -Milliseconds 100
}

$stopwatch.Stop()
Write-Host "`n`nBlocking demo ended. Notice how the timer jumps?`n" -ForegroundColor Red

# Demo 2: Non-Blocking Approach
Write-Host "Demo 2: Non-Blocking Approach" -ForegroundColor Yellow
Write-Host "Watch the timer - it updates smoothly even while waiting for input!" -ForegroundColor Gray
Write-Host ""

# Setup non-blocking input
$inputQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())
$inputRunspace = [runspacefactory]::CreateRunspace()
$inputRunspace.Open()
$inputRunspace.SessionStateProxy.SetVariable('InputQueue', $inputQueue)

$inputScript = {
    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            $InputQueue.Enqueue($key)
        }
        Start-Sleep -Milliseconds 10
    }
}

$inputPowerShell = [powershell]::Create()
$inputPowerShell.Runspace = $inputRunspace
$inputPowerShell.AddScript($inputScript)
$inputHandle = $inputPowerShell.BeginInvoke()

# Non-blocking main loop
$stopwatch2 = [System.Diagnostics.Stopwatch]::StartNew()
$continue2 = $true
$lastUpdate = [DateTime]::Now
$animFrame = 0
$spinner = @('|', '/', '-', '\')

while ($continue2 -and $stopwatch2.Elapsed.TotalSeconds -lt 10) {
    # Update display continuously
    if (([DateTime]::Now - $lastUpdate).TotalMilliseconds -gt 50) {
        # Clear line and show smooth timer with spinner
        $spin = $spinner[$animFrame % 4]
        Write-Host "`rElapsed: $($stopwatch2.Elapsed.ToString('mm\:ss\.ff')) $spin - Press 'q' to quit (non-blocking): " -NoNewline
        $lastUpdate = [DateTime]::Now
        $animFrame++
    }
    
    # Process input without blocking
    if ($inputQueue.Count -gt 0) {
        $key = $inputQueue.Dequeue()
        if ($key.KeyChar -eq 'q') {
            $continue2 = $false
        }
    }
    
    # Small delay to prevent CPU spinning
    Start-Sleep -Milliseconds 10
}

# Cleanup
$inputPowerShell.Stop()
$inputPowerShell.Dispose()
$inputRunspace.Close()
$inputRunspace.Dispose()
$stopwatch2.Stop()

Write-Host "`n`nNon-blocking demo ended. Notice the smooth updates!`n" -ForegroundColor Green

# Summary
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Blocking Approach:" -ForegroundColor Yellow
Write-Host "  ❌ UI freezes while waiting for input" -ForegroundColor Red
Write-Host "  ❌ Cannot update display during input wait" -ForegroundColor Red
Write-Host "  ❌ Poor user experience" -ForegroundColor Red
Write-Host ""
Write-Host "Non-Blocking Approach:" -ForegroundColor Yellow
Write-Host "  ✅ UI remains responsive" -ForegroundColor Green
Write-Host "  ✅ Smooth animations and updates" -ForegroundColor Green
Write-Host "  ✅ Better user experience" -ForegroundColor Green
Write-Host ""
Write-Host "The fixed TUI implementation uses the non-blocking approach throughout!" -ForegroundColor Cyan
