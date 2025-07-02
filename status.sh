#!/bin/bash

HOST_IP="localhost" # Or your EC2 instance's public/private IP
PORTS=(8001 8002 8003 8004 8005) # Add all your worker ports here

echo "--- Fleet Status ---"
for port in "${PORTS[@]}"; do
    # Use --max-time to prevent waiting forever on a dead container
    status=$(curl -s --max-time 1 "http://${HOST_IP}:${port}/health")
    
    if [ -z "$status" ]; then
        echo "Worker on port $port: DOWN or UNRESPONSIVE"
    else
        # Use jq to parse and pretty-print the JSON status
        echo "Worker on port $port: $(echo $status | jq .)"
    fi
done
echo "--------------------"