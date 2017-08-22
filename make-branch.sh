#!/usr/bin/env bash
#/
#/ Make a new branch
#/
#/ Usage: git $KIT_ID make-branch
#/
set -e

KIT_PATH="$(dirname "$0")"
. "$KIT_PATH/lib/setup_helpers.sh"

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

JIRA_ISSUE=''
if [ -n "$JIRA_KEY" ]
then
    JIRA_ID=''
    while ! [[ $JIRA_ID =~ ^[0-9]+$ ]]; do
        echo 'What is the Jira ID (only numbers)?'
        echo -n "$JIRA_KEY-"
        read -r JIRA_ID
    done
    JIRA_ISSUE="/$JIRA_KEY-$JIRA_ID"
fi

FEATURE_NAME=''
echo ''
while ! [[ $FEATURE_NAME =~ ^[[:alnum:][:blank:]_-]+$ ]]
do
    echo 'What is the branch name (only letters, numbers, dashes and underscores)?'
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

    # Check of the upstream branch exists locally
    if ! git rev-parse --verify $LOCAL_BRANCH_NAME > /dev/null 2>&1
    then
        git branch $LOCAL_BRANCH_NAME origin/$LOCAL_BRANCH_NAME > /dev/null
    fi

    # Check if the upstream branch is in a good state
    if ! git merge-base --is-ancestor $LOCAL_BRANCH_NAME origin/$LOCAL_BRANCH_NAME
    then
        error_exit "Your local '$LOCAL_BRANCH_NAME' has commits that are not upstream - please contact @githelp on #tech-git! Please don't work on '$LOCAL_BRANCH_NAME' directly in the future!"
    fi

    # Check if the local version of the upstream branch could be updated
    UPDATE_BRANCH=
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

# This check is redundant for the $CURRENT_BRANCH case but it doesn't hurt.
if ! git merge-base --is-ancestor HEAD $LOCAL_BRANCH_NAME
then
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

git checkout -b $BRANCH_NAME $LOCAL_BRANCH_NAME
