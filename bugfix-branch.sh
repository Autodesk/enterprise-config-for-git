#!/usr/bin/env bash
#
# Create a branch to deliver a critical bugfix
set -e

# Use git-sh-setup to initialize Git variables
SUBDIRECTORY_OK=Yes
. "$(git --exec-path)/git-sh-setup"
require_work_tree
cd_to_toplevel

# Source shared kit content
KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

: ${GIT_TRACE:=0}

function usage() {
    echo "Usage: git $KIT_ID bugfix-branch [--remote <owner>] [--release <release>] <branch>" >&2
    [[ $# -gt 0 ]] && die "$@"
    exit 0
}

# Parse parameters
declare options
options=$(getopt --longoptions "remote:,release:,help" --options "h" --name "git $KIT_ID bugfix-branch" -- "$@") || usage "Invalid parameters"
eval set -- "$options"
while :; do
    case "$1" in
        --remote) remote=$2; shift 2;;
        --release) release=$2; shift 2;;
        -h|--help) usage;;
        --) shift; break;;
    esac
done
[[ $# -eq 1 ]] || usage "Invalid parameters"
declare branch=$1
: ${remote:=$DEFAULT_OWNER}
: ${release:=$DEFAULT_RELEASE}

# Calculate the branch
[[ $branch ]] || usage "Missing branch name"
if [[ $branch != dev/* ]]; then
    declare gh_user=$(git config --global adsk.github.account)
    [[ $gh_user ]] || die "Missing GitHub user account"
    branch="dev/${gh_user,,}/$branch"
    say "NOTE: Using $branch as branch name"
fi

status "Checking the origin remote"
declare origin_url=$(git remote get-url origin)
[[ $origin_url ]] || die "Failed to get URL for origin remote"
[[ $origin_url = https://* ]] || die "Please clone using HTTPS"
declare repo=${origin_url##*/}
declare server_url=${origin_url%/*/$repo}
declare remote_url="$server_url/$remote/$repo"

status "Checking for $remote remote"
if ! git remote get-url "$remote" &>/dev/null; then
    status "Adding remote $remote"
    git remote add "$remote" "$remote_url" || die "Failed to define $remote remote"
fi

status "Updating local information about $remote remote"
git remote update "$remote" || die "Failed to update information about $remote remote"

status "Creating local bugfix branch"
git checkout -b "$branch" --track remotes/"$remote"/feature/"$release"-bugfix || die "Failed to create local $branch branch"

status "Configuring local bugfix branch to push to domain fork (origin)"
git config --local "branch.$branch.pushRemote" origin || die "Failed to set push destination of local $branch"

status "Your bugfix branch has been successfully created"
