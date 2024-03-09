wget https://www.python.org/ftp/python/3.13.0/Python-3.13.0a4.tgz
tar xvf Python-3.13.0a4.tgz
cd Python-3.13.0a4 || exit
./configure --enable-optimizations --with-ensurepip=install
make altinstall