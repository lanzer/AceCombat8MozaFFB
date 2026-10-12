<#
  Removes only the AC8 presets (name starts with "AC8 ") from MOZA Cockpit's PresetLibrary,
  their PresetIndex entries and the OptimalMatch keys that point at them.
  Real DCS profiles are not touched. A backup is made first; the install script's
  PresetLibrary-backup-<date> folders are also left in place if you want a full restore.
#>
$ErrorActionPreference = 'Stop'
$lib = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'MOZA Cockpit\PresetLibrary'
$backup = "$lib-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item $lib $backup -Recurse; Write-Host "Backup: $backup"
$exe = "${env:ProgramFiles(x86)}\MOZA Cockpit\MOZA Cockpit.exe"
Get-Process 'MOZA Cockpit' -ea 0 | ForEach-Object { $_.CloseMainWindow() | Out-Null }
Start-Sleep 6; Get-Process 'MOZA Cockpit' -ea 0 | Stop-Process -Force
$idxPath = Join-Path $lib 'PresetIndex.index'; $omPath = Join-Path $lib 'OptimalMatch.vconfig'
$idx = Get-Content $idxPath -Raw | ConvertFrom-Json
$ac8 = @($idx.presets | Where-Object { $_.name -like 'AC8 *' })
$ids = $ac8.uuid
foreach ($u in $ids) { Remove-Item (Join-Path $lib "$u.preset") -ea 0 }
$idx.presets = @($idx.presets | Where-Object { $_.name -notlike 'AC8 *' })
$idx | ConvertTo-Json -Depth 10 | Set-Content $idxPath -Encoding UTF8
$om = Get-Content $omPath -Raw | ConvertFrom-Json
$map = $om.Base.AB6.dcs_world
foreach ($k in @($map.PSObject.Properties.Name)) { if ($ids -contains $map.$k) { $map.PSObject.Properties.Remove($k) } }
$om | ConvertTo-Json -Depth 10 | Set-Content $omPath -Encoding UTF8
if (Test-Path $exe) { Start-Process $exe }
Write-Host "Removed $($ac8.Count) AC8 presets."
