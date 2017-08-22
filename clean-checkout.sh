#!/usr/bin/env bash
#/
#/ Clean checkout of a branch/tag/commit including all submodules.
#/ Attention: This is going to delete all local changes!
#/
#/ Usage: git $KIT_ID clean-checkout <options> <branch>
#/
#/ <options> will be passed to the git clean command, see git-clean reference
#/           for available options (-d --force --quiet are passed by default)
#/ <branch>  is expected to be the last argument
#/
#/ Example: git ask clean-checkout master
#/
set -e

# check if there is at least one argument passed to the command
if [ $# -lt 1 ]; then
    echo "No branch/commit specified"
    exit 1
fi

function execute_with_retry {
    COMMAND=$1
    RETRIES=7   # longest continuous wait should be 64s (2**6)
    COUNT=1     # first try after 4s, if needed
    RET=1       # make command overwrite this
    while [ $COUNT -lt $RETRIES ]; do
        set +e
        $COMMAND
        RET=$?
        set -e
        if [ $RET -eq 0 ]; then
            break
        fi
        COUNT=$((COUNT+1))
        DELAY=$((2**COUNT))
        sleep $DELAY
    done
    if [ $RET -gt 0 ]; then
        echo "'$COMMAND' failed with exit code '$RET'"
        exit $RET
    fi
}


# read branch and options from the arguments, branch is expected to be the last argument
REF=${!#}
OPTIONS=${@:1:$#-1}

# fetch latest changes from all remotes
# cleanup all refs that no longer exist in the remote:
#   * could avoid name collisions on case insensitive file systems

execute_with_retry "git fetch --all --force --prune"

# checkout branch and update submodules
git checkout --force $REF
git submodule sync --recursive
execute_with_retry "git submodule update --force --init --recursive"

# clean up repo and submodules
git clean -d --force --quiet $OPTIONS
git submodule foreach --recursive git clean -d --force --quiet $OPTIONS
git submodule foreach --recursive git reset --hard HEAD
