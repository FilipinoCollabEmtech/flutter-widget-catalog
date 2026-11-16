#!/usr/bin/env powershell
# Auto-refresh script to find m3u8 video links on omeglevids - FAST (0.2s interval)

$url = "https://omeglevids.com/video/premium-obj05-girl-from-omegle-has-sex-on-discord-call/"
$logFile = "$env:TEMP\omegle_m3u8_monitor.log"
$foundFile = "$env:TEMP\omegle_m3u8_found.txt"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp | $Message"
    $line >> $logFile
    Write-Host $line
}

function Find-M3U8Links {
    param([string]$Html)
    $links = New-Object System.Collections.Generic.List[string]

    if ([string]::IsNullOrEmpty($Html)) {
        return $links
    }

    # Match m3u8 URLs
    $matches = [regex]::Matches($Html, 'https?://[^""\s<>]+\.m3u8[^""\s<>]*')
    foreach ($m in $matches) {
        $links.Add($m.Value)
    }

    # Match quoted m3u8 paths
    $matches2 = [regex]::Matches($Html, """([^""]*\.m3u8[^""]*)""")
    foreach ($m in $matches2) {
        if ($m.Groups[1].Value) { $links.Add($m.Groups[1].Value) }
    }

    # Match single-quoted m3u8 paths
    $matches3 = [regex]::Matches($Html, "'([^']*\.m3u8[^']*)'")
    foreach ($m in $matches3) {
        if ($m.Groups[1].Value) { $links.Add($m.Groups[1].Value) }
    }

    return $links | Select-Object -Unique
}

function Fetch-Page {
    Write-Host "Fetching page..."
    $tempHtml = "$env:TEMP\omegle_fetch_temp.html"
    if (Test-Path $tempHtml) { Remove-Item $tempHtml -Force }

    $curlResult = cmd /c "curl.exe -s -L --max-time 10 -A `"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36`" `"$url`" -o `"$tempHtml`"" 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Log "curl failed with exit code $exitCode"
        return $null
    }

    if (-not (Test-Path $tempHtml)) {
        return $null
    }

    $htmlStr = Get-Content $tempHtml -Raw
    return $htmlStr
}

function Check-Page {
    $htmlStr = Fetch-Page

    if ($null -eq $htmlStr) {
        return $false
    }

    # Check if page is 404
    if ($htmlStr -match "Page Not Found|404|error-404|not-found") {
        return $false
    }

    # Search for m3u8 links
    $m3u8Links = Find-M3U8Links -Html $htmlStr

    if ($m3u8Links.Count -gt 0) {
        Write-Log "FOUND m3u8 link(s): $($m3u8Links -join ', ')"
        $m3u8Links | Out-File -FilePath $foundFile -Encoding utf8
        return $true
    }

    # Search for any video URLs
    $videoPattern = 'https?://[^""\s<>]+\.(mp4|m3u8|mpd|f4m)[^""\s<>]*'
    $videoMatches = [regex]::Matches($htmlStr, $videoPattern)
    if ($videoMatches.Count -gt 0) {
        $videoLinks = $videoMatches.Value | Select-Object -Unique
        Write-Log "FOUND video link(s): $($videoLinks -join ', ')"
        $videoLinks | Out-File -FilePath $foundFile -Encoding utf8
        return $true
    }

    return $false
}

# Main loop - 0.2 second interval
Write-Log "=== Starting m3u8 monitor (FAST - 0.2s) ==="
Write-Log "Target URL: $url"

$checkCount = 0

while ($true) {
    $checkCount++
    Write-Host "Check #$checkCount"

    if (Check-Page) {
        Write-Log "=== Link found! Check $foundFile for details ==="
        [console]::beep(800, 500)
        Start-Sleep -Seconds 1
        [console]::beep(800, 500)
    }

    Start-Sleep -Milliseconds 200
}
