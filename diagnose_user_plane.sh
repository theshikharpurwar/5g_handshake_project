#!/bin/bash

# =================================================================
# User Plane Diagnostic Toolkit
# =================================================================
# This script provides comprehensive diagnostics for the User Plane
# to help troubleshoot GTP-U tunnel issues in containerized 5G labs.
#
# Usage: ./diagnose_user_plane.sh
# =================================================================

echo "
=================================================================
   5G USER PLANE DIAGNOSTIC TOOLKIT
=================================================================
"

# =================================================================
# 1. OGSTUN INTERFACE VERIFICATION
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. OGSTUN INTERFACE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Checking if ogstun TUN device exists in UPF container..."
echo ""

if docker exec open5gs-core ip addr show ogstun 2>/dev/null; then
    echo ""
    echo "✅ ogstun interface exists and is configured"
else
    echo ""
    echo "❌ ogstun interface NOT FOUND!"
    echo "   This is critical - UPF cannot route UE traffic without it"
fi

# =================================================================
# 2. IPTABLES NAT RULES VERIFICATION
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  2. IPTABLES NAT MASQUERADE RULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Checking NAT rules in UPF container..."
echo ""

docker exec open5gs-core iptables -t nat -L POSTROUTING -v -n 2>/dev/null

echo ""
if docker exec open5gs-core iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q "10.45.0.0/16"; then
    echo "✅ MASQUERADE rule for UE subnet (10.45.0.0/16) exists"
else
    echo "❌ MASQUERADE rule NOT FOUND!"
    echo "   UEs will not be able to access external networks"
fi

# =================================================================
# 3. IP FORWARDING STATUS
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  3. IP FORWARDING STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

IP_FORWARD=$(docker exec open5gs-core cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
echo "IP Forwarding: $IP_FORWARD"
echo ""

if [ "$IP_FORWARD" = "1" ]; then
    echo "✅ IP forwarding is enabled"
else
    echo "❌ IP forwarding is DISABLED!"
    echo "   The UPF cannot route packets between interfaces"
fi

# =================================================================
# 4. UE INTERFACE STATUS
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  4. UE TUNNEL INTERFACE STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for i in 1 2 3 4; do
    echo "--- UE$i (ueransim-ue$i) ---"
    if docker exec ueransim-ue$i ip addr show uesimtun0 2>/dev/null | grep -q "inet "; then
        UE_IP=$(docker exec ueransim-ue$i ip addr show uesimtun0 2>/dev/null | grep "inet " | awk '{print $2}')
        echo "  ✅ uesimtun0 exists with IP: $UE_IP"
    else
        echo "  ❌ uesimtun0 NOT FOUND (UE not registered or PDU session failed)"
    fi
    echo ""
done

# =================================================================
# 5. CONNECTIVITY TESTS
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  5. USER PLANE CONNECTIVITY TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Testing internet connectivity from each UE..."
echo ""

PASSED=0
FAILED=0

for i in 1 2 3 4; do
    echo -n "UE$i → 8.8.8.8: "
    if docker exec ueransim-ue$i ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo "✅ SUCCESS"
        PASSED=$((PASSED + 1))
    else
        echo "❌ FAILED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "DNS Resolution Test:"
echo -n "UE1 → google.com: "
if docker exec ueransim-ue1 ping -c 2 -W 3 google.com >/dev/null 2>&1; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILED"
fi

# =================================================================
# 6. GTP-U TUNNEL VERIFICATION
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  6. GTP-U TRAFFIC DETECTION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To capture GTP-U packets on the host, run this command:"
echo ""
echo "  sudo tcpdump -i any -n 'udp port 2152' -c 20 -v"
echo ""
echo "Then trigger traffic from a UE:"
echo ""
echo "  docker exec ueransim-ue1 ping -c 5 8.8.8.8"
echo ""
echo "You should see GTP-U packets with TEID (Tunnel Endpoint ID)."
echo ""

# =================================================================
# 7. CONTAINER NETWORK INSPECTION
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  7. CONTAINER NETWORK ADDRESSES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Open5GS Core (UPF) IP:"
docker exec open5gs-core ip addr show eth0 2>/dev/null | grep "inet " | awk '{print "  " $2}'

echo ""
echo "gNB1 IP:"
docker exec ueransim-gnb1 ip addr show eth0 2>/dev/null | grep "inet " | awk '{print "  " $2}'

echo ""
echo "gNB2 IP:"
docker exec ueransim-gnb2 ip addr show eth0 2>/dev/null | grep "inet " | awk '{print "  " $2}'

echo ""
echo "gNB3 IP:"
docker exec ueransim-gnb3 ip addr show eth0 2>/dev/null | grep "inet " | awk '{print "  " $2}'

# =================================================================
# 8. OPEN5GS UPF LOGS
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  8. RECENT UPF LOG ENTRIES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Last 20 lines from UPF log:"
echo ""

docker exec open5gs-core tail -n 20 /var/log/open5gs/upf.log 2>/dev/null || echo "⚠️  UPF log not available"

# =================================================================
# SUMMARY
# =================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DIAGNOSTIC SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Connectivity Test Results: $PASSED passed, $FAILED failed"
echo ""

if [ $PASSED -gt 0 ]; then
    echo "✅ User Plane is FUNCTIONAL for at least $PASSED UE(s)"
    echo ""
    echo "   Your 5G lab's data plane is working correctly!"
elif [ $FAILED -eq 4 ]; then
    echo "❌ User Plane is NOT WORKING for any UE"
    echo ""
    echo "TROUBLESHOOTING STEPS:"
    echo ""
    echo "1. Verify ogstun interface exists (see Section 1 above)"
    echo "2. Verify NAT masquerade rule exists (see Section 2 above)"
    echo "3. Check that IP forwarding is enabled (see Section 3 above)"
    echo "4. Restart Open5GS container:"
    echo "   docker compose restart open5gs-core"
    echo "5. Wait 30 seconds, then restart UEs:"
    echo "   docker compose restart ueransim-ue1 ueransim-ue2 ueransim-ue3 ueransim-ue4"
    echo "6. Run this diagnostic again:"
    echo "   ./diagnose_user_plane.sh"
fi

echo ""
echo "=================================================================

ADVANCED DIAGNOSTIC COMMANDS:

1. Check if ogstun interface is up:
   docker exec open5gs-core ip addr show ogstun

2. Verify the CRITICAL NAT rule:
   docker exec open5gs-core iptables -t nat -L POSTROUTING -v -n

3. Test ping from UE1:
   docker exec ueransim-ue1 ping -c 4 8.8.8.8

4. Test DNS resolution from UE1:
   docker exec ueransim-ue1 nslookup google.com 8.8.8.8

5. Capture GTP-U packets (run on host):
   sudo tcpdump -i any -n 'udp port 2152' -c 20 -v

6. View live UPF logs:
   docker exec open5gs-core tail -f /var/log/open5gs/upf.log

7. Check PFCP association (SMF <-> UPF):
   docker exec open5gs-core tail -f /var/log/open5gs/smf.log | grep -i pfcp

8. Monitor UE traffic in real-time:
   docker exec open5gs-core tcpdump -i ogstun -n

9. View routing table in UPF:
   docker exec open5gs-core ip route

10. Check all iptables rules:
    docker exec open5gs-core iptables -L -v -n
    docker exec open5gs-core iptables -t nat -L -v -n

================================================================="
