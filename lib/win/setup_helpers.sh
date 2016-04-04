function credential_helper () {
    echo wincred
}

function install_git_lfs ()
{
    local KIT_PATH=$1
    local VERSION=$2

    local GIT_LFS_CHECKSUM=7034f7ea80fb2d12033829a8d9d1c6c4
    # Run this to calculate the hash for a new version:
    # export V="1.1.1"; curl --location https://github.com/github/git-lfs/releases/download/v$V/git-lfs-windows-amd64-$V.zip | md5

    # Assigned in fetch_git_lfs
    local DOWNLOAD_FILE
    fetch_git_lfs $VERSION git-lfs-windows-amd64-$VERSION.zip $GIT_LFS_CHECKSUM

    echo "Installing Git LFS version $VERSION"

    # If Git LFS was already installed then install it in the same directory.
    # Otherwise use the Git directory.
    if has_command git-lfs; then
        TARGET_DIR=$(dirname $(which git-lfs))
    else
        TARGET_DIR=$(dirname $(which git))
    fi

    # The current Git-LFS installer cannot not be instructed to use a
    # certain install location. Use PowerShell to elevate the file
    # system rights and install Git-LFS to a custom location with the
    # Perl script.
    script="$KIT_PATH/lib/win/install_git_lfs.pl"
    powershell -command "Microsoft.PowerShell.Management\Start-Process -wait -verb runas perl \"$script\",\"$DOWNLOAD_FILE\",\"$TARGET_DIR\""

    # Cleanup
    rm -f $DOWNLOAD_FILE

    check_git_lfs no-install
}
