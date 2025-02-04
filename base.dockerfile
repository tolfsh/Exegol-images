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
RUN DEBIAN_FRONTEND=noninteractive apt-fast install -y --no-install-recommends man git lsb-release pciutils pkg-config zip unzip kmod gnupg2 wget \
libffi-dev  zsh asciinema npm gem automake autoconf make cmake time gcc g++ file lsof \
less net-tools vim nano jq iputils-ping iproute2 tidy mlocate libtool \
dos2unix ftp sshpass telnet nfs-common ncat netcat-traditional socat \
screen p7zip-full p7zip-rar unrar xz-utils tree ruby ruby-dev ruby-full bundler \
perl libwww-perl openjdk-17-jdk \
logrotate tldr bat libxml2-utils virtualenv libsasl2-dev \
libldap2-dev libssl-dev isc-dhcp-client sqlite3 dnsutils samba ssh snmp php \
python3 grc xsel xxd libnss3-tools macchanger

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

RUN ./entrypoint.sh  setup_python_env 

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

# install java 
RUN ./entrypoint.sh install_java11
RUN ./entrypoint.sh install_java21
RUN ln -s -v /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/java-17-openjdk
RUN update-alternatives --set java /usr/lib/jvm/java-17-openjdk-*/bin/java

RUN ./entrypoint.sh install_go                                          
RUN ./entrypoint.sh install_ohmyzsh                                     
RUN ./entrypoint.sh install_fzf                                         
RUN ./entrypoint.sh install_yarn
RUN ./entrypoint.sh add-aliases bat
RUN ./entrypoint.sh add-test-command "bat --version"    

RUN cp -v /root/sources/assets/grc/grc.conf /etc/grc.conf

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
RUN /root/.pyenv/shims/pip3 install -r /root/sources/assets/python/requirements.txt
####################
# end package_base #
####################

COPY sources/install/package_network.sh /root/sources/install
RUN ./entrypoint.sh install_nmap

# put all packages for future install inside the container
COPY sources/install /root/sources/install

# run post install (will modify the installed files for source to work so we put it after the copy)
RUN chmod +x entrypoint.sh && ./entrypoint.sh post_install

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
