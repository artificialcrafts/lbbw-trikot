#!/bin/bash

git pull
git submodule update --init --recursive

docker build -t lbbw-trikot-sqs:latest .
docker image prune -f