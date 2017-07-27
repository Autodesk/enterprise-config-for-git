# =====================================================================
# Copyright 2011 - Present RealDimensions Software, LLC, and the
# original authors/contributors from ChocolateyGallery
# at https://github.com/chocolatey/chocolatey.org
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =====================================================================

$gitInstallerURL = 'https://github.com/git-for-windows/git/releases/download/v2.11.0.windows.3/Git-2.11.0.3-64-bit.exe'
$gitInstallerHash = 'c3897e078cd7f7f496b0e4ab736ce144c64696d3dbee1e5db417ae047ca3e27f'

if ((Get-WmiObject Win32_OperatingSystem).OSArchitecture -eq "32-bit") {
  $gitInstallerURL = 'https://github.com/git-for-windows/git/releases/download/v2.11.0.windows.3/Git-2.11.0.3-32-bit.exe'
  $gitInstallerHash = 'dff9bec9c4e21eaba5556fe4a7b1071d1f18e3a8b9645bffb48fda9eaee37e62'
}

if ($env:TEMP -eq $null) {
  $env:TEMP = Join-Path $env:SystemDrive 'temp'
}

$tempDir = Join-Path $env:TEMP "adsk-bundle"
if (![System.IO.Directory]::Exists($tempDir)) {[System.IO.Directory]::CreateDirectory($tempDir)}
$gitInstallerEXE = Join-Path $tempDir "Git-64-bit-installer.exe"
$bootstrap = Join-Path $tempDir "install-Git-and-GitADSK.bat"

# PowerShell v2/3 caches the output stream. Then it throws errors due
# to the FileStream not being what is expected. Fixes "The OS handle's
# position is not what FileStream expected. Do not use a handle
# simultaneously in one FileStream and in Win32 code or another
# FileStream."
function Fix-PowerShellOutputRedirectionBug {
  $poshMajorVerion = $PSVersionTable.PSVersion.Major

  if ($poshMajorVerion -lt 4) {
    try{
      # http://www.leeholmes.com/blog/2008/07/30/workaround-the-os-handles-position-is-not-what-filestream-expected/ plus comments
      $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
      $objectRef = $host.GetType().GetField("externalHostRef", $bindingFlags).GetValue($host)
      $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetProperty"
      $consoleHost = $objectRef.GetType().GetProperty("Value", $bindingFlags).GetValue($objectRef, @())
      [void] $consoleHost.GetType().GetProperty("IsStandardOutputRedirected", $bindingFlags).GetValue($consoleHost, @())
      $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
      $field = $consoleHost.GetType().GetField("standardOutputWriter", $bindingFlags)
      $field.SetValue($consoleHost, [Console]::Out)
      [void] $consoleHost.GetType().GetProperty("IsStandardErrorRedirected", $bindingFlags).GetValue($consoleHost, @())
      $field2 = $consoleHost.GetType().GetField("standardErrorWriter", $bindingFlags)
      $field2.SetValue($consoleHost, [Console]::Error)
    } catch {
      Write-Output "Unable to apply redirection fix."
    }
  }
}

Fix-PowerShellOutputRedirectionBug

function Download-File {
param (
  [string]$url,
  [string]$file
 )
  $downloader = new-object System.Net.WebClient
  $proxyurl = ""
  if (Test-Path env:http_proxy) {
     $proxyurl = $env:http_proxy
  }
  if ($proxyurl.length -gt 0) {
    $proxy = new-object System.Net.WebProxy
    $proxy.Address = $proxyurl
    $proxy.useDefaultCredentials = $true
    $downloader.proxy = $proxy
  }
  $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
  if ($defaultCreds -ne $null) {
    $downloader.Credentials = $defaultCreds
  }
  Try {
    $downloader.DownloadFile($url, $file)
  }
  Catch
  {
    Write-Host "ERROR" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
  }
}

Write-Host -NoNewline "Downloading '$gitInstallerURL'..."
Download-File $gitInstallerURL $gitInstallerEXE
Write-Output "OK"

function Check-SHA256 {
param (
  [string]$file
 )
  # Code snippet found here: https://github.com/FuzzySecurity/PowerShell-Suite/blob/master/Calculate-Hash.ps1
  $stream = [system.io.file]::openread((resolve-path $file))
  $algorithm = [System.Security.Cryptography.HashAlgorithm]::create("SHA256")
  $hash = $algorithm.ComputeHash($stream)
  $stream.close()
  $stream.dispose()
  $hash = [system.bitconverter]::tostring($hash).replace('-', '' )
  return $hash.ToLower()
}

Write-Host -NoNewline "Verifying SHA256 checksum of 'Git for Windows' installer..."
if ($PSVersionTable.PSVersion.Major -ge 4) {
  $hash = (Get-FileHash $gitInstallerEXE -Algorithm SHA256).Hash
}
else {
  $hash = Check-SHA256 $gitInstallerEXE
}
if ($hash -ne $gitInstallerHash) {
  Write-Host "ERROR" -ForegroundColor Red
  Write-Host "SHA256 hash of the 'Git for Windows' installer does not match:" -ForegroundColor Red
  Write-Host "Downloaded: $hash" -ForegroundColor Red
  Write-Host "Expected:   $gitInstallerHash" -ForegroundColor Red
  exit 1
}
Write-Output "OK"

Set-Content $bootstrap "@echo off" -Encoding ASCII
Add-Content $bootstrap "`"$gitInstallerEXE`" /SILENT /COMPONENTS=`"icons,icons\desktop,ext,ext\shellhere,ext\guihere,assoc,assoc_sh`"" -Encoding ASCII
Add-Content $bootstrap "SET PATH=%PATH%;`"C:\Program Files\Git\bin`""
Add-Content $bootstrap "git config --system --unset credential.helper" -Encoding ASCII
Add-Content $bootstrap "git clone -c credential.helper=`"!f() { cat >/dev/null; echo `"username=%1`"; echo `"password=%2`"; }; f`" --branch production https://git.autodesk.com/github-solutions/adsk-git.git `"%HOMEDRIVE%%HOMEPATH%\.adsk-git`"" -Encoding ASCII
Add-Content $bootstrap "git config --global include.path `"%HOMEDRIVE%%HOMEPATH%/.adsk-git/config.include`"" -Encoding ASCII

if ("<<USERNAME>>" -eq "token") {
  Add-Content $bootstrap "cmd /V /C `"set GITHUB_TOKEN=%2 && git adsk`"" -Encoding ASCII
} else {
  Add-Content $bootstrap "cmd /V /C `"git adsk`"" -Encoding ASCII
}

Start-Process  -verb RunAs $bootstrap '<<USERNAME>> <<PASSWORD>>'
