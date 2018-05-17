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
    local GIT_LFS_SHA256=6755e109a85ffd9a03aacc629ea4ab1cbb8e7d83e41bd1880bf44b41927f4cfe

    # Assigned in fetch_git_lfs
    local DOWNLOAD_FILE
    fetch_git_lfs $VERSION git-lfs-linux-amd64-$VERSION.tar.gz $GIT_LFS_SHA256

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
            PFX=$(dirname $(which git))
        fi
        chmod 755 "$EXTRACT_FOLDER/$f/git-lfs"
        sudo cp "$EXTRACT_FOLDER/$f/git-lfs" $PFX
        sudo chmod 755 $PFX/git-lfs
    done

    if [ -e "$DOWNLOAD_FILE" ]; then
        rm -f "$DOWNLOAD_FILE"
    fi

    if [ -e "$EXTRACT_FOLDER" ]; then
        rm -rf "$EXTRACT_FOLDER"
    fi

    check_git_lfs no-install
}

function install_git {
    if [[ -f /etc/redhat-release && $(grep -c "CentOS Linux release 7" /etc/redhat-release) -eq 1 ]]; then
        # Centos 7

    elif [[ -f /etc/redhat-release && $(grep -c "Fedora release" /etc/redhat-release) -eq 1 ]]; then
        # Fedora
        sudo dnf update -y git
    elif [[ -f /etc/issue && $(grep -c "Ubuntu" /etc/issue) -eq 1 ]]; then
        # Ubuntu
        sudo apt-get -y install software-properties-common python-software-properties
        sudo add-apt-repository -y ppa:git-core/ppa
        sudo apt-get -y update
        sudo apt-get -y remove git
        sudo apt-get -y install git
    else
        error_exit "O/S not (yet) supported."
    fi
}
