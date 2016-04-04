#!/usr/bin/env bash
#
set -e

read -r -d '\0' HELP <<EOM
###
### Enterprise Config
###

# Setup
Description: Configures your machine to use Git.
Command:     git adsk

# Teardown
Description: Removes all Git credentials from your machine.
Command:     git adsk teardown

# Clone
Description: Fast clone a repository with Git LFS files and submodules.
Command:     git adsk clone <repository URL> [<target directory>]

# Pull
Description: Pull changes from a repository and all its submodules.
Command:     git adsk pull

# Help
Description: This help page.
Command:     git adsk help

# Version
Description: Print version information.
Command:     git adsk version

\0
EOM
echo "$HELP"

