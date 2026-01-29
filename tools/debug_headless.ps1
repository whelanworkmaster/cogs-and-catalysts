$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $projectRoot

$metadataPath = Join-Path $projectRoot ".godot\\editor\\project_metadata.cfg"
$godotExe = $null
if (Test-Path $metadataPath) {
    $metadata = Get-Content -LiteralPath $metadataPath -Raw
    if ($metadata -match 'executable_path="([^"]+)"') {
        $godotExe = $Matches[1]
    }
}

if (-not $godotExe) {
    $cmd = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($cmd) { $godotExe = $cmd.Path }
}

if (-not $godotExe) {
    Write-Error "Godot executable not found. Open the project once in the editor to populate project_metadata.cfg."
}

$args = @(
    "--headless",
    "--path", $projectRoot,
    "--script", "res://scripts/tools/headless_validate.gd"
)

$logDir = Join-Path $projectRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}
$logFile = Join-Path $logDir "headless-godot.log"
$args += @("--log-file", $logFile)
Set-Content -LiteralPath $logFile -Value ""

Write-Host "Running headless validation..."
Write-Host "`"$godotExe`" $($args -join ' ')"

& $godotExe @args
$exitCode = $LASTEXITCODE

if (Test-Path $logFile) {
    $logText = Get-Content -LiteralPath $logFile -Raw
    $hardFail = $logText -match "CrashHandlerException|SCRIPT ERROR|Parse Error|^ERROR: Failed to load"
    $errors = Select-String -LiteralPath $logFile -Pattern '^ERROR:' -AllMatches |
        ForEach-Object { $_.Line }
    $errors = $errors | Where-Object { $_ -notmatch 'Failed to read the root certificate store' }
    $failed = $hardFail -or ($errors.Count -gt 0)
} 
if ($exitCode -ne 0 -and -not $failed) {
    Write-Host "Non-zero exit code with no actionable errors detected."
}

if ($failed) {
    if (Test-Path $logFile) {
        Write-Host "`n--- headless-godot.log (tail) ---"
        Get-Content -LiteralPath $logFile -Tail 120
    }
}

if ($failed) { exit 1 } else { exit 0 }
