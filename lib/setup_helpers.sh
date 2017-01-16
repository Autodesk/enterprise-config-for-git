###############################################################################
# Utility functions
###############################################################################
VERSION_PARSER='use version; my ($version) = $_ =~ /([0-9]+([.][0-9]+)+)/; if (version->parse($version) lt version->parse($min)) { exit 1 };'
CURL_RETRY_OPTIONS='--connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 60'

function print_kit_header () {
    cat << EOM
###
### Enterprise Config
###

EOM
}

function read_password () {
    local HOST=$1
    local TEST_FILE=$2
    local USER=$3
    local RETURN_PASSWORD="$4"
    echo -n 'Please enter your GitHub Enterprise password and press [ENTER]: '
    read -s PASSWORD
    echo ''
    if ! has_valid_credentials $TEST_FILE $USER "$PASSWORD"; then
        error_exit "Could not connect to $HOST. Wrong username or password? If you have enabled 2FA then you need to use a token instead of a password."
    fi

    eval $RETURN_PASSWORD="'$PASSWORD'"
}

function store_token () {
    local HOST=$1
    local USER=$2
    local TOKEN="$3"
    local HELPER=$(credential_helper)
    printf "protocol=https\nhost=$HOST\n\n" | git credential-$HELPER erase
    printf "protocol=https\nhost=$HOST\nusername=$USER\npassword=${TOKEN/\%/\%\%}\n\n" | git credential-$HELPER store
}

function get_credentials () {
    local HOST=$1
    local USER=$2
    printf "protocol=https\nhost=$HOST\nusername=$USER\n\n" \
        | git credential-$(credential_helper) get \
        | perl -0pe 's/.*password=//s'
}

function has_command() {
    which $1 > /dev/null 2>&1
}

function has_valid_credentials () {
    local TEST_FILE=$1
    local USER=$2
    local PASSWORD="$3"
    curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$PASSWORD" $TEST_FILE > /dev/null
}

function is_ghe_token () {
    echo "$1" | perl -ne 'exit 1 if not /\b[0-9a-f]{40}\b/'
}

function is_ghe_token_with_user_scope () {
    local HOST=$1
    local USER=$2
    local PASSWORD="$3"
    curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$PASSWORD" https://$HOST/api/v3/users -I \
        | grep '^X-OAuth-Scopes:.*user.*' > /dev/null
}

function get_ghe_name () {
    local HOST=$1
    local USER=$2
    local PASSWORD="$3"
    curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$PASSWORD" https://$HOST/api/v3/user \
        | perl -ne 'print "$1" if m%^\s*"name":\s*"(.*)"[,]?$%i'
}

function get_ghe_email () {
    local HOST=$1
    local USER=$2
    local PASSWORD="$3"
    curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$PASSWORD" https://$HOST/api/v3/user/emails \
        | perl -ne 'print "$1\n" if m%^\s*"email":\s*"(.+\@.+)"[,]?$%i' \
        | head -n 1
}

function create_ghe_token () {
    local HOST=$1
    local USER=$2
    local PASSWORD="$3"
    local CLIENT_ID=$4
    local CLIENT_SECRET=$5
    local COMPUTER_NAME=$(hostname)
    local FINGERPRINT=$(calc_md5sum "$COMPUTER_NAME")
    local TOKEN_URL="https://$HOST/api/v3/authorizations/clients/$CLIENT_ID/$FINGERPRINT"

    # Query all tokens of the current user and try to find a token for the current machine
    TOKEN_ID=$(curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$PASSWORD" https://$HOST/api/v3/authorizations \
        | perl -pe 'chomp' \
        | perl -sne 'print "$1\n" if m%^.*{\s*"id"\:\s+(\d+).*?"fingerprint":\s*"$fingerprint".*%i' -- -fingerprint=$FINGERPRINT \
    )

    # If a token for the current machine was found then delete it
    if [ -n $TOKEN_ID ]; then
        curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$PASSWORD" -X DELETE https://$HOST/api/v3/authorizations/$TOKEN_ID
    fi

    # Request a new token
    curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$PASSWORD" -X PUT \
            --data "{\"scopes\":[\"repo\"], \"note\":\"Enterprise Config ($COMPUTER_NAME)\", \"client_secret\":\"$CLIENT_SECRET\"}" \
            $TOKEN_URL \
        | perl -ne 'print "$1\n" if m%^\s*"token":\s*"([0-9a-f]{40})"[,]?$%i' \
        | head -n 1
}

function check_md5sum () {
    local MD5=$1
    local FILEPATH=$2

    if has_command md5sum; then
        # Exit with the exit code of this command.
        md5sum --check - <<EOM > /dev/null
$MD5  $FILEPATH
EOM
    elif has_command md5; then
        # OS X doesn't ship with md5sum :-/
        local CHECKSUM=$(md5 -q "$FILEPATH")
        [[ $MD5 == $CHECKSUM ]]
    else
        error_exit "No MD5 tool found. Can't verify file: $FILEPATH"
    fi
}

function calc_md5sum () {
    local STRING=$1
    if has_command md5sum; then
        printf '%s' "$STRING" | md5sum | cut -d ' ' -f 1
    elif has_command md5; then
        md5 -qs "$STRING"
    else
        error_exit 'No MD5 tool found.'
    fi
}

function fetch_git_lfs() {
    local VERSION=$1
    local SRC_FILE=$2
    local GIT_LFS_CHECKSUM=$3

    local SRC_URL=https://github.com/github/git-lfs/releases/download/v$VERSION/$SRC_FILE

    # Deliberately no-local so that it can be accessed by caller
    DOWNLOAD_FILE=$(mktemp -t gitlfs_install_${VERSION}_XXXXXXX)

    echo "Downloading Git LFS version $VERSION"
    if ! curl --location --fail --output "$DOWNLOAD_FILE" "$SRC_URL"; then
        rm -f "$DOWNLOAD_FILE"
        error_exit "Git LFS download failed ($SRC_URL)."
    fi

    if ! check_md5sum $GIT_LFS_CHECKSUM "$DOWNLOAD_FILE"; then
        rm -f "$DOWNLOAD_FILE"
        error_exit "Git LFS does not have expected contents ($SRC_URL)." >&2
    fi
}

function check_git () {
    if !(git --version | perl -pse "$VERSION_PARSER" -- -min=$MINIMUM_GIT_VERSION > /dev/null); then
        error_exit "Git version $MINIMUM_GIT_VERSION required."
    fi
}

function git_lfs_error_exit () {
    read -r -d '\0' MESSAGE <<EOM
Git LFS is not available or does not meet the minimum version ($MINIMUM_GIT_LFS_VERSION).
Automated install/update is not supported on your platform. Please see
the instructions on https://git-lfs.github.com/ for manual setup.\0
EOM
    error_exit "$MESSAGE"
}

function check_git_lfs () {
    if !(has_command git-lfs) ||
       !(git-lfs 2>&1 | grep "git-lfs" > /dev/null) ||
       !(git-lfs version | perl -pse "$VERSION_PARSER" -- -min=$MINIMUM_GIT_LFS_VERSION > /dev/null)
    then
        if [[ $1 != no-install ]]; then
            install_git_lfs "$KIT_PATH" $MINIMUM_GIT_LFS_VERSION
        else
            git_lfs_error_exit
        fi
    fi
}

function check_dependency () {
    if ! which $1 > /dev/null 2>&1; then
        error_exit "$1 not installed."
    fi
}

function rewrite_ssh_to_https_if_required () {
    local HOST=$1

    # Check if we can access the host via SSH
    set +e
    ssh -T -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no git@$HOST > /dev/null 2>&1
    SSH_EXIT=$?
    set -e

    # SSH exists with "1" in case the user successfully authenticated because
    # GitHub does not provide shell access.
    if [[ $SSH_EXIT -ne 1 ]]; then
        echo "Configuring HTTPS URL rewrite for $HOST..."
        set +e
        git config --global --remove-section url."https://$HOST/" > /dev/null 2>&1
        set -e
        git config --global --add url."https://$HOST/".insteadOf "ssh://git@$HOST:"
        git config --global --add url."https://$HOST/".insteadOf "ssh://git@$HOST:/"
        git config --global --add url."https://$HOST/".insteadOf "git@$HOST:"
        git config --global --add url."https://$HOST/".insteadOf "git@$HOST:/"
        git config --global --add url."https://$HOST/".pushInsteadOf "ssh://git@$HOST:"
        git config --global --add url."https://$HOST/".pushInsteadOf "ssh://git@$HOST:/"
        git config --global --add url."https://$HOST/".pushInsteadOf "git@$HOST:"
        git config --global --add url."https://$HOST/".pushInsteadOf "git@$HOST:/"
    fi
}

function error_exit () {
    echo -e "\n$(tput setaf 1)###\n### ERROR\n###\n> $(tput sgr 0)$1\n" >&2
    echo -e "$(tput setaf 1)$ERROR_HELP_MESSAGE$(tput sgr 0)\n" >&2
    exit 1
}

function warning () {
    echo -e "\n$(tput setaf 3)###\n### WARNING\n###\n> $(tput sgr 0)$1\n" >&2
}

function print_success () {
    echo -e "\n$(tput setaf 2)$1$(tput sgr 0)\n"
}


###############################################################################
# Load platform-specifics
###############################################################################
function install_git_lfs () {
    git_lfs_error_exit
}

function credential_helper_parameters () {
    : # by default credentials helper have no parameters
}

function one_ping () {
    ping -c 1 $1
}

case $(uname -s) in
    MINGW??_NT*) . "$KIT_PATH/lib/win/setup_helpers.sh";;
         Darwin) . "$KIT_PATH/lib/osx/setup_helpers.sh";;
          Linux) . "$KIT_PATH/lib/lnx/setup_helpers.sh";;
              *) . "$KIT_PATH/lib/other/setup_helpers.sh";;
esac
