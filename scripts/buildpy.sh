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
apt-get update && apt-get upgrade -y
apt-get install build-essential tk-dev libncurses5-dev libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev -y
echo "Downloading most recent stable release..."
url='https://www.python.org/ftp/python/'

curl --silent "$url" |
sed -n 's!.*href="\([0-9]\+\.[0-9]\+\.[0-9]\+\)/".*!\1!p' |
sort -rV |
{
    while read -r version; do
        filename="Python-$version"
        # Versions which only have alpha, beta, or rc releases will fail here.
        # Stop when we find one with a final release.
        if curl --fail --silent -O "$url/$version/$filename.tgz"; then
            echo "$filename"
            break
        fi
    done
    echo "Extracting.."
    tar xvf "$filename.tgz"
    cd Python-"$version" || exit
}
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
exit