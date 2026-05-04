# Generates all artifacts in one run:
# - certificate_pub.crt                  (upload to your target system)
# - certificate_pub.cer
# - private_key.pfx
# - private_key_pfx_password.txt
# - private_key_pfx_base64.txt
# - rsa-params.json                      (modulus/exponent/d/p/q/dp/dq/inverseQ in Base64)

param(
  [string]$OutDir = "..\jwt-keys\jwt-assets",
  [int]$YearsValid = 2
)

$ErrorActionPreference = "Stop"

$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$out = Join-Path $base $OutDir
New-Item -ItemType Directory -Path $out -Force | Out-Null

# 1) Create RSA cert
$cert = New-SelfSignedCertificate `
  -Subject "CN=JWTAssets" `
  -KeyAlgorithm RSA `
  -KeyLength 2048 `
  -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
  -KeySpec Signature `
  -KeyExportPolicy Exportable `
  -HashAlgorithm SHA256 `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -NotAfter (Get-Date).AddYears($YearsValid)

# 2) Public certificate export
$cerPath = Join-Path $out "certificate_pub.cer"
$crtPath = Join-Path $out "certificate_pub.crt"
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
certutil -f -encode $cerPath $crtPath | Out-Null

# 3) PFX + password
$pfxPasswordPlain = ([Guid]::NewGuid().ToString("N") + "!")
$pfxSecure = ConvertTo-SecureString $pfxPasswordPlain -AsPlainText -Force
$pfxPath = Join-Path $out "private_key.pfx"
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $pfxSecure | Out-Null
Set-Content -Path (Join-Path $out "private_key_pfx_password.txt") -Value $pfxPasswordPlain -NoNewline -Encoding ascii

# 4) PFX as Base64 (single line)
$pfxB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($pfxPath))
Set-Content -Path (Join-Path $out "private_key_pfx_base64.txt") -Value $pfxB64 -NoNewline -Encoding ascii

# 5) RSA params JSON + minified Base64
$rsa = $cert.PrivateKey -as [System.Security.Cryptography.RSACryptoServiceProvider]
if (-not $rsa) { throw "Private key is not RSACryptoServiceProvider." }

$params = $rsa.ExportParameters($true)
$rsaObj = [ordered]@{
  modulus  = [Convert]::ToBase64String($params.Modulus)
  exponent = [Convert]::ToBase64String($params.Exponent)
  d        = [Convert]::ToBase64String($params.D)
  p        = [Convert]::ToBase64String($params.P)
  q        = [Convert]::ToBase64String($params.Q)
  dp       = [Convert]::ToBase64String($params.DP)
  dq       = [Convert]::ToBase64String($params.DQ)
  inverseQ = [Convert]::ToBase64String($params.InverseQ)
}

# pretty JSON (optional debug)
$rsaJsonPath = Join-Path $out "rsa-params.json"
($rsaObj | ConvertTo-Json -Depth 3) | Set-Content -Path $rsaJsonPath -Encoding ascii

# minified JSON -> Base64 single line (for connection/header)
$minJson = $rsaObj | ConvertTo-Json -Compress
$minB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($minJson))
Set-Content -Path (Join-Path $out "rsa_params.min.b64.txt") -Value $minB64 -NoNewline -Encoding ascii

Write-Host "Done. Files in: $out"
Write-Host " - certificate_pub.crt"
Write-Host " - private_key.pfx"
Write-Host " - private_key_pfx_password.txt"
Write-Host " - private_key_pfx_base64.txt"
Write-Host " - rsa-params.json"
Write-Host " - rsa_params.min.b64.txt  (use this in connector)"
