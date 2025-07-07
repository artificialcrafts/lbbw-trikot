#!/bin/bash
UUID=$(uuidgen)
docker run --gpus all -it --rm \
  -e REPLICATE_API_TOKEN \
  -e WARMUP_JOB_PATH=s3://lbbw-trikot/workflow-assets/d1a83069-ac7c-47a0-ae1a-083265d5a98e.json \
  lbbw-trikot-sqs:latest