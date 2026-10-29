# Helper for "Update REAPER" on Windows (Windows PowerShell 5.1+).
#
#   update.ps1 check <platform>           print the latest REAPER version on reaper.fm
#   update.ps1 install <platform> <dir>   wait for REAPER to quit, download and install
#                                         the latest version into <dir>, start REAPER again
#
# <platform>: win-x64, win-x86, win-arm64ec
# <dir>: REAPER's executable folder (reaper.GetExePath())
param(
  [string]$Mode,
  [string]$Platform,
  [string]$ExeDir
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$WaitSec = 300
$Log = Join-Path $env:TEMP 'reaper-update.log'

$FileRe = switch ($Platform) {
  'win-x64'     { 'reaper\d+_x64-install\.exe' }
  'win-x86'     { 'reaper\d+-install\.exe' }
  'win-arm64ec' { 'reaper\d+_win11_arm64ec[a-z_]*-install\.exe' }
  default       { Write-Output "unknown platform: $Platform"; exit 2 }
}

function Write-Log($Text) {
  Add-Content -Path $Log -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text)
}

function Stop-WithError($Text) {
  Write-Log "ERROR: $Text"
  Add-Type -AssemblyName System.Windows.Forms
  [System.Windows.Forms.MessageBox]::Show("$Text`n`nLog: $Log", 'REAPER update failed', 'OK', 'Error') | Out-Null
  exit 2
}

# "files/7.x/reaper784_x64-install.exe" -> path and "7.84"
function Get-Latest {
  $page = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 'https://www.reaper.fm/download.php').Content
  $m = [regex]::Match($page, "files/(\d+)\.x/$FileRe")
  if (-not $m.Success) { return $null }
  $major = $m.Groups[1].Value
  $digits = [regex]::Match($m.Value, 'reaper(\d+)').Groups[1].Value
  @{ Path = $m.Value; Version = "$major." + $digits.Substring($major.Length) }
}

try { $latest = Get-Latest } catch { $latest = $null }
if (-not $latest) {
  Write-Output 'could not get the latest version from reaper.fm'
  if ($Mode -eq 'check') { exit 2 }
  Stop-WithError 'could not get the latest version from reaper.fm'
}

if ($Mode -eq 'check') {
  Write-Output $latest.Version
  exit 0
}
if ($Mode -ne 'install' -or -not $ExeDir) {
  Write-Output 'usage: update.ps1 check|install <platform> [<dir>]'
  exit 2
}

Write-Log "=== updating $ExeDir to $($latest.Version)"
$exe = Join-Path $ExeDir 'reaper.exe'
if (-not (Test-Path $exe)) { Stop-WithError "REAPER not found in $ExeDir" }

for ($i = 0; $i -lt $WaitSec -and (Get-Process -Name reaper -ErrorAction SilentlyContinue); $i++) {
  Start-Sleep -Seconds 1
}
if (Get-Process -Name reaper -ErrorAction SilentlyContinue) {
  Stop-WithError "REAPER did not quit within $($WaitSec / 60) minutes, update cancelled"
}

$installer = Join-Path $env:TEMP ([IO.Path]::GetFileName($latest.Path))
try {
  Write-Log "downloading https://www.reaper.fm/$($latest.Path)"
  Invoke-WebRequest -UseBasicParsing -TimeoutSec 600 -OutFile $installer "https://www.reaper.fm/$($latest.Path)"
} catch {
  Stop-WithError "download failed: https://www.reaper.fm/$($latest.Path)`n$($_.Exception.Message)"
}

# A portable REAPER keeps reaper.ini next to reaper.exe; the installer
# leaves it alone, it only replaces program files.
$writable = $true
try { [IO.File]::OpenWrite((Join-Path $ExeDir '.reaper-update-test')).Close(); Remove-Item (Join-Path $ExeDir '.reaper-update-test') }
catch { $writable = $false }

# NSIS: /S silent, /D=<dir> must be last and unquoted
$installArgs = @('/S', "/D=$ExeDir")
Write-Log "running $installer $($installArgs -join ' ') (elevated: $(-not $writable))"
try {
  if ($writable) {
    $p = Start-Process -FilePath $installer -ArgumentList $installArgs -Wait -PassThru
  } else {
    $p = Start-Process -FilePath $installer -ArgumentList $installArgs -Verb RunAs -Wait -PassThru
  }
} catch {
  Remove-Item $installer -ErrorAction SilentlyContinue
  Stop-WithError "installation cancelled: $($_.Exception.Message)"
}
Remove-Item $installer -ErrorAction SilentlyContinue
if ($p.ExitCode -ne 0) { Stop-WithError "installer exited with code $($p.ExitCode)" }

$version = (Get-Item $exe).VersionInfo.ProductVersion
Write-Log "installed, reaper.exe version: $version"
Start-Process -FilePath $exe -WorkingDirectory $ExeDir
