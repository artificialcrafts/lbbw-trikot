#!/bin/bash

NUM_WORKERS=5
IMAGE_NAME="lbbw-trikot-sqs:latest"

# Check for the REPLICATE_API_TOKEN
if [ -z "$REPLICATE_API_TOKEN" ]; then
    echo "Error: REPLICATE_API_TOKEN environment variable is not set."
    exit 1
fi

echo "Starting $NUM_WORKERS worker containers in the background..."

for i in $(seq 1 $NUM_WORKERS)
do
  # Use -d to run the container in "detached" (background) mode
  # Give each container a unique name for easy identification
  docker run -d --rm \
    --name "lbbw-worker-$i" \
    -e REPLICATE_API_TOKEN \
    -e SQS_QUEUE_URL="https://sqs.your-region.amazonaws.com/123456789012/lbbw-trikot-jobs" \
    "$IMAGE_NAME"
done

echo "All workers started. Use 'docker logs -f lbbw-worker-1' to view logs for a specific worker."
echo "Use 'docker stop \$(docker ps -q --filter \"name=lbbw-worker-\")' to stop all workers."