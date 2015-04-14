#<powershell>
# Script version 0.2

# Allow use of Write-Verbose
[CmdletBinding()]
Param()

# Only tested with Powershell V4
#requires -version 4.0
Set-StrictMode -Version Latest  # Helps to catch errors

# Directories
$MY_HOME = "C:\Users\Administrator"
$DOWNLOADS = "$MY_HOME\Downloads"
$SSH_DIR = "$MY_HOME\.ssh"
$MOZILLABUILD_INSTALLDIR = "C:\mozilla-build"
$TREES = "$MY_HOME\trees"
$MC_REPO = "$TREES\mozilla-central"

# Versions
$MOZILLABUILD_VERSION = "1.11.0"
$NOTEPADPP_MAJOR_VER = "6"
$NOTEPADPP_VERSION = "$NOTEPADPP_MAJOR_VER.7.5"
$FXDEV_ARCH = "64"
$FXDEV_VERSION = "39.0a2"  # Change the URL in the $FXDEV_FTP variable as well.

# Programs
$FXDEV_FILENAME = "firefox-$FXDEV_VERSION.en-US.win$FXDEV_ARCH.installer.exe"
$MOZ_FTP = "https://ftp.mozilla.org/pub/mozilla.org"
$FXDEV_FTP = "$MOZ_FTP/firefox/nightly/2015/04/2015-04-13-00-40-06-mozilla-aurora/$FXDEV_FILENAME"
$FXDEV_FILE_WITH_DIR = "$DOWNLOADS\$FXDEV_FILENAME"
# For 32-bit, use "start-shell-msvc2013.bat". For 64-bit, use "start-shell-msvc2013-x64.bat"
$MOZILLABUILD_START_SCRIPT = "start-shell-msvc2013.bat"
$HG_BINARY = "$MOZILLABUILD_INSTALLDIR\hg\hg.exe"

Function DownloadBinary ($binName, $location) {
    # .DESCRIPTION
    # Downloads binaries.
    $wc = New-Object net.webclient  # Download prerequisites by not using Invoke-WebRequest (slow)
    Write-Verbose "Downloading $binName ..."
    if (-not (Test-Path $location)) {
        $wc.Downloadfile($binName, $location)
        Write-Verbose "Finished downloading to $location ."
    } else {
        Write-Verbose "$location already exists!"
    }
}

Function InstallBinary ($binName) {
    # .DESCRIPTION
    # Installs NSIS programs using the /S switch.
    Write-Verbose "Installing $binName ..."
    & $binName /S | out-null
    Write-Verbose "Finished installing $binName ."
}

Function ExtractArchive ($fileName, $dirName) {
    # .DESCRIPTION
    # Extracts archives using 7-Zip in mozilla-build directory.
    Write-Verbose "Extracting $fileName ..."
    (C:\mozilla-build\7zip\7z.exe e -y -o"$dirName" $fileName) | out-null
    Write-Verbose "Finished extracting $fileName ."
}

# Microsoft Visual Studio 2013 Community Edition
$VS2013COMMUNITY_FTP = "http://go.microsoft.com/?linkid=9863608"
$VS2013COMMUNITY_SETUP = "$DOWNLOADS\vs_community.exe"
DownloadBinary $VS2013COMMUNITY_FTP $VS2013COMMUNITY_SETUP
New-Item "$DOWNLOADS\AdminDeployment.xml" -type file -value '<?xml version="1.0" encoding="utf-8"?>
<AdminDeploymentCustomizations xmlns="http://schemas.microsoft.com/wix/2011/AdminDeployment">
    <BundleCustomizations TargetDir="default" NoWeb="default"/>

    <SelectableItemCustomizations>
        <SelectableItemCustomization Id="Blend" Hidden="no" Selected="no" />
        <SelectableItemCustomization Id="VC_MFC_Libraries" Hidden="no" Selected="no" />
        <SelectableItemCustomization Id="SQL" Hidden="no" Selected="no" />
        <SelectableItemCustomization Id="WebTools" Hidden="no" Selected="no" />
        <SelectableItemCustomization Id="SilverLight_Developer_Kit" Hidden="no" Selected="no" />
        <SelectableItemCustomization Id="Win8SDK" Hidden="no" Selected="no" />
        <SelectableItemCustomization Id="WindowsPhone80" Hidden="no" Selected="no" />
    </SelectableItemCustomizations>

</AdminDeploymentCustomizations>' | out-null
& "$DOWNLOADS\vs_community.exe" /Passive /NoRestart /AdminFile "$DOWNLOADS\AdminDeployment.xml" | Write-Output

# MozillaBuild
$MOZILLABUILD_FTP = "http://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-$MOZILLABUILD_VERSION.exe"
$MOZILLABUILD_SETUP = "$DOWNLOADS\MozillaBuildSetup-$MOZILLABUILD_VERSION.exe"
DownloadBinary $MOZILLABUILD_FTP $MOZILLABUILD_SETUP
InstallBinary $MOZILLABUILD_SETUP

# Notepad++ editor
$NOTEPADPP_FTP = "http://dl.notepad-plus-plus.org/downloads/$NOTEPADPP_MAJOR_VER.x/$NOTEPADPP_VERSION/npp.$NOTEPADPP_VERSION.bin.7z"
$NOTEPADPP_FILE = "$DOWNLOADS\npp.$NOTEPADPP_VERSION.bin.7z"
DownloadBinary $NOTEPADPP_FTP $NOTEPADPP_FILE
ExtractArchive $NOTEPADPP_FILE "$DOWNLOADS\npp-$NOTEPADPP_VERSION"

# Firefox Developer Edition (Aurora)
DownloadBinary $FXDEV_FTP $FXDEV_FILE_WITH_DIR
Write-Verbose "Installing $FXDEV_FILE_WITH_DIR ..."
& $FXDEV_FILE_WITH_DIR -ms | out-null
Write-Verbose "Finished installing $FXDEV_FILE_WITH_DIR ."

# mozilla-central bundle
$MCBUNDLE_FTP = "http://ftp.mozilla.org/pub/mozilla.org/firefox/bundles/mozilla-central.hg"
$MCBUNDLE_FILE = "$DOWNLOADS\mozilla-central.hg"
DownloadBinary $MCBUNDLE_FTP $MCBUNDLE_FILE

Write-Verbose "Setting up ssh configurations..."
New-Item $SSH_DIR -type directory | out-null
New-Item "$SSH_DIR\id_dsa.pub" -type file -value '<public key>' | out-null
New-Item "$SSH_DIR\id_dsa" -type file -value '<private key>' | out-null
New-Item "$SSH_DIR\config" -type file -value 'Host *
StrictHostKeyChecking no

Host hg.mozilla.org
User fuzzbots' | out-null
Write-Verbose "Finished setting up ssh configurations."

Write-Verbose "Setting up configurations..."
# Windows Registry settings
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting' -Name DontShowUI -Value 1 | out-null
# Mercurial settings
New-Item "$MY_HOME\.hgrc" -type file -value "[ui]
merge = internal:merge
ssh = $MOZILLABUILD_INSTALLDIR\msys\bin\ssh.exe -C -v

[extensions]
progress =
purge =
rebase =

[hostfingerprints]
hg.mozilla.org = af:27:b9:34:47:4e:e5:98:01:f6:83:2b:51:c9:aa:d8:df:fb:1a:27" | out-null
New-Item "$MY_HOME\repoUpdateRunBotPy.sh" -type file -value '#! /bin/bash
/usr/bin/env python -u ~/fuzzing/util/reposUpdate.py 2>&1 | tee ~/log-reposUpdate.txt
/usr/bin/env python -u ~/fuzzing/bot.py -b "--random" -t "js" --target-time=25000 2>&1 | tee ~/log-botPy.txt' | out-null

# -encoding utf8 is needed for out-file for the batch file to be run properly. See https://technet.microsoft.com/en-us/library/hh849882.aspx
cat "$MOZILLABUILD_INSTALLDIR\$MOZILLABUILD_START_SCRIPT" |
    % { $_ -replace ' --login -i', ' --login -i "%USERPROFILE%\repoUpdateRunBotPy.sh"' } |
    out-file "$MOZILLABUILD_INSTALLDIR\fz-$MOZILLABUILD_START_SCRIPT" -encoding utf8 |
    out-null
Write-Verbose "Finished setting up configurations."

Write-Verbose "Cloning fuzzing repository..."
Measure-Command { & $HG_BINARY --cwd $MY_HOME clone -e "$MOZILLABUILD_INSTALLDIR\msys\bin\ssh.exe -i $SSH_DIR\id_dsa -o stricthostkeychecking=no -C -v" `
    <repository location> fuzzing |
    Out-Host }
Write-Verbose "Finished cloning fuzzing repository."

Write-Verbose "Unbundling mozilla-central..."
New-Item $TREES -type directory | out-null
& $HG_BINARY --cwd $TREES init mozilla-central | out-null
New-Item "$MC_REPO\.hg\hgrc" -type file -value '[paths]

default = https://hg.mozilla.org/mozilla-central
' | out-null
& $HG_BINARY -R $MC_REPO unbundle "$DOWNLOADS\mozilla-central.hg" | Write-Output
Write-Verbose "Finished unbundling mozilla-central."

Write-Verbose "Updating mozilla-central..."
& $HG_BINARY -R $MC_REPO update -C default | Write-Output
& $HG_BINARY -R $MC_REPO pull | Write-Output
& $HG_BINARY -R $MC_REPO update -C default | Write-Output
Write-Verbose "Finished updating mozilla-central."

Write-Verbose "Setting scheduled fuzzing task..."
& schtasks.exe /create /sc hourly /mo 8 /ru Administrator /tn "jsFuzzing" /tr "$MOZILLABUILD_INSTALLDIR\fz-$MOZILLABUILD_START_SCRIPT" | Write-Output
Write-Verbose "Finished scheduling fuzzing task."
& schtasks.exe /run /tn "jsFuzzing" | Write-Output
Write-Verbose "Running scheduled fuzzing task once."

#</powershell>
