#!/usr/bin/env bash
#/
#/ Create a new repo on GitHub
#/
#/ Usage: git $KIT_ID mkrepo my_new_repo
#/

set -e

REPO=$1
[ -z "$REPO" ] && echo "Missing repo name" && exit 1

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

ADS_USER=$(git config --global adsk.github.account)
[ -z "$ADS_USER" ] && error_exit 'Username must not be empty!'

SERVER=$(git config --global adsk.github.server)
[ -z "$SERVER" ] && error_exit 'Server must not be empty!'

TOKEN="$(get_credentials $SERVER $ADS_USER)"
[ -z "$TOKEN" ] && echo "Missing GitHub token" && exit 1

URL="https://$SERVER/api/v3/user/repos"
HEADERS="Authorization: token $TOKEN"
DATA="{\"name\":\"$REPO\"}"

set +e
RESPONSE=$(curl --silent --fail -H "$HEADERS" -d "$DATA" $URL)
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]
then
  echo "Could not create repo '$REPO'"
  echo $RESPONSE
  exit $STATUS
fi

echo "repo 'https://$SERVER/$ADS_USER/$REPO' created!"
