# Test the fuzzy search improvements

# Load the fuzzy functions
. "C:\Users\jhnhe\Documents\GitHub\pmc-terminal\modular\experimental features\new testgtound\fuzzy.ps1"

# Test cases
$testCommands = @(
    "Calendar View",
    "Complete Task", 
    "Add Task",
    "Manage Command Snippets",
    "Backup Now",
    "Project Details"
)

Write-Host "`nTesting fuzzy search improvements:" -ForegroundColor Cyan
Write-Host "==================================`n" -ForegroundColor Cyan

# Test different search patterns
$searchTerms = @("ca", "ca_", "cal", "c_", "task", "ta", "ba", "proj")

foreach ($term in $searchTerms) {
    Write-Host "Search: '$term'" -ForegroundColor Yellow
    Write-Host "Results:" -ForegroundColor Gray
    
    foreach ($command in $testCommands) {
        $score = Get-FuzzyMatch -SearchTerm $term -Target $command
        if ($score -gt 0) {
            Write-Host "  → $command (Score: $score)" -ForegroundColor Green
        }
    }
    Write-Host ""
}

Write-Host "`nDemonstrating why 'ca_' should match 'Calendar View':" -ForegroundColor Cyan
Write-Host "The characters 'c', 'a', '_' appear in that order in 'Calendar View'" -ForegroundColor Gray
Write-Host "(The underscore can match the space between words)`n" -ForegroundColor Gray
