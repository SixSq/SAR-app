#!/bin/bash

set -e
set -x

apt-get install -y \
    python-matplotlib \
    python-numpy \
    python-pip \
    python-scipy \
    python-setuptools \
    openjdk-8-jdk-headless \
    unzip \
    nmap \
    ntp \
    git \
    filebeat
