#!/bin/bash

set -eu

mkdir -m 755 -p /root/rootfs/proc
mkdir -m 755 -p /root/rootfs/bin
mkdir -m 755 -p /root/rootfs/lib

cp -Lr /bin/* /root/rootfs/bin
cp -Lr /usr/bin/* /root/rootfs/bin

cp -Lr /lib/x86_64-linux-gnu /root/rootfs/lib
cp -Lr /lib64/ld-linux-x86-64.so.2 /root/rootfs/lib

cd /root/rootfs/
ln -s lib lib64
