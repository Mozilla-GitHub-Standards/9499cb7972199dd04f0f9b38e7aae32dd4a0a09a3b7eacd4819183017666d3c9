# MozillaBuild
$MOZILLABUILD_FTP = "http://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-$MOZILLABUILD_VERSION.exe"
$MOZILLABUILD_SETUP = "$DOWNLOADS\MozillaBuildSetup-$MOZILLABUILD_VERSION.exe"
DownloadBinary $MOZILLABUILD_FTP $MOZILLABUILD_SETUP
InstallBinary $MOZILLABUILD_SETUP
