#!/usr/bin/env bash
#
# Remove credentials stored using the credential helpers
#
# Usage: git <KIT_ID> teardown
#
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/lib/setup_helpers.sh"

remove_credentials '<< YOUR GITHUB SERVER >>>'

print_kit_header
print_success 'Git credentials successfully removed!'
