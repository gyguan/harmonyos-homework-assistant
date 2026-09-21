param(
  [switch]$Coverage
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptDir '..')).Path
$entryDir = Join-Path $projectRoot 'entry'
$packagePath = Join-Path $entryDir 'oh-package.json5'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$originalPackage = [System.IO.File]::ReadAllText($packagePath)

function Write-Utf8NoBom([string]$path, [string]$content) {
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

try {
  $package = $originalPackage | ConvertFrom-Json
  if ($null -eq $package.devDependencies) {
    $package | Add-Member -MemberType NoteProperty -Name 'devDependencies' -Value ([PSCustomObject]@{})
  }
  $package.devDependencies | Add-Member -MemberType NoteProperty -Name '@ohos/hypium' -Value '1.0.19' -Force
  $temporaryPackage = $package | ConvertTo-Json -Depth 20
  Write-Utf8NoBom $packagePath ($temporaryPackage + [Environment]::NewLine)

  Write-Host '[Harmony Local Test] Installing optional Hypium test dependency...'
  Push-Location $entryDir
  try {
    & ohpm install
    if ($LASTEXITCODE -ne 0) {
      throw "ohpm install failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }

  $coverageValue = if ($Coverage) { 'true' } else { 'false' }
  Write-Host "[Harmony Local Test] Running entry Local Test (coverage=$coverageValue)..."
  Push-Location $projectRoot
  try {
    & hvigorw test -p module=entry -p "coverage=$coverageValue" --no-daemon
    if ($LASTEXITCODE -ne 0) {
      throw "hvigorw test failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
} finally {
  Write-Utf8NoBom $packagePath $originalPackage
  Write-Host '[Harmony Local Test] Restored entry/oh-package.json5; normal app builds remain Hypium-free.'
}
