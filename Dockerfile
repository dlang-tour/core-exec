FROM ubuntu:17.10

MAINTAINER "Sebastian Wilzbach <seb@wilzba.ch>"

RUN apt-get update && apt-get install --no-install-recommends -y \
	ca-certificates \
	curl \
	gcc \
	jq \
	libatlas-base-dev \
	libc-dev \
	libevent-dev \
	libssl-dev xz-utils \
	&& update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.gold" 20 \
	&& update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.bfd" 10

ENV DLANG_VERSION "dmd-nightly"
ENV DLANG_EXEC "dmd"

RUN curl -fsS -o /tmp/install.sh https://dlang.org/install.sh \
 && bash /tmp/install.sh -p /dlang install ${DLANG_VERSION} \
 && rm -f /dlang/d-keyring.gpg \
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
  PATH=/dlang/${DLANG_VERSION}/linux/bin64:/dlang/dub:/dlang/${DLANG_VERSION}/bin:${PATH} \
  LD_LIBRARY_PATH=/dlang/${DLANG_VERSION}/linux/lib64:/dlang/${DLANG_VERSION}/lib \
  LIBRARY_PATH=/dlang/${DLANG_VERSION}/linux/lib64:/dlang/${DLANG_VERSION}/lib

RUN useradd -d /sandbox d-user

RUN mkdir /sandbox && chown d-user:nogroup /sandbox
USER d-user

RUN cd /sandbox && for package_name in \
		mir-algorithm \
		mir-random \
		mir \
		lubeck \
		vibe-d:0.8.3-alpha.1 \
		dyaml \
		libdparse \
		emsi_containers \
		collections \
		; do \
      	package="$(echo $package_name | cut -d: -f1)"; \
      	version="$(echo $package_name | grep : |cut -d: -f2)"; \
      	version="${version:-*}"; \
		printf "/++dub.sdl: name\"foo\"\ndependency\"${package}\" version=\"${version}\"+/\n void main() {}" > foo.d; \
		dub fetch "${package}" --version="${version}"; \
		dub build --single -v --compiler=${DLANG_EXEC} foo.d; \
		version=$(dub describe ${package} | jq '.packages[0].version') ; \
		echo "${package}:${version}" >> packages; \
		rm -f foo*; \
		rm -rf .dub/build; \
	done

USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh; \
	mv /sandbox/packages /installed_packages; \
	chmod 555 /installed_packages
USER d-user

ENTRYPOINT [ "/entrypoint.sh" ]
