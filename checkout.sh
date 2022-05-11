#!/usr/bin/env bash
#
# Checkout a branch, possibly by build identifier, and update submodules accordingly
#
# Usage: git <KIT_ID> checkout [--ibid <ibid> | --revision <rev> | <branch>]
#
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
    echo "Usage: git $KIT_ID checkout [--ibid <IBID> | --revision <rev>] [--remote <remote>]" >&2
    [[ $# -gt 0 ]] && die "$@"
    exit 0
}


declare -a args
declare -i idx
declare ibid
declare revision
declare remote=origin

# Process arguments
for ((idx=1; idx <= $#; idx++)); do
    if [[ ${!idx} == --ibid || ${!idx} == -i ]]; then
        if [[ $revision ]]; then
            echo "WARNING: IBID taking precedence over revision" >&2
            unset revision
        fi
        idx+=1
        ibid=${!idx}
    elif [[ ${!idx} == --revision || ${!idx} == --rev || ${!idx} == -r ]]; then
        if [[ $ibid ]]; then
            echo "WARNING: Build revision taking precedence over IBID" >&2
            unset ibid
        fi
        idx+=1
        revision=${!idx}
    elif [[ ${!idx} == --remote || ${!idx} == -R ]]; then
        # TODO Query IBID to determine remote instead
        idx+=1
        remote=${!idx}
    elif [[ ${!idx} == --help || ${!idx} == -h ]]; then
        usage
    else
        args+=("${!idx}")
    fi
done

# Determine commit to fetch
if [[ $ibid ]]; then
    status "Identifying Git source for IBID $ibid"
    git fetch "$remote" refs/ibid/"$ibid" || die "Unable to fetch IBID record $ibid from $remote remote"
    commit=$(git rev-parse --quiet FETCH_HEAD)
    [[ $commit ]] || die "Failed to identify commit for IBID record $ibid"
    args+=("$commit")
elif [[ $revision ]]; then
    status "Identifying Git source for build revision $revision"
    git fetch "$remote" refs/revision/"$revision" || die "Unable to fetch build revision $revision from $remote remote"
    commit=$(git rev-parse --quiet FETCH_HEAD)
    [[ $commit ]] || die "Failed to identify commit for build revision $revision"
    args+=("$commit")
fi

# Check out content
status "Updating workspace"
git checkout "${args[@]}" || die "Checkout failed"
[[ ! -e .gitmodules ]] || git submodule update --init --recursive || die "Submodule update failed"

if [[ $ibid ]]; then
    status "Your workspace has been updated to match IBID $ibid"
elif [[ $revision ]]; then
    status "Your workspace has been updated to match build revision $revision"
else
    status "Your workspace has been successfully updated"
fi
