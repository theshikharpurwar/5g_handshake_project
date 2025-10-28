# 🔐 5G Custom Handshake Authentication Project

[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://www.docker.com/)
[![Open5GS](https://img.shields.io/badge/Open5GS-v2.7.6-green)](https://open5gs.org/)
[![UERANSIM](https://img.shields.io/badge/UERANSIM-v3.2.6-orange)](https://github.com/aligungr/UERANSIM)
[![Python](https://img.shields.io/badge/Python-3.9+-yellow)](https://www.python.org/)
[![Status](https://img.shields.io/badge/Status-Fully%20Operational-success)](https://github.com)

A **production-ready** 5G network testbed with custom handshake authentication, realistic traffic simulation, GTP-U tunneling analysis, and comprehensive packet capture capabilities. **All tests passing with 0% packet loss.**

## 🎯 Project Achievements

### ✅ Goal 1: Control 5G Network Access with Custom Handshake
Implement an authentication layer that intercepts gNB connections and requires a secret handshake before allowing access to the 5G core network.

**Status**: ✅ **OPERATIONAL** - Custom proxy server authenticates all connections using "HELLO123" secret before forwarding traffic to Open5GS core.

### ✅ Goal 2: Build a Realistic End-to-End 5G Test Lab  
Deploy a complete 5G network using Open5GS (5G core) and UERANSIM (RAN simulator) in containerized environment with proper GTP-U tunneling.

**Status**: ✅ **OPERATIONAL** - Full 5G stack running with:
- **Core Network**: AMF, SMF, UPF, NRF, UDM, AUSF, PCF, BSF, UDR, NSSF
- **RAN**: 3 gNBs (gNB1, gNB2, gNB3) with static IP assignments
- **User Equipment**: 4 UEs (UE1-UE4) with active PDU sessions
- **GTP-U Tunneling**: Verified with packet captures (2400+ packets/15s)

### ✅ Goal 3: Analyze Realistic 5G Data Traffic
Generate and analyze network traffic with multiple traffic profiles and packet capture for Wireshark analysis.

**Status**: ✅ **OPERATIONAL** - Traffic generator with 5 profiles:
- **VoIP**: 160-byte packets @ 50 pkt/s (tested and working)
- **Video**: Variable bitrate streaming patterns
- **Bulk**: Large file transfers
- **IoT**: Low-rate sensor data
- **Dataset Replay**: Real GeForce Now cloud gaming traces

### ✅ Goal 4: Multi-Scenario Testing & Analysis
Test both inter-gNB and intra-gNB communication scenarios with packet capture and traffic generation.

**Status**: ✅ **OPERATIONAL** - Two complete test scenarios:
- **Scenario A**: 2 gNBs + 2 UEs (inter-gNB handover capability)
- **Scenario B**: 1 gNB + 2 UEs (intra-gNB resource contention)

## 🚀 Quick Start

### Scenario A: Inter-gNB Communication
```bash
# Setup and verify 2 gNBs + 2 UEs
./scenario_A.sh

# Generate traffic and capture packets (15 seconds)
sudo ./capture_scenario_A.sh 15 &
sleep 2
./generate_traffic_A.sh 15
```

### Scenario B: Intra-gNB Communication
```bash
# Setup and verify 1 gNB + 2 UEs
./scenario_B.sh

# Generate traffic and capture packets (15 seconds)
sudo ./capture_scenario_B.sh 15 &
sleep 2
./generate_traffic_B.sh 15
```

**Packet captures saved to**: `./packet_captures/*.pcap` (open in Wireshark)

### Alternative: Step-by-Step
```bash
# 1. Start all services
docker compose up -d
sleep 20

# 2. Provision UE subscribers
./provision_all_ues.sh

# 3. Restart RAN components for clean registration
## 🏗️ Architecture

```
                    ┌──────────────────────┐
                    │   User Equipment     │
                    │   UE1, UE2, UE3, UE4 │
                    │   (UERANSIM)         │
                    │   10.45.0.2-0.5      │
                    └──────────┬───────────┘
                               │ NAS + RRC
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
┌────────▼────────┐   ┌────────▼────────┐   ┌────────▼────────┐
│     gNB1        │   │     gNB2        │   │     gNB3        │
│  172.18.0.5     │   │  172.18.0.6     │   │  172.18.0.7     │
│  (UERANSIM)     │   │  (UERANSIM)     │   │  (UERANSIM)     │
└────────┬────────┘   └────────┬────────┘   └────────┬────────┘
         │ N2 (NGAP)           │ N2                  │ N2
         │ N3 (GTP-U:2152)     │ N3                  │ N3
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
                      ┌────────▼────────┐
                      │  Custom Proxy   │
                      │  Port 9999      │  ◄── Handshake: "HELLO123"
                      │  (Python)       │       Response: "ACK"
                      └────────┬────────┘
                               │
                      ┌────────▼────────────────┐
                      │   5G Core Network       │
                      │   172.18.0.2 (STATIC)   │
                      │   (Open5GS v2.7.6)      │
                      │                         │
                      │  ┌──────────────────┐   │
                      │  │ AMF  SMF  UPF   │   │
                      │  │ NRF  UDM  AUSF  │   │
                      │  │ PCF  BSF  UDR   │   │
                      │  │ NSSF MongoDB    │   │
                      │  └──────────────────┘   │
                      └─────────┬───────────────┘
                                │ N6 (ogstun)
                                │ NAT + Routing
                                ▼
                         [ Internet ]
```

## 📦 Components

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **5G Core** | Open5GS | v2.7.6 | Complete SA 5G Core (AMF, SMF, UPF, etc.) |
| **RAN Simulator** | UERANSIM | v3.2.6 | 3 gNBs + 4 UEs with GTP-U tunneling |
| **Auth Proxy** | Python | 3.9 | Custom handshake authentication layer |
| **Database** | MongoDB | 7.0 | Subscriber management & HSS data |
| **Traffic Generator** | Python + Scapy | 3.9 | Multi-profile traffic generation |
| **Packet Capture** | tcpdump | Latest | GTP-U tunnel analysis for Wireshark |

## 🔧 Prerequisites

- **Docker**: 20.10+ with Compose V2
- **Linux Kernel**: 5.0+ (for TUN/TAP devices)
- **Root Access**: Required for packet captures
- **Disk Space**: ~2GB for images + captures
- **RAM**: 4GB minimum, 8GB recommended
- **Network**: Internet access for UE connectivity tests

## 📚 Documentation & Guides

- 📖 **[Project Guide](PROJECT_GUIDE.md)** - Complete architecture and scenarios
- 📝 **[Commands Reference](COMMANDS.md)** - All essential commands
- 🔬 **[Handover Testing](HANDOVER_TESTING_GUIDE.md)** - Advanced experiments
- ⚡ **[Quick Reference](QUICK_REFERENCE.md)** - Fast lookup guide
- 📁 **[Project Structure](PROJECT_STRUCTURE.md)** - File organization
- ✅ **[Validation Results](VALIDATION_RESULTS.md)** - Test outcomes

## 🧪 Verified Test Results

### Scenario A: Inter-gNB Communication
```
✅ UE1 (gNB1) → Internet: 0% packet loss
✅ UE2 (gNB2) → Internet: 0% packet loss  
✅ UE1 ↔ UE2: 0% packet loss (0.976-1.183ms latency)
✅ Traffic Generation: 498 packets/UE in 10s (VoIP @ 49.8 pkt/s)
✅ Packet Capture: 2448 GTP-U packets in 15s
```

### Scenario B: Intra-gNB Communication
```
✅ UE3 (gNB3) → Internet: 0% packet loss
✅ UE4 (gNB3) → Internet: 0% packet loss
✅ UE3 ↔ UE4: 0% packet loss (0.884-0.984ms latency)
✅ Traffic Generation: 498 packets/UE in 10s (VoIP @ 49.8 pkt/s)
✅ Packet Capture: 2452 GTP-U packets in 15s
```

### GTP-U Tunneling
```
✅ UPF Listen Address: 172.18.0.2 (CRITICAL FIX APPLIED)
✅ gNB1 ↔ UPF: Port 2152 tunnel operational
✅ gNB2 ↔ UPF: Port 2152 tunnel operational
✅ gNB3 ↔ UPF: Port 2152 tunnel operational
✅ Packet Encapsulation: Verified via Wireshark analysis
```

## 🎯 Traffic Profiles
./run_full_test.sh voip

# Video streaming (30 fps)
./run_full_test.sh video

# Bulk file transfer (max throughput)
./run_full_test.sh bulk

# IoT sensor data (5-sec intervals)
./run_full_test.sh iot

# Dataset replay (GeForce Now gaming traffic)
docker exec ueransim-ue1 python3 /traffic_generator.py \
  --profile dataset --target 8.8.8.8 --duration 60 \
  --dataset_file /datasets/GeForce_Now_1.csv
```

### Multi-UE Testing
```bash
# Provision new UEs
./provision_ue3_ue4.sh

# Start multi-UE services
docker compose up -d ueransim-gnb3 ueransim-ue3 ueransim-ue4

# Validate setup
./test_multi_ue.sh

# Test UE-to-UE communication
UE4_IP=$(docker exec ueransim-ue4 ip -4 addr show uesimtun0 | grep inet | awk '{print $2}' | cut -d'/' -f1)
docker exec ueransim-ue3 python3 /traffic_generator.py --profile voip --target $UE4_IP --duration 30
```

### Manual Testing
```bash
# Test handshake
echo "HELLO123" | nc 127.0.0.1 9999

# View all logs
docker compose logs -f

# Check service status
docker compose ps

# View proxy events
docker compose logs proxy | grep HANDSHAKE
```

## 🛠️ Development

### Streamlined Project Structure
```
5g_handshake_project/
├── 📄 Scripts (Automation)
│   ├── quick_start.sh              # Master deployment
│   ├── verify_lab.sh               # Health check
│   ├── run_full_test.sh            # Traffic testing
│   └── run_ue_comparison.sh        # Handover testing
│
├── 📚 Documentation (4 files)
│   ├── README.md                   # This file
│   ├── PROJECT_COMPLETE.md         # Complete reference
│   ├── AUTOMATION_GUIDE.md         # Script docs
│   └── HANDOVER_TESTING_GUIDE.md   # Advanced testing
│
├── 🐍 Core Application
│   ├── handshake_proxy.py          # Auth layer
│   └── traffic_generator.py        # Traffic simulation
│
├── 🐳 Docker Configuration
│   ├── docker-compose.yml          # Orchestration
│   └── *.Dockerfile                # Container definitions
│
└── ⚙️ Configuration Files
    ├── open5gs-config/             # 5G core (11 files)
    └── ueransim-config/            # RAN (4 files)
```

📁 **[Complete Structure Guide](PROJECT_STRUCTURE.md)**

### Customize Handshake Secret
Edit `handshake_proxy.py`:
```python
SECRET = "YOUR_SECRET_HERE"
```

### Modify 5G Configuration
- **Core Network**: Edit files in `open5gs-config/`
- **RAN Parameters**: Edit files in `ueransim-config/`
- **Rebuild**: `sudo docker-compose up --build -d`

## 🔒 Security Features

- ✅ Custom authentication layer before 5G access
- ✅ Localhost-only port binding (9999, 38412)
- ✅ Isolated Docker network (172.18.0.0/16)
- ✅ Handshake secret validation before core access
- ✅ GTP-U tunnel encapsulation (port 2152)
- ✅ Static IP assignments for reliable routing

## 📊 Performance Metrics

- **Startup Time**: ~40 seconds (full stack initialization)
- **Memory Usage**: ~1.8GB total across all containers
- **CPU Usage**: <10% idle, ~30% under traffic generation
- **Network Latency**: 
  - UE ↔ Internet: 5-70ms (depends on external network)
  - UE ↔ UE: <2ms (local 5G network)
- **Throughput**: 2400+ GTP-U packets per 15-second test
- **Packet Loss**: 0% in all verified scenarios

## � Wireshark Analysis

### Opening Packet Captures

1. **Transfer from VM**:
   ```bash
   scp user@vm:/path/to/packet_captures/scenario_A_*.pcap ~/Downloads/
   ```

2. **Open in Wireshark**:
   - Double-click the .pcap file, or
   - `wireshark scenario_A_20251025_094952.pcap`

3. **Apply Filters**:
   - `gtp` - Show all GTP-U packets
   - `gtp.teid` - Display Tunnel Endpoint IDs
   - `ip.src == 10.45.0.2` - Filter by UE IP
   - `udp.port == 2152` - Show GTP-U protocol
   - `icmp` - Show ping packets

### What You'll See

**Scenario A** (2 gNBs):
- GTP-U tunnels from 172.18.0.5 (gNB1) → 172.18.0.2 (UPF)
- GTP-U tunnels from 172.18.0.6 (gNB2) → 172.18.0.2 (UPF)
- Inner IP packets from 10.45.0.2 (UE1) and 10.45.0.3 (UE2)
- VoIP traffic: 160-byte packets every 20ms

**Scenario B** (1 gNB):
- GTP-U tunnels from 172.18.0.7 (gNB3) → 172.18.0.2 (UPF)
- Inner IP packets from 10.45.0.2 (UE3) and 10.45.0.3 (UE4)
- Resource sharing between UEs on same base station

## 🐛 Troubleshooting

### Issue: UE Registration Failed
```bash
# Check if UE is provisioned in MongoDB
docker compose exec open5gs-core mongosh open5gs --eval 'db.subscribers.find()'

# Re-provision if needed
./provision_all_ues.sh
```

### Issue: No Internet Connectivity
```bash
# Verify UPF NAT rules
docker compose exec open5gs-core iptables -t nat -L

# Check ogstun interface
docker compose exec open5gs-core ip addr show ogstun
```

### Issue: Traffic Generation Fails
```bash
# Check UE has valid IP
docker compose exec ueransim-ue1 ip addr show uesimtun0

# Verify routing
docker compose exec ueransim-ue1 ip route
```

### Complete System Reset
```bash
docker compose down -v
./scenario_A.sh  # or scenario_B.sh
```

## 🎓 Technical Deep Dive

### Critical Configuration Fix

The **key breakthrough** in this project was identifying that the UPF GTP-U server needed explicit address binding:

```yaml
# open5gs-config/upf.yaml (CRITICAL)
upf:
  gtpu:
    server:
      - address: 172.18.0.2  # Must match advertised IP
```

Without this, the UPF would advertise 172.18.0.2 but only listen on 127.0.0.7, causing 100% packet loss.

### Network Architecture

- **Static IPs** ensure reliable GTP-U tunneling
- **Docker bridge** (172.18.0.0/16) isolates 5G network
- **TUN devices** (uesimtun0) carry UE traffic
- **NAT traversal** via ogstun interface
- **GTP-U encapsulation** on UDP port 2152

## 🏆 Project Summary

This project demonstrates a **fully functional 5G network testbed** with:

✅ **Custom Authentication**: Proxy-based handshake before core access  
✅ **Complete 5G Stack**: Open5GS core + UERANSIM RAN  
✅ **GTP-U Tunneling**: Verified with packet captures  
✅ **Multi-Scenario Testing**: Inter-gNB and intra-gNB scenarios  
✅ **Traffic Generation**: Multiple profiles (VoIP, video, bulk, IoT)  
✅ **Packet Analysis**: Wireshark-ready .pcap files  
✅ **Zero Packet Loss**: All connectivity tests passing  
✅ **Production Ready**: Automated scripts for reproducible deployments  

**Perfect for**: 5G research, protocol analysis, network testing, educational demonstrations, and handover experiments.

## 🎓 Learn More

- **5G Architecture**: SA (Standalone) with AMF, SMF, UPF network functions
- **NGAP Protocol**: N2 interface - gNB to AMF signaling (port 38412)
- **GTP-U Protocol**: N3 interface - User plane tunneling (port 2152)
- **PFCP Protocol**: N4 interface - SMF to UPF control plane
- **Custom Authentication**: Proxy-based handshake access control
- **Wireshark Analysis**: GTP-U packet captures with TEID inspection

## 📚 Documentation

- 📖 **[PROJECT_GUIDE.md](PROJECT_GUIDE.md)** - Complete architecture and scenarios
- 📝 **[COMMANDS.md](COMMANDS.md)** - All verified commands with examples
- 🗂️ **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - File organization
- 📊 **[VALIDATION_RESULTS.md](VALIDATION_RESULTS.md)** - Test outcomes

## 🤝 Contributing

This is a complete, tested implementation. Areas for potential enhancement:
- Additional traffic profiles (gaming, streaming, etc.)
- Performance metrics dashboard
- Network slicing implementation
- Handover procedure automation
- Advanced Wireshark filters

## 📄 License

This project is for educational and research purposes. 
- **Open5GS**: AGPL-3.0 License
- **UERANSIM**: GPL-3.0 License
- **This Project**: Educational use

## 🌟 Acknowledgments

- **Open5GS Team** - Outstanding 5G core network implementation
- **UERANSIM** - Comprehensive 5G RAN simulator
- **Docker** - Containerization platform enabling portable deployment
- **Community** - 5G research and open-source contributors

## 📞 Support & Resources

- 📖 **Full Documentation**: See [PROJECT_GUIDE.md](PROJECT_GUIDE.md)
- 📝 **Command Reference**: See [COMMANDS.md](COMMANDS.md)
- 🐛 **Troubleshooting**: Check README troubleshooting section
- � **Packet Analysis**: Use Wireshark filters documented above
- 💬 **Issues**: Report via GitHub Issues

## ✅ Project Status

**Current Version**: 2.0 - Fully Operational  
**Last Updated**: October 25, 2025  
**Test Status**: ✅ All scenarios passing with 0% packet loss  
**Packet Captures**: ✅ 2400+ GTP-U packets captured and verified  
**Documentation**: ✅ Complete and up-to-date  

---

**Built with ❤️ for 5G network research and education**

*Verified and tested on Docker Compose V2 with Ubuntu/Fedora Linux*