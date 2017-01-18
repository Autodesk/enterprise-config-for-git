@echo off
rem
rem Run `install.bat` to install the Autodesk Git Bundle. It will ask
rem you for your credentials!
rem
rem Run `install.bat <TOKEN>` to install the Autodesk Git Bundle with a
rem GitHub token. More info here:
rem https://help.github.com/articles/creating-an-access-token-for-command-line-use/
rem

echo Installing Autodesk Git Bundle...

if [%1]==[] goto ask

SET USERNAME=token
SET PASSWORD=%1
goto :run

:ask
set /p USERNAME="Please enter your Autodesk username and press [ENTER]: "
set "psCommand=powershell -Command "$pword = read-host 'Please enter your Autodesk password (no GitHub token!) and press [ENTER]' -AsSecureString ; ^
    $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pword); ^
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)""
for /f "usebackq delims=" %%p in (`%psCommand%`) do set PASSWORD=%%p

:run
@powershell -NoProfile -ExecutionPolicy Bypass -Command "$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('%USERNAME%:%PASSWORD%')); $webClient = New-Object System.Net.WebClient; $webClient.Headers.add('Accept','application/vnd.github.v3.raw'); $webClient.Headers.add('Authorization',\"Basic ${auth}\"); iex $webClient.DownloadString('https://git.autodesk.com/api/v3/repos/github-solutions/adsk-git/contents/install-helper.ps1?ref=production').replace('<<USERNAME>>','%USERNAME%').replace('<<PASSWORD>>','%PASSWORD%')"
