FROM ubuntu:17.04

MAINTAINER "Sebastian Wilzbach <seb@wilzba.ch>"

RUN apt-get update && apt-get install --no-install-recommends -y libc-dev gcc curl ca-certificates xz-utils

ENV DLANG_VERSION "dmd-nightly"
ENV DLANG_EXEC "dmd"

RUN curl -fsS -o /tmp/install.sh http://dlang.org/install.sh \
 && bash /tmp/install.sh -p /dlang install -s ${DLANG_VERSION} \
 && rm -f /dlang/d-keyring.gpg \
 && rm -rf /dlang/dub* \
 && ln -s /dlang/$(ls -tr /dlang | tail -n1) /dlang/${DLANG_VERSION} \
 && rm /tmp/install.sh \
 && rm /dlang/install.sh \
 && apt-get auto-remove -y curl ca-certificates xz-utils \
 && rm -rf /var/cache/apt \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && find /dlang \( -type d -and \! -type l -and -path "*/bin32" -or -path "*/lib32" -or -path "*/html" \) | xargs rm -rf \
 && chmod 555 -R /dlang

ENV \
  PATH=/dlang/${DLANG_VERSION}/linux/bin64:/dlang/${DLANG_VERSION}/bin:${PATH} \
  LD_LIBRARY_PATH=/dlang/${DLANG_VERSION}/linux/lib64:/dlang/${DLANG_VERSION}/lib \
  LIBRARY_PATH=/dlang/${DLANG_VERSION}/linux/lib64:/dlang/${DLANG_VERSION}/lib

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir /sandbox && chown nobody:nogroup /sandbox
USER nobody

ENTRYPOINT [ "/entrypoint.sh" ]
