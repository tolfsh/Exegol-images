# Author: The Exegol Project

FROM debian:12-slim

COPY sources/install/common.sh sources/install/entrypoint.sh sources/install/preinstall.sh /root/sources/install/

WORKDIR /root/sources/install

RUN echo "${TAG}-${VERSION}" > /opt/.exegol_version
RUN chmod +x entrypoint.sh preinstall.sh
###########################
# run package_base        #
# only need preinstall.sh #
###########################
RUN ./preinstall.sh update
RUN ./preinstall.sh colorecho "Installing apt-fast for faster dep installs"
RUN apt-get install -y curl sudo wget
# splitting curl | bash to avoid having additional logs put in curl output being executed because of catch_and_retry
RUN curl -sL https://git.io/vokNn -o /tmp/apt-fast-install.sh && bash /tmp/apt-fast-install.sh && rm /tmp/apt-fast-install.sh
RUN apt-fast install -y --no-install-recommends software-properties-common
RUN ./preinstall.sh add_debian_repository_components
COPY sources/assets/apt/sources.list.d /root/sources/assets/apt/sources.list.d
COPY sources/assets/apt/preferences.d /root/sources/assets/apt/preferences.d
RUN cp -v /root/sources/assets/apt/sources.list.d/* /etc/apt/sources.list.d/
RUN cp -v /root/sources/assets/apt/preferences.d/* /etc/apt/preferences.d/
RUN apt-get update
RUN ./preinstall.sh colorecho "Starting main programs install"
RUN apt-fast install -y --no-install-recommends man git lsb-release pkg-config zip unzip gnupg2 wget \
    libffi-dev  zsh asciinema file less net-tools vim jq iputils-ping iproute2 \
    dos2unix ftp telnet nfs-common netcat-openbsd p7zip-full p7zip-rar unrar xz-utils tree \
    tldr virtualenv libssl-dev sqlite3 dnsutils ssh php \
    python3 grc xxd

# now we need assets
COPY sources/assets /root/sources/assets
RUN ./preinstall.sh deploy_exegol
RUN ./preinstall.sh install_exegol-history
RUN ./preinstall.sh filesystem
RUN cp -v /root/sources/assets/shells/exegol_shells_rc /opt/.exegol_shells_rc
RUN cp -v /root/sources/assets/shells/bashrc ~/.bashrc

############################
# now need package_base.sh #
############################
COPY sources/install/package_base.sh /root/sources/install/

RUN ./entrypoint.sh install_locales

RUN ./entrypoint.sh install_asdf

RUN ./entrypoint.sh setup_python_env

# change default shell
RUN chsh -s /bin/zsh

RUN ./entrypoint.sh add-history dnsutils
RUN ./entrypoint.sh add-history samba
RUN ./entrypoint.sh add-history ssh
RUN ./entrypoint.sh add-history snmp
RUN ./entrypoint.sh add-history faketime
RUN ./entrypoint.sh add-history curl

RUN ./entrypoint.sh add-aliases php
RUN ./entrypoint.sh add-aliases python3
RUN ./entrypoint.sh add-aliases grc
RUN ./entrypoint.sh add-aliases emacs-nox
RUN ./entrypoint.sh add-aliases xsel
RUN ./entrypoint.sh add-aliases pyftpdlib

# Rust, Cargo, rvm
RUN ./entrypoint.sh install_rust_cargo
# Ruby Version Manager
RUN ./entrypoint.sh install_rvm

# java11 install, and java17 as default
#install_java11
#ln -s -v /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/java-17-openjdk    # To avoid determining the correct path based on the architecture
#update-alternatives --set java /usr/lib/jvm/java-17-openjdk-*/bin/java  # Set the default openjdk version to 17

RUN ./entrypoint.sh install_go                                          
RUN ./entrypoint.sh install_ohmyzsh                                     
RUN ./entrypoint.sh install_fzf                                         
RUN ./entrypoint.sh install_yarn
#install_ultimate_vimrc                              # Make vim usable OOFB
#install_neovim
#install_mdcat                                       # cat markdown files
RUN ./entrypoint.sh add-aliases bat
RUN ./entrypoint.sh add-test-command "bat --version"
# Macchanger
RUN DEBIAN_FRONTEND=noninteractive apt-fast install -y --no-install-recommends macchanger      
#install_gf                                          # wrapper around grep
#install_firefox

RUN cp -v /root/sources/assets/grc/grc.conf /etc/grc.conf # grc

# openvpn
# Fixing openresolv to update /etc/resolv.conf without resolvectl daemon (with a fallback if no DNS server are supplied)
RUN LINE=$(($(grep -n 'up)' /etc/openvpn/update-resolv-conf | cut -d ':' -f1) +1));\
sed -i "${LINE}"'i cp /etc/resolv.conf /etc/resolv.conf.backup' /etc/openvpn/update-resolv-conf;\
LINE=$(($(grep -n 'resolvconf -a' /etc/openvpn/update-resolv-conf | cut -d ':' -f1) +1));\
# shellcheck disable=SC2016
sed -i "${LINE}"'i [ "$((resolvconf -l "tun*" 2>/dev/null || resolvconf -l "tap*") | grep -vE "^(\s*|#.*)$")" ] && /sbin/resolvconf -u || cp /etc/resolv.conf.backup /etc/resolv.conf' /etc/openvpn/update-resolv-conf;\
((LINE++));\
sed -i "${LINE}"'i rm /etc/resolv.conf.backup' /etc/openvpn/update-resolv-conf
RUN ./entrypoint.sh add-test-command "openvpn --version"

# logrotate
RUN mv /root/sources/assets/logrotate/* /etc/logrotate.d/
RUN chmod 644 /etc/logrotate.d/*

# tmux
RUN cp -v /root/sources/assets/shells/tmux.conf ~/.tmux.conf
RUN touch ~/.hushlogin

# TLDR
RUN mkdir -p ~/.local/share/tldr
RUN tldr -u

# NVM (install in context)
RUN zsh -c "source ~/.zshrc && nvm install node && nvm use default"

# Set Global config path to vendor
# All programs using bundle will store their deps in vendor/
RUN bundle config path vendor/

# OpenSSL activate legacy support
RUN cat /root/sources/assets/patches/openssl.patch >> /etc/ssl/openssl.cnf
RUN ./entrypoint.sh add-test-command "echo -n '1337' | openssl dgst -md4"
RUN ./entrypoint.sh add-test-command "python3 -c 'import hashlib;print(hashlib.new(\"md4\", \"1337\".encode()).digest())'"

# Global python dependencies
RUN pip3 install -r /root/sources/assets/python/requirements.txt
####################
# end package_base #
####################


RUN ./entrypoint.sh install_nmap
RUN ./entrypoint.sh post_install

WORKDIR /workspace

ENTRYPOINT ["/.exegol/entrypoint.sh"]

# put label at the end to not invalidate cache
ARG TAG="local"
ARG VERSION="local"
ARG BUILD_DATE="n/a"

LABEL org.exegol.tag="${TAG}"
LABEL org.exegol.version="${VERSION}"
LABEL org.exegol.build_date="${BUILD_DATE}"
LABEL org.exegol.app="Exegol"
LABEL org.exegol.src_repository="https://github.com/tolfsh/Exegol-images"
