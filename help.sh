#!/usr/bin/env bash
#
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"

# Infer a github url from a remote url
INFO_URL=${KIT_REMOTE_URL%%.git}
INFO_URL=${INFO_URL/#git@/https:\/\/}

read -r -d '\0' HELP <<EOM
###
### Enterprise Config
###

# Setup
Description: Configures your machine to use Git.
Command:     git $KIT_ID

# Teardown
Description: Removes all Git credentials from your machine.
Command:     git $KIT_ID teardown

# Clone
Description: Fast clone a repository with Git LFS files and submodules.
Command:     git $KIT_ID clone <repository URL> [<target directory>]

# Pull
Description: Pull changes from a repository and all its submodules.
Command:     git $KIT_ID pull

# Deleted
Description: list the files that have been deleted from the current repository
Command:    git adsk show-deleted [-h] [<path/to/file>]
Example:    git adsk show-deleted

# Help
Description: This help page.
Command:     git $KIT_ID help

# Version
Description: Print version information.
Command:     git $KIT_ID version

---
You can easily add your own commands. See $INFO_URL for details.

If you run into any trouble:
$ERROR_HELP_MESSAGE
\0
EOM
echo "$HELP"
