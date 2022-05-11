$script = $args[0]
$DOWNLOAD_FILE = $args[1]
$TARGET_DIR = $args[2]
$FOLDER = $args[3]

Start-Process -Verb runas C:\Program` Files\Git\usr\bin\perl -ArgumentList " $script","$DOWNLOAD_FILE",`"$TARGET_DIR`",`"$FOLDER`";
