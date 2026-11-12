# Docker option: build the userspace OpenVPN client in a container and run the
# tunnel from it. No kernel tunnel device is needed inside the container
# either; the client hands packets to a userspace stack over a pipe.
#
#   docker build -t userspace-vpn .
#   docker run -d --name vpn -p 127.0.0.1:2323:2323 -p 127.0.0.1:1081:1081 \
#     -v /path/to/profile.ovpn:/config/profile.ovpn:ro \
#     userspace-vpn /config/profile.ovpn <target-ip> <target-port> 2323
#
# The forwards listen inside the container, so publish the local port and the
# SOCKS port (1081) as shown. Stop with: docker rm -f vpn
FROM debian:bookworm-slim
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    git build-essential autoconf automake libtool pkg-config \
    libssl-dev liblzo2-dev liblz4-dev libpam0g-dev libevent-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/userspace-vpn
COPY . .
RUN ./build.sh
ENTRYPOINT ["./run.sh"]
