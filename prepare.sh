#!/bin/bash

set -eu

ROOTNAME=rootfs

mkdir -p /root/${ROOTNAME}/proc
mkdir -p /root/${ROOTNAME}/bin
mkdir -p /root/${ROOTNAME}/lib

cp /bin/sh /root/${ROOTNAME}/bin
cp /bin/ls /root/${ROOTNAME}/bin

cp /lib/x86_64-linux-gnu/libc.so.6 /root/${ROOTNAME}/lib
cp /lib64/ld-linux-x86-64.so.2 /root/${ROOTNAME}/lib
cp /lib/x86_64-linux-gnu/libselinux.so.1 /root/${ROOTNAME}/lib
cp /lib/x86_64-linux-gnu/libpcre.so.3 /root/${ROOTNAME}/lib
cp /lib/x86_64-linux-gnu/libdl.so.2 /root/${ROOTNAME}/lib
cp /lib/x86_64-linux-gnu/libpthread.so.0 /root/${ROOTNAME}/lib

cd /root/${ROOTNAME}/
ln -s lib lib64

cd