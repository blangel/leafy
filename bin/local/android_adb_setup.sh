#!/usr/bin/env bash

set -euo pipefail

device=${1:-}
if [ -z "$device" ]; then
  echo "usage: ./android_adb_setup.sh EMULATOR_NAME"
  echo "        where EMULATOR_NAME is a name of an emulator from 'adb devices -l', see below"
  echo ""
  adb devices -l
  exit 1
fi

adb -s "$device" reverse tcp:8080 tcp:8080
