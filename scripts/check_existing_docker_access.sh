#!/usr/bin/env bash
set -euo pipefail

PYTHON_ROOT="/mnt/packages/apps/external/python/${PYTHON_VERSION}/platform-linux"
PYTHON_BIN="${PYTHON_ROOT}/bin/python3.10"

echo "Checking deployed Python..."
"$PYTHON_BIN" --version

echo "Checking Python environment..."
"$PYTHON_BIN" -c \
    'import sys, sysconfig, ssl; print("Executable:", sys.executable); print("Prefix:", sys.prefix); print("Include:", sysconfig.get_path("include")); print("OpenSSL:", ssl.OPENSSL_VERSION)'

# bash "$BUILD_SCRIPT"