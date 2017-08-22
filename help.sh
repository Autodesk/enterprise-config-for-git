#!/usr/bin/env bash
#
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"

# Infer a github url from a remote url
INFO_URL=${KIT_REMOTE_URL%%.git}
INFO_URL=${INFO_URL/#git@/https:\/\/}

echo "###"
echo "### Enterprise Config"
echo "###"
echo
echo "########################################################################"
echo "# git $KIT_ID"
echo "########################################################################"
echo
echo "Update your Git environment and all commands below."
echo
echo

for f in $KIT_PATH/*.sh
do
    # echo
    case $f in
        */help.sh)      continue;;
        */install.sh)   continue;;
        */setup.sh)     continue;;
    esac
    echo "########################################################################"
    echo "# git $KIT_ID $(basename $f | sed 's/\.sh$//')"
    echo "########################################################################"
    grep '^#/' "$f" | cut -c 3- | sed "s/\$KIT_ID/$KIT_ID/"
    echo
done

echo "---"
echo
echo "You can easily add your own commands. See $INFO_URL for details."
echo
echo "If you run into any trouble:"
echo "$ERROR_HELP_MESSAGE"
echo
