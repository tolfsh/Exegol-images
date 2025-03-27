#!/bin/bash

source common.sh

function update() {
    colorecho "Updating, upgrading, cleaning"
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
    apt-get -y update && apt-get -y install apt-utils dialog && apt-get -y upgrade && apt-get -y autoremove && apt-get clean
}

function deploy_exegol() {
    colorecho "Installing Exegol things"
    # Moving exegol files to /
    # It's copied and not moved for caching and updating purposes (reusing exegol_base to create exegol_base)
    # mkdir -p /opt/packages
    # chown -Rv _apt:root /opt/packages
    rm -rf /.exegol || true
    cp -r /root/sources/assets/exegol /.exegol
    cp -v /root/sources/assets/shells/history.d/_init ~/.zsh_history
    cp -v /root/sources/assets/shells/aliases.d/_init /opt/.exegol_aliases
    # Moving supported custom configurations in /opt
    mv /.exegol/skel/supported_setups.md /opt/
    mkdir -p /var/log/exegol
    # Setup perms
    chown -R root:root /.exegol
    chmod 500 /.exegol/*.sh
    find /.exegol/skel/ -type f -exec chmod 660 {} \;
}

function install_exegol-history() {
    colorecho "Installing Exegol-history"
    git -C /opt/tools/ clone --depth 1 https://github.com/ThePorgs/Exegol-history
    cd /opt/tools/Exegol-history || exit
    python3 -m venv --system-site-packages ./venv
    source ./venv/bin/activate
    pip3 install -r requirements.txt
    deactivate
    add-aliases exegol-history
    add-history exegol-history
    add-test-command "exh -h"
    add-to-list "exegol-history,https://github.com/ThePorgs/Exegol-history,Credentials management for Exegol"
}

function filesystem() {
    colorecho "Preparing filesystem"
    mkdir -p /opt/tools/bin/ /data/ /var/log/exegol /.exegol/build_pipeline_tests/ /opt/rules/ /opt/lists
    touch /.exegol/build_pipeline_tests/all_commands.txt
    touch /.exegol/installed_tools.csv
    echo "Tool,Link,Description" >> /.exegol/installed_tools.csv
}

function add_debian_repository_components() {
    # add non-free non-free-firmware contrib repository
    # adding at the end of the line start with Components of the repository to add
    colorecho "add non-free non-free-firmware contrib repository"
    local source_file="/etc/apt/sources.list.d/debian.sources"
    local out_file="/etc/apt/sources.list.d/debian2.sources"

    while IFS= read -r line; do
      if [[ "$line" == "Components"* ]]; then
        echo  "${line} non-free non-free-firmware contrib" >> "$out_file"
      else
        echo "$line" >> "$out_file"
      fi
    done < "$source_file"
    mv "$out_file" "$source_file"
}

# if there is arg, execute them, mimic entrypoint.sh
if [ $# -gt 0 ]; then
  "$@"
fi