#!/bin/bash

# =================================================================
# Traffic Generation for Scenario A (2 gNBs + 2 UEs)
# =================================================================
#
# Generates traffic from UE1 and UE2 using GeForce Now dataset
# Runs traffic in parallel to simulate real-world load
#
# =================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default parameters
DURATION=${1:-60}
PROFILE=${2:-"voip"}

echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}  Traffic Generation: Scenario A${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# Check if Scenario A is running
echo -e "${YELLOW}Checking if Scenario A is active...${NC}"

if ! docker compose ps | grep -q "ueransim-ue1.*Up"; then
    echo -e "${RED}❌ Error: UE1 is not running${NC}"
    echo -e "${YELLOW}Run ./scenario_A.sh first${NC}"
    exit 1
fi

if ! docker compose ps | grep -q "ueransim-ue2.*Up"; then
    echo -e "${RED}❌ Error: UE2 is not running${NC}"
    echo -e "${YELLOW}Run ./scenario_A.sh first${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Scenario A is active${NC}"
echo ""

# Get UE IPs
UE1_IP=$(docker compose exec -T ueransim-ue1 ip addr show uesimtun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
UE2_IP=$(docker compose exec -T ueransim-ue2 ip addr show uesimtun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -z "$UE1_IP" ] || [ -z "$UE2_IP" ]; then
    echo -e "${RED}❌ Error: UEs don't have IP addresses${NC}"
    echo -e "${YELLOW}Check registration with: docker compose logs ueransim-ue1${NC}"
    exit 1
fi

echo -e "${CYAN}Configuration:${NC}"
echo "  • Duration: ${DURATION} seconds"
echo "  • Profile:  ${PROFILE}"
echo "  • UE1 IP:   ${UE1_IP}"
echo "  • UE2 IP:   ${UE2_IP}"
echo ""

# Start timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="./traffic_logs"
mkdir -p "$LOG_DIR"

echo -e "${YELLOW}Starting traffic generation...${NC}"
echo ""

# Generate traffic on UE1 (in background)
echo -e "${CYAN}[UE1]${NC} Starting ${PROFILE} traffic..."
docker compose exec -T ueransim-ue1 python3 /traffic_generator.py \
    --profile "$PROFILE" \
    --duration $DURATION \
    --target 8.8.8.8 \
    > "$LOG_DIR/ue1_traffic_${TIMESTAMP}.log" 2>&1 &

UE1_PID=$!

# Generate traffic on UE2 (in background)
echo -e "${CYAN}[UE2]${NC} Starting ${PROFILE} traffic..."
docker compose exec -T ueransim-ue2 python3 /traffic_generator.py \
    --profile "$PROFILE" \
    --duration $DURATION \
    --target 8.8.8.8 \
    > "$LOG_DIR/ue2_traffic_${TIMESTAMP}.log" 2>&1 &

UE2_PID=$!

echo ""
echo -e "${GREEN}✅ Traffic generation started on both UEs${NC}"
echo ""
echo -e "${YELLOW}Running for ${DURATION} seconds...${NC}"

# Progress bar
for i in $(seq 1 $DURATION); do
    if [ $((i % 10)) -eq 0 ]; then
        echo -n "."
    fi
    sleep 1
done
echo ""

# Wait for completion (disable error exit temporarily)
set +e
wait $UE1_PID 2>/dev/null
UE1_EXIT=$?

wait $UE2_PID 2>/dev/null
UE2_EXIT=$?
set -e

# Give a moment for logs to be flushed
sleep 1

# Check if traffic generation was successful by examining logs
UE1_SUCCESS=0
UE2_SUCCESS=0

if grep -qi "packets sent" "$LOG_DIR/ue1_traffic_${TIMESTAMP}.log" 2>/dev/null; then
    UE1_SUCCESS=1
fi

if grep -qi "packets sent" "$LOG_DIR/ue2_traffic_${TIMESTAMP}.log" 2>/dev/null; then
    UE2_SUCCESS=1
fi

echo ""
echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}  Traffic Generation Complete${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# Show results
if [ $UE1_SUCCESS -eq 1 ]; then
    echo -e "${GREEN}✅ UE1 traffic completed successfully${NC}"
    set +e
    UE1_STATS=$(tail -5 "$LOG_DIR/ue1_traffic_${TIMESTAMP}.log" | grep -E "packets sent|packet loss|duration")
    set -e
    if [ -n "$UE1_STATS" ]; then
        echo "$UE1_STATS" | sed 's/^/   /'
    fi
else
    echo -e "${RED}❌ UE1 traffic failed${NC}"
    echo "   Check log: $LOG_DIR/ue1_traffic_${TIMESTAMP}.log"
fi

echo ""

if [ $UE2_SUCCESS -eq 1 ]; then
    echo -e "${GREEN}✅ UE2 traffic completed successfully${NC}"
    set +e
    UE2_STATS=$(tail -5 "$LOG_DIR/ue2_traffic_${TIMESTAMP}.log" | grep -E "packets sent|packet loss|duration")
    set -e
    if [ -n "$UE2_STATS" ]; then
        echo "$UE2_STATS" | sed 's/^/   /'
    fi
else
    echo -e "${RED}❌ UE2 traffic failed${NC}"
    echo "   Check log: $LOG_DIR/ue2_traffic_${TIMESTAMP}.log"
fi

echo ""
echo -e "${CYAN}Logs saved to:${NC}"
echo "  • $LOG_DIR/ue1_traffic_${TIMESTAMP}.log"
echo "  • $LOG_DIR/ue2_traffic_${TIMESTAMP}.log"
echo ""

if [ $UE1_SUCCESS -eq 1 ] && [ $UE2_SUCCESS -eq 1 ]; then
    echo -e "${GREEN}🎉 Traffic generation successful on both UEs!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some traffic generation failed. Check logs above.${NC}"
    exit 1
fi
