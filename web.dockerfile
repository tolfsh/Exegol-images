# Author: The Exegol Project

ARG BASE_IMAGE_REGISTRY="tolfsh/exegol"
ARG BASE_IMAGE_NAME="base"

FROM ${BASE_IMAGE_REGISTRY}:${BASE_IMAGE_NAME}

RUN apt-get update

COPY sources/install /root/sources/install
COPY sources/assets /root/sources/assets

WORKDIR /root/sources/install

# WARNING: package_most_used can't be used with other functions other than: package_base
# ./entrypoint.sh package_most_used
RUN chmod +x entrypoint.sh

RUN ./entrypoint.sh 'set_env; install_nuclei'
RUN ./entrypoint.sh "set_env; install_weevely"
RUN ./entrypoint.sh "set_env; install_whatweb"
RUN ./entrypoint.sh "set_env; install_wfuzz"
RUN ./entrypoint.sh "set_env; install_gobuster"
RUN ./entrypoint.sh "set_env; install_dirsearch"
RUN ./entrypoint.sh "set_env; install_nosqlmap"
RUN ./entrypoint.sh "set_env; install_joomscan"
RUN ./entrypoint.sh "set_env; install_wpscan"
RUN ./entrypoint.sh "set_env; install_droopescan"
RUN ./entrypoint.sh "set_env; install_testssl"
RUN ./entrypoint.sh "set_env; install_eyewitness"
RUN ./entrypoint.sh "set_env; install_sqlmap"

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
LABEL org.exegol.src_repository="https://github.com/tolfsh/Exegol-Images"
