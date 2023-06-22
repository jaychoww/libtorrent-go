#!/bin/bash

set -e

git checkout master

sudo -S true

# Compile Docker images
make envs

# Compile libtorrent-go Go package
make all

# Push images to Docker Hub
make push-all
