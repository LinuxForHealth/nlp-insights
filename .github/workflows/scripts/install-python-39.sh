#!/bin/bash
set -ex
sudo apt install python3.9
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 2
sudo update-alternatives --set python3 /usr/bin/python3.9
sudo pip3 install -U pip
