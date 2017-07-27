#!/usr/bin/env bash
set -e

###############################################################################
# Set Required Versions
###############################################################################
MINIMUM_GIT_VERSION=2.3.2
MINIMUM_GIT_LFS_VERSION=1.5.5   # On update make sure to update $GIT_LFS_CHECKSUM in lib/*/setup_helpers.sh, too!

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

. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

# Check basic dependencies
check_dependency curl
check_dependency ping

# Check availability of the GitHub Enterprise server
if ! one_ping $GHE_SERVER > /dev/null 2>&1; then
    error_exit "Cannot reach $GHE_SERVER! Are you connected to the company network?"
fi

# Check if we can reach the GitHub Enterprise server
if ! curl $CURL_RETRY_OPTIONS --silent --fail $GHE_URL > /dev/null 2>&1; then
    error_exit "Cannot connect to $GHE_SERVER via $GHE_HTTP!"
fi

if [[ -z $QUIET_INTRO ]]; then
    print_kit_header

    #
    # Ask user for GitHub Enterprise credentials
    #
    # By default Enterprise Config will ask you for your username and
    # password to generate a Personal Access Token. That is annoying
    # for automation. In these cases you can just pass the Personal
    # Access Token as environment variables directly:
    #
    #
    # GHE_TOKEN=01234567890abcdef01234567890abcdef012345 git adsk
    #
    set +e
    STORED_GHE_ACCOUNT=$(git config --global $KIT_ID.github.account)
    STORED_GHE_SERVER=$(git config --global $KIT_ID.github.server)
    set -e

    if [[ -z $GHE_TOKEN ]]; then
        if [[ -z $STORED_GHE_ACCOUNT ]]; then
            echo -n 'Please enter your $KIT_COMPANY username and press [ENTER]: '
        else
            echo -n "Please enter your $KIT_COMPANY username and press [ENTER] (empty for \"$STORED_GHE_ACCOUNT\"): "
        fi
        read GHE_USER

        if [[ -z $GHE_USER ]]; then
            if [[ ! -z $STORED_GHE_ACCOUNT ]]; then
                GHE_USER=$STORED_GHE_ACCOUNT
            else
                error_exit 'Username must not be empty!'
            fi
        fi

        # GitHub usernames have a "-" instead of a "_"
        GHE_USER=${GHE_USER//_/-}

        if [ -n "$STORED_GHE_SERVER" ]; then
            GHE_PASSWORD_OR_TOKEN="$(get_credentials $STORED_GHE_SERVER $GHE_USER)"
        fi
    else
        GHE_USER="token"
        GHE_PASSWORD_OR_TOKEN=$GHE_TOKEN
    fi

    if [ -n "$GHE_PASSWORD_OR_TOKEN" ]; then
        if has_valid_credentials $KIT_TESTFILE $GHE_USER "$GHE_PASSWORD_OR_TOKEN"; then
            echo 'Stored token is still valid. Using it ...'
        else
            echo 'Stored or cached token is invalid.'
            read_password $GHE_SERVER $KIT_TESTFILE $GHE_USER GHE_PASSWORD_OR_TOKEN
        fi
    else
        read_password $GHE_SERVER $KIT_TESTFILE $GHE_USER GHE_PASSWORD_OR_TOKEN
    fi

    #
    # Update Enterprise Config repository.
    #
    # By default Enterprise Config always uses the "production" branch.
    # If you set the BRANCH variable then you can explicitly define the
    # branch that should be used for the update:
    #
    # $ BRANCH=mybranch git adsk
    #
    # You can also skip the update entirely by defining the NO_UPDATE
    # variable:
    #
    # $ NO_UPDATE=1 git adsk
    #
    # This is especially useful for testing development branches
    # of the repo.
    #
    if  [[ -z $BRANCH ]]; then
        BRANCH=production
    fi
    if  [[ -z $NO_UPDATE ]]; then
        CURRENT_KIT_REMOTE_URL=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" config --get remote.origin.url)
        if [[ $CURRENT_KIT_REMOTE_URL != $KIT_REMOTE_URL ]]; then
            warning "You are updating 'git $KIT_ID' from an unofficial source: $CURRENT_KIT_REMOTE_URL"
        fi

        printf -v HELPER "!f() { cat >/dev/null; echo 'username=%s'; echo 'password=%s'; }; f" "$GHE_USER" "$GHE_PASSWORD_OR_TOKEN"
        git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" -c credential.helper="$HELPER" fetch --prune --quiet origin

        OLD_COMMIT=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" rev-parse HEAD)
        NEW_COMMIT=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" rev-parse origin/$BRANCH)

        if [[ $OLD_COMMIT != $NEW_COMMIT ]]; then
            # After syncing to remote, delegate to the new setup script
            # ... in case that changed.
            git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" checkout --quiet -B $KIT_ID-setup && \
            git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" reset --quiet --hard origin/$BRANCH && \
            GHE_USER=$GHE_USER GHE_PASSWORD_OR_TOKEN="$GHE_PASSWORD_OR_TOKEN" "$KIT_PATH/setup.sh" -q "$@"
            exit $?
        fi
    fi
fi

case $(uname -s) in
    CYGWIN_NT-*) warning 'You are using Cygwin which Git for Windows does not official support.';;
esac

# Detect special user accounts
case $GHE_USER in
    svc-*)  IS_SERVICE_ACCOUNT=1;;
esac

echo ''

echo 'Checking Git/Git LFS versions...'
check_git
check_git_lfs

# Setup/store credentials
git config --global $KIT_ID.github.account $GHE_USER
git config --global $KIT_ID.github.server "$GHE_SERVER"
git config --global credential.helper "$(credential_helper) $(credential_helper_parameters)"

if ! is_ghe_token "$GHE_PASSWORD_OR_TOKEN"; then
    echo 'Requesting a new GitHub token for this machine...'
    GHE_PRODUCTION_TOKEN=$(create_ghe_token $GHE_SERVER $GHE_USER "$GHE_PASSWORD_OR_TOKEN" $KIT_CLIENT_ID $KIT_CLIENT_SECRET)
    store_token $GHE_SERVER $GHE_USER $GHE_PRODUCTION_TOKEN
else
    echo 'Reusing existing GitHub token...'
    store_token $GHE_SERVER $GHE_USER $GHE_PASSWORD_OR_TOKEN
fi

# Setup URL rewrite
rewrite_ssh_to_https_if_required $GHE_SERVER

# Setup username and email only for actual users, no service accounts
if [[ -z $IS_SERVICE_ACCOUNT ]]; then
    if ! is_ghe_token "$GHE_PASSWORD_OR_TOKEN" || \
        is_ghe_token_with_user_scope $GHE_SERVER $GHE_USER "$GHE_PASSWORD_OR_TOKEN"; then

        echo ''
        echo "Querying information for user \"$GHE_USER\" from $GHE_SERVER..."
        NAME=$(get_ghe_name $GHE_SERVER $GHE_USER "$GHE_PASSWORD_OR_TOKEN")
        EMAIL=$(get_ghe_email $GHE_SERVER $GHE_USER "$GHE_PASSWORD_OR_TOKEN")

        if [[ -z "$NAME" ]]; then
            error_exit "Could not retrieve your name. Please go to $GHE_URL/settings/profile and check your name!"
        elif [[ -z "$EMAIL" ]]; then
            error_exit "Could not retrieve your email address. Please go to $GHE_URL/settings/emails and check your email!"
        fi

        echo ''
        echo "Name:  $NAME"
        echo "Email: $EMAIL"

        git config --global user.name "$NAME"
        git config --global user.email "$EMAIL"
    fi
fi

# Activate clickable JIRA links in commit messages of Git GUIs.
# Spec defined here: https://github.com/mstrap/bugtraq
# SmartGit is the only known implementer of the spec thus-far
# Note: This _would_ have been more straight-forward to just dump in
# config.include, but apparently this is not support right now:
# https://groups.google.com/d/msg/smartgit/srEr0FpSjhI/UC2nEAKTCAAJ
if [[ -z $(git config --global --get-regexp '^bugtraq\.jira\.') ]]; then
    git config --global bugtraq.jira.url "https://jira.yourcompany.com/browse/%BUGID%"
    git config --global bugtraq.jira.logregex "\\b([A-Z]{2,5}-\\d+)\\b"
fi

if [[ $(git config --global http.sslVerify) == "false" ]]; then
    warning "Git SSL verification is disabled. We recommended to run 'git config --global --unset-all http.sslVerify'. $ERROR_HELP_MESSAGE"
fi

# Setup environment
if [[ -z "$ENVIRONMENT" ]]; then
    set +e
    ENVIRONMENT=$(git config --global $KIT_ID.environment)
    set -e
fi
if [[ -e "$KIT_PATH/envs/$ENVIRONMENT/setup.sh" ]]; then
    echo "Configuring $ENVIRONMENT environment..."
    git config --global $KIT_ID.environment "$ENVIRONMENT"
    . "$KIT_PATH/envs/$ENVIRONMENT/setup.sh" "$KIT_PATH/envs/$ENVIRONMENT"
elif [[ "$ENVIRONMENT" == "vanilla" ]]; then
    echo "Resetting environment..."
    git config --global $KIT_ID.environment ""
elif [[ -n "$ENVIRONMENT" ]]; then
    warning "Environment \"$ENVIRONMENT\" not found!"
    git config --global $KIT_ID.environment ""
fi

GIT_TAG=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" tag --points-at HEAD)
if [[ -z "$GIT_TAG" ]]; then
    GIT_TAG="[dev build]"
fi
print_success "git $KIT_ID $GIT_TAG successfully configured!"
