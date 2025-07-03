#!/bin/bash

# --- Configuration ---
RAM_PER_CONTAINER_GB=7,5      # RAM required by each worker container
HOST_OVERHEAD_GB=1          # Reserve this much RAM for the host OS and other services
                            # (e.g., 4GB is a reasonable default for many servers)
IMAGE_NAME="lbbw-trikot-sqs:latest"
CONTAINER_BASE_NAME="lbbw-worker" # Base name for containers

# --- Pre-checks ---

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker command not found. Please install Docker."
    exit 1
fi

# Check for the REPLICATE_API_TOKEN
if [ -z "$REPLICATE_API_TOKEN" ]; then
    echo "Error: REPLICATE_API_TOKEN environment variable is not set."
    exit 1
fi

# --- Calculate Number of Workers ---

echo "Calculating optimal number of workers based on system RAM..."

# Get total RAM in GB, rounded to the nearest whole number
TOTAL_RAM_GB=$(awk '/^MemTotal:/ {printf "%.0f\n", $2 / (1024 * 1024)}' /proc/meminfo)

if [ -z "$TOTAL_RAM_GB" ] || [ "$TOTAL_RAM_GB" -eq 0 ]; then
    echo "Error: Could not determine total system RAM or RAM is 0GB."
    exit 1
fi

echo "Total system RAM detected: ${TOTAL_RAM_GB} GB"
echo "Reserving ${HOST_OVERHEAD_GB} GB for host OS overhead."

# Calculate usable RAM for containers
USABLE_RAM_GB=$((TOTAL_RAM_GB - HOST_OVERHEAD_GB))

# Determine the number of workers
if [ "$USABLE_RAM_GB" -lt "$RAM_PER_CONTAINER_GB" ]; then
    echo "Warning: Not enough usable RAM (${USABLE_RAM_GB} GB) after reserving host overhead to start even one worker (needs ${RAM_PER_CONTAINER_GB} GB)."
    NUM_WORKERS=0
else
    NUM_WORKERS=$((USABLE_RAM_GB / RAM_PER_CONTAINER_GB))
fi

if [ "$NUM_WORKERS" -eq 0 ]; then
    echo "No workers will be started."
    exit 0
fi

echo "Calculated to start $NUM_WORKERS worker containers (each needing ${RAM_PER_CONTAINER_GB} GB)."

# --- Docker Container Management ---

echo "Stopping any previously running containers with base name '${CONTAINER_BASE_NAME}'..."
# Get IDs of containers matching the base name, then stop them
EXISTING_CONTAINERS=$(docker ps -q --filter "name=${CONTAINER_BASE_NAME}")
if [ -n "$EXISTING_CONTAINERS" ]; then
    docker stop $EXISTING_CONTAINERS
    echo "Stopped: $(echo $EXISTING_CONTAINERS | tr '\n' ' ')" # Prettier output
else
    echo "No existing containers found with base name '${CONTAINER_BASE_NAME}'."
fi

echo "Starting $NUM_WORKERS worker containers in the background..."

for i in $(seq 1 $NUM_WORKERS)
do
  # Construct unique container name
  CONTAINER_NAME="${CONTAINER_BASE_NAME}-$i"
  echo "Starting container: $CONTAINER_NAME..."

  # Use -d to run the container in "detached" (background) mode
  # --rm ensures the container is removed when it exits
  docker run --gpus all -it --rm -d \
    --memory="${RAM_PER_CONTAINER_GB}g" \
    --memory-swap="${RAM_PER_CONTAINER_GB}g" \
    --name "$CONTAINER_NAME" \
    -e REPLICATE_API_TOKEN \
    -e WARMUP_JOB_PATH=s3://lbbw-trikot/workflow-assets/33429fd4-7ba1-4680-a7a3-44c895bf45cd.json \
    "$IMAGE_NAME"
done

echo "All $NUM_WORKERS workers started."
echo "Use 'docker logs -f ${CONTAINER_BASE_NAME}-1' to view logs for a specific worker."
echo "To stop all workers, run: docker stop \$(docker ps -q --filter \"name=${CONTAINER_BASE_NAME}-\")"