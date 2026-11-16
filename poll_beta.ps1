$runId = "40628837440"
$repo = "FilipinoCollabEmtech/flutter-widget-catalog"
$outFile = "$PWD\poll_beta.log"
while ($true) {
  try {
    $line = (gh run view $runId --repo $repo 2>&1) -split "`n" | Select-String -Pattern "completed|failure|in_progress|BUILD FAILED" | Select-Object -Last 1
    Add-Content -Path $outFile -Value ("$(Get-Date -Format 'HH:mm:ss') :: " + ($line -join " ") + " [tick]" )
    if ($line -match "completed") { Add-Content -Path $outFile -Value ("$(Get-Date -Format 'HH:mm:ss') :: SUCCESS status: " + ($line -join " ")); exit }
    if ($line -match "failure")  { Add-Content -Path $outFile -Value ("$(Get-Date -Format 'HH:mm:ss') :: FAILURE status: " + ($line -join " ")); exit }
  } catch { Add-Content -Path $outFile -Value "$(Get-Date -Format 'HH:mm:ss') :: ERR: $($_.Exception.Message)" }
  Start-Sleep -Seconds 60
}
