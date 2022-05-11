function open_url () {
    open "$1"
}

function credential_helper () {
    echo osxkeychain
}

function _brew_has_formulae() {
    has_command brew && \
        (( $(brew list --versions $1 | wc -l) > 0 ))
}

function _macports_has_port() {
    has_command port && \
        (( $(port installed $1 | wc -l) > 1 ))
}

function _managerless_lfs_install() {
    local VERSION=$1
    local GIT_LFS_CHECKSUM=e7048a1bcd89f7928598a246501926b5
    # Run this to calculate the hash for a new version:
    # export V="1.1.1"; curl --location https://github.com/github/git-lfs/releases/download/v$V/git-lfs-darwin-amd64-$V.tar.gz | md5

    # Assigned in fetch_git_lfs
    local DOWNLOAD_FILE
    fetch_git_lfs $VERSION git-lfs-darwin-amd64-$VERSION.tar.gz $GIT_LFS_CHECKSUM

    local EXTRACT_FOLDER=$(mktemp -d -t gitlfs_extract)
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
            local XCODE_PATH=$(xcode-select --print-path)
            if [[ $PFX == /usr || ( $XCODE_PATH && $PFX == ${XCODE_PATH}* ) ]]; then
                # El Capitan's "System integrity protection" doesn't let us
                # put things in /usr, and putting things in the xcode install
                # doesn't help either (not generally accessible via path, not
                # sure why "which git" is returning that path here).
                PFX=/usr/local
            fi
            echo "Installing git-lfs to $PFX, please supply credentials if prompted."
            if ! (cd "$EXTRACT_FOLDER/$f"; sudo env PREFIX=$PFX "$EXTRACT_FOLDER/$f/install.sh"); then
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
}

function install_git_lfs() {
    local KIT_PATH=$1
    local VERSION=$2
    local METHOD
    local ACTION=install

    if _brew_has_formulae git-lfs; then
        # If git-lfs has been installed via brew before, update using that
        METHOD=brew
        ACTION=reinstall
    elif _macports_has_port git-lfs; then
        # If git-lfs has been installed via macports before, update using that
        METHOD=port
        ACTION=upgrade
    elif _brew_has_formulae git; then
        # if git has been installed via brew, install git-lfs with that as well
        METHOD=brew
    elif _macports_has_port git; then
        # if git has been installed via macports, install git-lfs with that as well
        METHOD=port
    elif ! has_command git-lfs; then
        # If there is no git-lfs already installed
        # and we have a package manager, then why not use it, even if
        # we have been using the stock apple git
        if has_command port; then
            METHOD=port
        elif has_command brew; then
            METHOD=brew
        fi
    fi

    case $METHOD in
        brew )
            echo "Installing/Updating Git LFS using brew."
            brew update
            brew $ACTION git-lfs
            ;;
        port )
            echo "Installing/Updating Git LFS using MacPorts. Provide credentials as requested."
            sudo port sync
            sudo port $ACTION git-lfs
            ;;
        * )
            _managerless_lfs_install $VERSION
            ;;
    esac

    check_git_lfs no-install
}
