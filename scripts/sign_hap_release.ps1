# Build a SIGNED .hap from the hvigor "unsigned" output, using the signing
# material that ships with the OpenHarmony/HarmonyOS SDK (OpenHarmony.p12).
#
# What this gets you:
#   - a signed HAP that passes `hap-sign-tool verify-app`
#   - installable on OpenHarmony targets / local emulator builds that trust the
#     OpenHarmony root CA
#   - NO Huawei account needed
#
# What this does NOT get you:
#   - installation on a commercial HarmonyOS (Huawei) phone. Those devices only
#     trust certificates + provisioning profiles issued by Huawei AGC, so the
#     one-time step is: open DevEco Studio, log in with a Huawei account, then
#     File > Project Structure > Signing Configs > "Automatically generate
#     signature". After that the IDE (or hvigor with that signingConfig) emits a
#     phone-installable HAP.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\sign_hap_release.ps1 `
#     -HapPath entry\build\default\outputs\default\entry-default-unsigned.hap `
#     -CompatibleVersion 20

param(
    [Parameter(Mandatory = $true)][string]$HapPath,
    [string]$OutPath = "",
    [string]$DevEcoHome = "E:\DevTools\DevEco Studio",
    [int]$CompatibleVersion = 20,
    [string]$KeystorePwd = "123456"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$lib = Join-Path $DevEcoHome "sdk\default\openharmony\toolchains\lib"
$java = Join-Path $DevEcoHome "jbr\bin\java.exe"
$keytool = Join-Path $DevEcoHome "jbr\bin\keytool.exe"
$signTool = Join-Path $lib "hap-sign-tool.jar"
$sigDir = Join-Path $repoRoot "signature"

foreach ($p in @($java, $keytool, $signTool)) {
    if (-not (Test-Path $p)) { throw "Not found: $p (check -DevEcoHome)" }
}

if (-not [System.IO.Path]::IsPathRooted($HapPath)) {
    $HapPath = Join-Path $repoRoot $HapPath
}
if (-not (Test-Path $HapPath)) { throw "Unsigned HAP not found: $HapPath" }
$hapFile = Get-Item $HapPath
if ($OutPath -eq "") {
    $baseName = $hapFile.BaseName -replace "-unsigned$", ""
    $OutPath = Join-Path $hapFile.DirectoryName "${baseName}-signed.hap"
}

New-Item -ItemType Directory -Force -Path $sigDir | Out-Null

Write-Host "[1/5] Copy SDK signing material into $sigDir"
Copy-Item (Join-Path $lib "OpenHarmony.p12") $sigDir -Force
Copy-Item (Join-Path $lib "OpenHarmonyProfileRelease.pem") $sigDir -Force

Write-Host "[2/5] Assemble the 3-level application certificate chain"
# IMPORTANT: the p12 entry "openharmony application release" holds a SELF-SIGNED
# placeholder cert (same key pair, but issuer == subject), which makes
# hap-sign-tool fail with "verify certificate chain failed! Signature does not
# match." The CA-issued cert for that very same key pair is embedded in the
# SDK's release profile template, so take the leaf from there and the
# CA + root from the keystore.
$template = Get-Content (Join-Path $lib "UnsgnedReleasedProfileTemplate.json") -Raw | ConvertFrom-Json
$leafPem = $template.'bundle-info'.'distribution-certificate'

$caRaw = & $keytool -list -rfc -alias "openharmony application ca" `
    -keystore (Join-Path $lib "OpenHarmony.p12") -storepass $KeystorePwd 2>$null
$caLines = @()
$inCert = $false
foreach ($line in $caRaw) {
    if ($line -match "-----BEGIN CERTIFICATE-----") { $inCert = $true }
    if ($inCert) { $caLines += $line }
    if ($line -match "-----END CERTIFICATE-----") { $inCert = $false }
}
$appCert = Join-Path $sigDir "OpenHarmonyApplication.pem"
[System.IO.File]::WriteAllText($appCert,
    $leafPem.TrimEnd() + "`r`n" + ($caLines -join "`r`n") + "`r`n",
    (New-Object System.Text.UTF8Encoding($false)))
$certCount = (Select-String -Path $appCert -Pattern "BEGIN CERTIFICATE" -AllMatches).Matches.Count
Write-Host "      chain contains $certCount certificates (leaf + CA + root)"

Write-Host "[3/5] Build the release provision profile for this bundle"
$appJson5 = Get-Content (Join-Path $repoRoot "AppScope\app.json5") -Raw
$bundleName = [regex]::Match($appJson5, '"bundleName"\s*:\s*"([^"]+)"').Groups[1].Value
if ($bundleName -eq "") { throw "bundleName not found in AppScope/app.json5" }

$profile = Get-Content (Join-Path $lib "UnsgnedReleasedProfileTemplate.json") -Raw | ConvertFrom-Json
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$profile.uuid = [guid]::NewGuid().ToString()
$profile.validity.'not-before' = $now - 86400
$profile.validity.'not-after' = $now + 315360000   # ~10 years
$profile.'bundle-info'.'bundle-name' = $bundleName
$profileJson = Join-Path $sigDir "profile-release.json"
[System.IO.File]::WriteAllText($profileJson, ($profile | ConvertTo-Json -Depth 10),
    (New-Object System.Text.UTF8Encoding($false)))
Write-Host "      bundle-name = $bundleName"

$p7b = Join-Path $sigDir "homework-release.p7b"
& $java -jar $signTool sign-profile -mode localSign `
    -keyAlias "openharmony application profile release" -keyPwd $KeystorePwd `
    -profileCertFile (Join-Path $sigDir "OpenHarmonyProfileRelease.pem") `
    -inFile $profileJson -signAlg SHA256withECDSA `
    -keystoreFile (Join-Path $sigDir "OpenHarmony.p12") -keystorePwd $KeystorePwd `
    -outFile $p7b
if ($LASTEXITCODE -ne 0) { throw "sign-profile failed" }

Write-Host "[4/5] Sign the HAP -> $OutPath"
& $java -jar $signTool sign-app -mode localSign `
    -keyAlias "openharmony application release" -keyPwd $KeystorePwd `
    -appCertFile $appCert -profileFile $p7b `
    -inFile $hapFile.FullName -signAlg SHA256withECDSA `
    -keystoreFile (Join-Path $sigDir "OpenHarmony.p12") -keystorePwd $KeystorePwd `
    -outFile $OutPath -compatibleVersion $CompatibleVersion -signCode 1
if ($LASTEXITCODE -ne 0) { throw "sign-app failed" }

Write-Host "[5/5] Verify the signed HAP"
& $java -jar $signTool verify-app -inFile $OutPath -outCertChain (Join-Path $sigDir "verify-certchain.cer") `
    -outProfile (Join-Path $sigDir "verify-profile.p7b")
if ($LASTEXITCODE -ne 0) { throw "verify-app failed" }

$out = Get-Item $OutPath
Write-Host ""
Write-Host "DONE: $($out.FullName)"
Write-Host "size: $([math]::Round($out.Length / 1MB, 2)) MB"
