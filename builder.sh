#!/bin/bash

git pull
docker build -t lbbw-trikot-sqs:latest .
docker image prune -f