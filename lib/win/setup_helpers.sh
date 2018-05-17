function open_url () {
	cmd //c start "${@//&/^&}"
}

function one_ping () {
    ping -n 1 $1
}

function credential_helper () {
    echo wincred
}

function is_admin() {
    net session > /dev/null 2>&1
}

function install_git_lfs () {
    local KIT_PATH=$1
    local VERSION=$2
    export GIT_LFS_INSTALLER_LIB="$KIT_PATH/install-helper.ps1"
    export GIT_LFS_INSTALLER_URL="https://github.com/git-lfs/git-lfs/releases/download/v$VERSION/git-lfs-windows-$VERSION.exe"
    export GIT_LFS_INSTALLER_SHA256='f11ee43eae6ae33c258418e6e4ee221eb87d2e98955c498f572efa7b607f9f9b'

    # Previous versions of this installer installed Git LFS into the wrong
    # directory. The current installer wouldn't update these files. If they
    # are earlier in the $PATH then Git would always find an outdated Git LFS
    # binary.
    rm -f /cmd/git-lfs.exe

    powershell -InputFormat None -ExecutionPolicy Bypass -File "$KIT_PATH/lib/win/install-git-lfs.ps1"
    check_git_lfs no-install
}

function install_git () {
    local USERNAME=$1
    local TOKEN=$2

    warning 'The upgrade will close all your git-bash windows.'
    read -n 1 -s -r -p "Press any key to continue"

    INSTALLBAT=$(mktemp -t "git-install-XXXXXXX.bat")
    cp "$KIT_PATH/install.bat" "$INSTALLBAT"

    # remove the first two arguments from the arguments array so that they
    # can be re-arranged.
    shift 2
    start "" "$INSTALLBAT" -password $TOKEN -username $USERNAME "$@"
}
