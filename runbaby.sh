#!/bin/bash
UUID=$(uuidgen)
docker run --gpus all -it --rm \
  -e REPLICATE_API_TOKEN \
  -e WARMUP_JOB_PATH=s3://lbbw-trikot/workflow-assets/d5dfdea5-b466-495d-86dc-3767b7b29c3e.json \
  lbbw-trikot-sqs:latest