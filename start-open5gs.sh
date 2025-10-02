#!/bin/bash

# Start MongoDB
mongod --fork --logpath /var/log/mongodb.log --dbpath /var/lib/mongodb

# Wait a moment for MongoDB to start
sleep 5

# Start Open5GS services - using the binary directly since service might not work in container
open5gs-nrfd -D &
sleep 1
open5gs-scpd -D &
sleep 1
open5gs-ausfd -D &
sleep 1
open5gs-udmd -D &
sleep 1
open5gs-udrd -D &
sleep 1
open5gs-pcfd -D &
sleep 1
open5gs-bsfd -D &
sleep 1
open5gs-nssfd -D &
sleep 1
open5gs-smfd -D &
sleep 1
open5gs-amfd -D &  # AMF is the one we connect to
sleep 1
open5gs-upfd -D &
sleep 2

echo "Open5GS services started"

# Keep the container running by tailing logs
mkdir -p /var/log/open5gs
touch /var/log/open5gs/amf.log /var/log/open5gs/smf.log /var/log/open5gs/upf.log
tail -f /var/log/open5gs/*.log