# Author: The Exegol Project

ARG BASE_IMAGE_REGISTRY="tolfsh/exegol"
ARG BASE_IMAGE_NAME="base"

FROM ${BASE_IMAGE_REGISTRY}:${BASE_IMAGE_NAME}

RUN apt-get update

COPY sources/install /root/sources/install
COPY sources/assets /root/sources/assets

WORKDIR /root/sources/install

# WARNING: package_most_used can't be used with other functions other than: package_base, post_install
# ./entrypoint.sh package_most_used
RUN chmod +x entrypoint.sh

###############################################
# Here you put all the tools you need like this
RUN ./entrypoint.sh 'set_env; install_pretender'
RUN ./entrypoint.sh "set_env; install_responder"
RUN ./entrypoint.sh "set_env; install_bloodhound-py"
RUN ./entrypoint.sh "set_env; install_bloodhound-ce-py"
RUN ./entrypoint.sh "set_env; install_bloodhound"
RUN ./entrypoint.sh "set_env; install_mitm6_pip"
RUN ./entrypoint.sh "set_env; install_impacket"
RUN ./entrypoint.sh "set_env; install_krbrelayx"
RUN ./entrypoint.sh "set_env; install_evilwinrm"
RUN ./entrypoint.sh "set_env; install_pypykatz"
RUN ./entrypoint.sh "set_env; install_enum4linux-ng"
RUN ./entrypoint.sh "set_env; install_smbmap"
RUN ./entrypoint.sh "set_env; install_adidnsdump"
RUN ./entrypoint.sh "set_env; install_ldapsearch-ad"
RUN ./entrypoint.sh "set_env; install_petitpotam"
RUN ./entrypoint.sh "set_env; install_coercer"
RUN ./entrypoint.sh "set_env; install_pkinittools"
RUN ./entrypoint.sh "set_env; install_pywhisker"
RUN ./entrypoint.sh "set_env; install_pywsus"
RUN ./entrypoint.sh "set_env; install_donpapi"
RUN ./entrypoint.sh "set_env; install_webclientservicescanner"
RUN ./entrypoint.sh "set_env; install_certipy"
RUN ./entrypoint.sh "set_env; install_shadowcoerce"
RUN ./entrypoint.sh "set_env; install_ldaprelayscan"
RUN ./entrypoint.sh "set_env; install_keepwn"
#RUN ./entrypoint.sh "set_env; install_bloodhound-ce"
RUN ./entrypoint.sh "set_env; install_netexec"
RUN ./entrypoint.sh "set_env; install_neo4j"

###############################################


RUN ./entrypoint.sh post_install

WORKDIR /workspace

ENTRYPOINT ["/.exegol/entrypoint.sh"]

# ARGs need to be placed after the FROM instruction. As per https://docs.docker.com/engine/reference/builder/#arg.
# If they are placed before, they will be overwritten somehow, and the LABELs below will be filled with empty ARGs
ARG TAG="local"
ARG VERSION="local"
ARG BUILD_DATE="n/a"

RUN echo "${TAG}-${VERSION}" > /opt/.exegol_version

LABEL org.exegol.tag="${TAG}"
LABEL org.exegol.version="${VERSION}"
LABEL org.exegol.build_date="${BUILD_DATE}"
LABEL org.exegol.app="Exegol"
LABEL org.exegol.src_repository="https://github.com/tolfsh/Exegol-images"