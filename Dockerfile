# Stage 1: build the missing res_pjsip_sdp_rtp module from source
FROM debian:trixie AS asterisk-builder

ENV ASTERISK_VERSION=22.5.2

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		bison \
		build-essential \
		ca-certificates \
		curl \
		flex \
		git \
		libcurl4-openssl-dev \
		libedit-dev \
		libjansson-dev \
		libncurses5-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-dev \
		python3 \
		pkg-config \
		tar \
		uuid-dev \
		wget \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src
RUN curl -fsSL "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz" -o asterisk.tar.gz \
	&& tar -xzf asterisk.tar.gz \
	&& rm asterisk.tar.gz

WORKDIR /usr/src/asterisk-${ASTERISK_VERSION}
RUN ./configure --with-pjproject-bundled \
	&& make menuselect.makeopts \
	&& make -j"$(nproc)"

RUN install -D "res/res_pjsip_sdp_rtp.so" /artifacts/res_pjsip_sdp_rtp.so

# Stage 2: runtime image with Asterisk plus compiled module
FROM andrius/asterisk:22.5.2_debian-trixie

COPY --from=asterisk-builder /artifacts/res_pjsip_sdp_rtp.so /usr/lib/asterisk/modules/res_pjsip_sdp_rtp.so

USER root

COPY config/asterisk/ /opt/asterisk/templates/
COPY scripts/bootstrap-asterisk.sh /usr/local/bin/bootstrap-asterisk.sh

RUN chown asterisk:asterisk /usr/lib/asterisk/modules/res_pjsip_sdp_rtp.so \
	&& chmod +x /usr/local/bin/bootstrap-asterisk.sh \
	&& chown -R asterisk:asterisk /opt/asterisk/templates

ENTRYPOINT ["/usr/local/bin/bootstrap-asterisk.sh"]
CMD ["/usr/sbin/asterisk","-vvvdddf","-T","-W","-U","asterisk","-p"]
