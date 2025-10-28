#!/bin/bash

# =================================================================
# Traffic Generation for Scenario B (1 gNB + 2 UEs)
# =================================================================
#
# Generates traffic from UE3 and UE4 using GeForce Now dataset
# Runs traffic in parallel to test resource contention on single gNB
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
echo -e "${BLUE}  Traffic Generation: Scenario B${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# Check if Scenario B is running
echo -e "${YELLOW}Checking if Scenario B is active...${NC}"

if ! docker compose ps | grep -q "ueransim-ue3.*Up"; then
    echo -e "${RED}❌ Error: UE3 is not running${NC}"
    echo -e "${YELLOW}Run ./scenario_B.sh first${NC}"
    exit 1
fi

if ! docker compose ps | grep -q "ueransim-ue4.*Up"; then
    echo -e "${RED}❌ Error: UE4 is not running${NC}"
    echo -e "${YELLOW}Run ./scenario_B.sh first${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Scenario B is active${NC}"
echo ""

# Get UE IPs
UE3_IP=$(docker compose exec -T ueransim-ue3 ip addr show uesimtun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
UE4_IP=$(docker compose exec -T ueransim-ue4 ip addr show uesimtun0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)

if [ -z "$UE3_IP" ] || [ -z "$UE4_IP" ]; then
    echo -e "${RED}❌ Error: UEs don't have IP addresses${NC}"
    echo -e "${YELLOW}Check registration with: docker compose logs ueransim-ue3${NC}"
    exit 1
fi

echo -e "${CYAN}Configuration:${NC}"
echo "  • Duration: ${DURATION} seconds"
echo "  • Profile:  ${PROFILE}"
echo "  • UE3 IP:   ${UE3_IP}"
echo "  • UE4 IP:   ${UE4_IP}"
echo ""

# Start timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="./traffic_logs"
mkdir -p "$LOG_DIR"

echo -e "${YELLOW}Starting traffic generation...${NC}"
echo ""

# Generate traffic on UE3 (in background)
echo -e "${CYAN}[UE3]${NC} Starting ${PROFILE} traffic..."
docker compose exec -T ueransim-ue3 python3 /traffic_generator.py \
    --profile "$PROFILE" \
    --duration $DURATION \
    --target 8.8.8.8 \
    > "$LOG_DIR/ue3_traffic_${TIMESTAMP}.log" 2>&1 &

UE3_PID=$!

# Generate traffic on UE4 (in background)
echo -e "${CYAN}[UE4]${NC} Starting ${PROFILE} traffic..."
docker compose exec -T ueransim-ue4 python3 /traffic_generator.py \
    --profile "$PROFILE" \
    --duration $DURATION \
    --target 8.8.8.8 \
    > "$LOG_DIR/ue4_traffic_${TIMESTAMP}.log" 2>&1 &

UE4_PID=$!

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
wait $UE3_PID 2>/dev/null
UE3_EXIT=$?

wait $UE4_PID 2>/dev/null
UE4_EXIT=$?
set -e

# Give a moment for logs to be flushed
sleep 1

# Check if traffic generation was successful by examining logs
UE3_SUCCESS=0
UE4_SUCCESS=0

if grep -qi "packets sent" "$LOG_DIR/ue3_traffic_${TIMESTAMP}.log" 2>/dev/null; then
    UE3_SUCCESS=1
fi

if grep -qi "packets sent" "$LOG_DIR/ue4_traffic_${TIMESTAMP}.log" 2>/dev/null; then
    UE4_SUCCESS=1
fi

echo ""
echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}  Traffic Generation Complete${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# Show results
if [ $UE3_SUCCESS -eq 1 ]; then
    echo -e "${GREEN}✅ UE3 traffic completed successfully${NC}"
    set +e
    UE3_STATS=$(tail -5 "$LOG_DIR/ue3_traffic_${TIMESTAMP}.log" | grep -E "packets sent|packet loss|duration")
    set -e
    if [ -n "$UE3_STATS" ]; then
        echo "$UE3_STATS" | sed 's/^/   /'
    fi
else
    echo -e "${RED}❌ UE3 traffic failed${NC}"
    echo "   Check log: $LOG_DIR/ue3_traffic_${TIMESTAMP}.log"
fi

echo ""

if [ $UE4_SUCCESS -eq 1 ]; then
    echo -e "${GREEN}✅ UE4 traffic completed successfully${NC}"
    set +e
    UE4_STATS=$(tail -5 "$LOG_DIR/ue4_traffic_${TIMESTAMP}.log" | grep -E "packets sent|packet loss|duration")
    set -e
    if [ -n "$UE4_STATS" ]; then
        echo "$UE4_STATS" | sed 's/^/   /'
    fi
else
    echo -e "${RED}❌ UE4 traffic failed${NC}"
    echo "   Check log: $LOG_DIR/ue4_traffic_${TIMESTAMP}.log"
fi

echo ""
echo -e "${CYAN}Logs saved to:${NC}"
echo "  • $LOG_DIR/ue3_traffic_${TIMESTAMP}.log"
echo "  • $LOG_DIR/ue4_traffic_${TIMESTAMP}.log"
echo ""

if [ $UE3_SUCCESS -eq 1 ] && [ $UE4_SUCCESS -eq 1 ]; then
    echo -e "${GREEN}🎉 Traffic generation successful on both UEs!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some traffic generation failed. Check logs above.${NC}"
    exit 1
fi
