#!/usr/bin/env bash
#/
#/ Create a Pull Request
#/
#/ If --auto is specified as the first command line argument, the script
#/ will create a PR with the title and body from the equivalents in the
#/ first commit.
#/ With no arguments, the script will prepare Pull Request on GitHub and
#/ open it in default browser. You will have an opportunity to review the
#/ files, modify the prefilled title and body and finish PR creation.
#/
#/ What the script does compared to plain GitHub:
#/    1. Pushes all commits in the branch to GitHub
#/    2. Identifies the base branch
#/    3. Includes the branch and commit notes in the body of PR
#/
#/
#/ *** Setup/implementation notes ***
#/ In order to create a Pull Request from the current branch we need to
#/ know the base branch of the Pull Request (also known as the "target"
#/ of the Pull Request). If the current branch name contains a configured
#/ base branch as substring, then this is used. If no base branch was
#/ found, then the default base branch is used if configured.
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
#/ Usage: git $KIT_ID mkpr [--auto]
#/
set -e

KIT_PATH=$(dirname "${BASH_SOURCE[0]}")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"
. "$KIT_PATH/lib/git-utils.sh"

BASE_BRANCH=$(get_base_branch)
CURRENT_BRANCH=$(get_branch_name)

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

function sanitize_json {
    printf -- "$1" \
        | tr -d '\000-\011\013\014\016-\037' \
        | perl -pe 's/\\/\\\\/g' \
        | perl -pe 's/\//\\\//g' \
        | perl -pe 's/"/\\"/g' \
        | perl -pe "s/'/\'/g" \
        | perl -pe 's/\t/    /g' \
        | perl -pe 's/\r//g' \
        | perl -pe 's/\n/\\n/g'
}

function sanitize_url {
    perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$1"
}

echo "Please wait..."

if [[ $1 = "--auto" ]]
then
    FIRST_COMMIT_TITLE=$(git log $REMOTE/$BASE_BRANCH.. --pretty=format:":COMMIT:%s:BODY:%b" | tr -d '\000-\011\013\014\016-\037')
    FIRST_COMMIT_TITLE=${FIRST_COMMIT_TITLE##*:COMMIT:}
    FIRST_COMMIT_BODY=${FIRST_COMMIT_TITLE##*:BODY:}
    FIRST_COMMIT_TITLE=${FIRST_COMMIT_TITLE%:BODY:*}

    TITLE=$FIRST_COMMIT_TITLE
    BODY=$FIRST_COMMIT_BODY

	TITLE=$(sanitize_json "$TITLE")
	BODY=$(sanitize_json "$BODY")
	PR_COMMAND="{ \
		\"title\": \"$TITLE\", \
		\"head\": \"$CURRENT_BRANCH\", \
		\"base\": \"$BASE_BRANCH\", \
		\"body\": \"$BODY\" \
		}"
    if PR_RESP=$(curl $CURL_RETRY_OPTIONS --user "$USER:$PASSWORD" --data "$PR_COMMAND" --silent \
                     -X POST "https://$GITHUB_SERVER/api/v3/repos/$SLUG/pulls" )
    then
        PR_URL=$(printf "$PR_RESP" | perl -ne 'print "$1\n" if m%^\s*"html_url":\s*"(.*\/pull\/[0-9]+)"[,]?$%i')
        MESSAGE=$(printf "$PR_RESP" | perl -ne 'print "$1\n" if m%^.*"message":\s*"([^"]+)".*$%i')

        if [ -n "$PR_URL" ]
        then
            print_success "Pull request created: $PR_URL"
            open_url $PR_URL
        elif [ -n "$MESSAGE" ]
        then
            error_exit "Pull request creation failed. \n\n$MESSAGE"
        else
            error_exit "Pull request creation failed with invalid response: $PR_RESP"
        fi
    else
        error_exit "Pull request creation failed with error response: $PR_RESP"
    fi
else # not "--auto"

    # prepare url to compare and create PR
    PR_URL_BASE="https://$GITHUB_SERVER/$SLUG/compare/$BASE_BRANCH...$CURRENT_BRANCH?expand=1"

    COMMITS_COUNT=$(git rev-list --count $REMOTE/$BASE_BRANCH..)
    if (( COMMITS_COUNT<=1 ))
    then
        # let GitHub fill out title and body
        PR_URL=$PR_URL_BASE
    else
        echo "Number of commits: $COMMITS_COUNT"
        # multiple commits - put the branch name and commits in the body
        TITLE=$(sanitize_url "Please enter title...")

        COMMITS=$(git log $REMOTE/$BASE_BRANCH.. --pretty=format:"* %s%n%b")

        BODY=$(printf "Branch name: %s\n\nCommits:\n%s" "$CURRENT_BRANCH" "$COMMITS")
        BODY=$(sanitize_url "$BODY")
        PR_URL="$PR_URL_BASE&title=$TITLE&body=$BODY"
    fi

    print_success "Please finish pull request creation in the browser at $PR_URL"
    open_url "$PR_URL"
fi
