$ErrorActionPreference = 'Stop'

function Resolve-Hvigorw {
  if ($env:HARMONY_HVIGORW) {
    if (Test-Path $env:HARMONY_HVIGORW) { return $env:HARMONY_HVIGORW }
  }

  if ($env:HARMONY_CLI_HOME) {
    $candidates = @(
      (Join-Path $env:HARMONY_CLI_HOME 'bin\hvigorw.bat'),
      (Join-Path $env:HARMONY_CLI_HOME 'bin\hvigorw'),
      (Join-Path $env:HARMONY_CLI_HOME 'hvigorw.bat'),
      (Join-Path $env:HARMONY_CLI_HOME 'hvigorw')
    )
    foreach ($candidate in $candidates) {
      if (Test-Path $candidate) { return $candidate }
    }
  }

  $command = Get-Command hvigorw -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  $command = Get-Command hvigorw.bat -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  throw 'HarmonyOS hvigorw not found. Install Huawei Command Line Tools 26.0.0 and expose hvigorw on PATH, or set HARMONY_CLI_HOME/HARMONY_HVIGORW.'
}

function Invoke-Hvigor([string]$Hvigorw, [string[]]$Arguments) {
  Write-Host ('+ ' + $Hvigorw + ' ' + ($Arguments -join ' '))
  & $Hvigorw @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "hvigorw failed with exit code $LASTEXITCODE"
  }
}

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $hvigorw = Resolve-Hvigorw
  Invoke-Hvigor $hvigorw @('-v')
  Invoke-Hvigor $hvigorw @('--sync', '--no-daemon')
  Invoke-Hvigor $hvigorw @('assembleHap', '--mode', 'module', '-p', 'product=default', '-p', 'buildMode=debug', '--no-daemon', '--no-parallel')
  Write-Host 'HARMONY_CLIENT_BUILD_PASS'
} finally {
  Pop-Location
}
