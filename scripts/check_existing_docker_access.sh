#!/usr/bin/env bash
set -euo pipefail
export REZ_CONFIG_FILE=/mnt/packages/.config/linux_rezconfig.py

# PYTHON_ROOT="/mnt/packages/apps/external/python/${PYTHON_VERSION}/platform-linux"
# PYTHON_BIN="${PYTHON_ROOT}/bin/python3.10"

# echo "Checking deployed Python..."
# "$PYTHON_BIN" --version

# echo "Checking Python environment..."
# "$PYTHON_BIN" -c \
#     'import sys, sysconfig, ssl; print("Executable:", sys.executable); print("Prefix:", sys.prefix); print("Include:", sysconfig.get_path("include")); print("OpenSSL:", ssl.OPENSSL_VERSION)'
# Configure Rez
export REZ_ROOT=/opt/rez/current
export PYTHONPATH=/opt/rez/current
export REZ_CONFIG_FILE=/mnt/packages/.config/linux_rezconfig.py
export PATH="/opt/rez/current/bin/rez:${PATH}"
which rez-search || echo "failed to seek rez-search"
echo "*****"
rez-search python-3.10
echo "*****"
# bash "$BUILD_SCRIPT"
