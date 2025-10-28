#!/bin/bash

# =================================================================
# Scenario B: 1 gNB with 2 UEs (Same Base Station)
# =================================================================
#
# Architecture:
#   gNB3 ← UE3 (IMSI: 999700000000003)
#        ← UE4 (IMSI: 999700000000004)
#
# Use Cases:
#   - Test resource contention on single cell
#   - Test intra-gNB scheduling
#   - Simulate congested cell scenario
#
# =================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}  SCENARIO B: 1 gNB + 2 UEs (Intra-gNB Communication)${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# =================================================================
# STEP 1: COMPLETE CLEANUP
# =================================================================
echo -e "${CYAN}[Step 1/7]${NC} ${YELLOW}Performing complete cleanup...${NC}"
echo "   - Stopping ALL containers"
echo "   - Removing volumes and networks"
echo "   - Ensuring clean state"

docker compose down -v --remove-orphans 2>/dev/null || true
sleep 2

echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

# =================================================================
# STEP 2: START CORE INFRASTRUCTURE
# =================================================================
echo -e "${CYAN}[Step 2/7]${NC} ${YELLOW}Starting core infrastructure...${NC}"
echo "   - Open5GS 5G Core (all network functions)"
echo "   - Custom authentication proxy"
echo "   - WebUI for subscriber management"

docker compose up --build -d open5gs-core proxy webui 2>&1 | grep -v "version"

echo -e "${GREEN}✅ Core infrastructure started${NC}"
echo ""

# =================================================================
# STEP 3: WAIT FOR CORE INITIALIZATION
# =================================================================
echo -e "${CYAN}[Step 3/7]${NC} ${YELLOW}Waiting for core to initialize (35 seconds)...${NC}"
echo "   - MongoDB database startup"
echo "   - Open5GS network functions (AMF, SMF, UPF, etc.)"
echo "   - User Plane setup (ogstun interface, NAT rules)"

for i in {1..35}; do
    echo -n "."
    sleep 1
done
echo ""

echo -e "${GREEN}✅ Core initialized${NC}"
echo ""

# =================================================================
# STEP 4: PROVISION SUBSCRIBERS (UE3 and UE4)
# =================================================================
echo -e "${CYAN}[Step 4/7]${NC} ${YELLOW}Provisioning UE3 and UE4 subscribers...${NC}"

# Provision UE3
docker compose exec -T open5gs-core mongosh --quiet open5gs --eval '
db.subscribers.replaceOne(
  { imsi: "999700000000003" },
  {
    imsi: "999700000000003",
    msisdn: ["0000000003"],
    security: {
      k: "465B5CE8B199B49FAA5F0A2EE238A6BC",
      opc: "E8ED289DEBA952E4283B54E88E6183CA",
      amf: "8000",
      op_type: 1,
      sqn: 0
    },
    ambr: {
      uplink: { value: 1, unit: 3 },
      downlink: { value: 1, unit: 3 }
    },
    slice: [{
      sst: 1,
      default_indicator: true,
      session: [{
        name: "internet",
        type: 1,
        ambr: {
          uplink: { value: 1, unit: 3 },
          downlink: { value: 1, unit: 3 }
        },
        qos: {
          index: 9,
          arp: {
            priority_level: 8,
            pre_emption_capability: 1,
            pre_emption_vulnerability: 1
          }
        }
      }]
    }],
    access_restriction_data: 0,
    subscriber_status: 0,
    network_access_mode: 2,
    subscribed_rau_tau_timer: 12
  },
  { upsert: true }
)' > /dev/null 2>&1

echo -e "   ${GREEN}✓${NC} UE3 (IMSI: 999700000000003) provisioned"

# Provision UE4
docker compose exec -T open5gs-core mongosh --quiet open5gs --eval '
db.subscribers.replaceOne(
  { imsi: "999700000000004" },
  {
    imsi: "999700000000004",
    msisdn: ["0000000004"],
    security: {
      k: "465B5CE8B199B49FAA5F0A2EE238A6BC",
      opc: "E8ED289DEBA952E4283B54E88E6183CA",
      amf: "8000",
      op_type: 1,
      sqn: 0
    },
    ambr: {
      uplink: { value: 1, unit: 3 },
      downlink: { value: 1, unit: 3 }
    },
    slice: [{
      sst: 1,
      default_indicator: true,
      session: [{
        name: "internet",
        type: 1,
        ambr: {
          uplink: { value: 1, unit: 3 },
          downlink: { value: 1, unit: 3 }
        },
        qos: {
          index: 9,
          arp: {
            priority_level: 8,
            pre_emption_capability: 1,
            pre_emption_vulnerability: 1
          }
        }
      }]
    }],
    access_restriction_data: 0,
    subscriber_status: 0,
    network_access_mode: 2,
    subscribed_rau_tau_timer: 12
  },
  { upsert: true }
)' > /dev/null 2>&1

echo -e "   ${GREEN}✓${NC} UE4 (IMSI: 999700000000004) provisioned"
echo -e "${GREEN}✅ Subscribers provisioned${NC}"
echo ""

# =================================================================
# STEP 5: PERFORM CUSTOM SECURITY HANDSHAKE
# =================================================================
echo -e "${CYAN}[Step 5/7]${NC} ${YELLOW}Performing custom security handshake...${NC}"

sleep 2
if echo "HELLO123" | nc -w 5 127.0.0.1 9999 2>/dev/null | grep -q "ACK"; then
    echo -e "${GREEN}✅ Handshake successful${NC}"
else
    echo -e "${YELLOW}⚠️  Handshake response not detected (may still work)${NC}"
fi
sleep 3
echo ""

# =================================================================
# STEP 6: START GNB AND UES
# =================================================================
echo -e "${CYAN}[Step 6/7]${NC} ${YELLOW}Starting gNB and UEs...${NC}"

# Start gNB3
echo "   Starting gNB3..."
docker compose up -d ueransim-gnb3 2>&1 | grep -v "version"
sleep 5

# Start UEs
echo "   Starting UE3..."
docker compose up -d ueransim-ue3 2>&1 | grep -v "version"
sleep 5

echo "   Starting UE4..."
docker compose up -d ueransim-ue4 2>&1 | grep -v "version"
sleep 10

echo -e "${GREEN}✅ All services started${NC}"
echo ""

# =================================================================
# STEP 7: VERIFICATION
# =================================================================
echo -e "${CYAN}[Step 7/7]${NC} ${YELLOW}Verifying connectivity...${NC}"
echo ""

PASS=0
FAIL=0

# Get UE IPs
UE3_IP=$(docker compose exec -T ueransim-ue3 ip addr show uesimtun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
UE4_IP=$(docker compose exec -T ueransim-ue4 ip addr show uesimtun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -z "$UE3_IP" ]; then
    echo -e "${RED}❌ UE3 has no IP address (registration failed)${NC}"
    ((FAIL++))
else
    echo -e "${GREEN}✓${NC} UE3 IP: $UE3_IP"
    ((PASS++))
fi

if [ -z "$UE4_IP" ]; then
    echo -e "${RED}❌ UE4 has no IP address (registration failed)${NC}"
    ((FAIL++))
else
    echo -e "${GREEN}✓${NC} UE4 IP: $UE4_IP"
    ((PASS++))
fi

echo ""

# Test internet connectivity
if [ -n "$UE3_IP" ]; then
    echo -n "Testing UE3 → Internet (8.8.8.8): "
    if docker compose exec -T ueransim-ue3 ping -I uesimtun0 -c 3 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Success${NC}"
        ((PASS++))
    else
        echo -e "${RED}❌ Failed${NC}"
        ((FAIL++))
    fi
fi

if [ -n "$UE4_IP" ]; then
    echo -n "Testing UE4 → Internet (8.8.8.8): "
    if docker compose exec -T ueransim-ue4 ping -I uesimtun0 -c 3 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Success${NC}"
        ((PASS++))
    else
        echo -e "${RED}❌ Failed${NC}"
        ((FAIL++))
    fi
fi

# Test inter-UE communication (same gNB)
if [ -n "$UE3_IP" ] && [ -n "$UE4_IP" ]; then
    echo -n "Testing UE3 ↔ UE4 (intra-gNB): "
    if docker compose exec -T ueransim-ue3 ping -I uesimtun0 -c 3 -W 2 $UE4_IP >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Success${NC}"
        ((PASS++))
    else
        echo -e "${RED}❌ Failed${NC}"
        ((FAIL++))
    fi
fi

echo ""

# =================================================================
# FINAL STATUS
# =================================================================
echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}  Scenario B Status${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS! All tests passed ($PASS/$PASS)${NC}"
    echo ""
    echo -e "${CYAN}Running Services:${NC}"
    echo "  • Open5GS Core (AMF, SMF, UPF, etc.)"
    echo "  • gNB3 with 2 UEs:"
    echo "    - UE3 (IP: $UE3_IP)"
    echo "    - UE4 (IP: $UE4_IP)"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  • Generate traffic:  ${YELLOW}./generate_traffic_B.sh${NC}"
    echo "  • Capture packets:   ${YELLOW}./capture_scenario_B.sh${NC}"
    echo "  • View logs:         ${YELLOW}docker compose logs -f ueransim-ue3${NC}"
    echo "  • Stop scenario:     ${YELLOW}docker compose down${NC}"
    echo ""
else
    echo -e "${RED}⚠️  Some tests failed ($PASS passed, $FAIL failed)${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  • Check UE logs:     docker compose logs ueransim-ue3"
    echo "  • Check Core logs:   docker compose logs open5gs-core"
    echo "  • Verify ogstun:     docker compose exec open5gs-core ip addr show ogstun"
    echo "  • Check NAT rules:   docker compose exec open5gs-core iptables -t nat -L"
    echo ""
fi

echo -e "${BLUE}=================================================================${NC}"
