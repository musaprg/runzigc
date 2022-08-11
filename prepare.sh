#!/bin/bash

set -eu

arch=$(uname -m)

mkdir -m 755 -p /root/rootfs/proc
mkdir -m 755 -p /root/rootfs/bin
mkdir -m 755 -p /root/rootfs/lib

cp -Lr /bin/* /root/rootfs/bin
cp -Lr /usr/bin/* /root/rootfs/bin

cp -Lr /lib/${arch}-linux-gnu /root/rootfs/lib
[ -e /lib/ld-linux-${arch}.so.2 ] && cp -Lr /lib/ld-linux-${arch}.so.2 /root/rootfs/lib
[ -e /lib64/ld-linux-${arch}.so.2 ] && cp -Lr /lib64/ld-linux-${arch}.so.2 /root/rootfs/lib

cd /root/rootfs/
ln -s lib lib64
