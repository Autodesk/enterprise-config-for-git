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
    local GIT_LFS_CHECKSUM="8ae06f58d9133110e1ba7e5eddbe7058"
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

    for f in $(ls "$EXTRACT_FOLDER/"); do
        if [[ -x "$EXTRACT_FOLDER/$f/install.sh" ]]; then
            local PFX=$(dirname $(dirname $(which git)))
            if ( has_command git-lfs ); then
                # reuse existing install folder if this is an update
                PFX=$(dirname $(dirname $(which git-lfs)))
            fi
            echo "Installing git-lfs to $PFX, please supply credentials if prompted."
            if ! (cd "$EXTRACT_FOLDER/$f"; sudo PREFIX=$PFX "$EXTRACT_FOLDER/$f/install.sh"); then
                rm -f "$DOWNLOAD_FILE"
                rm -rf "$EXTRACT_FOLDER"
                error_exit "Failed to execute the Git-LFS installation script"
            fi
            break
        fi
    done

    if [[ -e $DOWNLOAD_FILE ]]; then
        rm -f "$DOWNLOAD_FILE"
    fi

    if [[ -e $EXTRACT_FOLDER ]]; then
        rm -rf "$EXTRACT_FOLDER"
    fi

    check_git_lfs no-install
}
