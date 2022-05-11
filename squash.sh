#!/usr/bin/env bash
#
# Automatically squash all pending Git commits
set -e

declare message="$*"

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

function die_handler() {
    if [[ $head && $head != HEAD ]]; then
        echo "Checking out original branch ($head) ..."
        git checkout "$head"
        printf "${red}ERROR${normal} (repeated): %s\\n" "$@" >&2
    fi
}

status "Finding information about the Git workspace"

declare head=$(git rev-parse --abbrev-ref HEAD)
[[ $head ]] || die "Unable to determine the current HEAD (are you in a Git workspace?)"
[[ $head != HEAD ]] || die "Running from a detached head is not supported"

declare upstream=$(git rev-parse --abbrev-ref @{upstream})
[[ $upstream ]] || die "Unable to determine the upstream branch"
[[ $upstream != */$head ]] || die "Upstream branch ($upstream) needs to be a different branch from the local branch ($head)"

declare upstream_rev=$(git rev-parse "$upstream")
[[ $upstream_rev ]] || die "Unable to determine revision for upstream branch ($upstream)"
[[ $upstream == $(git rev-parse --abbrev-ref refs/remotes/"$upstream") ]] || die "Upstream branch ($upstream) needs to be a remote branch"
[[ $head != $upstream_rev ]] || die "Nothing to squash"

declare base=$(git merge-base "$upstream" "$head")
[[ $base ]] || die "Unable to determine the merge base between the current HEAD ($head) and the upstream branch ($upstream)"

if [[ ! $message ]]; then
    declare msgrev=$(git log --no-merges --max-count=1 --format=%H "$upstream..$head")

    [[ $msgrev && $msgrev != $upstream_rev ]] || die "Unable to find a commit to use for a commit message"
    status "Reusing commit message from $msgrev"
    message=$(git show --no-patch --format=%B "$msgrev")
    [[ $message ]] || die "Unable to retrieve commit message from $message"
fi

status "Checking out the last merged revision ($base) from the upstream branch ($upstream)"
git checkout "$base" || die "Unable to check out the merge basis ($base)"

status "Squashing changes from your branch ($head)"
git merge --squash "$head" || die "Unable to squash change from $head onto $base"

status "Committing squashed changes"
git commit -m "$message" || die "Unable to commit squashed contents"

status "Updating $head to the squashed commit"
git checkout -B "$head" HEAD || die "Unable to update $head branch"

status "Your branch has been successfully squashed"
