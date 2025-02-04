#!/bin/bash

set -e

for file in package_*.sh; do
    if [ -f "$file" ]; then
        source "$file"
    fi
done

eval "$@"
