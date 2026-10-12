<#
  Installs the AC8 MOZA Cockpit presets (AB6, DCS mode) into your PresetLibrary.
  - Backs up Documents\MOZA Cockpit\PresetLibrary to PresetLibrary-backup-<date> first.
  - Only ADDS AC8-only aircraft names (e.g. F-22A, FA-18C-AC8). Existing keys in
    OptimalMatch.vconfig are never overwritten, so real DCS profiles are untouched.
#>
param([string]$PresetDir = (Join-Path $PSScriptRoot '..\cockpit-presets'))
$ErrorActionPreference = 'Stop'
$lib  = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'MOZA Cockpit\PresetLibrary'
if (-not (Test-Path $lib)) { throw "PresetLibrary not found: $lib (run MOZA Cockpit once first)" }
$backup = "$lib-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item $lib $backup -Recurse
Write-Host "Backup: $backup"

# close Cockpit so it doesn't overwrite our edits
$exe = (Get-Process 'MOZA Cockpit' -ea 0 | Where-Object Path | Select-Object -First 1).Path
if (-not $exe) { $exe = "${env:ProgramFiles(x86)}\MOZA Cockpit\MOZA Cockpit.exe" }
if ($exe -like '*\bin\*') { $exe = Join-Path (Split-Path (Split-Path $exe)) 'MOZA Cockpit.exe' }
Get-Process 'MOZA Cockpit' -ea 0 | ForEach-Object { $_.CloseMainWindow() | Out-Null }
Start-Sleep 6
Get-Process 'MOZA Cockpit' -ea 0 | Stop-Process -Force

$idxPath = Join-Path $lib 'PresetIndex.index'
$omPath  = Join-Path $lib 'OptimalMatch.vconfig'
$idx = if (Test-Path $idxPath) { Get-Content $idxPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{ presets = @() } }
$om  = if (Test-Path $omPath)  { Get-Content $omPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{ Base = [pscustomobject]@{}; version = '1.0.4' } }

if (-not $om.Base.AB6) { $om.Base | Add-Member AB6 ([pscustomobject]@{}) }
if (-not $om.Base.AB6.dcs_world) { $om.Base.AB6 | Add-Member dcs_world ([pscustomobject]@{}) }
$map = $om.Base.AB6.dcs_world
$presets = [System.Collections.ArrayList]@($idx.presets)

foreach ($f in Get-ChildItem $PresetDir -Filter *.preset) {
  $p = Get-Content $f.FullName -Raw | ConvertFrom-Json
  $dest = Join-Path $lib "$($p.uuid).preset"
  Copy-Item $f.FullName $dest -Force
  if (-not ($presets | Where-Object uuid -eq $p.uuid)) {
    [void]$presets.Add([pscustomobject]@{ date=$p.date; device_type=$p.device_type; devices=@($p.devices)
      file_path=($lib + '/' + "$($p.uuid).preset"); games=@($p.games); name=$p.name
      product_type=$p.product_type; uuid=$p.uuid; vehicles=$p.vehicles; version=$p.version })
  }
  if ($map.PSObject.Properties.Name -contains $p.vehicles) {
    if ($map.($p.vehicles) -ne $p.uuid) { Write-Warning "Keeping existing mapping for $($p.vehicles)" }
  } else { $map | Add-Member $p.vehicles $p.uuid }
  Write-Host "Installed $($p.name)"
}
$idx.presets = @($presets)
$idx | ConvertTo-Json -Depth 10 | Set-Content $idxPath -Encoding UTF8
$om  | ConvertTo-Json -Depth 10 | Set-Content $omPath -Encoding UTF8
if (Test-Path $exe) { Start-Process $exe }
Write-Host "Done. To undo, run Uninstall-CockpitPresets.ps1 or restore $backup"
