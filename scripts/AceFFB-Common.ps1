# Shared helpers for Install-AceFFB.ps1 and Uninstall-AceFFB.ps1 (dot-sourced).
# Windows PowerShell 5.1 compatible. Keep this file pure ASCII: PowerShell 5.1 reads BOM-less
# scripts as ANSI, so any non-ASCII character would be garbled.

$script:AppId        = '2288340'                         # ACE COMBAT 8: WINGS OF THEVE (Steam)
$script:AuthorGuid   = '{A4E48D70-C29A-11F1-8001-444553540000}'   # device GUID used in examples\*.lua
$script:Utf8NoBom    = New-Object System.Text.UTF8Encoding($false)
$script:Results      = New-Object System.Collections.ArrayList
$script:Stamp        = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Head([string]$Text) {
  Write-Host ''
  Write-Host ('=' * 72) -ForegroundColor DarkCyan
  Write-Host " $Text" -ForegroundColor Cyan
  Write-Host ('=' * 72) -ForegroundColor DarkCyan
}
function Add-Result([string]$Step, [string]$Status, [string]$Text) {
  [void]$script:Results.Add([pscustomobject]@{ Step = $Step; Status = $Status; Text = $Text })
}
function Say-OK([string]$Text)     { Write-Host "  [OK]            $Text" -ForegroundColor Green;  Add-Result $script:CurStep 'OK' $Text }
function Say-Skip([string]$Text)   { Write-Host "  [SKIP]          $Text" -ForegroundColor DarkGray; Add-Result $script:CurStep 'SKIP' $Text }
function Say-Action([string]$Text) { Write-Host "  [ACTION NEEDED] $Text" -ForegroundColor Yellow; Add-Result $script:CurStep 'ACTION NEEDED' $Text }
function Say-Fail([string]$Text)   { Write-Host "  [FAILED]        $Text" -ForegroundColor Red;    Add-Result $script:CurStep 'FAILED' $Text }
function Say-Info([string]$Text)   { Write-Host "                  $Text" }
function Say-Warn([string]$Text)   { Write-Host "  [!]             $Text" -ForegroundColor Magenta }

function Start-Step([string]$Name) {
  $script:CurStep = $Name
  Write-Head $Name
}

# Yes/no question. In -DryRun mode the default answer is used without asking.
function Ask-YesNo([string]$Question, [bool]$Default = $false) {
  $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
  if ($script:DryRun) { Write-Host "  ? $Question $hint -> (dry run, using default: $(if($Default){'yes'}else{'no'}))"; return $Default }
  while ($true) {
    $a = Read-Host "  ? $Question $hint"
    if ([string]::IsNullOrWhiteSpace($a)) { return $Default }
    switch -Regex ($a.Trim()) { '^(y|yes)$' { return $true } '^(n|no)$' { return $false } }
    Write-Host '    Please answer y or n.'
  }
}

# Free-text question with a default value.
function Ask-Text([string]$Question, [string]$Default) {
  if ($script:DryRun) { Write-Host "  ? $Question [$Default] -> (dry run, using default)"; return $Default }
  $a = Read-Host "  ? $Question [$Default]"
  if ([string]::IsNullOrWhiteSpace($a)) { return $Default }
  return $a.Trim().Trim('"')
}

function Read-TextFile([string]$Path) {
  # ReadAllText detects and strips a BOM if one is present.
  return [System.IO.File]::ReadAllText($Path)
}

# Every text file is written as UTF-8 WITHOUT a BOM (a BOM stops AC8HOTAS from loading bindings.lua).
function Write-TextFile([string]$Path, [string]$Text) {
  if ($script:DryRun) { Say-Info "(dry run) would write $Path"; return }
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

# Copies a file or folder into this run's backup folder before it is changed. Returns the backup path.
function Backup-Item([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $rel  = ($Path -replace '^[A-Za-z]:\\', '') -replace '^\\\\', 'UNC\'
  $dest = Join-Path $script:BackupRoot $rel
  if ($script:DryRun) { Say-Info "(dry run) would back up $Path"; return $dest }
  $parent = Split-Path -Parent $dest
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  if (Test-Path -LiteralPath $dest) { $dest = "$dest.$([guid]::NewGuid().ToString('N').Substring(0,6))" }
  Copy-Item -LiteralPath $Path -Destination $dest -Recurse -Force
  Say-Info "Backup: $dest"
  $script:Manifest.backups = @($script:Manifest.backups) + [pscustomobject]@{ original = $Path; backup = $dest; time = $script:Stamp }
  Save-Manifest
  return $dest
}

# ---- Manifest: remembers what the installer did, so Uninstall-AceFFB.ps1 can undo it ----
function Get-ManifestPath { Join-Path $script:StateDir 'install-manifest.json' }
function Load-Manifest {
  $p = Get-ManifestPath
  $m = $null
  if (Test-Path -LiteralPath $p) { try { $m = (Read-TextFile $p) | ConvertFrom-Json } catch { $m = $null } }
  if (-not $m) { $m = [pscustomobject]@{} }
  foreach ($k in 'backups', 'created') { if (-not ($m.PSObject.Properties.Name -contains $k)) { $m | Add-Member -NotePropertyName $k -NotePropertyValue @() } }
  $script:Manifest = $m
}
function Set-Man([string]$Key, $Value) {
  $script:Manifest | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force
  Save-Manifest
}
function Get-Man([string]$Key) {
  if ($script:Manifest.PSObject.Properties.Name -contains $Key) { return $script:Manifest.$Key }
  return $null
}
function Add-Created([string]$Path) {
  if (@($script:Manifest.created) -notcontains $Path) { $script:Manifest.created = @($script:Manifest.created) + $Path; Save-Manifest }
}
function Save-Manifest {
  if ($script:DryRun) { return }
  if (-not (Test-Path -LiteralPath $script:StateDir)) { New-Item -ItemType Directory -Force -Path $script:StateDir | Out-Null }
  [System.IO.File]::WriteAllText((Get-ManifestPath), (ConvertTo-Json -InputObject $script:Manifest -Depth 6), $script:Utf8NoBom)
}

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Test-Writable([string]$Dir) {
  try {
    $p = Join-Path $Dir ('.aceffb-write-test-' + [guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllText($p, 'x')
    Remove-Item -LiteralPath $p -Force
    return $true
  } catch { return $false }
}

# ---- Locating ACE COMBAT 8 ----
function Get-SteamRoots {
  $roots = New-Object System.Collections.ArrayList
  $keys = @(
    @{ Path = 'HKCU:\Software\Valve\Steam'; Name = 'SteamPath' },
    @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'; Name = 'InstallPath' },
    @{ Path = 'HKLM:\SOFTWARE\Valve\Steam'; Name = 'InstallPath' })
  foreach ($k in $keys) {
    try { $v = (Get-ItemProperty -Path $k.Path -Name $k.Name -ErrorAction Stop).($k.Name) } catch { $v = $null }
    if ($v) { $v = ($v -replace '/', '\').TrimEnd('\'); if ((Test-Path -LiteralPath $v) -and ($roots -notcontains $v)) { [void]$roots.Add($v) } }
  }
  $def = Join-Path ${env:ProgramFiles(x86)} 'Steam'
  if ((Test-Path -LiteralPath $def) -and ($roots -notcontains $def)) { [void]$roots.Add($def) }
  return @($roots)
}
function Get-SteamLibraries {
  $libs = New-Object System.Collections.ArrayList
  foreach ($r in Get-SteamRoots) {
    # libraryfolders.vdf first: its paths keep their real capitalisation (the registry value is often lower case)
    $vdf = Join-Path $r 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
      foreach ($m in [regex]::Matches((Read-TextFile $vdf), '"path"\s+"([^"]+)"')) {
        $p = ($m.Groups[1].Value -replace '\\\\', '\').TrimEnd('\')
        if ((Test-Path -LiteralPath $p) -and ($libs -notcontains $p)) { [void]$libs.Add($p) }
      }
    }
    if ($libs -notcontains $r) { [void]$libs.Add($r) }
  }
  return @($libs)
}
# Accepts the game root, Game\Binaries\Win64, or anything in between; returns the game root or $null.
function Resolve-GameRoot([string]$Path) {
  if (-not $Path) { return $null }
  $p = $Path.Trim().Trim('"').TrimEnd('\')
  for ($i = 0; $i -lt 4 -and $p; $i++) {
    if (Test-Path -LiteralPath (Join-Path $p 'Game\Binaries\Win64\AceCombat8.exe')) { return $p }
    $p = Split-Path -Parent $p
  }
  return $null
}
function Find-GameRoots {
  $found = New-Object System.Collections.ArrayList
  foreach ($lib in Get-SteamLibraries) {
    $dirs = @()
    $acf = Join-Path $lib "steamapps\appmanifest_$($script:AppId).acf"
    if (Test-Path -LiteralPath $acf) {
      $m = [regex]::Match((Read-TextFile $acf), '"installdir"\s+"([^"]+)"')
      if ($m.Success) { $dirs += $m.Groups[1].Value }
    }
    $dirs += 'ACE COMBAT 8'
    foreach ($d in $dirs) {
      $g = Resolve-GameRoot (Join-Path $lib "steamapps\common\$d")
      if ($g -and ($found -notcontains $g)) { [void]$found.Add($g) }
    }
  }
  return @($found)
}
function Select-FolderDialog([string]$Description) {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = $Description
    $dlg.ShowNewFolderButton = $false
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
  } catch { }
  return $null
}

# ---- UE4SS layout ----
# Returns @{ Installed; Partial; Dll; ModsDir; Settings; Layout } for a Win64 folder.
function Get-UE4SSInfo([string]$Win64) {
  $proxy = Join-Path $Win64 'dwmapi.dll'
  $sub   = Join-Path $Win64 'UE4SS\UE4SS.dll'
  $flat  = Join-Path $Win64 'UE4SS.dll'
  $info = @{ Installed = $false; Partial = $false; Dll = $null; ModsDir = $null; Settings = $null; Layout = $null }
  if (Test-Path -LiteralPath $sub)      { $info.Dll = $sub;  $info.Layout = 'subfolder'; $base = Join-Path $Win64 'UE4SS' }
  elseif (Test-Path -LiteralPath $flat) { $info.Dll = $flat; $info.Layout = 'flat';      $base = $Win64 }
  if ($info.Dll -and (Test-Path -LiteralPath $proxy)) {
    $info.Installed = $true
    $info.Settings = Join-Path $base 'UE4SS-settings.ini'
    $mods = Join-Path $base 'Mods'
    if (Test-Path -LiteralPath $info.Settings) {
      $m = [regex]::Match((Read-TextFile $info.Settings), '(?m)^[ \t]*ModsFolderPath[ \t]*=[ \t]*(\S.*?)[ \t]*\r?$')
      if ($m.Success -and $m.Groups[1].Value -and (Test-Path -LiteralPath $m.Groups[1].Value)) { $mods = $m.Groups[1].Value }
    }
    $info.ModsDir = $mods
  } elseif ($info.Dll -or (Test-Path -LiteralPath $proxy) -or (Test-Path -LiteralPath (Join-Path $Win64 'override.txt'))) {
    $info.Partial = $true
  }
  return $info
}

function Get-SavedGamesDirs([string]$UserHome) {
  $dirs = @()
  try {
    $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction Stop).'{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}'
    if ($v) { $dirs += [Environment]::ExpandEnvironmentVariables($v) }
  } catch { }
  $dirs += (Join-Path $UserHome 'Saved Games')
  return @($dirs | Select-Object -Unique)
}
function Get-MozaLuaFiles([string]$UserHome) {
  $files = @()
  foreach ($sg in Get-SavedGamesDirs $UserHome) {
    foreach ($d in 'DCS', 'DCS.openbeta', 'DCS.openalpha') {
      $f = Join-Path $sg "$d\Scripts\MOZA\MOZA.lua"
      if ((Test-Path -LiteralPath $f) -and ($files -notcontains $f)) { $files += $f }
    }
  }
  return @($files)
}

function New-Shortcut([string]$LnkPath, [string]$Target, [string]$Arguments, [string]$WorkDir, [string]$Icon) {
  if ($script:DryRun) { Say-Info "(dry run) would create shortcut $LnkPath"; return }
  $sh = New-Object -ComObject WScript.Shell
  $s = $sh.CreateShortcut($LnkPath)
  $s.TargetPath = $Target
  if ($Arguments) { $s.Arguments = $Arguments }
  if ($WorkDir) { $s.WorkingDirectory = $WorkDir }
  if ($Icon) { $s.IconLocation = $Icon }
  $s.Save()
}

function Write-Summary([string]$Title) {
  Write-Head $Title
  $last = ''
  foreach ($r in $script:Results) {
    if ($r.Step -ne $last) { Write-Host " $($r.Step)" -ForegroundColor Cyan; $last = $r.Step }
    $c = switch ($r.Status) { 'OK' { 'Green' } 'SKIP' { 'DarkGray' } 'ACTION NEEDED' { 'Yellow' } default { 'Red' } }
    Write-Host ("   {0,-15} {1}" -f "[$($r.Status)]", $r.Text) -ForegroundColor $c
  }
  $todo = @($script:Results | Where-Object { $_.Status -eq 'ACTION NEEDED' -or $_.Status -eq 'FAILED' })
  Write-Host ''
  if ($script:DryRun) { Write-Host ' DRY RUN: nothing was changed. "[OK]" above means "would be done".' -ForegroundColor Magenta; return }
  if ($todo.Count) {
    Write-Host " $($todo.Count) item(s) need your attention (yellow/red above). Fix them and run this again;" -ForegroundColor Yellow
    Write-Host ' it is safe to rerun: finished steps are skipped.' -ForegroundColor Yellow
  } else {
    Write-Host ' Everything is done.' -ForegroundColor Green
  }
}
