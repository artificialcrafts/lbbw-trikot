#!/bin/bash
UUID=$(uuidgen)
docker run -it --rm \
  -e REPLICATE_API_TOKEN \
  lbbw-trikot-sqs:latest