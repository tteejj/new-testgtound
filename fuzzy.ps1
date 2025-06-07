# Fuzzy Text Matching Algorithms

function global:Get-LevenshteinDistance {
    param(
        [string]$String1,
        [string]$String2,
        [switch]$CaseSensitive
    )
    
    if (-not $CaseSensitive) {
        $String1 = $String1.ToLower()
        $String2 = $String2.ToLower()
    }
    
    $len1 = $String1.Length
    $len2 = $String2.Length
    
    # Use hashtable approach to avoid PowerShell multidimensional array issues
    $matrix = @{}
    
    for ($i = 0; $i -le $len1; $i++) { $matrix["$i,0"] = $i }
    for ($j = 0; $j -le $len2; $j++) { $matrix["0,$j"] = $j }
    
    for ($i = 1; $i -le $len1; $i++) {
        for ($j = 1; $j -le $len2; $j++) {
            $cost = if ($String1[$i-1] -eq $String2[$j-1]) { 0 } else { 1 }
            
            $matrix["$i,$j"] = [Math]::Min(
                [Math]::Min( $matrix["$($i-1),$j"] + 1, $matrix["$i,$($j-1)"] + 1 ),
                $matrix["$($i-1),$($j-1)"] + $cost
            )
        }
    }
    return $matrix["$len1,$len2"]
}

function global:Get-FuzzySimilarity {
    param(
        [string]$String1,
        [string]$String2,
        [switch]$CaseSensitive
    )
    
    $distance = Get-LevenshteinDistance -String1 $String1 -String2 $String2 -CaseSensitive:$CaseSensitive
    $maxLen = [Math]::Max($String1.Length, $String2.Length)
    
    if ($maxLen -eq 0) { return 100 }
    
    $similarity = (1 - ($distance / $maxLen)) * 100
    return [Math]::Round($similarity, 2)
}
