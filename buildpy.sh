clear
echo "Updating and installing dependencies"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install build-essential tk-dev libncurses5-dev libncursesw5-dev li>
clear
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
echo "Done."
exit
