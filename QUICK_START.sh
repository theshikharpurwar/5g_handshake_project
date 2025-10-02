#!/bin/bash
set -e

echo "==================================================="
echo "5G Network Quick Start Script"
echo "==================================================="
echo ""

# Step 1: Build (only needed once)
echo "Step 1: Building Docker images..."
docker compose build
echo "✓ Build complete"
echo ""

# Step 2: Start core
echo "Step 2: Starting 5G Core Network..."
docker compose up -d open5gs-core
echo "   Waiting 20 seconds for core initialization..."
sleep 20
echo "✓ Core network started"
echo ""

# Step 3: Provision subscriber
echo "Step 3: Provisioning UE subscriber in MongoDB..."
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
)" > /dev/null 2>&1'
echo "✓ Subscriber provisioned"
echo ""

# Step 4: Start proxy
echo "Step 4: Starting proxy..."
docker compose up -d proxy
echo "✓ Proxy started"
echo ""

# Step 5: Start gNB
echo "Step 5: Starting gNB (base station)..."
docker compose up -d ueransim-gnb
echo "   Waiting 5 seconds for gNB to connect..."
sleep 5
echo "✓ gNB started"
echo ""

# Step 6: Start UE
echo "Step 6: Starting UE (user equipment)..."
docker compose up -d ueransim-ue
echo "   Waiting 10 seconds for UE registration..."
sleep 10
echo "✓ UE started"
echo ""

# Step 7: Verify
echo "==================================================="
echo "Verification"
echo "==================================================="
echo ""

echo "All running containers:"
docker compose ps
echo ""

echo "UE Registration Status:"
docker compose logs --no-color --tail=200 ueransim-ue | grep -E "Initial Registration is successful|PDU Session establishment is successful|uesimtun0" || echo "   ⚠ Registration might still be in progress..."
echo ""

echo "uesimtun0 Interface:"
docker compose exec -T ueransim-ue ip addr show uesimtun0 2>/dev/null || echo "   ⚠ Interface not yet available, wait a few more seconds and run: docker compose exec -T ueransim-ue ip addr show uesimtun0"
echo ""

echo "==================================================="
echo "Setup Complete!"
echo "==================================================="
echo ""
echo "Useful commands:"
echo "  - View UE logs:    docker compose logs -f ueransim-ue"
echo "  - View gNB logs:   docker compose logs -f ueransim-gnb"
echo "  - View Core logs:  docker compose logs -f open5gs-core"
echo "  - View Proxy logs: docker compose logs -f proxy"
echo "  - Stop all:        docker compose down"
echo "  - Check interface: docker compose exec -T ueransim-ue ip addr show uesimtun0"
echo ""
