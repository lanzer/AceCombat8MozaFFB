<#
  AceFFB installer: force feedback for ACE COMBAT 8 on a MOZA AB6 / AB9.
  Double-click Install-AceFFB.cmd in the release folder, or run:
      powershell -ExecutionPolicy Bypass -File scripts\Install-AceFFB.ps1

  Steps (each one can be skipped, and the whole thing is safe to rerun):
    1. Find ACE COMBAT 8 (Steam libraries, or pick the folder)
    2. Offline / no-EAC launch: steam_appid.txt + an "offline" desktop shortcut (asks you to type YES)
    3. UE4SS script loader (detects it; can download the tested build)
    4. AceTelemetry game mod (copied into UE4SS\Mods, enabled in mods.txt / mods.json)
    5. MOZA Cockpit: DCS export port 3476, optional AC8 presets, "auto switch presets" check
    6. AceBridge (copied to %USERPROFILE%\AceFFB by default) + .NET 8 Desktop Runtime check
    7. AC8HOTAS key bindings (choose an example; your MOZA device GUID is filled in)

  Every file is backed up before it is changed (see the backup folder in the summary), and
  everything the installer did is recorded so scripts\Uninstall-AceFFB.ps1 can undo it.
  -DryRun shows what would happen without changing anything.
#>
[CmdletBinding()]
param(
  [string]$GamePath,
  [string]$BridgeDir,
  [string]$UserHome = $env:USERPROFILE,
  [switch]$DryRun,
  [switch]$Elevated,
  [switch]$FromCmd
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow in PS 5.1 with the progress bar on
. (Join-Path $PSScriptRoot 'AceFFB-Common.ps1')
$script:DryRun = [bool]$DryRun
$script:StateDir = Join-Path $UserHome 'AppData\Local\AceFFB'
$script:BackupRoot = Join-Path $script:StateDir "backups\$($script:Stamp)"
Load-Manifest

# ---- What we are installing from (release zip layout, or the repo after scripts\build.ps1) ----
$Root = Split-Path -Parent $PSScriptRoot
function First-Existing([string[]]$Paths) { foreach ($p in $Paths) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } }; return $null }
$SrcTelemetry = First-Existing @((Join-Path $Root 'Mods\AceTelemetry'), (Join-Path $Root 'mod\AceTelemetry'))
$SrcBridge = $null
if (Test-Path -LiteralPath (Join-Path $Root 'AceBridge\AceBridge.exe')) { $SrcBridge = Join-Path $Root 'AceBridge' }
else {
  $rel = Get-ChildItem -Path (Join-Path $Root 'release') -Directory -Filter 'AceFFB-*' -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'AceBridge\AceBridge.exe') } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($rel) { $SrcBridge = Join-Path $rel.FullName 'AceBridge' }
}
$SrcStartCmd = First-Existing @((Join-Path $Root 'Start-AceBridge.cmd'), (Join-Path $Root 'scripts\Start-AceBridge.cmd'))
$SrcMap      = First-Existing @($(if ($SrcBridge) { Join-Path $SrcBridge 'aircraft-map.json' }), (Join-Path $Root 'config\aircraft-map.json'))
$SrcExamples = Join-Path $Root 'examples'
$SrcPresets  = Join-Path $Root 'cockpit-presets'

# The tested UE4SS build ("v3.0.1 Beta, Git SHA 03dbd5c0") is the one inside the AC8HOTAS full-install
# package. Pinned by SHA-256 so a changed download is refused.
$UE4SS_Url      = 'https://github.com/Drumsmasher17/AC8HOTAS/releases/download/v0.1.1/AC8HOTAS-0.1.1-full-install.zip'
$UE4SS_ZipSha   = '0AA0899371C7A9E7B3D4EAF8AC164294B2C227733269AB7C6321F28445524656'
$UE4SS_DllSha   = @{ 'dwmapi.dll' = 'C5D2AB9F9B89BD94460B0A283EEFB113085105014011CAC961F36787376DB744'; 'UE4SS.dll' = '3FC1CD877007499E8C4F2152E12F76098ABA8E267B7EE65846EDC17CF7A0D1A4' }

Write-Host ''
Write-Host ' AceFFB installer - force feedback for ACE COMBAT 8 on MOZA AB6 / AB9' -ForegroundColor Cyan
if ($script:DryRun) { Write-Host ' DRY RUN: nothing will be changed.' -ForegroundColor Magenta }
Write-Host ' Answer the questions with y / n (Enter picks the capital letter). You can rerun this any time.'

$GameRoot = $null; $Win64 = $null; $UE = $null; $ModsDir = $null

# =====================================================================================
Start-Step 'Step 1 of 7: Find ACE COMBAT 8'
# =====================================================================================
if ($GamePath) {
  $GameRoot = Resolve-GameRoot $GamePath
  if (-not $GameRoot) { Say-Warn "No Game\Binaries\Win64\AceCombat8.exe under $GamePath" }
}
if (-not $GameRoot) {
  $cands = @(Find-GameRoots)
  if ($cands.Count -eq 1) {
    Say-Info "Found: $($cands[0])"
    if (Ask-YesNo 'Is this your ACE COMBAT 8 folder?' $true) { $GameRoot = $cands[0] }
  } elseif ($cands.Count -gt 1) {
    for ($i = 0; $i -lt $cands.Count; $i++) { Say-Info "[$($i+1)] $($cands[$i])" }
    $n = Ask-Text 'Which one? (number)' '1'
    if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $cands.Count) { $GameRoot = $cands[[int]$n - 1] }
  } else {
    Say-Info 'ACE COMBAT 8 was not found in your Steam libraries.'
  }
}
if (-not $GameRoot -and -not $script:DryRun) {
  Say-Info 'Pick the "ACE COMBAT 8" folder (Steam: right-click the game > Manage > Browse local files).'
  $GameRoot = Resolve-GameRoot (Select-FolderDialog 'Select the ACE COMBAT 8 folder (the one that contains start_protected_game.exe)')
  if (-not $GameRoot) { $GameRoot = Resolve-GameRoot (Read-Host '  ? Or paste the folder path here (Enter to skip)') }
}
if ($GameRoot) {
  $Win64 = Join-Path $GameRoot 'Game\Binaries\Win64'
  Say-OK "ACE COMBAT 8: $GameRoot"
  Set-Man 'gameRoot' $GameRoot
} else {
  Say-Action 'ACE COMBAT 8 not found. Game steps 2, 3, 4 and 7 are skipped. Rerun and pick the folder, or use -GamePath "<folder>".'
}

# ---- Administrator rights: the game usually lives under C:\Program Files (x86) ----
if ($Win64 -and -not $script:DryRun -and -not (Test-Writable $Win64)) {
  if ($Elevated -or (Test-Admin)) {
    Say-Fail "Can't write to $Win64 even as administrator. Close the game and try again."
    $Win64 = $null; $GameRoot = $null
  } else {
    Say-Info 'The game folder needs administrator rights to change. Windows will ask for permission;'
    Say-Info 'the installer then continues in a new window.'
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated', '-GamePath', "`"$GameRoot`"", '-UserHome', "`"$UserHome`"")
    if ($BridgeDir) { $a += @('-BridgeDir', "`"$BridgeDir`"") }
    try {
      Start-Process -FilePath 'powershell.exe' -ArgumentList $a -Verb RunAs | Out-Null
      Write-Host '  Continuing in the administrator window. You can close this one.' -ForegroundColor Cyan
      exit 0
    } catch {
      Say-Fail 'Administrator permission was refused, so the game steps are skipped.'
      $Win64 = $null; $GameRoot = $null
    }
  }
}
if ($Elevated -and $env:USERPROFILE -ne $UserHome) {
  Say-Warn "Running as a different Windows user ($env:USERNAME). Desktop shortcuts and the Cockpit presets go to that user."
}

# =====================================================================================
Start-Step 'Step 2 of 7: Offline launch without Easy Anti-Cheat'
# =====================================================================================
if (-not $Win64) { Say-Skip 'Game not found.' }
else {
  $appIdFile = Join-Path $Win64 'steam_appid.txt'
  $have = if (Test-Path -LiteralPath $appIdFile) { (Read-TextFile $appIdFile).Trim() } else { $null }
  $eacReady = $false
  if ($have -eq $script:AppId) {
    Say-OK "steam_appid.txt is already there ($appIdFile)."
    $eacReady = $true
  } else {
    Write-Host ''
    Write-Host '  !!! READ THIS !!!' -ForegroundColor Red
    Write-Host '  AceFFB runs inside the game as a UE4SS script mod, so ACE COMBAT 8 has to be started' -ForegroundColor Red
    Write-Host '  WITHOUT Easy Anti-Cheat. This step puts steam_appid.txt (it contains the game id' -ForegroundColor Red
    Write-Host "  $($script:AppId)) next to AceCombat8.exe, so the game can be started directly from" -ForegroundColor Red
    Write-Host '  AceCombat8.exe, with no anti-cheat. Use that ONLY for the offline single-player' -ForegroundColor Red
    Write-Host '  campaign. NEVER go into ACE COMBAT ONLINE / multiplayer this way or with mods installed:' -ForegroundColor Red
    Write-Host '  that can get you banned. You use this at your own risk.' -ForegroundColor Red
    Write-Host ''
    if ($script:DryRun) { Say-Info '(dry run) would ask you to type YES' ; $ok = $false }
    else { $ok = ((Read-Host '  ? Type YES (in capitals) to continue, or press Enter to skip') -ceq 'YES') }
    if ($ok) {
      if ($have) { [void](Backup-Item $appIdFile) } else { Add-Created $appIdFile }
      Write-TextFile $appIdFile $script:AppId
      Say-OK "Created $appIdFile"
      $eacReady = $true
    } elseif ($script:DryRun) {
      Say-Skip '(dry run) steam_appid.txt would be created after you type YES.'
    } else {
      Say-Action 'Skipped. Without an offline (no-EAC) launch the AceTelemetry mod cannot run.'
    }
  }
  if ($eacReady -or $script:DryRun) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = Join-Path $desktop 'ACE COMBAT 8 (offline, no EAC).lnk'
    $exe = Join-Path $Win64 'AceCombat8.exe'
    if (Test-Path -LiteralPath $lnk) { Say-Skip "Desktop shortcut already exists: $lnk" }
    elseif (Ask-YesNo 'Create a desktop shortcut "ACE COMBAT 8 (offline, no EAC)"?' $true) {
      New-Shortcut $lnk $exe '-SaveToUserDir' $Win64 "$exe,0"
      if (-not $script:DryRun) { Add-Created $lnk }
      Say-OK "Shortcut: $lnk  (starts AceCombat8.exe -SaveToUserDir, the same save folder as Steam)"
    } else {
      Say-Skip 'No shortcut. Start the game by running Game\Binaries\Win64\AceCombat8.exe -SaveToUserDir.'
    }
    Say-Info 'Start the game with that shortcut (not with Play in Steam) when you want force feedback.'
    Say-Info 'Before playing online: run Uninstall-AceFFB.cmd (removes the mods), then use Play in Steam.'
  }
}

# =====================================================================================
Start-Step 'Step 3 of 7: UE4SS script loader'
# =====================================================================================
if (-not $Win64) { Say-Skip 'Game not found.' }
else {
  $UE = Get-UE4SSInfo $Win64
  if ($UE.Installed) {
    $hash = (Get-FileHash -LiteralPath $UE.Dll -Algorithm SHA256).Hash
    $tested = ($hash -eq $UE4SS_DllSha['UE4SS.dll'])
    Say-OK "UE4SS found ($($UE.Layout) layout): $($UE.Dll)"
    if ($tested) { Say-Info 'This is the tested build (v3.0.1 Beta, Git SHA 03dbd5c0).' }
    else { Say-Warn 'This is a different UE4SS build than the tested one (v3.0.1 Beta 03dbd5c0). It may still work; if the mod never connects, check UE4SS.log.' }
  } elseif ($UE.Partial) {
    Say-Action 'Found part of a mod loader (dwmapi.dll, UE4SS.dll or override.txt) but not a complete UE4SS. The installer will not touch another loader. Fix or remove it, then rerun.'
  } else {
    Say-Info 'UE4SS is not installed. AceFFB needs it to read the game.'
    Say-Info 'The installer can download the tested UE4SS build. It comes inside the AC8HOTAS "full install"'
    Say-Info 'package by Drumsmasher17 (GitHub), which also adds AC8HOTAS 0.1.1 (stick bindings) and'
    Say-Info 'AC8AnalogYaw 0.1.3 (proportional yaw). The download (about 9 MB) is checked against a pinned SHA-256.'
    Say-Info "Source: $UE4SS_Url"
    if (Ask-YesNo 'Download and install it now?' $false) {
      $tmp = Join-Path $env:TEMP "AceFFB-ue4ss-$($script:Stamp)"
      try {
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $zip = Join-Path $tmp 'full-install.zip'
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Say-Info 'Downloading...'
        Invoke-WebRequest -Uri $UE4SS_Url -OutFile $zip -UseBasicParsing
        $zh = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
        if ($zh -ne $UE4SS_ZipSha) { throw "Download checksum mismatch ($zh). Nothing was installed." }
        $ex = Join-Path $tmp 'x'
        Expand-Archive -LiteralPath $zip -DestinationPath $ex -Force
        $srcGame = Join-Path $ex 'Game'
        foreach ($k in $UE4SS_DllSha.Keys) {
          $f = Get-ChildItem -LiteralPath $srcGame -Recurse -Filter $k | Select-Object -First 1
          if (-not $f -or (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash -ne $UE4SS_DllSha[$k]) { throw "$k in the package is not the expected file. Nothing was installed." }
        }
        $added = 0; $kept = 0
        foreach ($f in Get-ChildItem -LiteralPath $srcGame -Recurse -File) {
          $rel = $f.FullName.Substring($srcGame.Length).TrimStart('\')
          $dest = Join-Path (Join-Path $GameRoot 'Game') $rel
          if (Test-Path -LiteralPath $dest) { $kept++; continue }      # never overwrite anything that is already there
          $dd = Split-Path -Parent $dest
          if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Force -Path $dd | Out-Null }
          Copy-Item -LiteralPath $f.FullName -Destination $dest
          Add-Created $dest; $added++
        }
        Set-Man 'ue4ssInstalledByAceFFB' $true
        Say-OK "UE4SS installed into $Win64 ($added files added, $kept existing files left alone)."
        Say-Info 'AC8HOTAS and AC8AnalogYaw are enabled too. Newer AC8HOTAS versions are on Nexus Mods (mod 8).'
        $UE = Get-UE4SSInfo $Win64
      } catch {
        Say-Fail "UE4SS install failed: $($_.Exception.Message)"
      } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
      }
    } elseif ($script:DryRun) {
      Say-Skip '(dry run) UE4SS would be offered for download here.'
    } else {
      Say-Action 'Install UE4SS yourself: the AC8HOTAS "full install" package (https://www.nexusmods.com/acecombat8wingsoftheve/mods/8 or https://github.com/Drumsmasher17/AC8HOTAS/releases). Copy its Game folder into the ACE COMBAT 8 folder, then rerun this installer.'
    }
  }
  if ($UE -and $UE.Installed) {
    $ModsDir = $UE.ModsDir
    Say-Info "UE4SS mods folder: $ModsDir"
  }
}

# =====================================================================================
Start-Step 'Step 4 of 7: AceTelemetry game mod'
# =====================================================================================
if (-not $ModsDir) { Say-Skip 'UE4SS is not installed (step 3), so there is nowhere to put the mod yet.' }
elseif (-not $SrcTelemetry) { Say-Fail "AceTelemetry not found next to the installer (expected $Root\Mods\AceTelemetry)." }
else {
  $dst = Join-Path $ModsDir 'AceTelemetry'
  $same = $false
  if (Test-Path -LiteralPath $dst) {
    $same = $true
    foreach ($f in Get-ChildItem -LiteralPath $SrcTelemetry -Recurse -File) {
      $d = Join-Path $dst $f.FullName.Substring($SrcTelemetry.Length).TrimStart('\')
      if (-not (Test-Path -LiteralPath $d) -or (Get-FileHash -LiteralPath $d).Hash -ne (Get-FileHash -LiteralPath $f.FullName).Hash) { $same = $false; break }
    }
  }
  if ($same) { Say-Skip "AceTelemetry is already installed and up to date ($dst)." }
  else {
    if (Test-Path -LiteralPath $dst) { [void](Backup-Item $dst); Say-Info 'Updating the existing AceTelemetry.' }
    else { Add-Created $dst }
    if (-not $script:DryRun) {
      New-Item -ItemType Directory -Force -Path $dst | Out-Null
      Copy-Item -Path (Join-Path $SrcTelemetry '*') -Destination $dst -Recurse -Force
    }
    Say-OK "AceTelemetry copied to $dst"
  }

  # mods.txt: add "AceTelemetry : 1", keep every other line and the order.
  $modsTxt = Join-Path $ModsDir 'mods.txt'
  if (Test-Path -LiteralPath $modsTxt) {
    $text = Read-TextFile $modsTxt
    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    $lines = New-Object System.Collections.ArrayList
    if ($text.Length) { foreach ($l in ($text -split "`r?`n")) { [void]$lines.Add($l) } }
    while ($lines.Count -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*AceTelemetry\s*:') { $idx = $i; break } }
    if ($idx -ge 0 -and $lines[$idx] -match '^\s*AceTelemetry\s*:\s*1\s*$') { Say-Skip 'mods.txt already has "AceTelemetry : 1".' }
    else {
      [void](Backup-Item $modsTxt)
      if ($idx -ge 0) { $lines[$idx] = 'AceTelemetry : 1'; if ($null -eq (Get-Man 'modsTxtLineAdded')) { Set-Man 'modsTxtLineAdded' $false } }
      else {
        # UE4SS's own mods.txt wants the built-in Keybinds entry last, so insert before it if present.
        $kb = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*Keybinds\s*:') { $kb = $i } }
        while ($kb -gt 0 -and $lines[$kb - 1] -match '^\s*;') { $kb-- }   # keep its "; do not move" comment with it
        if ($kb -ge 0) { $lines.Insert($kb, 'AceTelemetry : 1') } else { [void]$lines.Add('AceTelemetry : 1') }
        Set-Man 'modsTxtLineAdded' $true
      }
      Write-TextFile $modsTxt (($lines -join $nl) + $nl)
      Say-OK 'mods.txt: AceTelemetry enabled.'
    }
  } else {
    Write-TextFile $modsTxt "AceTelemetry : 1`r`n"
    Add-Created $modsTxt
    Say-OK "Created $modsTxt with AceTelemetry enabled."
  }

  # mods.json (written by some UE4SS builds / mod managers): keep it in step with mods.txt.
  $modsJson = Join-Path $ModsDir 'mods.json'
  if (Test-Path -LiteralPath $modsJson) {
    try {
      $raw = Read-TextFile $modsJson
      $arr = ConvertFrom-Json -InputObject $raw   # assigned first: piping would wrap the array in PS 5.1
      $arr = @($arr)
      $e = $arr | Where-Object { $_.mod_name -eq 'AceTelemetry' } | Select-Object -First 1
      if ($e -and $e.mod_enabled -eq $true) { Say-Skip 'mods.json already enables AceTelemetry.' }
      else {
        [void](Backup-Item $modsJson)
        if ($e) { $e.mod_enabled = $true } else { $arr += [pscustomobject]@{ mod_name = 'AceTelemetry'; mod_enabled = $true }; Set-Man 'modsJsonEntryAdded' $true }
        $compact = -not ($raw -match "`n\s")
        $json = if ($compact) { ConvertTo-Json -InputObject @($arr) -Depth 5 -Compress } else { ConvertTo-Json -InputObject @($arr) -Depth 5 }
        Write-TextFile $modsJson $json
        Say-OK 'mods.json: AceTelemetry enabled.'
      }
    } catch { Say-Action "Couldn't read mods.json ($($_.Exception.Message)). Add AceTelemetry to it by hand: {""mod_name"":""AceTelemetry"",""mod_enabled"":true}" }
  } else { Say-Skip 'No mods.json in this UE4SS (mods.txt is enough).' }
}

# =====================================================================================
Start-Step 'Step 5 of 7: MOZA Cockpit'
# =====================================================================================
$mozaFiles = @(Get-MozaLuaFiles $UserHome)
$portChanged = $false
if (-not $mozaFiles.Count) {
  Say-Action 'MOZA Cockpit''s DCS export script (Saved Games\DCS\Scripts\MOZA\MOZA.lua) was not found. Open MOZA Cockpit, go to its DCS game page once (it installs the script), then rerun this installer.'
} else {
  foreach ($f in $mozaFiles) {
    $text = Read-TextFile $f
    $rx = '(?m)^([ \t]*local[ \t]+tcp_server_port[ \t]*=[ \t]*)(\d+)'
    $m = [regex]::Match($text, $rx)
    if (-not $m.Success) { Say-Action "No 'local tcp_server_port = ...' line in $f. Edit it by hand: see dcs\MOZA-lua-port.md."; continue }
    if ($m.Groups[2].Value -eq '3476') { Say-Skip "Port is already 3476 in $f"; continue }
    [void](Backup-Item $f)
    $old = $m.Groups[2].Value
    $new = [regex]::Replace($text, $rx, '${1}3476', 1)
    Write-TextFile $f $new
    $ports = Get-Man 'mozaOriginalPorts'
    if (-not $ports) { $ports = [pscustomobject]@{} }
    $ports | Add-Member -NotePropertyName $f -NotePropertyValue $old -Force
    Set-Man 'mozaOriginalPorts' $ports
    $portChanged = $true
    Say-OK "Port changed $old -> 3476 in $f"
  }
}

# Optional: the per-plane AC8 Cockpit presets (the existing preset installer does the work and backs up first).
$presetScript = Join-Path $PSScriptRoot 'Install-CockpitPresets.ps1'
$lib = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'MOZA Cockpit\PresetLibrary'
if (-not (Test-Path -LiteralPath $SrcPresets) -or -not (Test-Path -LiteralPath $presetScript)) { Say-Skip 'No cockpit-presets folder next to the installer.' }
elseif (-not (Test-Path -LiteralPath $lib)) { Say-Action "MOZA Cockpit preset library not found ($lib). Start MOZA Cockpit once, then rerun to add the AC8 presets." }
else {
  Say-Info 'The AC8 presets give every plane its own stick feel and switch automatically when you pick a plane.'
  Say-Info 'Installing them closes and restarts MOZA Cockpit. Your own presets and real DCS profiles are kept (backed up first).'
  if (Ask-YesNo 'Install / update the AC8 Cockpit presets now?' $true) {
    if ($script:DryRun) { Say-Skip "(dry run) would run $presetScript" }
    else {
      try { & $presetScript -PresetDir $SrcPresets; Set-Man 'cockpitPresetsInstalled' $true; Say-OK 'AC8 Cockpit presets installed. MOZA Cockpit was restarted.'; $portChanged = $false }
      catch { Say-Fail "Preset install failed: $($_.Exception.Message)" }
    }
  } else { Say-Skip 'AC8 Cockpit presets not installed (you can run scripts\Install-CockpitPresets.ps1 later).' }
}
if ($portChanged) { Say-Action 'Restart MOZA Cockpit so it uses the new port. (A Cockpit update can put the port back to 1234; just rerun this installer.)' }
elseif ($mozaFiles.Count) { Say-Info 'Reminder: after a MOZA Cockpit update, rerun this installer in case the port was reset to 1234.' }
# "auto switch presets" is what makes Cockpit load each plane's preset.
$userJson = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'MOZA Cockpit\user.json'
$auto = $null
if (Test-Path -LiteralPath $userJson) { $mm = [regex]::Match((Read-TextFile $userJson), '"autoSwitchPresets"\s*:\s*(true|false)'); if ($mm.Success) { $auto = $mm.Groups[1].Value } }
if ($auto -eq 'true') { Say-OK 'MOZA Cockpit "auto switch presets" is on.' }
else { Say-Action 'Turn on "auto switch presets" in MOZA Cockpit''s settings, otherwise the per-plane presets never switch in.' }

# =====================================================================================
Start-Step 'Step 6 of 7: AceBridge'
# =====================================================================================
if (-not $SrcBridge) { Say-Fail "AceBridge.exe not found next to the installer (expected $Root\AceBridge). Use the release zip, or run scripts\build.ps1 first." }
else {
  if (-not $BridgeDir) {
    $def = Get-Man 'bridgeDir'
    if (-not $def) { $def = Join-Path $UserHome 'AceFFB' }
    $BridgeDir = Ask-Text 'Install AceBridge to (Enter = default, or type another folder)' $def
  }
  $BridgeDir = $BridgeDir.TrimEnd('\')
  if (Test-Path -Path (Join-Path $BridgeDir 'AceBridge\*.csproj')) {
    Say-Warn "$BridgeDir\AceBridge holds AceBridge source code (a developer setup). Installing there would mix the release into it."
    $BridgeDir = (Ask-Text 'Install AceBridge to this folder instead' (Join-Path $UserHome 'AceFFB-bridge')).TrimEnd('\')
  }
  if (-not $script:DryRun -and -not (Test-Path -LiteralPath $BridgeDir)) { New-Item -ItemType Directory -Force -Path $BridgeDir | Out-Null; Add-Created $BridgeDir }
  Set-Man 'bridgeDir' $BridgeDir
  $pairs = New-Object System.Collections.ArrayList
  foreach ($f in Get-ChildItem -LiteralPath $SrcBridge -Recurse -File) { [void]$pairs.Add(@($f.FullName, (Join-Path $BridgeDir ('AceBridge\' + $f.FullName.Substring($SrcBridge.Length).TrimStart('\'))))) }
  if ($SrcMap -and -not (Test-Path -LiteralPath (Join-Path $SrcBridge 'aircraft-map.json'))) { [void]$pairs.Add(@($SrcMap, (Join-Path $BridgeDir 'AceBridge\aircraft-map.json'))) }
  if ($SrcStartCmd) { [void]$pairs.Add(@($SrcStartCmd, (Join-Path $BridgeDir 'Start-AceBridge.cmd'))) }
  $copied = 0; $same = 0
  foreach ($p in $pairs) {
    $s = $p[0]; $d = $p[1]
    if ((Test-Path -LiteralPath $d) -and (Get-FileHash -LiteralPath $d).Hash -eq (Get-FileHash -LiteralPath $s).Hash) { $same++; continue }
    if (Test-Path -LiteralPath $d) { [void](Backup-Item $d) } else { Add-Created $d }
    if (-not $script:DryRun) {
      $dd = Split-Path -Parent $d
      if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Force -Path $dd | Out-Null }
      Copy-Item -LiteralPath $s -Destination $d -Force
    }
    $copied++
  }
  if ($copied) { Say-OK "AceBridge installed in $BridgeDir ($copied files copied, $same already up to date)." }
  else { Say-Skip "AceBridge in $BridgeDir is already up to date." }

  $desktop = [Environment]::GetFolderPath('Desktop')
  $lnk = Join-Path $desktop 'AceBridge.lnk'
  $startCmd = Join-Path $BridgeDir 'Start-AceBridge.cmd'
  if (Test-Path -LiteralPath $lnk) { Say-Skip "Desktop shortcut already exists: $lnk" }
  elseif (Ask-YesNo 'Create a desktop shortcut for AceBridge?' $true) {
    New-Shortcut $lnk $startCmd '' $BridgeDir (Join-Path $BridgeDir 'AceBridge\AceBridge.exe')
    if (-not $script:DryRun) { Add-Created $lnk }
    Say-OK "Shortcut: $lnk"
  } else { Say-Skip "No shortcut. Start AceBridge with $startCmd" }

  # .NET 8 Desktop Runtime (x64): only needed by the normal (framework-dependent) build.
  $selfContained = Test-Path -LiteralPath (Join-Path $SrcBridge 'coreclr.dll')
  $rt = @(Get-ChildItem -Path (Join-Path $env:ProgramFiles 'dotnet\shared\Microsoft.WindowsDesktop.App') -Directory -Filter '8.*' -ErrorAction SilentlyContinue)
  if ($rt.Count) { Say-OK ".NET 8 Desktop Runtime found ($($rt[-1].Name))." }
  elseif ($selfContained) { Say-Skip 'This AceBridge build includes .NET, no runtime needed.' }
  else { Say-Action 'Install the .NET 8 Desktop Runtime (x64): https://dotnet.microsoft.com/download/dotnet/8.0 (direct: https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe). AceBridge will not start without it.' }
}

# =====================================================================================
Start-Step 'Step 7 of 7: Stick key bindings (AC8HOTAS)'
# =====================================================================================
$hotasDir = if ($ModsDir) { Join-Path $ModsDir 'AC8HOTAS' } else { $null }
if (-not $hotasDir) { Say-Skip 'UE4SS is not installed (step 3).' }
elseif (-not (Test-Path -LiteralPath $hotasDir)) {
  Say-Skip 'AC8HOTAS is not installed. It is optional but lets the game read the MOZA stick directly: https://www.nexusmods.com/acecombat8wingsoftheve/mods/8 . Rerun this installer after installing it.'
} else {
  $bind = Join-Path $hotasDir 'bindings.lua'
  $cur = if (Test-Path -LiteralPath $bind) { Read-TextFile $bind } else { '' }
  # AC8HOTAS appends the controllers it sees at the bottom of bindings.lua when the game starts.
  $block = ''
  $bm = [regex]::Match($cur, '(?s)-- BEGIN DETECTED DEVICES.*?-- END DETECTED DEVICES[^\r\n]*')
  if ($bm.Success) { $block = $bm.Value }
  $devs = @()
  foreach ($m in [regex]::Matches($block, '(?m)^--\s*(?<name>[^|\r\n]+?)\s*\|\s*0x[0-9A-Fa-f]+\s*\r?\n--\s*device\s*=\s*"(?<guid>\{[0-9A-Fa-f-]{36}\})"')) {
    $devs += [pscustomobject]@{ Name = $m.Groups['name'].Value.Trim(); Guid = $m.Groups['guid'].Value.ToUpper() }
  }
  $moza = @($devs | Where-Object { $_.Name -match 'MOZA' })
  $base = @($moza | Where-Object { $_.Name -match 'AB6|AB9|Base' })
  if ($base.Count) { $moza = $base }
  $guid = $null
  if ($moza.Count -eq 1) { $guid = $moza[0].Guid; Say-Info "MOZA device found: $($moza[0].Name) $guid" }
  elseif ($moza.Count -gt 1) {
    for ($i = 0; $i -lt $moza.Count; $i++) { Say-Info "[$($i+1)] $($moza[$i].Name) $($moza[$i].Guid)" }
    $n = Ask-Text 'Which one is your flight base? (number)' '1'
    if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $moza.Count) { $guid = $moza[[int]$n - 1].Guid }
  }
  $examples = @(
    @{ Key = '1'; File = 'AC8HOTAS-bindings-AB6.lua'; Text = 'Standard AB6 layout: missile on the red top button' },
    @{ Key = '2'; File = 'AC8HOTAS-bindings-AB6-trigger-missile.lua'; Text = 'Trigger-missile layout: missile on the trigger''s second stage, thumb never moves' })
  if (-not $guid) {
    if ($devs.Count) { Say-Action "AC8HOTAS lists no MOZA device. Plug in the base, start the game once (or press F5 in game), then rerun this installer." }
    else { Say-Action 'AC8HOTAS has not listed your controllers yet. Plug in the MOZA base, start the game once (with the offline shortcut), quit, then rerun this installer to set up the bindings.' }
  } else {
    Say-Info 'Pick a key binding layout (explained in README.md):'
    foreach ($e in $examples) { Say-Info "[$($e.Key)] $($e.Text)" }
    Say-Info '[S] Skip, keep my current bindings.lua'
    $c = Ask-Text 'Your choice' 'S'
    $pick = $examples | Where-Object { $_.Key -eq $c } | Select-Object -First 1
    if (-not $pick) { Say-Skip 'Key bindings left as they are.' }
    else {
      $src = Join-Path $SrcExamples $pick.File
      $new = (Read-TextFile $src) -replace [regex]::Escape($script:AuthorGuid), $guid
      if ($block) { $new = $new.TrimEnd() + "`r`n`r`n" + $block + "`r`n" }
      $hasOwn = [regex]::IsMatch(($cur -replace '(?s)-- BEGIN DETECTED DEVICES.*', ''), '(?m)^\s*\w+\s*=\s*\{\s*device\s*=')
      if ($cur -ceq $new) { Say-Skip 'bindings.lua already matches this layout.' }
      elseif ($hasOwn -and -not (Ask-YesNo 'Your bindings.lua already has bindings. Replace it? (a backup is kept)' $false)) { Say-Skip 'Kept your existing bindings.lua.' }
      else {
        if ($cur) { $bk = Backup-Item $bind; Set-Man 'bindingsBackup' $bk } else { Add-Created $bind }
        Write-TextFile $bind $new
        Say-OK "bindings.lua set to '$($pick.File)' with your device $guid."
        Say-Info 'In game: choose Expert flight controls, then press F5. Turn off any Xbox-controller emulator.'
      }
    }
  }
}

Write-Summary 'Summary'
Write-Host ''
if (Test-Path -LiteralPath $script:BackupRoot) { Write-Host " Backups of changed files: $($script:BackupRoot)" }
Write-Host ' To undo: run Uninstall-AceFFB.cmd.'
Write-Host ''
Write-Host ' Every time you play:' -ForegroundColor Cyan
Write-Host '   1. MOZA Cockpit: select DCS and press Start game.'
Write-Host '   2. DCS World: start it and leave it at the main menu.'
Write-Host '   3. AceBridge: run the AceBridge shortcut (or Start-AceBridge.cmd).'
Write-Host '   4. ACE COMBAT 8: start it with the "ACE COMBAT 8 (offline, no EAC)" shortcut. Offline campaign only.'
Write-Host ''
if ($Elevated) { [void](Read-Host ' Press Enter to close this window') }
