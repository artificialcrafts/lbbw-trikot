#!/bin/bash
UUID=$(uuidgen)
docker run --gpus all -it --rm \
  -e REPLICATE_API_TOKEN \
  -e WARMUP_JOB_PATH=s3://lbbw-trikot/workflow-assets/33429fd4-7ba1-4680-a7a3-44c895bf45cd.json \
  lbbw-trikot-sqs:latest