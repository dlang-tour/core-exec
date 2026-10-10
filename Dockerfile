FROM ubuntu:26.04 AS base

LABEL MAINTAINER="DLang Tour Community <tour@dlang.io>"

RUN apt-get update && apt-get install --no-install-recommends -y \
  ca-certificates gpg \
  curl \
  gcc \
  jq \
  libc-dev \
  libevent-dev \
  liblapack-dev \
  libopenblas-dev \
  libssl-dev xz-utils \
  binutils-gold \
  clang libxml2-16 zlib1g-dev \
  # 'llvm' is needed to get llvm-symbolizer symbol-->source line information in e.g. AddressSanitizer output
  llvm \
  && update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.gold" 20 \
  && update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.bfd" 10

# set default libclang version
RUN ln -s /usr/lib/x86_64-linux-gnu/libclang-*.so.1 /usr/lib/x86_64-linux-gnu/libclang.so \
  && test -e /usr/lib/x86_64-linux-gnu/libclang.so
FROM base
ARG DLANG_VERSION=dmd
ARG DLANG_EXEC=dmd
ENV DLANG_VERSION=$DLANG_VERSION
ENV DLANG_EXEC=$DLANG_EXEC

# CI sets this to the UTC date. A new day rebuilds from the compiler
# install down, which is what picks up dmd/ldc and dub version=*.
# The apt stage above does not use this value, so it stays cached.
# Local builds leave it at the default and reuse this layer.
ARG COMPILER_CACHE_EPOCH=stable

# Download and install the compiler. Referencing the epoch here makes
# it part of this layer's cache key.
RUN echo "compiler-cache-epoch=${COMPILER_CACHE_EPOCH}" \
 && curl -fsS -o /tmp/install.sh https://dlang.org/install.sh \
 && bash /tmp/install.sh -p /dlang install ${DLANG_VERSION}

# Fetch obj2asm from an older release if it's not included in the selected release
RUN set -eux ; \
  if [ ! -f /dlang/*/linux/bin32/obj2asm ] ; \
  then \
    echo "Fetching missing obj2asm from an older release!" ; \
    bash /tmp/install.sh -p /tmp/dlang-tools install dmd-2.093.1 ; \
    if [ "${DLANG_EXEC}" = "dmd" ] ; \
    then \
      mv /tmp/dlang-tools/dmd-2.093.1/linux/bin32/obj2asm $(find -P /dlang/ -name bin32) ; \
      mv /tmp/dlang-tools/dmd-2.093.1/linux/bin64/obj2asm $(find -P /dlang/ -name bin64) ; \
    else \
      mv /tmp/dlang-tools/dmd-2.093.1/linux/bin64/obj2asm $(find -P /dlang/ -name bin) ; \
    fi ; \
    \
    rm -r /tmp/dlang-tools ; \
  fi

# Clean up to keep the image size minimal.
# har is compiled after the dub prefetch, so this layer stays cached
# when only har changes.
RUN rm -f /dlang/d-keyring.gpg \
 && rm -rf /dlang/dub* \
 && ln -s /dlang/$(ls -tr /dlang | tail -n1) /dlang/${DLANG_VERSION} \
 && rm /tmp/install.sh \
 && rm /dlang/install.sh \
 && apt-get auto-remove -y xz-utils \
 && rm -rf /var/cache/apt \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && find /dlang \( -type d -and \! -type l -and -path "*/bin32" -or -path "*/lib32" -or -path "*/html" \) | xargs rm -rf \
 && chmod 555 -R /dlang

ENV \
  PATH=/dlang/${DLANG_VERSION}/linux/bin64:/dlang/dub:/dlang/${DLANG_VERSION}/bin:/dlang/har:${PATH} \
  LD_LIBRARY_PATH=/dlang/${DLANG_VERSION}/linux/lib64:/dlang/${DLANG_VERSION}/lib \
  LIBRARY_PATH=/dlang/${DLANG_VERSION}/linux/lib64:/dlang/${DLANG_VERSION}/lib

RUN useradd -d /sandbox d-user

RUN mkdir /sandbox && chown d-user:nogroup /sandbox
USER d-user

WORKDIR /sandbox
RUN dub build --compiler=${DLANG_EXEC} dpp
COPY packages.txt .
# The prefetch loop uses `echo -e`, which dash does not support.
SHELL ["/bin/bash", "-c"]
RUN packages=$(cat packages.txt) && \
  for package_name in $packages; do \
    package="$(echo $package_name | cut -d: -f1)"; \
    version="$(echo $package_name | grep : |cut -d: -f2)"; \
    version="${version:-*}"; \
    echo -e '/++dub.sdl:\nname "foo"' > foo.d; \
    echo -e "dependency \"${package}\" version=\"${version}\"" >> foo.d; \
    echo -e '+/\nvoid main() {}' >> foo.d; \
    dub build --single --compiler=${DLANG_EXEC} foo.d; \
    version=$(dub describe ${package} | jq '.packages[0].version'); \
    echo "${package}:${version}" >> packages; \
    rm -f foo*; \
    rm -rf .dub/build; \
  done

USER root
COPY entrypoint.sh /entrypoint.sh
RUN mv /sandbox/packages /installed_packages; \
  chmod 555 /installed_packages

# After the prefetch on purpose: editing har must not rebuild dpp
# or re-download the packages above. /dlang is mode 555; root can
# still create /dlang/har.
COPY ./har /tmp/har/src
RUN source /dlang/${DLANG_VERSION}/activate; \
  echo "$PATH" && \
  "$DMD" -of=/tmp/har/src/har -g -debug \
    /tmp/har/src/harmain.d /tmp/har/src/archive/har.d && \
  mkdir -p /dlang/har && \
  cp /tmp/har/src/har /dlang/har/har && \
  rm -rf /tmp/har && \
  chmod 555 /dlang/har /dlang/har/har
USER d-user

ENTRYPOINT [ "/entrypoint.sh" ]
