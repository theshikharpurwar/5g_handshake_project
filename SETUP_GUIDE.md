# 5G Network Setup Guide - Complete Steps

This guide walks you through setting up a complete 5G network using Open5GS core, UERANSIM RAN simulator, and a custom proxy.

---

## Prerequisites

- Docker and Docker Compose installed
- Linux kernel with SCTP support and TUN device
- At least 4GB RAM available

---

## Step-by-Step Setup

### 1. Verify Prerequisites

```bash
# Check SCTP support
cat /proc/net/protocols | grep -i sctp

# Check TUN device
ls -l /dev/net/tun

# Both should return results. If not, load kernel modules:
sudo modprobe sctp
sudo modprobe tun
```

### 2. Navigate to Project Directory

```bash
cd /home/lunge/Documents/repos/5g_handshake_project
```

### 3. Build All Docker Images

This will build the Open5GS core, UERANSIM, proxy, and WebUI containers.

```bash
docker compose build
```

**Expected time**: 2-5 minutes depending on your internet speed.

### 4. Start the 5G Core Network

```bash
docker compose up -d open5gs-core
```

**Wait 20 seconds** for MongoDB and all Open5GS network functions (AMF, SMF, UPF, AUSF, UDM, UDR, NRF, etc.) to initialize.

```bash
sleep 20
```

### 5. Verify Core Network Functions

```bash
# Check if all Open5GS processes are running
docker compose exec -T open5gs-core sh -c "pgrep -a open5gs"
```

**Expected output** should show processes like:
- `open5gs-nrfd` (NRF - Network Repository Function)
- `open5gs-scpd` (SCP - Service Communication Proxy)
- `open5gs-ausfd` (AUSF - Authentication Server)
- `open5gs-udmd` (UDM - Unified Data Management)
- `open5gs-udrd` (UDR - Unified Data Repository)
- `open5gs-pcfd` (PCF - Policy Control Function)
- `open5gs-bsfd` (BSF - Binding Support Function)
- `open5gs-nssfd` (NSSF - Network Slice Selection Function)
- `open5gs-smfd` (SMF - Session Management Function)
- `open5gs-amfd` (AMF - Access and Mobility Management)
- `open5gs-upfd` (UPF - User Plane Function)

### 6. Provision UE Subscriber in MongoDB

The subscriber data must be added to MongoDB before the UE can register.

```bash
docker compose exec -T open5gs-core sh -lc 'mongosh --quiet open5gs --eval "
db.subscribers.replaceOne(
  { imsi: \"999700000000001\" },
  {
    imsi: \"999700000000001\",
    msisdn: [\"0000000001\"],
    security: {
      k: \"465B5CE8B199B49FAA5F0A2EE238A6BC\",
      opc: \"E8ED2890EBA952E4283B54E88E6183CA\",
      amf: \"8000\",
      op_type: 1,
      sqn: 0
    },
    ambr: {
      uplink: { value: 1, unit: 3 },
      downlink: { value: 1, unit: 3 }
    },
    slice: [
      {
        sst: 1,
        default_indicator: true,
        session: [
          {
            name: \"internet\",
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
          }
        ]
      }
    ],
    access_restriction_data: 0,
    subscriber_status: 0,
    network_access_mode: 2,
    subscribed_rau_tau_timer: 12
  },
  { upsert: true }
);
printjson(db.subscribers.findOne({imsi: \"999700000000001\"}));
"'
```

**Expected output**: Should show the complete subscriber document with all fields.

### 7. Start the Proxy

```bash
docker compose up -d proxy
```

The proxy intercepts SCTP traffic between gNB and AMF for handshake analysis.

### 8. Start the gNB (Base Station)

```bash
docker compose up -d ueransim-gnb
```

**Wait 5 seconds** for gNB to establish SCTP connection and complete NG Setup with AMF.

```bash
sleep 5
```

### 9. Verify gNB Connection

```bash
docker compose logs --no-color --tail=50 ueransim-gnb | grep -E "SCTP connection|NG Setup"
```

**Expected output**:
```
[sctp] Trying to establish SCTP connection...
[sctp] SCTP connection established
[ngap] NG Setup Request sent
[ngap] NG Setup Response received
```

### 10. Start the UE (User Equipment)

```bash
docker compose up -d ueransim-ue
```

**Wait 10 seconds** for UE to register and establish PDU session.

```bash
sleep 10
```

### 11. Verify UE Registration and PDU Session

```bash
docker compose logs --no-color --tail=200 ueransim-ue | grep -E "Initial Registration is successful|PDU Session establishment is successful|uesimtun0"
```

**Expected output**:
```
[nas] [info] Initial Registration is successful
[nas] [info] PDU Session establishment is successful PSI[1]
[app] [info] Connection setup for PDU session[1] is successful, TUN interface[uesimtun0, 10.45.0.2] is up.
```

### 12. Check the uesimtun0 Interface

```bash
docker compose exec -T ueransim-ue ip addr show uesimtun0
```

**Expected output**:
```
3: uesimtun0: <POINTOPOINT,PROMISC,NOTRAILERS,UP,LOWER_UP> mtu 1400 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none 
    inet 10.45.0.2/32 scope global uesimtun0
       valid_lft forever preferred_lft forever
    inet6 fe80::xxxx:xxxx:xxxx:xxxx/64 scope link stable-privacy 
       valid_lft forever preferred_lft forever
```

### 13. Test Internet Connectivity (Optional)

```bash
# Ping from UE through the 5G network
docker compose exec -T ueransim-ue ping -I uesimtun0 -c 4 8.8.8.8
```

---

## Quick Start (All-in-One Script)

After the initial build, you can use this single command sequence:

```bash
# Clean start
docker compose down

# Start everything
docker compose up -d open5gs-core && sleep 20 && \
docker compose up -d proxy && \
docker compose up -d ueransim-gnb && sleep 5 && \
docker compose up -d ueransim-ue && sleep 10

# Verify
docker compose ps
docker compose exec -T ueransim-ue ip addr show uesimtun0
```

---

## Verifying All Services

```bash
# Check all containers are running
docker compose ps

# Expected output:
# NAME            IMAGE                               COMMAND                  SERVICE        STATUS
# open5gs-core    5g_handshake_project-open5gs-core   "/start-open5gs.sh"      open5gs-core   Up
# open5gs-webui   5g_handshake_project-webui          "docker-entrypoint.s…"   webui          Up
# proxy           5g_handshake_project-proxy          "python /handshake_p…"   proxy          Up
# ueransim-gnb    5g_handshake_project-ueransim-gnb   "/UERANSIM/build/nr-…"   ueransim-gnb   Up
# ueransim-ue     5g_handshake_project-ueransim-ue    "/UERANSIM/build/nr-…"   ueransim-ue    Up
```

---

## Troubleshooting

### UE Registration Fails

1. **Check if UDR is running**:
   ```bash
   docker compose exec -T open5gs-core pgrep open5gs-udrd
   ```
   If no output, restart core:
   ```bash
   docker compose restart open5gs-core && sleep 20
   ```

2. **Check subscriber provisioning**:
   ```bash
   docker compose exec -T open5gs-core sh -c "mongosh --quiet open5gs --eval 'db.subscribers.findOne({imsi: \"999700000000001\"})'"
   ```

3. **Check AMF logs**:
   ```bash
   docker compose exec -T open5gs-core sh -c "tail -n 100 /var/log/open5gs/amf.log"
   ```

### gNB Cannot Connect to AMF

1. **Restart gNB after core is fully up**:
   ```bash
   docker compose restart ueransim-gnb && sleep 5
   ```

2. **Check proxy logs**:
   ```bash
   docker compose logs proxy
   ```

### No uesimtun0 Interface

This happens when PDU session establishment fails.

1. **Check UE logs for errors**:
   ```bash
   docker compose logs --tail=200 ueransim-ue
   ```

2. **Restart UE**:
   ```bash
   docker compose restart ueransim-ue && sleep 10
   docker compose exec -T ueransim-ue ip addr show uesimtun0
   ```

---

## Stopping the Network

```bash
# Stop all services
docker compose down

# Stop and remove volumes (complete cleanup)
docker compose down -v
```

---

## Configuration Details

### UE Configuration
- **IMSI**: 999700000000001
- **K (Auth Key)**: 465B5CE8B199B49FAA5F0A2EE238A6BC
- **OPc**: E8ED2890EBA952E4283B54E88E6183CA
- **IP Address**: 10.45.0.2 (assigned by SMF/UPF)
- **DNN (Data Network Name)**: internet
- **S-NSSAI**: SST=1 (default slice)

### Network Architecture
```
UE (uesimtun0: 10.45.0.2)
  ↓
gNB (UERANSIM)
  ↓ SCTP/NGAP
Proxy (intercepts handshake)
  ↓
AMF → AUSF → UDM → UDR → MongoDB
  ↓
SMF → UPF
  ↓
Data Network (internet)
```

---

## Next Steps

- Use the proxy to analyze 5G handshake messages
- Run traffic generator through uesimtun0
- Analyze captured handshake data in datasets/

---

**Setup Complete!** Your 5G network is ready for testing and handshake analysis.

