#!/usr/bin/env bash
set -e

# Set ECG_DEBUG (ECG = Enterprise Config for Git) environment variable to
# enable extensive logging:
# $ ECG_DEBUG=1 git adsk
if [ -n "$ECG_DEBUG" ]; then
    set -x
fi

###############################################################################
# Main
###############################################################################
# Force UTF-8 to avoid encoding issues for users with broken locale settings.
if [ "$(locale charmap 2> /dev/null)" != "UTF-8" ]; then
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
if ! one_ping $GITHUB_SERVER > /dev/null 2>&1; then
    error_exit "Cannot reach $GITHUB_SERVER! Are you connected to the company network?"
fi

# Check if we can reach the GitHub Enterprise server via HTTPS
if ! curl $CURL_RETRY_OPTIONS --silent --fail https://$GITHUB_SERVER > /dev/null 2>&1; then
    error_exit "Cannot connect to $GITHUB_SERVER via HTTPS!"
fi

if [ -z "$QUIET_INTRO" ]; then
    print_kit_header

    #
    # Ask user for GitHub Enterprise credentials
    #
    # By default Enterprise Config will ask you for your username and
    # password to generate a Personal Access Token. That is annoying
    # for automation. In these cases you can just pass the Personal
    # Access Token as environment variables directly:
    #
    # $ GITHUB_TOKEN=0ab5bde4f0b102d9ce17f1c97ed800a9e5975366 git adsk
    #
    set +e
    STORED_GITHUB_ENTERPRISE_ACCOUNT=$(git config --global adsk.github.account)
    STORED_GITHUB_ENTERPRISE_SERVER=$(git config --global adsk.github.server)
    set -e

    unset HAS_CACHED_TOKEN
    if [ -n "$CREDENTIALS_BASE64" ]; then
        # Read the credentials out of the provided variable
        CREDENTIALS="$(echo "$CREDENTIALS_BASE64" | base64 --decode)"
        ADS_USER="$(echo "$CREDENTIALS" | cut -d : -f 1)"
        ADS_PASSWORD_OR_TOKEN="$(echo "$CREDENTIALS" | cut -d : -f 2-)"
    elif [ -z "$GITHUB_TOKEN" ]; then
        if [ -z "$STORED_GITHUB_ENTERPRISE_ACCOUNT" ]; then
            echo -n 'Please enter your Company username and press [ENTER]: '
        else
            echo -n "Please enter your Company username and press [ENTER] (empty for \"$STORED_GITHUB_ENTERPRISE_ACCOUNT\"): "
        fi
        read ADS_USER

        if [ -z "$ADS_USER" ]; then
            if [ -n "$STORED_GITHUB_ENTERPRISE_ACCOUNT" ]; then
                ADS_USER=$STORED_GITHUB_ENTERPRISE_ACCOUNT
            else
                error_exit 'Username must not be empty!'
            fi
        fi

        if [ -n "$STORED_GITHUB_ENTERPRISE_SERVER" ]; then
            ADS_PASSWORD_OR_TOKEN="$(get_credentials $STORED_GITHUB_ENTERPRISE_SERVER $ADS_USER)"
        fi
    else
        ADS_USER="token"
        ADS_PASSWORD_OR_TOKEN=$GITHUB_TOKEN
    fi

    # GitHub usernames have a "-" instead of a "_"
    ADS_USER=${ADS_USER//_/-}

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
    if [ -z "$BRANCH" ]; then
        BRANCH=production
    fi
    if [ -z "$NO_UPDATE" ]; then
        CURRENT_KIT_REMOTE_URL=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" config --get remote.origin.url)
        if [ $CURRENT_KIT_REMOTE_URL != $KIT_REMOTE_URL ]; then
            warning "You are updating 'git adsk' from an unofficial source: $CURRENT_KIT_REMOTE_URL"
        fi

        printf -v HELPER "!f() { cat >/dev/null; echo 'username=%s'; echo 'password=%s'; }; f" "$ADS_USER" "$ADS_PASSWORD_OR_TOKEN"
        git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" -c credential.helper="$HELPER" fetch --prune --quiet origin

        OLD_COMMIT=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" rev-parse HEAD)
        NEW_COMMIT=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" rev-parse origin/$BRANCH)

        if [ "$OLD_COMMIT" != "$NEW_COMMIT" ]; then
            # After syncing to remote, delegate to the new setup script
            # ... in case that changed.
            git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" checkout --quiet -B adsk-setup && \
            git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" reset --quiet --hard origin/$BRANCH && \
            ADS_USER=$ADS_USER ADS_PASSWORD_OR_TOKEN="$ADS_PASSWORD_OR_TOKEN" "$KIT_PATH/setup.sh" -q "$@"
            exit $?
        fi
    fi
fi

#
# git-adsk update code
#
# v0.8.1 to newer changed the password variable name
if [ -z "$ADS_PASSWORD_OR_TOKEN" ] && [ -n "$ADS_PASSWORD" ]; then
    ADS_PASSWORD_OR_TOKEN="$ADS_PASSWORD"
fi
# up to v1.4.10 might have exposed the user credentials in a local credential.helper config
set +e
git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" config --local --unset credential.helper
set -e

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
git config --global credential.helper "$(credential_helper) $(credential_helper_parameters)"

if ! is_ghe_token "$ADS_PASSWORD_OR_TOKEN"; then
    echo 'Requesting a new GitHub token for this machine...'
    GIT_PRODUCTION_TOKEN=$(create_ghe_token $GITHUB_SERVER $ADS_USER "$ADS_PASSWORD_OR_TOKEN" $KIT_CLIENT_ID $KIT_CLIENT_SECRET)
    test -n "$GIT_PRODUCTION_TOKEN" || error_exit "Token request failed for $GITHUB_SERVER!"
    store_token $GITHUB_SERVER $ADS_USER $GIT_PRODUCTION_TOKEN

else
    echo 'Reusing existing GitHub token...'
    store_token $GITHUB_SERVER $ADS_USER $ADS_PASSWORD_OR_TOKEN
fi

# Setup URL rewrite
rewrite_ssh_to_https_if_required $GITHUB_SERVER

# Setup username and email only for actual users, no service accounts
if [ -z $IS_SERVICE_ACCOUNT ]; then
    if ! is_ghe_token "$ADS_PASSWORD_OR_TOKEN" || \
        is_ghe_token_with_user_email_scope $GITHUB_SERVER $ADS_USER "$ADS_PASSWORD_OR_TOKEN"; then

        echo ''
        echo "Querying information for user \"$ADS_USER\" from $GITHUB_SERVER..."
        NAME=$(get_ghe_name $GITHUB_SERVER $ADS_USER "$ADS_PASSWORD_OR_TOKEN")
        EMAIL=$(get_ghe_email $GITHUB_SERVER $ADS_USER "$ADS_PASSWORD_OR_TOKEN")

        if [ -z "$NAME" ]; then
            error_exit "Could not retrieve your name. Please go to https://$GITHUB_SERVER/settings/profile and check your name!"
        elif [ -z "$EMAIL" ]; then
            error_exit "Could not retrieve your email address. Please go to https://$GITHUB_SERVER/settings/emails and check your email!"
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
if [ -z "$(git config --global --get-regexp '^bugtraq\.jira\.')" ]; then
    git config --global bugtraq.jira.url "https://jira.yourcompany.com/browse/%BUGID%"
    git config --global bugtraq.jira.logregex "\\b([A-Z]{2,5}-\\d+)\\b"
fi

if [ "$(git config --global http.sslVerify)" == "false" ]; then
    warning "Git SSL verification is disabled. We recommended to run 'git config --global --unset-all http.sslVerify'. $ERROR_HELP_MESSAGE"
fi

# Setup environment
if [ -z "$ENVIRONMENT" ]; then
    set +e
    ENVIRONMENT=$(git config --global adsk.environment)
    set -e
fi
if [ -e "$KIT_PATH/envs/$ENVIRONMENT/setup.sh" ]; then
    echo "Configuring $(tput setaf 3)$ENVIRONMENT environment$(tput sgr0)..."
    git config --global adsk.environment "$ENVIRONMENT"
    . "$KIT_PATH/envs/$ENVIRONMENT/setup.sh" "$KIT_PATH/envs/$ENVIRONMENT"
elif [ "$ENVIRONMENT" == "vanilla" ]; then
    echo "Resetting environment..."
    git config --global adsk.environment ""
elif [ -n "$ENVIRONMENT" ]; then
    warning "Environment \"$ENVIRONMENT\" not found!"
    git config --global adsk.environment ""
fi

GIT_TAG=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" tag --points-at HEAD)
if [ -z "$GIT_TAG" ]; then
    GIT_TAG="[dev build]"
fi
print_success "git adsk $GIT_TAG successfully configured!"
