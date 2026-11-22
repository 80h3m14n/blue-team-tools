# dns_dump.ps1 — dump resolver cache entries with timestamps
$raw = ipconfig /displaydns
$entries = ($raw -join "`n") -split "`n`n"

$entries | ForEach-Object {
    $name = ($_ -split "`n")[0].Trim() -replace '^\s*Record Name.*?:\s*',''
    if ($name -and $name -notmatch '^-+$') {
        $ttl = ($_ -split "`n" | Select-String 'Time To Live').ToString() -replace '.*:\s*',''
        [pscustomobject]@{ Host = $name; TTL = $ttl }
    }
} | Sort-Object Host -Unique | Format-Table -AutoSize

# Filter it to real sites instead of CDN noise
# .\dns_dump.ps1 | Where-Object { $_.Host -match '\.(com|net|org|io|co)$' -and $_.Host -notmatch '(google|gstatic|gvt1|doubleclick|cloudflare)' }

# DNS holds hostnames only, never query strings or paths.
