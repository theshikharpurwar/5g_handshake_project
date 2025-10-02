# Quick Command Reference

## One-Line Complete Setup (After Build)

```bash
docker compose down && docker compose up -d open5gs-core && sleep 20 && docker compose up -d proxy ueransim-gnb && sleep 5 && docker compose up -d ueransim-ue && sleep 10 && docker compose exec -T ueransim-ue ip addr show uesimtun0
```

---

## Step-by-Step Commands

### 1. Build (First Time Only)
```bash
docker compose build
```

### 2. Start Core Network
```bash
docker compose up -d open5gs-core
sleep 20
```

### 3. Provision Subscriber (First Time Only)
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
)"'
```

### 4. Start Proxy and RAN
```bash
docker compose up -d proxy ueransim-gnb
sleep 5
```

### 5. Start UE
```bash
docker compose up -d ueransim-ue
sleep 10
```

### 6. Verify uesimtun0 Interface
```bash
docker compose exec -T ueransim-ue ip addr show uesimtun0
```

---

## Verification Commands

### Check All Services
```bash
docker compose ps
```

### Check UE Registration
```bash
docker compose logs --no-color --tail=200 ueransim-ue | grep -E "Initial Registration is successful|PDU Session"
```

### Check gNB Connection
```bash
docker compose logs --no-color --tail=100 ueransim-gnb | grep -E "SCTP connection|NG Setup"
```

### Check Core Network Functions
```bash
docker compose exec -T open5gs-core pgrep -a open5gs
```

### Check Subscriber in Database
```bash
docker compose exec -T open5gs-core mongosh --quiet open5gs --eval 'db.subscribers.findOne({imsi: "999700000000001"})'
```

---

## Log Viewing

### Follow UE Logs
```bash
docker compose logs -f ueransim-ue
```

### Follow gNB Logs
```bash
docker compose logs -f ueransim-gnb
```

### Follow Core Logs
```bash
docker compose logs -f open5gs-core
```

### Follow Proxy Logs
```bash
docker compose logs -f proxy
```

### View AMF Logs
```bash
docker compose exec -T open5gs-core tail -f /var/log/open5gs/amf.log
```

### View SMF Logs
```bash
docker compose exec -T open5gs-core tail -f /var/log/open5gs/smf.log
```

---

## Testing Commands

### Ping from UE
```bash
docker compose exec -T ueransim-ue ping -I uesimtun0 -c 4 8.8.8.8
```

### Check Routing
```bash
docker compose exec -T ueransim-ue ip route
```

### Check UE IP Address
```bash
docker compose exec -T ueransim-ue ip addr show uesimtun0
```

---

## Restart Commands

### Restart Everything
```bash
docker compose restart
```

### Restart Core Only
```bash
docker compose restart open5gs-core
sleep 20
```

### Restart RAN Only
```bash
docker compose restart ueransim-gnb ueransim-ue
sleep 10
```

### Restart UE Only
```bash
docker compose restart ueransim-ue
sleep 10
```

---

## Stop Commands

### Stop All Services
```bash
docker compose down
```

### Stop All and Remove Volumes
```bash
docker compose down -v
```

### Stop Specific Service
```bash
docker compose stop ueransim-ue
```

---

## Debugging Commands

### Shell into Core Container
```bash
docker compose exec open5gs-core bash
```

### Shell into UE Container
```bash
docker compose exec ueransim-ue bash
```

### Check MongoDB Data
```bash
docker compose exec -T open5gs-core mongosh open5gs
```

### Check Network Connectivity
```bash
docker network inspect 5g_handshake_project_5g_network
```

### Check Container IPs
```bash
docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker compose ps -q)
```

---

## Quick Scripts

### Use the Automated Script
```bash
./QUICK_START.sh
```

### Check if Everything is Working
```bash
docker compose ps && \
docker compose exec -T ueransim-ue ip addr show uesimtun0 && \
docker compose logs --tail=10 ueransim-ue | grep -E "Registration|PDU"
```

---

## Expected Output

### Successful uesimtun0 Interface
```
3: uesimtun0: <POINTOPOINT,PROMISC,NOTRAILERS,UP,LOWER_UP> mtu 1400 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none 
    inet 10.45.0.2/32 scope global uesimtun0
       valid_lft forever preferred_lft forever
```

### Successful UE Registration
```
[nas] [info] Initial Registration is successful
[nas] [info] PDU Session establishment is successful PSI[1]
[app] [info] Connection setup for PDU session[1] is successful, TUN interface[uesimtun0, 10.45.0.2] is up.
```

---

## Troubleshooting One-Liners

### Fix UDR Crash
```bash
docker compose restart open5gs-core && sleep 20
```

### Reprovision Subscriber
```bash
docker compose exec -T open5gs-core mongosh --quiet open5gs --eval 'db.subscribers.updateOne({imsi: "999700000000001"}, {$set: {"slice.0.default_indicator": true}})'
```

### Force Clean Restart
```bash
docker compose down -v && docker compose build && ./QUICK_START.sh
```
