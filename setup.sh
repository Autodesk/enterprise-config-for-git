#!/usr/bin/env bash
set -e


###############################################################################
# Configure these variables. See README.md for details.
###############################################################################
GITHUB_SERVER='<< YOUR GITHUB SERVER >>>'
KIT_ORG_REPO='<< YOUR ENTERPRISE CONFIG ORGANIZATION/URL >>'
KIT_TESTFILE="https://$GITHUB_SERVER/raw/$KIT_ORG_REPO/master/README.md"
KIT_REMOTE_URL="https://$GITHUB_SERVER/$KIT_ORG_REPO.git"
KIT_CLIENT_ID='<< YOUR OAUTH CLIENT ID >>'
KIT_CLIENT_SECRET='<< YOUR OAUTH SECRET >>'
MINIMUM_GIT_VERSION=2.3.2
MINIMUM_GIT_LFS_VERSION=1.2.0   # On update make sure to update $GIT_LFS_CHECKSUM in lib/*/setup_helpers.sh, too!


###############################################################################
# Main
###############################################################################
# Force UTF-8 to avoid encoding issues for users with broken locale settings.
if [[ "$(locale charmap 2> /dev/null)" != "UTF-8" ]]; then
  export LC_ALL="en_US.UTF-8"
fi

###############################################################################
# Options and parameters
###############################################################################
while getopts ':q' opt; do
    case $opt in
         q) QUIET_INTRO=1;;
        \?) echo "Invalid setup option: -$OPTARG" >&2;;
    esac
done

# Remove options from arguments and set up the positional parameters...
shift $((${OPTIND} - 1))
KIT_PATH=$1
ENVIRONMENT=$2

. "$KIT_PATH/lib/setup_helpers.sh"

if [[ -z $QUIET_INTRO ]]; then
    print_kit_header

    #
    # Ask user for GitHub Enterprise credentials
    #
    set +e
    STORED_GITHUB_ENTERPRISE_ACCOUNT=$(git config --global adsk.github.account)
    STORED_GITHUB_ENTERPRISE_SERVER=$(git config --global adsk.github.server)
    set -e

    if [[ -z $STORED_GITHUB_ENTERPRISE_ACCOUNT ]]; then
        echo -n 'Please enter your GitHub Enterprise username and press [ENTER]: '
    else
        echo -n "Please enter your GitHub Enterprise username and press [ENTER] (empty for \"$STORED_GITHUB_ENTERPRISE_ACCOUNT\"): "
    fi
    read ADS_USER

    if [[ -z $ADS_USER ]]; then
        if [[ ! -z $STORED_GITHUB_ENTERPRISE_ACCOUNT ]]; then
            ADS_USER=$STORED_GITHUB_ENTERPRISE_ACCOUNT
        else
            error_exit 'Username must not be empty!'
        fi
    fi

    # GitHub usernames have a "-" instead of a "-"
    ADS_USER=${ADS_USER//_/-}

    if [ -n "$STORED_GITHUB_ENTERPRISE_SERVER" ]; then
        ADS_PASSWORD_OR_TOKEN="$(get_credentials $STORED_GITHUB_ENTERPRISE_SERVER $ADS_USER)"
    fi

    if [ -n "$ADS_PASSWORD_OR_TOKEN" ]; then
        if has_valid_credentials $KIT_TESTFILE $ADS_USER "$ADS_PASSWORD_OR_TOKEN"; then
            echo 'Stored token is still valid. Using it ...'
        else
            echo 'Stored or cached token is invalid.'
            read_password $GITHUB_SERVER $KIT_TESTFILE $ADS_USER ADS_PASSWORD_OR_TOKEN
        fi
    else
        read_password $GITHUB_SERVER $KIT_TESTFILE $ADS_USER ADS_PASSWORD_OR_TOKEN
    fi

    #
    # Update Enterprise Config repository.
    #
    # Usage: git adsk setup <environment>
    #
    # No environment sets the repo to the production branch.
    # The 'dev' environment sets the repo to the master branch.
    # The 'no-update' environment will skip the automatic update:
    #
    # i.e. $ git adsk setup no-update
    #
    # This is especially useful for testing development branches
    # of the repo.
    #
    # If a branch name is provided as environment that the repo is set to
    # this particular branch.
    #
    # Only if there are differences between current and upstream
    # branch is anything updated.
    #
    if  [[ -z $ENVIRONMENT ]] || [[ $ENVIRONMENT != no-update ]]; then
        if [[ -z $ENVIRONMENT ]]; then
            BRANCH=production
        elif  [[ $ENVIRONMENT = dev ]]; then
            BRANCH=master
        else
            BRANCH=$ENVIRONMENT
        fi

        CURRENT_KIT_REMOTE_URL=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" config --get remote.origin.url)
        if [[ $CURRENT_KIT_REMOTE_URL != $KIT_REMOTE_URL ]]; then
            warning "You are updating 'git adsk' from an unofficial source: $CURRENT_KIT_REMOTE_URL"
        fi

        git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" \
            -c credential.helper="!f() { cat >/dev/null; echo \'username=$ADS_USER\'; echo \'password=$ADS_PASSWORD_OR_TOKEN\'; }; f" \
            fetch --prune --quiet origin

        OLD_COMMIT=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" rev-parse HEAD)
        NEW_COMMIT=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" rev-parse origin/$BRANCH)

        if [[ $OLD_COMMIT != $NEW_COMMIT ]]; then
            # After syncing to remote, delegate to the new setup script
            # ... in case that changed.
            git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" checkout --quiet -B adsk-setup && \
            git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" reset --quiet --hard origin/$BRANCH && \
            ADS_USER=$ADS_USER ADS_PASSWORD_OR_TOKEN="$ADS_PASSWORD_OR_TOKEN" "$KIT_PATH/setup.sh" -q "$@"
            exit $?
        fi
    fi
fi

case $(uname -s) in
    CYGWIN_NT-*) warning 'You are using Cygwin which Git for Windows does not official support.';;
esac

# Detect special user accounts
case $ADS_USER in
    svc-*)  IS_SERVICE_ACCOUNT=1;;
esac

echo ''

echo 'Checking Git/Git LFS versions...'
check_git
check_git_lfs

# Setup/store credentials
git config --global adsk.github.account $ADS_USER
git config --global adsk.github.server "$GITHUB_SERVER"

if ! is_ghe_token "$ADS_PASSWORD_OR_TOKEN"; then
    # Check things that require a domain password
    # e.g. check signed source code policy etc.

    echo 'Requesting a new GitHub token for this machine...'
    git config --global credential.helper "$(credential_helper) $(credential_helper_parameters)"
    GIT_PRODUCTION_TOKEN=$(create_ghe_token $GITHUB_SERVER $ADS_USER "$ADS_PASSWORD_OR_TOKEN" $KIT_CLIENT_ID $KIT_CLIENT_SECRET)
    store_token $GITHUB_SERVER $ADS_USER $GIT_PRODUCTION_TOKEN

else
    echo 'Reusing existing GitHub token...'
    store_token $GITHUB_SERVER $ADS_USER $ADS_PASSWORD_OR_TOKEN
fi

# Setup username and email only for actual users, no service accounts
if [[ -z $IS_SERVICE_ACCOUNT ]]; then
    if ! is_ghe_token "$ADS_PASSWORD_OR_TOKEN" || \
        is_ghe_token_with_user_scope $GITHUB_SERVER $ADS_USER "$ADS_PASSWORD_OR_TOKEN"; then

        echo ''
        echo "Querying information for user \"$ADS_USER\" from $GITHUB_SERVER..."
        NAME=$(get_ghe_name $GITHUB_SERVER $ADS_USER "$ADS_PASSWORD_OR_TOKEN")
        EMAIL=$(get_ghe_email $GITHUB_SERVER $ADS_USER "$ADS_PASSWORD_OR_TOKEN")

        if [[ -z "$NAME" ]]; then
            error_exit "Could not retrieve your name. Please go to https://$GITHUB_SERVER/settings/profile and check your name!"
        elif [[ -z "$EMAIL" ]]; then
            error_exit "Could not retrieve your email address. Please go to https://$GITHUB_SERVER/settings/emails and check your email!"
        fi

        echo ''
        echo "Name:  $NAME"
        echo "Email: $EMAIL"

        git config --global user.name "$NAME"
        git config --global user.email "$EMAIL"
    fi
fi

print_success 'Git successfully configured!'
