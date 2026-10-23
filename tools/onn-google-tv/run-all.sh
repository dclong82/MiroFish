#!/usr/bin/env bash
# Runs the steps in order. Each step prints its plan and stops for a typed
# "yes" before changing anything. Stop at any prompt and nothing further runs.
#   TV_ADDR=192.168.1.50 ./run-all.sh
cd "$(dirname "$0")"
set -e
./00-backup.sh
./10-debloat.sh
./20-launcher.sh
./30-speed.sh
./40-reboot-verify.sh
