#!/usr/bin/env bash
#/
#/ Create a Pull Request
#/
#/ In order to create a Pull Request from the current branch we need to
#/ know the base branch of the Pull Request (also known as the "target"
#/ of the Pull Request). If the current branch name contains a configured
#/ base branch as substring, then this is used. If no base branch was
#/ found, then the default base branch is used if configured. Afterwards
#/ the script creates a Pull Request on GitHub.
#/
#/ After the initial repository clone, change directory to your Git
#/ repository and setup...
#/
#/ ... your default base branch:
#/ $ git config --local adsk.pr-base-default "<BRANCH-NAME>"
#/
#/ ... your base branches:
#/ $ git config --local adsk.pr-base-branch-<BRANCH-NAME> "<BRANCH-NAME>"
#/
#/
#/ Example:
#/ $ git config --local adsk.pr-base-default "master"
#/ $ git config --local adsk.pr-base-branch-releasev3 "releasev3"
#/
#/
#/ Usage: git $KIT_ID mkpr
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

set +e
BASE_BRANCH=$(git config 'adsk.pr-base-default')
set -e
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
for BRANCH in $(git config --get-regexp 'adsk\.pr-base-branch-' | sed 's/.* //'); do
    BRANCH=${BRANCH#adsk.pr-base-branch-}
    shopt -s nocasematch
    case "$CURRENT_BRANCH" in
      *$BRANCH*)
        BASE_BRANCH=$BRANCH
        break
        ;;
    esac
    shopt -u nocasematch
done

if [ -z "$BASE_BRANCH" ]
then
    error_exit "No base branch found.\n  Please configure your default Pull Request base with:\n  git config --local adsk.pr-base-default YourBaseBranch"
else
    print_success "Pull Request base: $BASE_BRANCH"
fi

REMOTE=origin
if ! git remote | grep $REMOTE  >/dev/null 2>&1
then
    error_exit "Remote $REMOTE not found."
fi

git push --set-upstream $REMOTE "$CURRENT_BRANCH"

USER=$(git config adsk.github.account)
PASSWORD="$(get_credentials $GITHUB_SERVER $USER)"
SLUG_REGEX='/yourcompany\.com[:\/]([^\/]+\/[^\/\.]+)/ && print "$1\n"'
SLUG=$(git config --get remote.$REMOTE.url | perl -ne "$SLUG_REGEX")

if [ -z "$SLUG" ]
then
    error_exit "Cannot extract repository name from remote."
fi

PR_URL=$(curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$PASSWORD" -X POST \
        --data "{\"title\": \"$CURRENT_BRANCH\", \"head\": \"$CURRENT_BRANCH\", \"base\": \"$BASE_BRANCH\"}" \
        "https://$GITHUB_SERVER/api/v3/repos/$SLUG/pulls" \
    | perl -ne 'print "$1\n" if m%^\s*"html_url":\s*"(.*\/pull\/[0-9]+)"[,]?$%i' \
)

if [ -z "$PR_URL" ]
then
    error_exit "Pull Request creation failed. Maybe the same Pull Request exists already?"
fi

print_success "Pull Request created: $PR_URL"
open_url $PR_URL
