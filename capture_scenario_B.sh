#!/bin/bash

# =================================================================
# Packet Capture for Scenario B (1 gNB + 2 UEs)
# =================================================================
#
# Captures GTP-U tunnel traffic for Wireshark analysis
# Saves pcap file with timestamp for offline analysis
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
CAPTURE_DIR="./packet_captures"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAPTURE_FILE="$CAPTURE_DIR/scenario_B_${TIMESTAMP}.pcap"

echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}  Packet Capture: Scenario B${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# Check if running as root (tcpdump requires it)
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Error: This script must be run as root${NC}"
    echo -e "${YELLOW}Run with: sudo ./capture_scenario_B.sh${NC}"
    exit 1
fi

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

# Create capture directory
mkdir -p "$CAPTURE_DIR"

echo -e "${CYAN}Configuration:${NC}"
echo "  • Duration:     ${DURATION} seconds"
echo "  • Capture file: ${CAPTURE_FILE}"
echo "  • Filter:       GTP-U (UDP port 2152)"
echo ""

echo -e "${YELLOW}Starting packet capture...${NC}"
echo ""
echo -e "${CYAN}Capturing:${NC}"
echo "  • GTP-U tunnel traffic between gNB3 and UPF"
echo "  • Encapsulated UE3 and UE4 packets"
echo "  • TEID (Tunnel Endpoint ID) information"
echo ""

# Start tcpdump
echo -e "${GREEN}Recording for ${DURATION} seconds...${NC}"
timeout $DURATION tcpdump -i any -n 'udp port 2152' -w "$CAPTURE_FILE" 2>&1 | \
    grep -E "listening|captured" || true

echo ""
echo -e "${BLUE}=================================================================${NC}"
echo -e "${BLUE}  Capture Complete${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""

# Check if file was created and has data
if [ -f "$CAPTURE_FILE" ]; then
    FILE_SIZE=$(du -h "$CAPTURE_FILE" | cut -f1)
    PACKET_COUNT=$(tcpdump -r "$CAPTURE_FILE" 2>/dev/null | wc -l)
    
    echo -e "${GREEN}✅ Capture successful${NC}"
    echo ""
    echo -e "${CYAN}Capture Statistics:${NC}"
    echo "  • File size:    $FILE_SIZE"
    echo "  • Packets:      $PACKET_COUNT"
    echo "  • Location:     $CAPTURE_FILE"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Copy to your machine:  ${YELLOW}scp $CAPTURE_FILE your-pc:~/${NC}"
    echo "  2. Open in Wireshark"
    echo "  3. Filter by:  ${YELLOW}gtp${NC}  (to see only GTP-U packets)"
    echo "  4. Analyze:"
    echo "     • GTP headers and TEIDs"
    echo "     • Inner IP packets from UEs"
    echo "     • Packet sizes matching GeForce Now dataset"
    echo "     • Resource contention patterns (2 UEs on same gNB)"
    echo ""
else
    echo -e "${RED}❌ Capture failed - no file created${NC}"
    exit 1
fi
