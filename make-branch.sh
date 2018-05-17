#!/usr/bin/env bash
#/
#/ Make a new branch
#/
#/ Usage: git $KIT_ID make-branch [--no-local-repo-checks]
#/
#/ The command will ask for a base branch. If the base branch exists locally,
#/ it will work with it, otherwise it will work with the origin base branch.
#/
#/ if --no-local-repo-checks is specified,
#/ the command will not check if there're uncommitted changes in the folder
#/ or if the branch you're creating is unrelated to the current one.
#/
set -e

KIT_PATH="$(dirname "${BASH_SOURCE[0]}")"
. "$KIT_PATH/lib/setup_helpers.sh"
. "$KIT_PATH/lib/git-utils.sh"

NO_LOCAL_REPO_CHECKS=""
if [[ -n $1 ]]; then
    if [[ $1 = "--no-local-repo-checks" ]]; then
        NO_LOCAL_REPO_CHECKS="1"
    else
        error_exit "Unrecognized param $1"
    fi
fi

WORKTREE_DIRTY='
    You cannot create a new branch as your repository contains
    uncommitted changes.

    If you want to use the changes in your new branch, then do the
    following:
        1. Run `git stash` to stash the changes away
        2. Run `git adsk make-branch`, again, to create a new branch
        3. Run `git stash apply` to apply the stashed changes to the
           new branch

    If you wish to abandon the changes, use --no-local-repo-checks flag'

# Check if submodules have been changed.
# c.f. https://github.com/git/git/blob/master/Documentation/technical/index-format.txt
if git diff-index HEAD -- | grep '^:16.... 16.... ' >/dev/null;
then
    WORKTREE_DIRTY+='


    Attention: Submodules
    ^^^^^^^^^^^^^^^^^^^^^
    Changes in submodules cannot be stashed from the parent repository.
    Commit, stash, or revert them in the respective submodule. Git would
    also detect uncommitted changes if your submodules checkout commit
    does not match the commit recorded in the parent repository. If you
    did not change the submodule commit intentionally then do the
    following:
         4. Run `git submodule update --recursive`
    '
fi

echo '###'
echo '### New Branch'
echo '###'
echo ''

set +e
USERNAME=$(git config adsk.github.account)
JIRA_KEY=$(git config adsk.jira.key)
set -e

[ -z "$USERNAME" ] && error_exit "Git configuration error. Please run 'git adsk' and/or contact @githelp on #tech-git!"

OPTIONS=()
UPSTREAM_BRANCH_NAME=()
UPSTREAM_BRANCH_BASE=()

# Read all stable branches from the Git config
while read line
do
    NAME=$(echo $line | sed 's/^adsk\.make-branch\.upstream-[0-9]* \([^|]*\).*/\1/')
    BASE=$(echo $line | grep '|' | sed 's/^adsk\.make-branch\.upstream-[0-9]* .*|\(.*\)$/\1/')
    if [ -n "$NAME" ]
    then
        OPTIONS+=("$NAME")
        UPSTREAM_BRANCH_NAME+=("$NAME")
        UPSTREAM_BRANCH_BASE+=("$BASE")
    fi
done <<< "$(git config --get-regexp '^adsk\.make-branch\.upstream-[0-9]*$')"

# Set "master" branch as default upstream branch if no upstream branch is defined
if [ ${#UPSTREAM_BRANCH_NAME[@]} -eq 0 ]
then
    OPTIONS+=('master')
    UPSTREAM_BRANCH_NAME+=('master')
    UPSTREAM_BRANCH_BASE+=('')
fi

# If the current branch is not an upstream branch, then add it if desired by the config
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if  git config adsk.make-branch.present-current >/dev/null &&
    ! [[ " ${OPTIONS[@]} " =~ " ${CURRENT_BRANCH} " ]]
then
    OPTIONS+=("Current Branch ($CURRENT_BRANCH)")
fi

if  git config adsk.make-branch.present-current > /dev/null ||
    [ ${#UPSTREAM_BRANCH_NAME[@]} -gt 1 ]
then
    echo 'What is the base of your new branch?'
    PS3='Please enter your choice: '
    select answer in "${OPTIONS[@]}"
    do
        IS_NUMBER='^[0-9]+$'
        if ! [[ $REPLY =~ $IS_NUMBER ]]
        then
            echo 'Invalid option - please enter a number.'
        elif [ $((REPLY-1)) -lt ${#UPSTREAM_BRANCH_NAME[@]} ]
        then
            IS_CURRENT_BRANCH=
            LOCAL_BRANCH_NAME=${UPSTREAM_BRANCH_NAME[$((REPLY-1))]}
            LOCAL_BRANCH_BASE=${UPSTREAM_BRANCH_BASE[$((REPLY-1))]}
            break
        elif [ $((REPLY-1)) -eq ${#UPSTREAM_BRANCH_NAME[@]} ]
        then
            IS_CURRENT_BRANCH=1
            LOCAL_BRANCH_NAME=$CURRENT_BRANCH
            for UPSTREAM_BRANCH in "${UPSTREAM_BRANCH_NAME[@]}"
            do
                if [[ $LOCAL_BRANCH_NAME = *${UPSTREAM_BRANCH}* ]]
                then
                    LOCAL_BRANCH_BASE=$UPSTREAM_BRANCH
                fi
            done
            break
        else
            echo 'Invalid option.'
        fi
    done
    echo ''
else
    IS_CURRENT_BRANCH=
    LOCAL_BRANCH_NAME=${UPSTREAM_BRANCH_NAME[0]}
    LOCAL_BRANCH_BASE=${UPSTREAM_BRANCH_BASE[0]}
fi

if ! branch_exist origin/$LOCAL_BRANCH_NAME
then
    error_exit "Your upstream branch 'origin/$LOCAL_BRANCH_NAME' does not exist."
fi

if [ -n "$IS_CURRENT_BRANCH" ]
then
    SAME_BASE=1
elif $(branch_exist $LOCAL_BRANCH_NAME) && $(git merge-base --is-ancestor HEAD $LOCAL_BRANCH_NAME)
then
    SAME_BASE=1
else
    CURRENT_BASE_BRANCH=$(get_base_branch)
    # allow matching built/ and smoke/ branches
    if [[ $LOCAL_BRANCH_NAME == *$CURRENT_BASE_BRANCH ]]
    then
        SAME_BASE=1
    fi
fi

if [ -z "$NO_LOCAL_REPO_CHECKS" ]
then
    if [ -z $SAME_BASE ]
    then
        if [ -n "$CURRENT_BASE_BRANCH" ]; then
            warning "Your current base branch is '$CURRENT_BASE_BRANCH' and you are about to branch off '$LOCAL_BRANCH_NAME'."
        fi
        echo 'It looks like as if the branch you are about to create has a different'
        echo 'base than the branch you are on right now. This could cause a lengthy'
        echo 'rebuild. You might want to switch to another worktree.'
        echo 'What do you want to do?'
        PS3='Please enter your choice: '
        OPTIONS=('proceed' 'abort')
        select OPT in "${OPTIONS[@]}"
        do
            echo ''
            case $OPT in
                proceed) break;;
                  abort) exit 1; break;;
                      *) echo 'invalid option';;
            esac
        done
    fi

    if ! git diff-index --quiet HEAD --
    then
        if [ -n "$IS_CURRENT_BRANCH" ]
        then
            echo 'Note: Your repository contains uncommitted changes.'
            echo '      They will become a part of the new branch.'
            echo ''
        else
            error_exit "$WORKTREE_DIRTY"
        fi
    fi
fi

if [ -n "$JIRA_KEY" ]
then

    # Ask the user for the Jira ID with the default Jira key
    while [ -z ${JIRA_ID+x} ] || ! [[ $JIRA_ID =~ ^[0-9]*$ ]]
    do
        echo 'What is the Jira ID (only numbers, press enter to define a custom Jira key)?'
        echo -n "$JIRA_KEY-"
        read -r JIRA_ID
    done

    if [ -n "$JIRA_ID" ]
    then
        JIRA_ISSUE="/$JIRA_KEY-$JIRA_ID"
    else
        # Ask the user for custom Jira key with Jira ID
        while [ -z ${JIRA_ISSUE+x} ] || [ -n "$JIRA_ISSUE" ] && ! [[ $JIRA_ISSUE =~ ^[A-Z]+-[0-9]+$ ]]
        do
            echo 'What is the Jira key and ID (format: KEY-123, press enter to define no Jira ID)?'
            read -r JIRA_ISSUE
        done

        if [ -n "$JIRA_ISSUE" ]
        then
            JIRA_ISSUE="/$JIRA_ISSUE"
        fi
    fi
fi

FEATURE_NAME=''
echo ''
while ! [[ $FEATURE_NAME =~ ^[[:alnum:][:blank:]_-]+$ ]]
do
    echo 'What is the branch name (only letters, numbers, dashes and underscores; spaces will be replaced with underscores)?'
    read -r FEATURE_NAME
done
echo ''

# Convert to lower case characters
FEATURE_NAME=$(echo $FEATURE_NAME | tr '[:upper:]' '[:lower:]')

# Replace spaces with underscores
FEATURE_NAME="${FEATURE_NAME// /_}"

if [ -n "$LOCAL_BRANCH_BASE" ]
then
    BRANCH_NAME="$USERNAME/$LOCAL_BRANCH_BASE$JIRA_ISSUE/$FEATURE_NAME"
else
    BRANCH_NAME="$USERNAME$JIRA_ISSUE/$FEATURE_NAME"
fi

if [ -z "$IS_CURRENT_BRANCH" ]
then
    git fetch origin --quiet --prune

    UPDATE_BRANCH=

    # Check if the upstream branch exists locally
    if ! branch_exist $LOCAL_BRANCH_NAME
    then
        # use the upstream branch
        echo "$LOCAL_BRANCH_NAME does NOT exist locally - working with origin/$LOCAL_BRANCH_NAME..."
        START_POINT=origin/$LOCAL_BRANCH_NAME
    else
        # use the local branch
        echo "$LOCAL_BRANCH_NAME exists locally - working with it..."
        START_POINT=$LOCAL_BRANCH_NAME

        # Check if the upstream branch is in a good state
        if ! git merge-base --is-ancestor $LOCAL_BRANCH_NAME origin/$LOCAL_BRANCH_NAME
        then
            error_exit "Your local '$LOCAL_BRANCH_NAME' has commits that are not upstream - please contact @githelp on #tech-git! Please don't work on '$LOCAL_BRANCH_NAME' directly in the future!"
        fi

        # Check if the local version of the upstream branch could be updated
        if git config adsk.make-branch.ask-for-latest > /dev/null &&
        [ "$(git rev-parse $LOCAL_BRANCH_NAME)" != "$(git rev-parse origin/$LOCAL_BRANCH_NAME)" ]
        then
            echo "Do you want to use your local '$LOCAL_BRANCH_NAME' version or the latest?"
            PS3='Please enter your choice: '
            OPTIONS=(
                "$(git log -n1 --pretty='format:local%C(dim),  last change %ad: %s%Creset' --date=relative $LOCAL_BRANCH_NAME)"
                "$(git log -n1 --pretty='format:latest%C(dim), last change %ad: %s%Creset' --date=relative origin/$LOCAL_BRANCH_NAME)"
            )
            select RESPONSE in "${OPTIONS[@]}"
            do
                IS_NUMBER='^[0-9]+$'
                if ! [[ $REPLY =~ $IS_NUMBER ]]
                then
                    echo 'Invalid option - please enter a number.'
                elif [ $REPLY -eq 1 ]
                then
                    # Nothing to do
                    break
                elif [ $REPLY -eq 2 ]
                then
                    UPDATE_BRANCH=1
                    break
                else
                    echo 'Invalid option.'
                fi
            done
            echo ''
        else
            UPDATE_BRANCH=1
        fi
    fi

    if [ -n "$UPDATE_BRANCH" ]
    then
        if [ "$CURRENT_BRANCH" = "$LOCAL_BRANCH_NAME" ]
        then
            git reset --hard origin/$LOCAL_BRANCH_NAME
        else
            git branch -f $LOCAL_BRANCH_NAME origin/$LOCAL_BRANCH_NAME >/dev/null
        fi
    fi
fi

if git_version_greater_equal 2.16.0
then
    git checkout -b $BRANCH_NAME $START_POINT --no-track
else
    # Pre-Git 2.16.0 the Git LFS 'delay' filter-process capability is not
    # fully supported (*). That means Git LFS would download every file
    # individually which could take a very long time. Work around this
    # this problem by smudging the Git LFS pointer files _after_ the
    # checkout.
    # c.f. https://github.com/git-lfs/git-lfs/issues/2466
    #
    # (*) 'delay' is supported since Git 2.15 but a bug in the progress
    #     report might confuse the users.
    #     c.f. https://github.com/git/git/commit/9c5951cacf5cf2a4828480176921ca0307d22746
    GIT_LFS_SKIP_SMUDGE=1 git checkout -b $BRANCH_NAME $START_POINT --no-track
    git lfs pull
fi
