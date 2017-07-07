FROM ubuntu:16.04

MAINTAINER "Sebastian Wilzbach <seb@wilzba.ch>"

ENV DLANG_VERSION "dmd-nightly"

RUN apt-get update && apt-get install --no-install-recommends -y libc-dev gcc curl ca-certificates xz-utils \
 && curl -fsS -o /tmp/install.sh http://dlang.org/install.sh \
 && bash /tmp/install.sh -p /dlang install -s "dmd-nightly" \
 && ln -s /dlang/$(ls -tr /dlang | tail -n1) /dlang/${DLANG_VERSION} \
 && rm /tmp/install.sh \
 && rm /dlang/install.sh \
 && rm /dlang/d-keyring.gpg \
 && apt-get auto-remove -y curl build-essential wget curl ca-certificates xz-utils \
 && rm -rf /var/cache/apt \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && rm -rf /dlang/dub* \
 && bash -c "find /dlang \( -type d -and -path '*/bin32' -or -path '*/lib32' -or -path '*/html' \) -exec rm -rf {} \;" \
 && chmod 555 -R /dlang

ENV \
  PATH=/dlang/dmd-nightly/linux/bin64:${PATH} \
  LD_LIBRARY_PATH=/dlang/${DLANG_VERSION}/linux/lib64 \
  LIBRARY_PATH=/dlang/${DLANG_VERSION}/linux/lib64

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir /sandbox && chown nobody:nogroup /sandbox
USER nobody

ENTRYPOINT [ "/entrypoint.sh" ]
