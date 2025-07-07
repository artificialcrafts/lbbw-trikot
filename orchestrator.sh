#!/bin/bash

# --- Configuration ---
RAM_PER_CONTAINER_GB=7.5      # RAM required by each worker container
HOST_OVERHEAD_GB=0            # Reserve this much RAM for the host OS and other services
IMAGE_NAME="lbbw-trikot-sqs:latest"
CONTAINER_BASE_NAME="lbbw-worker" # Base name for containers

# --- Helper Function for stopping containers ---
stop_containers() {
    echo "Attempting to stop all containers with base name '${CONTAINER_BASE_NAME}'..."
    # Find all containers (running or exited) that match the base name pattern
    # -a for all (including stopped), -q for quiet (only IDs)
    STOP_TARGETS=$(docker ps -aq --filter "name=${CONTAINER_BASE_NAME}")

    if [ -n "$STOP_TARGETS" ]; then
        echo "Found the following containers to stop: $(echo $STOP_TARGETS | tr '\n' ' ')"
        docker stop $STOP_TARGETS
        echo "Successfully stopped specified containers."
    else
        echo "No containers found with base name '${CONTAINER_BASE_NAME}' to stop."
    fi
}

# --- Main Logic ---

# Check if a command is provided
if [ -z "$1" ]; then
    echo "Usage: $0 {start|stop}"
    exit 1
fi

case "$1" in
    start)
        echo "Executing 'start' command..."

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

        # Calculate usable RAM for containers (floating point division)
        USABLE_RAM_GB=$(echo "$TOTAL_RAM_GB - $HOST_OVERHEAD_GB" | bc)

        # Determine the number of workers (floor division)
        if (( $(echo "$USABLE_RAM_GB < $RAM_PER_CONTAINER_GB" | bc -l) )); then
            echo "Warning: Not enough usable RAM (${USABLE_RAM_GB} GB) after reserving host overhead to start even one worker (needs ${RAM_PER_CONTAINER_GB} GB)."
            NUM_WORKERS=0
        else
            NUM_WORKERS=$(echo "$USABLE_RAM_GB / $RAM_PER_CONTAINER_GB" | bc)
        fi

        if [ "$NUM_WORKERS" -eq 0 ]; then
            echo "No workers will be started."
            exit 0
        fi

        echo "Calculated to start $NUM_WORKERS worker containers (each needing ${RAM_PER_CONTAINER_GB} GB)."

        # --- Docker Container Management (Start Command) ---

        # Stop any existing containers before starting new ones (clean slate for 'start')
        stop_containers # Calls the helper function

        echo "Starting $NUM_WORKERS worker containers in the background..."

        for i in $(seq 1 $NUM_WORKERS)
        do
          CONTAINER_NAME="${CONTAINER_BASE_NAME}-$i"
          echo "Starting container: $CONTAINER_NAME..."

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
        echo "To stop all workers, run: $0 stop" # Updated instruction
        ;;

    stop)
        echo "Executing 'stop' command..."
        # Call the helper function to stop containers
        stop_containers
        exit 0
        ;;

    *)
        echo "Invalid command: $1"
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac