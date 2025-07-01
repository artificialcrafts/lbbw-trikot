#!/bin/bash
UUID=$(uuidgen)
docker run --gpus all -it --rm \
  -e REPLICATE_API_TOKEN \
  lbbw-trikot-sqs:latest