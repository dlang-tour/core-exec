FROM ubuntu:16.04

MAINTAINER "André Stein <andre.stein.1985@gmail.com>"

# Version updates here
ENV VERSION "2.074.0"

RUN apt-get update && apt-get install --no-install-recommends -y wget libc6-dev xdg-utils gcc libcurl3  && \
    wget http://downloads.dlang.org/releases/2.x/${VERSION}/dmd_${VERSION}-0_amd64.deb -O /dmd.deb && \
    dpkg -i /dmd.deb && \
    rm /dmd.deb && \
    apt-get remove -y wget && apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir /sandbox && chown nobody:nogroup /sandbox
USER nobody

ENTRYPOINT [ "/entrypoint.sh" ]
