# Builds AceBridge and assembles a ready-to-zip release folder in .\release (gitignored).
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1                 # framework-dependent (needs .NET 8 Desktop Runtime)
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -SelfContained  # bundles the .NET runtime (bigger, no install needed)
param([switch]$SelfContained, [string]$Version = "0.2.1")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$name = "AceFFB-$Version"
$out  = Join-Path $root "release\$name"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null

$sc = if ($SelfContained) { "true" } else { "false" }
dotnet publish (Join-Path $root "bridge\AceBridge\AceBridge.csproj") -c Release -r win-x64 --self-contained $sc `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o (Join-Path $out "AceBridge")
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }
Remove-Item (Join-Path $out "AceBridge\*.pdb") -ErrorAction SilentlyContinue

Copy-Item (Join-Path $root "config\aircraft-map.json") (Join-Path $out "AceBridge\aircraft-map.json")
New-Item -ItemType Directory -Force (Join-Path $out "Mods") | Out-Null
Copy-Item -Recurse (Join-Path $root "mod\AceTelemetry") (Join-Path $out "Mods\AceTelemetry")
Copy-Item -Recurse (Join-Path $root "examples") (Join-Path $out "examples")
Copy-Item -Recurse (Join-Path $root "dcs") (Join-Path $out "dcs")
Copy-Item (Join-Path $root "scripts\Start-AceBridge.cmd") $out
Copy-Item (Join-Path $root "README.md"), (Join-Path $root "LICENSE") $out

$zip = Join-Path $root "release\$name.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $out "*") -DestinationPath $zip
Write-Host "Release folder: $out"
Write-Host "Release zip:    $zip"
