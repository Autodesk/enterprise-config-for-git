#!/usr/bin/env bash

if [ -z $KIT_PATH ]; then
    KIT_PATH=$(dirname "$0")
fi
git config --global init.templatedir $KIT_PATH/template

