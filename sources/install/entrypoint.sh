#!/bin/bash

set -e

for file in package_*.sh; do
    if [ -f "$file" ]; then
        source "$file"
    fi
done

# Entry point for the installation
if [[ $EUID -ne 0 ]]; then
  criticalecho "You must be a root user"
else
  if declare -f "$1" > /dev/null
  then
    if [[ -f '/.dockerenv' ]]; then
      echo -e "${GREEN}"
      echo "This script is running in docker, as it should :)"
      echo "If you see things in red, don't panic, it's usually not errors, just badly handled colors"
      echo -e "${NOCOLOR}"
      for cmd in "$@"; do
        "$cmd"
      done
    else
      echo -e "${RED}"
      echo "[!] Careful : this script is supposed to be run inside a docker/VM, do not run this on your host unless you know what you are doing and have done backups. You have been warned :)"
      echo -e "${NOCOLOR}"
      for cmd in "$@"; do
        "$cmd"
      done
    fi
  else
    echo "'$1' is not a known function name" >&2
    exit 1
  fi
fi
