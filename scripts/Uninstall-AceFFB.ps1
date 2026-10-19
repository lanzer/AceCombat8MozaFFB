<#
  Undoes what Install-AceFFB.ps1 did, using the record it keeps in %LOCALAPPDATA%\AceFFB.
  Double-click Uninstall-AceFFB.cmd, or run:
      powershell -ExecutionPolicy Bypass -File scripts\Uninstall-AceFFB.ps1
  Asks before each part. Files are backed up before they are changed. -DryRun changes nothing.
  Run this before you play ACE COMBAT 8 online.
#>
[CmdletBinding()]
param(
  [string]$GamePath,
  [string]$UserHome = $env:USERPROFILE,
  [switch]$DryRun,
  [switch]$Elevated,
  [switch]$FromCmd
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AceFFB-Common.ps1')
$script:DryRun = [bool]$DryRun
$script:StateDir = Join-Path $UserHome 'AppData\Local\AceFFB'
$script:BackupRoot = Join-Path $script:StateDir "backups\uninstall-$($script:Stamp)"
Load-Manifest
$created = @($script:Manifest.created)

function Remove-Path([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  if ($script:DryRun) { Say-Info "(dry run) would remove $Path"; return $true }
  Remove-Item -LiteralPath $Path -Recurse -Force
  return $true
}
# Oldest installer backup of a path (its state before AceFFB first changed it).
function Get-FirstBackup([string]$Path) {
  $b = @($script:Manifest.backups | Where-Object { $_.original -eq $Path -and (Test-Path -LiteralPath $_.backup) } | Sort-Object time)
  if ($b.Count) { return $b[0].backup }
  return $null
}

Write-Host ''
Write-Host ' AceFFB uninstaller' -ForegroundColor Cyan
if ($script:DryRun) { Write-Host ' DRY RUN: nothing will be changed.' -ForegroundColor Magenta }

# ---- Game folder ----
Start-Step 'Game folder'
$GameRoot = $null
if ($GamePath) { $GameRoot = Resolve-GameRoot $GamePath }
if (-not $GameRoot) { $GameRoot = Resolve-GameRoot (Get-Man 'gameRoot') }
if (-not $GameRoot) { $c = @(Find-GameRoots); if ($c.Count) { $GameRoot = $c[0] } }
$Win64 = $null
if ($GameRoot) { $Win64 = Join-Path $GameRoot 'Game\Binaries\Win64'; Say-OK "ACE COMBAT 8: $GameRoot" }
else { Say-Action 'ACE COMBAT 8 not found; game files are skipped. Use -GamePath "<folder>".' }

if ($Win64 -and -not $script:DryRun -and -not (Test-Writable $Win64)) {
  if ($Elevated -or (Test-Admin)) { Say-Fail "Can't write to $Win64."; $Win64 = $null }
  else {
    Say-Info 'The game folder needs administrator rights. Continuing in a new window after Windows asks.'
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated', '-GamePath', "`"$GameRoot`"", '-UserHome', "`"$UserHome`"")
    try { Start-Process -FilePath 'powershell.exe' -ArgumentList $a -Verb RunAs | Out-Null; Write-Host '  Continuing in the administrator window.' -ForegroundColor Cyan; exit 0 }
    catch { Say-Fail 'Administrator permission was refused; game files are skipped.'; $Win64 = $null }
  }
}

# ---- AceTelemetry + mod lists ----
Start-Step 'AceTelemetry game mod'
$UE = if ($Win64) { Get-UE4SSInfo $Win64 } else { $null }
if (-not ($UE -and $UE.Installed)) { Say-Skip 'No UE4SS found.' }
else {
  $mods = $UE.ModsDir
  $dst = Join-Path $mods 'AceTelemetry'
  if (Test-Path -LiteralPath $dst) {
    if (Ask-YesNo "Remove the AceTelemetry mod ($dst)?" $true) { [void](Remove-Path $dst); Say-OK 'AceTelemetry removed.' } else { Say-Skip 'AceTelemetry kept.' }
  } else { Say-Skip 'AceTelemetry is not installed.' }
  $modsTxt = Join-Path $mods 'mods.txt'
  if ((Test-Path -LiteralPath $modsTxt) -and -not (Test-Path -LiteralPath $dst)) {
    $text = Read-TextFile $modsTxt
    if ($text -match '(?m)^[ \t]*AceTelemetry[ \t]*:') {
      [void](Backup-Item $modsTxt)
      $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
      $keep = @(($text -split "`r?`n") | Where-Object { $_ -notmatch '^\s*AceTelemetry\s*:' })
      while ($keep.Count -and $keep[-1] -eq '') { $keep = @($keep | Select-Object -First ($keep.Count - 1)) }
      Write-TextFile $modsTxt (($keep -join $nl) + $nl)
      Say-OK 'mods.txt: AceTelemetry line removed (other lines unchanged).'
    }
  }
  $modsJson = Join-Path $mods 'mods.json'
  if ((Test-Path -LiteralPath $modsJson) -and -not (Test-Path -LiteralPath $dst)) {
    try {
      $raw = Read-TextFile $modsJson
      $arr = ConvertFrom-Json -InputObject $raw
      $arr = @($arr)
      if (@($arr | Where-Object { $_.mod_name -eq 'AceTelemetry' }).Count) {
        [void](Backup-Item $modsJson)
        $arr = @($arr | Where-Object { $_.mod_name -ne 'AceTelemetry' })
        $json = if ($raw -match "`n\s") { ConvertTo-Json -InputObject $arr -Depth 5 } else { ConvertTo-Json -InputObject $arr -Depth 5 -Compress }
        Write-TextFile $modsJson $json
        Say-OK 'mods.json: AceTelemetry entry removed.'
      }
    } catch { Say-Action "Couldn't update mods.json: $($_.Exception.Message)" }
  }
}

# ---- Key bindings ----
Start-Step 'Key bindings (AC8HOTAS)'
$bk = Get-Man 'bindingsBackup'
if ($UE -and $UE.Installed) {
  $bind = Join-Path $UE.ModsDir 'AC8HOTAS\bindings.lua'
  if ($bk -and (Test-Path -LiteralPath $bk) -and (Test-Path -LiteralPath (Split-Path -Parent $bind))) {
    if (Ask-YesNo "Put back the bindings.lua you had before AceFFB? ($bk)" $false) {
      [void](Backup-Item $bind)
      if (-not $script:DryRun) { Copy-Item -LiteralPath $bk -Destination $bind -Force }
      Say-OK 'Previous bindings.lua restored.'
    } else { Say-Skip 'bindings.lua kept as it is.' }
  } else { Say-Skip 'AceFFB did not replace an existing bindings.lua.' }
} else { Say-Skip 'No UE4SS found.' }

# ---- UE4SS (only if AceFFB installed it) ----
Start-Step 'UE4SS script loader'
$ueFiles = @($created | Where-Object { $Win64 -and $_ -like "$GameRoot\Game\*" -and $_ -notlike '*\AceTelemetry*' -and $_ -notlike '*\steam_appid.txt' })
if ((Get-Man 'ue4ssInstalledByAceFFB') -and $ueFiles.Count) {
  Say-Info 'AceFFB installed UE4SS (with AC8HOTAS and AC8AnalogYaw). Removing it makes the game folder clean for online play.'
  if (Ask-YesNo 'Remove UE4SS, AC8HOTAS and AC8AnalogYaw files that AceFFB added?' $false) {
    $hb = Join-Path $UE.ModsDir 'AC8HOTAS\bindings.lua'
    if (Test-Path -LiteralPath $hb) { [void](Backup-Item $hb) }
    $n = 0
    foreach ($f in $ueFiles) { if (Remove-Path $f) { $n++ } }
    # remove folders that are now empty (deepest first)
    if (-not $script:DryRun) {
      foreach ($d in @(Get-ChildItem -LiteralPath (Join-Path $Win64 'UE4SS') -Recurse -Directory -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length } -Descending)) {
        if (-not (Get-ChildItem -LiteralPath $d.FullName -Force)) { Remove-Item -LiteralPath $d.FullName -Force }
      }
      $ud = Join-Path $Win64 'UE4SS'
      if ((Test-Path -LiteralPath $ud) -and -not (Get-ChildItem -LiteralPath $ud -Force)) { Remove-Item -LiteralPath $ud -Force }
    }
    Say-OK "Removed $n UE4SS files. Logs, bindings and other mods you added yourself stay in $Win64\UE4SS."
  } else { Say-Skip 'UE4SS kept.' }
} else {
  Say-Skip 'UE4SS was not installed by AceFFB, so it is left alone.'
  if ($Win64 -and (Test-Path -LiteralPath (Join-Path $Win64 'dwmapi.dll'))) { Say-Info 'Before playing online, disable UE4SS yourself (for example rename Game\Binaries\Win64\dwmapi.dll).' }
}

# ---- No-EAC launch ----
Start-Step 'Offline (no-EAC) launch'
if ($Win64) {
  $appIdFile = Join-Path $Win64 'steam_appid.txt'
  $bkA = Get-FirstBackup $appIdFile
  if ($created -contains $appIdFile -and (Test-Path -LiteralPath $appIdFile)) {
    if (Ask-YesNo 'Remove steam_appid.txt (added by AceFFB)?' $true) { [void](Remove-Path $appIdFile); Say-OK 'steam_appid.txt removed.' } else { Say-Skip 'steam_appid.txt kept.' }
  } elseif ($bkA) {
    if (Ask-YesNo 'Put back the steam_appid.txt you had before AceFFB?' $true) { if (-not $script:DryRun) { Copy-Item -LiteralPath $bkA -Destination $appIdFile -Force }; Say-OK 'steam_appid.txt restored.' } else { Say-Skip 'steam_appid.txt kept.' }
  } else { Say-Skip 'steam_appid.txt was not added by AceFFB.' }
}
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ACE COMBAT 8 (offline, no EAC).lnk'
if ($created -contains $lnk -and (Test-Path -LiteralPath $lnk)) { [void](Remove-Path $lnk); Say-OK 'Offline desktop shortcut removed.' }

# ---- MOZA Cockpit port ----
Start-Step 'MOZA Cockpit'
$ports = Get-Man 'mozaOriginalPorts'
if ($ports) {
  foreach ($p in $ports.PSObject.Properties) {
    $f = $p.Name; $old = [string]$p.Value
    if (-not (Test-Path -LiteralPath $f)) { continue }
    $text = Read-TextFile $f
    $rx = '(?m)^([ \t]*local[ \t]+tcp_server_port[ \t]*=[ \t]*)3476\b'
    if ([regex]::IsMatch($text, $rx) -and (Ask-YesNo "Set the MOZA.lua port back to $old? ($f)" $true)) {
      [void](Backup-Item $f)
      Write-TextFile $f ([regex]::Replace($text, $rx, ('${1}' + $old), 1))
      Say-OK "Port set back to $old. Restart MOZA Cockpit."
    }
  }
} else { Say-Skip 'AceFFB did not change the MOZA.lua port.' }
$presetUn = Join-Path $PSScriptRoot 'Uninstall-CockpitPresets.ps1'
if ((Test-Path -LiteralPath $presetUn) -and (Ask-YesNo 'Remove the AC8 Cockpit presets? (closes and restarts MOZA Cockpit; DCS presets are kept)' $false)) {
  if ($script:DryRun) { Say-Skip "(dry run) would run $presetUn" }
  else { try { & $presetUn; Say-OK 'AC8 Cockpit presets removed.' } catch { Say-Fail "Preset removal failed: $($_.Exception.Message)" } }
} else { Say-Skip 'AC8 Cockpit presets kept.' }

# ---- AceBridge ----
Start-Step 'AceBridge'
$bd = Get-Man 'bridgeDir'
$bridgeFiles = @($created | Where-Object { $bd -and $_ -like "$bd\*" })
if ($bd -and (Test-Path -LiteralPath $bd)) {
  if (Ask-YesNo "Remove the AceBridge files AceFFB installed in $bd?" $true) {
    $n = 0
    foreach ($f in $bridgeFiles) { if (Remove-Path $f) { $n++ } }
    # files that existed before were overwritten: put the originals back
    foreach ($b in @($script:Manifest.backups | Where-Object { $_.original -like "$bd\*" } | Sort-Object time -Descending)) {
      if (-not $script:DryRun -and (Test-Path -LiteralPath $b.backup)) { Copy-Item -LiteralPath $b.backup -Destination $b.original -Force }
    }
    if ($created -contains $bd -and -not $script:DryRun -and -not (Get-ChildItem -LiteralPath $bd -Recurse -File -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $bd -Recurse -Force }
    Say-OK "AceBridge removed ($n files). Anything you added to $bd yourself was kept."
  } else { Say-Skip 'AceBridge kept.' }
} else { Say-Skip 'AceBridge folder not found.' }
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AceBridge.lnk'
if ($created -contains $lnk -and (Test-Path -LiteralPath $lnk)) { [void](Remove-Path $lnk); Say-OK 'AceBridge desktop shortcut removed.' }

Write-Summary 'Uninstall summary'
if (Test-Path -LiteralPath $script:BackupRoot) { Write-Host " Backups made during uninstall: $($script:BackupRoot)" }
Write-Host ' Installer backups stay in %LOCALAPPDATA%\AceFFB\backups. Delete that folder when you no longer need them.'
Write-Host ' Before playing online: start ACE COMBAT 8 with Play in Steam (anti-cheat on) and make sure no mod loader is left in Game\Binaries\Win64.'
if ($Elevated) { [void](Read-Host ' Press Enter to close this window') }
