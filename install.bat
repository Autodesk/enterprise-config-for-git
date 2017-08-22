@SET _PS=powershell %_EXTRA_PS_PARAMS% -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command
@%_PS% "$sb = [scriptblock]::create((Get-Content  '%~dpnx0' | Select -Skip 3) -join \"`n\"); & $sb %*"
@goto :EOF
#
# Run `install.bat` to install Enterprise Config for Git. It will ask
# you for your credentials!
#
# Run `install.bat <TOKEN>` to install the Enterprise Git Bundle with a
# GitHub token. More info here:
# https://help.github.com/articles/creating-an-access-token-for-command-line-use/
#

param(
    $password=$null,
    $username='token',
    $branch='production',
    $repo='your-org/your-repo',
    $server='yourserver.com',
    $company='Your Company',
    $kit_id='adsk'
)

$installurl="https://$server/api/v3/repos/$repo/contents/install-helper.ps1?ref=$branch"

function _getCreds() {
    $username = Read-Host "Please enter your username"
    if ($PSVersionTable.PSVersion.Major -ge 2) {
        $password = Read-Host -assecurestring 'Please enter your password';
        $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    } else {
        $password = Read-Host 'Please enter your password (input not hidden due to outdated PowerShell version)'
    }
    return $username, $password
}

Write-Host "######################################## Installer v3.0 ###"
Write-Host ""
Write-Host "Installing $company Git Bundle ..."
Write-Host ""
Write-Host "###########################################################"
Write-Host ""
Write-Host ""

# Get credentials
if ($password -eq $null) {
    $username, $password = (_getCreds)
}

# Compute the basic auth string
$auth = "${username}:${password}"
$auth = [System.Convert]::ToBase64String(
     [System.Text.Encoding]::UTF8.GetBytes($auth))

 # Debugging
 #Write-Host "User name: $username"
 #Write-Host "Password: $password"
 #Write-Host "Auth: $auth"
 #Write-Host "URL: $installurl"

# Empty line before any output from the downloaded install script
Write-Host ""

# Prepare client for web request
$webClient = New-Object System.Net.WebClient
$webClient.Headers.add('Accept','application/vnd.github.v3.raw')
$webClient.Headers.add('Authorization', "Basic ${auth}")

try
{
    # Download install helper script
    $installScript=$webClient.DownloadString($installurl)

    # Make install helper functions available
    . ([ScriptBlock]::Create($installScript))

    & Install-Git-For-Windows $username $password $auth $server $repo $branch $kit_id
}
catch [System.Net.WebException]
{
    Write-Host ""
    Write-Host "`Downloading the install script failed!"
    Write-Host ""
    Write-Host "Please check the following and retry:"
    Write-Host "    1. Verify your password"
    Write-Host "    2. Ensure your user name does NOT contain 'ads/'"
    Write-Host "    3. Check network connectivity to $server`n"
    Write-Host "Press any key to continue ..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
