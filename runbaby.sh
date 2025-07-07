#!/bin/bash
UUID=$(uuidgen)
docker run --gpus all -it --rm \
  -e REPLICATE_API_TOKEN \
  -e WARMUP_JOB_PATH=s3://lbbw-trikot/workflow-assets/a7c5a9c8-858b-4cc6-9bc7-b97137307366.json \
  lbbw-trikot-sqs:latest