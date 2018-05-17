#!/usr/bin/env bash
#
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

while [ $# -gt 0 ]; do
    case $1 in
        (-v|--verbose) VERBOSE=1; shift;;
        (--) shift; break;;
        (-*) error_exit "$1: unknown option";;
        (*) COMMAND=$1; VERBOSE=1 ; shift;; # always verbose for a single/limited command
    esac
done

# Infer a github url from a remote url
INFO_URL=${KIT_REMOTE_URL%%.git}
INFO_URL=${INFO_URL/#git@/https:\/\/}

# Don't print the header if we show the help for a single command
if [ -z "$COMMAND" ]; then
    echo "###"
    echo "### Help"
    echo "###"
    echo

    if [ -n "$VERBOSE" ]; then
        echo "########################################################################"
        echo "# git $KIT_ID"
        echo "########################################################################"
        echo
        echo "Update your Git environment and all commands below."
        echo
    else
         echo "git $KIT_ID                           Update your Git environment and all commands below."
    fi
fi

echo

function print_script_help {
    for f in "$1/"*.sh
    do
        case $f in
            */help.sh)      continue;;
            */install.sh)   continue;;
            */setup.sh)     continue;;
        esac

        SCRIPT_NAME=$(basename $f | sed 's/\.sh$//')

        # if command is specified, match it as substring (so there could be multiple matches)
        if [[ ! -z "$COMMAND" && $SCRIPT_NAME != *"$COMMAND"* ]]; then
            continue
        fi
        COMMAND_FOUND=1

        if [ -n "$VERBOSE" ]; then
            echo "########################################################################"
            echo "# git $KIT_ID $SCRIPT_NAME"
            echo "########################################################################"
            grep '^#/' "$f" | cut -c 3- | sed "s/\$KIT_ID/$KIT_ID/"
            echo
        else
            printf "git $KIT_ID $SCRIPT_NAME"
            printf "%$((25 - ${#SCRIPT_NAME}))s" " "
            printf "$(grep '^#/' "$f" | cut -c 3- | sed "s/\$KIT_ID/$KIT_ID/" | sed -n 2p)\n"
        fi
    done
}

# main commands
print_script_help "$KIT_PATH"

# commands in the environment
set +e
ENVIRONMENT=$(git config --global adsk.environment)
set -e
if [ ! -z "$ENVIRONMENT" ]; then
    COMMANDS_PATH="$COMMANDS_PATH/envs/$ENVIRONMENT"

    # Don't print the header if we show the help for a single command
    if [ -z "$COMMAND" ]; then
        echo
        echo "###"
        echo "### Commands in $ENVIRONMENT environment"
        echo "###"
        echo
    fi
    print_script_help "$KIT_PATH/envs/$ENVIRONMENT"
fi

if [ -z "$COMMAND_FOUND" ]; then
    error_exit "Command 'git $KIT_ID $COMMAND' not found"
fi

# Don't print the footer if we show the help for a single command
if [ -z "$COMMAND" ]; then
    echo "---"
    echo

    if [ -n "$VERBOSE" ]; then
        echo "You can easily add your own commands. See $INFO_URL for details."
    else
        echo "Run 'git $KIT_ID help --verbose' for more help."
        echo "Run 'git $KIT_ID help <command>' for help on specific command(s)."
    fi

    echo
    echo "If you run into any trouble:"
    echo "$ERROR_HELP_MESSAGE"
    echo
fi
