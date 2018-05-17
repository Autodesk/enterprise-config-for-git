#
# Windows Install Helper
#


# PowerShell v2/3 caches the output stream. Then it throws errors due
# to the FileStream not being what is expected. Fixes "The OS handle's
# position is not what FileStream expected. Do not use a handle
# simultaneously in one FileStream and in Win32 code or another
# FileStream."
function Fix-PowerShellOutputRedirectionBug {
    if ($PSVersionTable.PSVersion.Major -lt 4) {
        try {
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


# Download a file with progress indicator
# c.f. https://blogs.msdn.microsoft.com/jasonn/2008/06/13/downloading-files-from-the-internet-in-powershell-with-progress/
function Download-File {
    param (
        [string]$url,
        [string]$file,
        [string]$name
    )
    Write-Host "Downloading $($name) ..."

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $uri = New-Object System.Uri $url
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.set_Timeout(15000) #15 second timeout
    $response = $request.GetResponse()
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
    $responseStream = $response.GetResponseStream()
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $file, Create
    $buffer = new-object byte[] 10KB
    $count = $responseStream.Read($buffer,0,$buffer.length)
    $downloadedBytes = $count
    while ($count -gt 0)
    {
        $progressMsg = "Downloaded {0}K of {1}K" -f [System.Math]::Floor($downloadedBytes/1024),$totalLength
        try {
            # Jump to the beginning of the line in cmd.exe
            [System.Console]::CursorLeft = 0
        } catch {
            # Jump to the beginning of the line in git-bash.exe
            [System.Console]::Write("`r")
        }
        [System.Console]::Write($progressMsg)

        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer,0,$buffer.length)
        $downloadedBytes = $downloadedBytes + $count
    }

    $targetStream.Flush()
    $targetStream.Close()
    $targetStream.Dispose()
    $responseStream.Dispose()

    $downloader = new-object System.Net.WebClient
    $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
    if ($defaultCreds -ne $null) {
        $downloader.Credentials = $defaultCreds
    }
    $downloader.DownloadFile($url, $file)

    Write-Host ""
    Write-Host ""
}


function Check-SHA256-Hash {
    param (
        [string]$filepath,
        [string]$sha256hash,
        [string]$errormsg
    )

    if ($PSVersionTable.PSVersion.Major -ge 4) {
        $hash = Get-FileHash $filepath -Algorithm SHA256
        if ($hash.Hash -ne $sha256hash) {
            Write-Output "ERROR: SHA256 hash of the $($errormsg) does not match."
            exit
        }
    } else {
        Write-Output "WARNING: SHA256 hash of the $($errormsg) cannot be checked as your Powershell version is outdated (expected on Windows 7 and below)."
    }
}


function Run {
    param (
        [string]$permissions,
        [string]$filepath,
        [string]$arguments,
        [string]$errormsg
    )

    if ($PSVersionTable.PSVersion.Major -ge 3) {
        if ($permissions -eq "admin") {
            $result = Start-Process -verb RunAs -PassThru -Wait $filepath -ArgumentList $arguments
        } else {
            $result = Start-Process -NoNewWindow -PassThru -Wait $filepath -ArgumentList $arguments
        }
        if ($result.ExitCode -ne 0) {
            Write-Output "ERROR: $($errormsg) with exit code $($result.ExitCode)."
            Write-Host "Press any key to continue ..."
            $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
        }
    } else {
        if ($permissions -eq "admin") {
            $result = $(Start-Process -verb RunAs -PassThru $filepath $arguments)
        } else {
            $result = $(Start-Process -NoNewWindow -PassThru $filepath $arguments)
        }
        $result.WaitForExit()
        if ($result.ExitCode) {
            Write-Output "ERROR: $($errormsg) with exit code $($result.ExitCode)."
            Write-Host "Press any key to continue ..."
            $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
        }
    }
}


function Detect-Previous-Installations {
    if ([System.IO.Directory]::Exists("$env:programfiles\Git LFS")) {
        Write-Output "ERROR: 'Git LFS' installation detected."
        Write-Output "Git LFS is now part of Git for Windows and your"
        Write-Output "installation might conflict with the official install."
        Write-Output "Please do the following:"
        Write-Output "  1. Open 'Programs and Features'"
        Write-Output "  2. Uninstall 'Git LFS version x.y.z'"
        Write-Output "  3. Delete the directory '$env:programfiles\Git LFS'"
        Write-Output "     if it still exists"
        Write-Host "Press any key to continue ..."
        $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
}


# The following options are recognized in the -options array parameter as
# of git for windows 2.14.1.windows.1.  They are reverse engineered from
# this code: 
# https://github.com/git-for-windows/build-extra/blob/9e59621fc536037fe913ef08af0242572a0e5c08/installer/install.iss#L2088-L2158
#
#    PathOption = BashOnly|Cmd|CmdTools
#    SSHOption = OpenSSH|Plink
#        PlinkPath = <path>
#    CURLOption= OpenSSL|WinSSL
#    CRLFOption = LFOnly|CRLFAlways|CRLFCommitAsIs
#    BashTerminal = MinTTY|ConHost
#    PerformanceTweaksFSCache = Disabled|Enabled
#    UsecredentialManager = Disabled|Enabled
#    EnableSymLinks = Diabled|Enabled
#
# TODO: Maybe print out this table via a function parameter?
function Install-Git-For-Windows {
    param(
        [string]$username,
        [string]$password,
        [string]$auth,
        [string]$server,
        [string]$repo,
        [string]$branch,
        [string]$kitID,
        [string]$gitVersion='2.17.0.windows.1',
        [string]$sha64bit='39b3da8be4f1cf396663dc892cbf818cb4cfddb5bf08c13f13f5b784f6654496',
        [string]$sha32bit='65b710e39db3d83b04a8a4bd56f54e929fb0abbab728c0a9abbc0dace8e361d2',
        [switch]$prompt,
        [string[]]$options=@()
    )

    Fix-PowerShellOutputRedirectionBug

    $bitness = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    if ($bitness -eq "32-bit") {
        # This check works only for Windows 7/8. AFAIK there is no 32-bit Windows 10
        $gitInstallerHash = $sha32bit
    } else {
        # Set the bitness string explicitly as Windows 10 returns "64 bits"
        $bitness = "64-bit"
        $gitInstallerHash = $sha64bit
    }

    $gitBaseVersion = $gitVersion.SubString(0, $gitVersion.IndexOf('windows')-1)
    $gitInstallerURL = "https://github.com/git-for-windows/git/releases/download/v$($gitVersion)/Git-$($gitBaseVersion)-$($bitness).exe"
    $gitInstallerEXE = Join-Path $([System.IO.Path]::GetTempPath()) "git-installer.exe"

    Detect-Previous-Installations
    Download-File "$gitInstallerURL" "$gitInstallerEXE" "Git for Windows (Version $($gitVersion))"
    Check-SHA256-Hash "$gitInstallerEXE" "$gitInstallerHash" "Git for Windows installer"

    # Kill all existing shells to make the update possible
    Stop-Process -erroraction 'silentlycontinue' -processname mintty
    Stop-Process -erroraction 'silentlycontinue' -processname bash

    #
    # Read install options from the command line
    #
    $silent_arg="/SILENT"
    if ($prompt.IsPresent) {
        # If the user wants prompting, then
        # remove the "silent" switch
        $silent_arg = ""
    }

    $gfw_options = @{
        "UseCredentialManager" = "Disabled"
    }

    # Set/override options from the input parameters
    $options | % { $o = $_ -split '='; $gfw_options.Set_Item($o[0], $o[1]) }

    # combine options in to a string to pass to the invocation
    $gfw_str_opts = ($gfw_options.GetEnumerator() | % { "/o:$($_.Name)=$($_.Value)" }) -join ' '

    #
    # Install "Git for Windows"
    #
    Run "admin" $gitInstallerEXE "$silent_arg /COMPONENTS='icons,icons\desktop,ext,ext\shellhere,ext\guihere,gitlfs,assoc,assoc_sh' $gfw_str_opts" "Git for Windows installation failed"

    #
    # Setup "Enterprise Config for Git"
    #
    $script = Join-Path $([System.IO.Path]::GetTempPath()) "setup-enterprise-config-for-git.sh"
    $content = @"
#!/usr/bin/env bash
set -e

# Remove an existing Enterprise Config for Git installation
rm -rf '$home\.$kitID-git'

# Clone Enterprise Config for Git
printf -v HELPER "!f() { cat >/dev/null; echo 'username=%s'; echo 'password=%s'; }; f" "`$1" "`$2"
git -c credential.helper="`$HELPER" \
    clone --branch $branch \
    https://$server/$repo.git \
    '$home\.$kitID-git'
git config --global include.path '$home\.$kitID-git\config.include'

# Configure Enterprise Config for Git with the given username and password
CREDENTIALS_BASE64=`$3 BRANCH=$branch git $kitID
"@
    Set-Content $script $content -Encoding ASCII
    $params = @"
-c "/'$($script.Replace(':', '').Replace('\','/'))' '$username' '$password' '$auth'"
"@
    $env:Path = "$env:programfiles\Git\bin;C:\Program Files\Git\bin;" + $env:Path
    Run "user" sh.exe $params "'git $kitID' setup failed"
}
