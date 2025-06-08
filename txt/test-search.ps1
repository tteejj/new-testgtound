# Quick test for improved search

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) {
    $scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

. "$scriptRoot\helper.ps1"
. "$scriptRoot\fuzzy.ps1"  
. "$scriptRoot\core-data.ps1"
. "$scriptRoot\theme.ps1"
. "$scriptRoot\command-palette.ps1"

Initialize-CommandRegistry

Write-Host "Testing improved search..." -ForegroundColor Yellow

# Test the improved search logic for "add p" vs "Add Project"
$testCommand = $script:CommandRegistry | Where-Object { $_.Name -eq "Add Project" } | Select-Object -First 1
$filter = "add p"

if ($testCommand) {
    Write-Host "`nTesting: '$filter' vs '$($testCommand.Name)'" -ForegroundColor Green
    
    $maxSimilarity = Get-FuzzySimilarity -String1 $testCommand.SearchText -String2 $filter
    Write-Host "Base similarity: $maxSimilarity%" -ForegroundColor Cyan
    
    # Multi-word check
    $filterWords = $filter.ToLower().Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
    $searchText = $testCommand.SearchText.ToLower()
    
    Write-Host "Filter words: $($filterWords -join ', ')" -ForegroundColor Gray
    Write-Host "Search text: $searchText" -ForegroundColor Gray
    
    if ($filterWords.Count -gt 1) {
        $allWordsMatch = $true
        foreach ($word in $filterWords) {
            $contains = $searchText.Contains($word)
            Write-Host "  '$word' found: $contains" -ForegroundColor $(if($contains){"Green"}else{"Red"})
            if (-not $contains) {
                $allWordsMatch = $false
            }
        }
        if ($allWordsMatch) {
            $maxSimilarity += 50
            Write-Host "Multi-word bonus: +50" -ForegroundColor Green
        }
    }
    
    # Substring check
    if ($searchText.Contains($filter.ToLower())) {
        $maxSimilarity += 30
        Write-Host "Substring bonus: +30" -ForegroundColor Green
    }
    
    Write-Host "Final score: $maxSimilarity%" -ForegroundColor Yellow
    Write-Host "Passes 25% threshold: $(if($maxSimilarity -ge 25){"YES"}else{"NO"})" -ForegroundColor $(if($maxSimilarity -ge 25){"Green"}else{"Red"})
}
