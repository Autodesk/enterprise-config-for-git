#!/usr/bin/env bash
#
# Eases the installation like this:
# curl --user '<YOUR-USER>:<YOUR-PASSWORD>' https://git.company.com/raw/org/enterprise-config-for-git/master/install.sh | sh
#

# Make sure any unintentional errors abort the script.
set -e

function _has() {
    which "$1" > /dev/null 2>&1
}

function _osxPackageManager() {
    if _has brew; then
        echo brew
        return
    elif _has port; then
        echo macports
        return
    fi

    echo "Installing brew to handle managing adsk-git requirements" 1>&2
    /usr/bin/ruby -e \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/932004ac080139249e8329eba639dce30c34d8d8/install)" 1>&2
    echo brew
}

function installGitOSX() {
    local _pkgmgr=$(_osxPackageManager)

    case $_pkgmgr in
        brew)
            brew update
            brew install git
            ;;
        macports)
            echo "Installing git with macports, please provide credentials" \
                "as required"
            sudo port sync
            sudo port install git
            ;;
        *)
            echo "could not find a package manager for git installation" 1>&2
            exit 1
            ;;
    esac
}

case $(uname) in
    Darwin)
        # make sure we have a package manager
        _osxPackageManager > /dev/null
        if ! _has git; then
            installGitOSX
        fi
        ;;
    *)
        if ! _has git; then
            echo "git is required and auto install is unsupported on this" 1>&2
            echo "platform.  Please install git first." 1>&2
            exit 1
        fi
        ;;
esac

git clone --branch production https://git.autodesk.com/github-solutions/adsk-git.git ~/.enterprise
git config --global include.path ~/.enterprise/config.include

# run git adsk setup
git adsk setup
