function open_url () {
    :
}

function credential_helper {
    echo cache
}

function credential_helper_parameters {
    # Cache credentials for 24h
    echo "--timeout=86400"
}

function install_git_lfs {
    local KIT_PATH=$1
    local VERSION=$2
    local GIT_LFS_CHECKSUM=33e65b2e1321fed86a6adbfcf008ea3c
    # Run this to calculate the hash for a new version:
    # export V="1.1.1"; curl --location https://github.com/github/git-lfs/releases/download/v$V/git-lfs-linux-amd64-$V.tar.gz | md5

    # Assigned in fetch_git_lfs
    local DOWNLOAD_FILE
    fetch_git_lfs $VERSION git-lfs-linux-amd64-$VERSION.tar.gz $GIT_LFS_CHECKSUM

    local EXTRACT_FOLDER=$(mktemp -d -t gitlfs_extract.XXXXXXX)
    if ! tar -xvf "$DOWNLOAD_FILE" -C "$EXTRACT_FOLDER"; then
        rm -f "$DOWNLOAD_FILE"
        rm -rf "$EXTRACT_FOLDER"
        error_exit "Failed to extract the contents of Git-LFS archive ($SRC_URL)"
    fi

    chmod -R 775 $EXTRACT_FOLDER
    for f in $(ls "$EXTRACT_FOLDER/"); do
        local PFX="/usr/bin"
        if ( has_command git-lfs ); then
            # reuse existing install folder if this is an update
            PFX=$(dirname $(which git-lfs))
        else
            PFX=$(perl "$KIT_PATH/lib/lnx/find_pfx.pl")
        fi
        chmod 755 "$EXTRACT_FOLDER/$f/git-lfs"
        sudo cp "$EXTRACT_FOLDER/$f/git-lfs" $PFX
        sudo chmod 755 $PFX/git-lfs
    done

    if [[ -e $DOWNLOAD_FILE ]]; then
        rm -f "$DOWNLOAD_FILE"
    fi

    if [[ -e $EXTRACT_FOLDER ]]; then
        rm -rf "$EXTRACT_FOLDER"
    fi

    check_git_lfs no-install
}
