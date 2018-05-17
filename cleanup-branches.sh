#!/usr/bin/env bash
#/
#/ Cleanup Branches
#/
#/ Delete (all or merged) branches that are prefixed with the current
#/ username.
#/
#/ Usage: git $KIT_ID cleanup-branches
#/        git $KIT_ID cub
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

BASE_BRANCH=$(git config 'adsk.pr-base-default') ||
    error_exit 'No base branch found.
  Please configure your default Pull Request base with:
  git config --local adsk.pr-base-default YourBaseBranch'

USERNAME=$(git config adsk.github.account) ||
    error_exit "Git configuration error. Please run 'git adsk' and/or contact @githelp on #tech-git!"

REMOTE=origin
if ! git remote | grep $REMOTE  >/dev/null 2>&1
then
    error_exit "Remote $REMOTE not found."
fi

echo 'Which branches do you want to delete?'
PS3='Please enter your choice: '
OPTIONS=("Delete '$USERNAME/*' branches merged to '$BASE_BRANCH'" "Delete all '$USERNAME/*' branches" "Abort")
select answer in "${OPTIONS[@]}"
do
    case $((REPLY)) in
        1)  LOCAL_DELETE_OPTION="--merged $BASE_BRANCH";
            REMOTE_DELETE_OPTION="--merged $REMOTE/$BASE_BRANCH";
            break;;
        2)  LOCAL_DELETE_OPTION='';
            REMOTE_DELETE_OPTION='';
            break;;
        3)  exit;;
        *) echo 'Invalid option.';;
    esac
done

# Delete any tracking branches that no longer exist on the remote
# This way we avoid "error: unable to delete 'xyz': remote ref does not exist"
git fetch --quiet --prune $REMOTE

LOCAL_DELETE=$(git branch $LOCAL_DELETE_OPTION | grep "^ *$USERNAME/" | cat)
REMOTE_DELETE=$(git branch --remotes $REMOTE_DELETE_OPTION | grep "^ *$REMOTE/$USERNAME/" | cat)

if [ -z "$LOCAL_DELETE" ] && [ -z "$REMOTE_DELETE" ]
then
    print_success "No branches found - all clean!"
    exit 0
fi

echo ''
echo 'The following branches are about to be deleted:'
echo "$LOCAL_DELETE"
echo "$REMOTE_DELETE"

PS3='Please enter your choice: '
OPTIONS=('proceed' 'abort')
select OPT in "${OPTIONS[@]}"
do
    echo ''
    case $OPT in
        proceed) break;;
          abort) exit 1; break;;
              *) echo 'Invalid option.';;
    esac
done

[ -z "$LOCAL_DELETE" ] || git branch --delete --force $(echo $LOCAL_DELETE | tr -d '\n')
[ -z "$REMOTE_DELETE" ] || git push --delete origin $(echo $REMOTE_DELETE | sed $"s/^ *$REMOTE\\// /" | tr -d '\n')

