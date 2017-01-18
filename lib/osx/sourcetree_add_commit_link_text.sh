#!/usr/bin/env bash

FILE=${1:-.git/sourcetreeconfig}

KEY_NUMBER="0"

DESC_KEY="commentURLParser$KEY_NUMBER.description"
DESC_VALUE="Enterprise config for Git"

TYPE_KEY="commentURLParser$KEY_NUMBER.type"
TYPE_VALUE="0"

REGEX_KEY="commentURLParser$KEY_NUMBER.regex"
REGEX_VALUE=$(git config --global bugtraq.jira.logregex)

TARGET_KEY="commentURLParser$KEY_NUMBER.target"
TARGET_VALUE=$(git config --global bugtraq.jira.url | sed s,%BUGID%,\$1,)

if grep -q $TYPE_KEY $FILE; then
    echo "The comment parser URL type is already present and will not be modified."
    exit 0
fi

# Ensure to remove any regex / target entries.
TEMP_FILE=$(mktemp)
mv $FILE $TEMP_FILE
grep -v "^commentURLParser$KEY_NUMBER\.\(description\|regex\|target\)" $TEMP_FILE > $FILE
rm $TEMP_FILE

echo "$DESC_KEY=$DESC_VALUE" >> $FILE
echo "$TYPE_KEY=$TYPE_VALUE" >> $FILE
echo "$REGEX_KEY=$REGEX_VALUE" >> $FILE
echo "$TARGET_KEY=$TARGET_VALUE" >> $FILE
