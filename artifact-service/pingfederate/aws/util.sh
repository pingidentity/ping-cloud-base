#!/bin/sh

# Method to check for errors after an aws call
function check_for_error() {
    if ! test $(echo $?) == "0"; then
        echo $1
        exit 1
    fi
}