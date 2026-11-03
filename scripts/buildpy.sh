#!/bin/bash
# Build Python from source on a Raspberry Pi.
#
# WARNING: this script is destructive. It disables and rewrites swap
# configuration, upgrades packages with apt, and installs Python with
# ``make altinstall``. Review it before running.
#
# Override the version with PYTHON_VERSION, for example:
#   sudo PYTHON_VERSION=3.13.18 ./scripts/buildpy.sh
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.13.18}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "Increasing swap size"
dphys-swapfile swapoff
cp /etc/dphys-swapfile /etc/dphys-swapfile.bak
rm /etc/dphys-swapfile
echo "CONF_SWAPSIZE=2048" | tee /etc/dphys-swapfile
dphys-swapfile setup
dphys-swapfile swapon

echo "Updating and installing dependencies"
apt-get update && apt-get upgrade -y
apt-get install build-essential tk-dev libncurses5-dev libncursesw5-dev \
    libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev \
    libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev -y

echo "Downloading Python $PYTHON_VERSION"
url="https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
curl --fail --location --output "Python-$PYTHON_VERSION.tgz" "$url"
tar xvf "Python-$PYTHON_VERSION.tgz"
cd "Python-$PYTHON_VERSION"

echo "Building, this will take a while..."
./configure --enable-optimizations --with-ensurepip=install
make -j "$(nproc)"
make altinstall

echo "Resetting swap"
dphys-swapfile swapoff
rm /etc/dphys-swapfile
mv /etc/dphys-swapfile.bak /etc/dphys-swapfile
dphys-swapfile setup
dphys-swapfile swapon
echo "Done."
