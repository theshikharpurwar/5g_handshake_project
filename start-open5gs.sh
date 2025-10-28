#!/bin/bash

# =================================================================
# Open5GS Startup Script with User Plane Configuration
# =================================================================
# This script initializes all Open5GS network functions and sets up
# the critical User Plane components for UE data traffic.

# Start MongoDB
echo "Starting MongoDB..."
mongod --fork --logpath /var/log/mongodb.log --dbpath /var/lib/mongodb

# Wait for MongoDB to be ready
sleep 5

# =================================================================
# USER PLANE SETUP - THE CRITICAL SECTION
# =================================================================
# This MUST happen before starting the UPF daemon
# These commands enable GTP-U tunnel traffic to flow correctly
# in the containerized environment

echo "Setting up User Plane (ogstun interface)..."

# 1. Create the TUN device for UE traffic
ip tuntap add name ogstun mode tun

# 2. Assign the gateway IP address and bring the interface up
ip addr add 10.45.0.1/16 dev ogstun
ip addr add 2001:db8:cafe::1/48 dev ogstun
ip link set ogstun up

# 3. THE CRITICAL NAT RULE - This enables UE internet access
# This performs Source NAT (masquerading) for all traffic from the UE subnet
# that exits the container. Without this, return packets cannot reach UEs.
iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE

# 4. Enable IP forwarding in the kernel (essential for routing)
echo 1 > /proc/sys/net/ipv4/ip_forward

# 5. Allow forwarding between ogstun and other interfaces
iptables -A FORWARD -i ogstun -j ACCEPT
iptables -A FORWARD -o ogstun -j ACCEPT

echo "✅ User Plane configured successfully"
echo "   - ogstun interface created: 10.45.0.1/16"
echo "   - NAT masquerading enabled for UE subnet"
echo "   - IP forwarding enabled"

# =================================================================
# START OPEN5GS NETWORK FUNCTIONS
# =================================================================

echo "Starting Open5GS Control Plane functions..."

# Network Repository Function (NRF) - Service discovery
open5gs-nrfd -D &
sleep 1

# Service Communication Proxy (SCP) - Optional but recommended
open5gs-scpd -D &
sleep 1

# Authentication Server Function (AUSF) - 5G authentication
open5gs-ausfd -D &
sleep 1

# Unified Data Management (UDM) - Subscriber data management
open5gs-udmd -D &
sleep 1

# Unified Data Repository (UDR) - Subscriber database
open5gs-udrd -D &
sleep 1

# Policy Control Function (PCF) - QoS policies
open5gs-pcfd -D &
sleep 1

# Binding Support Function (BSF) - Session binding
open5gs-bsfd -D &
sleep 1

# Network Slice Selection Function (NSSF) - Network slicing
open5gs-nssfd -D &
sleep 1

# Session Management Function (SMF) - PDU session management
open5gs-smfd -D &
sleep 1

# Access and Mobility Management Function (AMF) - UE registration
open5gs-amfd -D &
sleep 1

echo "Starting Open5GS User Plane function..."

# User Plane Function (UPF) - Data packet routing
# MUST start AFTER ogstun is configured
open5gs-upfd -D &
sleep 2

echo "✅ All Open5GS services started successfully"

# =================================================================
# KEEP CONTAINER RUNNING
# =================================================================

# Create log directory if it doesn't exist
mkdir -p /var/log/open5gs

echo "Open5GS is running. Tailing logs..."
echo "================================================================"

# Keep the container alive and show logs
tail -f /var/log/open5gs/*.log 2>/dev/null || tail -f /dev/null
touch /var/log/open5gs/amf.log /var/log/open5gs/smf.log /var/log/open5gs/upf.log
tail -f /var/log/open5gs/*.log