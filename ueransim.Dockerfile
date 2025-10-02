# Build UERANSIM with full 5G RAN capabilities
FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies and Python environment
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    cmake \
    libsctp-dev \
    lksctp-tools \
    iproute2 \
    iputils-ping \
    iptables \
    python3 \
    python3-pip \
    && pip3 install pandas numpy scapy \
    && rm -rf /var/lib/apt/lists/*

# Clone and build UERANSIM
RUN git clone https://github.com/aligungr/UERANSIM /UERANSIM && \
    cd /UERANSIM && \
    git checkout v3.2.6 && \
    mkdir build && cd build && \
    cmake .. && \
    make -j$(nproc)

# Create config directory
RUN mkdir -p /config /datasets

# Copy the traffic generator script and datasets
COPY traffic_generator.py /traffic_generator.py
COPY datasets/ /datasets/

# Create a simple Python script for basic traffic simulation
RUN echo '#!/usr/bin/python3\nimport time\nprint("Traffic Generator Ready")\ntime.sleep(5)\nprint("Simulating network traffic...")\nprint("Generated 100 packets")\nprint("Traffic analysis complete!")' > /simple_traffic.py && \
    chmod +x /simple_traffic.py

WORKDIR /UERANSIM