#!/bin/bash
echo "Checking for root"
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
echo "Increasing swap size"
dphys-swapfile swapoff
cp /etc/dphys-swapfile /etc/dphys-swapfile.bak
rm /etc/dphys-swapfile
echo "CONF_SWAPSIZE=2048" | sudo tee /etc/dphys-swapfile
dphys-swapfile setup
dphys-swapfile swapon
echo "Updating and installing dependencies"
apt-get update && sudo apt-get upgrade -y
apt-get install build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev
echo "Downloading Python 3.13"
wget https://www.python.org/ftp/python/3.12.2/Python-3.12.2.tgz
echo "Extracting.."
tar xvf Python-3.12.2.tgz
cd Python-3.12.2 || exit
echo "Building, this will take a while..."
./configure --enable-optimizations --with-ensurepip=install
make -j 'nproc'
make altinstall
echo "Resetting swap"
dphys-swapfile swapoff
rm /etc/dphys-swapfile
mv /etc/dphys-swapfile.bak /etc/dphys-swapfile
dphys-swapfile setup
dphys-swapfile swapon
echo "Done."
exit