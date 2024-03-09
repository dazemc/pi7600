echo "Increasing swap size"
sudo dphys-swapfile swapoff
sudo cp /etc/dphys-swapfile /etc/dphys-swapfile.bak
sudo rm /etc/dphys-swapfile
echo "CONF_SWAPSIZE=2048" | sudo tee /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
clear
echo "Updating and installing dependencies"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev
echo "Downloading Python 3.13"
wget https://www.python.org/ftp/python/3.13.0/Python-3.13.0a4.tgz
echo "Extracting.."
tar xvf Python-3.13.0a4.tgz
cd Python-3.13.0a4 || exit
clear
echo "Building, this will take a while..."
./configure --enable-optimizations --with-ensurepip=install
make -j$(nproc)
make altinstall
echo "Resetting swap"
sudo dphys-swapfile swapoff
sudo rm /etc/dphys-swapfile
sudo mv /etc/dphys-swapfile.bak /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
echo "Done."
exit