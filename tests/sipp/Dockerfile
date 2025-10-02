# syntax=docker/dockerfile:1

FROM debian:trixie AS builder

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git \
        build-essential \
        cmake \
        libsctp-dev \
        libpcap-dev \
        libncurses-dev \
        libssl-dev \
        libfl-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 https://github.com/SIPp/sipp.git

WORKDIR /src/sipp
RUN cmake -S . -B build \
        -DENABLE_SSL=ON \
        -DENABLE_SCTP=ON \
        -DENABLE_PCAP=ON \
        -DENABLE_FTP=OFF \
        -DENABLE_GSL=OFF \
    && cmake --build build --target sipp -- -j"$(nproc)"

RUN cmake --install build --prefix /opt/sipp

FROM debian:trixie-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libsctp1 \
        libpcap0.8 \
        libncursesw6 \
        libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/sipp /opt/sipp
COPY scenarios /opt/sipp/scenarios

ENV PATH="/opt/sipp/bin:${PATH}"

ENTRYPOINT ["sipp"]
