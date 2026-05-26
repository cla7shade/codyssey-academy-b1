#!/usr/bin/env bash
docker build -t b1-1 . && docker run --privileged --rm --name b1-1-agent --env-file .env -p 20022:20022 -p 15034:15034 b1-1
