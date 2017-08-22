#
# Git LFS Install
#

. $env:GIT_LFS_INSTALLER_LIB
Fix-PowerShellOutputRedirectionBug

$gitLFSInstallerEXE = Join-Path $([System.IO.Path]::GetTempPath()) "git-lfs-installer.exe"

Detect-Previous-Installations
Download-File $env:GIT_LFS_INSTALLER_URL $gitLFSInstallerEXE "Git LFS"
Check-SHA256-Hash $gitLFSInstallerEXE $env:GIT_LFS_INSTALLER_SHA256 "Git LFS installer"
Run "admin" $gitLFSInstallerEXE "/SILENT /DIR=`"$env:programfiles\Git\mingw64\bin`"" "Git LFS installation failed"
