FROM ubuntu:latest

MAINTAINER "DLang Tour Community <tour@dlang.io>"

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
	libclang-6.0-dev clang libxml2 zlib1g-dev \
	# 'llvm' is needed to get llvm-symbolizer symbol-->source line information in e.g. AddressSanitizer output
	llvm \
	&& update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.gold" 20 \
	&& update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.bfd" 10

# set libclang6 as default
RUN ln -s /usr/lib/x86_64-linux-gnu/libclang-6.0.so /usr/lib/x86_64-linux-gnu/libclang.so

ARG DLANG_VERSION=dmd
ARG DLANG_EXEC=dmd
ENV DLANG_VERSION=$DLANG_VERSION
ENV DLANG_EXEC=$DLANG_EXEC

# Download and run the install script
RUN curl -fsS -o /tmp/install.sh https://dlang.org/install.sh
RUN bash /tmp/install.sh -p /dlang install ${DLANG_VERSION}

# Fetch obj2asm from an older release if it's not included in the selected release
RUN if [ ! -f /dlang/*/linux/bin32/obj2asm ]; then \
		echo "Fetching missing obj2asm from an older release!" \
		&& bash /tmp/install.sh -p /tmp/dlang-tools install dmd-2.093.1 \
		&& mv /tmp/dlang-tools/dmd-2.093.1/linux/bin32/obj2asm /dlang/*/linux/bin32 \
		&& mv /tmp/dlang-tools/dmd-2.093.1/linux/bin64/obj2asm /dlang/*/linux/bin64 \
		&& rm -r /tmp/dlang-tools ; \
	fi

COPY ./har /tmp/har/src
SHELL ["/bin/bash", "-c"]
RUN source /dlang/$(ls -tr /dlang | tail -n1)/activate; \
  echo $PATH && \
  $DMD -of=/tmp/har/src/har -g -debug /tmp/har/src/harmain.d /tmp/har/src/archive/har.d

# Clean up to keep the image size minimal
RUN rm -f /dlang/d-keyring.gpg \
 && rm -rf /dlang/dub* \
 && ln -s /dlang/$(ls -tr /dlang | tail -n1) /dlang/${DLANG_VERSION} \
 && mkdir -p /dlang/har && cp /tmp/har/src/har /dlang/har/har && rm -rf /tmp/har \
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

RUN cd /sandbox && for package_name in \
		asdf \
		mir-algorithm \
		mir-blas \
		mir-core \
		mir-cpuid \
		mir-integral \
		mir-lapack \
		mir-optim \
		mir-random \
		mir \
		stdx-allocator \
		lubeck \
		numir \
		vibe-d \
		vibe-core \
		dyaml \
		libdparse \
		emsi_containers \
		collections \
		automem \
		pegged \
		sumtype \
		optional \
		; do \
      	package="$(echo $package_name | cut -d: -f1)"; \
      	version="$(echo $package_name | grep : |cut -d: -f2)"; \
      	version="${version:-*}"; \
		printf "/++dub.sdl: name\"foo\"\ndependency\"${package}\" version=\"${version}\"+/\n void main() {}" > foo.d; \
		dub fetch "${package}" --version="${version}"; \
		dub build --single --compiler=${DLANG_EXEC} foo.d; \
		version=$(dub describe ${package} | jq '.packages[0].version') ; \
		echo "${package}:${version}" >> packages; \
		rm -f foo*; \
		rm -rf .dub/build; \
		dub fetch dpp && dub build --compiler=${DLANG_EXEC} dpp; \
	done

USER root
COPY entrypoint.sh /entrypoint.sh
RUN mv /sandbox/packages /installed_packages; \
	chmod 555 /installed_packages
USER d-user

ENTRYPOINT [ "/entrypoint.sh" ]
