#!/bin/bash
UUID=$(uuidgen)
docker run --gpus all -it --rm \
  -e REPLICATE_API_TOKEN \
  -e WARMUP_JOB_PATH=s3://lbbw-trikot/workflow-assets/current_warmup_workflow.json \
  lbbw-trikot-sqs:latest