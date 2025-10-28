#!/bin/bash
# Start UERANSIM UE and configure routing

CONFIG_FILE=$1

# Start UE in background
/UERANSIM/build/nr-ue -c "$CONFIG_FILE" &
UE_PID=$!

# Wait for uesimtun0 to be created (max 30 seconds)
for i in {1..30}; do
    if ip link show uesimtun0 >/dev/null 2>&1; then
        echo "uesimtun0 interface detected"
        sleep 2
        # Delete eth0 default route to force traffic through 5G tunnel
        ip route del default via $(ip route | grep default | grep eth0 | awk '{print $3}') 2>/dev/null || true
        # Add default route through uesimtun0
        ip route add default dev uesimtun0 metric 100 2>/dev/null || true
        echo "Route configured - all traffic via 5G tunnel"
        break
    fi
    sleep 1
done

# Wait for UE process
wait $UE_PID
