FROM ubuntu:17.04

MAINTAINER "Sebastian Wilzbach <seb@wilzba.ch>"

RUN apt-get update && apt-get install --no-install-recommends -y libc-dev gcc curl ca-certificates libevent-dev libssl-dev xz-utils \
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

RUN cd /sandbox && for package in \
		mir:1.1.1 \
		mir-algorithm:0.6.7 \
		vibe-d:0.8.2 \
		dyaml:0.6.3 \
		libdparse:0.7.0 \
		; do \
		name="$(echo $package | cut -d: -f1)"; \
		version="$(echo $package | cut -d: -f2)"; \
		printf "/++dub.sdl: name\"foo\"\ndependency\"${name}\" version=\"${version}\"+/\n void main() {}" > foo.d; \
		dub build --single -v --compiler=${DLANG_EXEC} foo.d; \
		rm -f foo*; \
		rm -rf .dub/build; \
	done

USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER d-user

ENTRYPOINT [ "/entrypoint.sh" ]
