# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y software-properties-common gnupg wget curl

# Add MongoDB GPG key and repository
RUN wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg && \
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# Add Open5GS PPA
RUN add-apt-repository ppa:open5gs/latest && \
    apt-get update

# Install MongoDB and Open5GS
RUN apt-get install -y mongodb-org

# Install Open5GS
RUN apt-get install -y open5gs

# Copy a simple startup script
COPY start-open5gs.sh /start-open5gs.sh
RUN chmod +x /start-open5gs.sh

# Expose the necessary ports (NGAP and GTP)
EXPOSE 38412/sctp
EXPOSE 2152/udp

# Set the entrypoint to our startup script
CMD ["/start-open5gs.sh"]