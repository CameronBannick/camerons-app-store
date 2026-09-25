# add-app.ps1 — drop a vibe-coded APK into the store.
#
# Usage:
#   ./add-app.ps1 -Apk "C:\path\to\MyApp.apk" -Name "My App" -Tagline "Does cool stuff"
#   ./add-app.ps1 -Apk ".\downloads\game.apk" -Name "Space Game" -Category "Games"
#
# It copies the APK into apps\, optionally copies an icon, and appends a
# new entry to catalog.json. Re-running with the same -Id updates that app.

param(
  [Parameter(Mandatory = $true)] [string]$Apk,
  [Parameter(Mandatory = $true)] [string]$Name,
  [string]$Tagline = "",
  [string]$Description = "",
  [string]$Version = "1.0.0",
  [string]$Category = "Apps",
  [string]$Icon = "",
  [string]$Id = ""
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$appsDir = Join-Path $root "apps"
$iconsDir = Join-Path $root "icons"
$catalogPath = Join-Path $root "catalog.json"

if (-not (Test-Path $Apk)) { throw "APK not found: $Apk" }
if (-not (Test-Path $appsDir)) { New-Item -ItemType Directory -Path $appsDir | Out-Null }

# Slug / id
if ([string]::IsNullOrWhiteSpace($Id)) {
  $Id = ($Name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
}

# Copy APK -> apps\<id>-<version>.apk
$apkFile = "$Id-$Version.apk"
$apkDest = Join-Path $appsDir $apkFile
Copy-Item -Path $Apk -Destination $apkDest -Force
$apkRel = "apps/$apkFile"

# Optional icon
$iconRel = "icons/placeholder.svg"
if (-not [string]::IsNullOrWhiteSpace($Icon)) {
  if (-not (Test-Path $Icon)) { throw "Icon not found: $Icon" }
  $ext = [System.IO.Path]::GetExtension($Icon)
  $iconFile = "$Id$ext"
  Copy-Item -Path $Icon -Destination (Join-Path $iconsDir $iconFile) -Force
  $iconRel = "icons/$iconFile"
}

# Size (MB)
$bytes = (Get-Item $apkDest).Length
$sizeStr = if ($bytes -ge 1MB) { "{0:N1} MB" -f ($bytes / 1MB) } else { "{0:N0} KB" -f ($bytes / 1KB) }

# Load catalog
$catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
if ($null -eq $catalog.apps) { $catalog | Add-Member -NotePropertyName apps -NotePropertyValue @() }

$entry = [ordered]@{
  id          = $Id
  name        = $Name
  tagline     = $Tagline
  description = if ($Description) { $Description } else { $Tagline }
  version     = $Version
  category    = $Category
  updated     = (Get-Date -Format "yyyy-MM-dd")
  icon        = $iconRel
  apk         = $apkRel
  size        = $sizeStr
  screenshots = @()
}

# Replace existing entry with same id, else append
$list = @($catalog.apps | Where-Object { $_.id -ne $Id })
$list += [pscustomobject]$entry
$catalog.apps = $list

# Drop the bundled sample once a real app is added
$catalog.apps = @($catalog.apps | Where-Object { $_.id -ne "sample-app" })

# Write UTF-8 *without* a BOM. Set-Content -Encoding utf8 adds one on Windows
# PowerShell 5.1, and that BOM trips any plain JSON parser reading the bytes.
$json = $catalog | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($catalogPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Added '$Name' ($sizeStr) -> $apkRel" -ForegroundColor Green
Write-Host "Now commit & push:" -ForegroundColor Cyan
Write-Host "  git add . ; git commit -m 'Add $Name' ; git push"
