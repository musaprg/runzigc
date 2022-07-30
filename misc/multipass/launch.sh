#!/bin/bash

set -eu

GITROOT_DIR=$(git rev-parse --show-toplevel)
SCRIPT_DIR=$(cd $(dirname $0); pwd)
CLOUDCONF_PATH=${SCRIPT_DIR}/cloud-config.yaml

if [ ! -e ${CLOUDCONF_PATH} ]; then
    if [ ! -e ~/.ssh/multipass ]; then
        ssh-keygen -t rsa -b 4096 -C "$(uuidgen)" -f ~/.ssh/multipass
        cat >> ~/.ssh/config << _EOF_
Host multipass.local
    HostName multipass.local
    IdentityFile ~/.ssh/multipass
    User ubuntu
    Port 22
_EOF_
    fi

    AUTHORIZED_KEYS=$(cat ~/.ssh/multipass.pub)
    cat > ${CLOUDCONF_PATH} << _EOF_
#cloud-config

locale: en_US.UTF8
timezone: Asia/Tokyo

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh-authorized-keys:
      - ${AUTHORIZED_KEYS}

package_upgrade: true

packages:
  - avahi-daemon
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - zip
  - jq
  - python3-pip
_EOF_
fi

multipass delete multipass 2>/dev/null || :
multipass purge
multipass launch \
    --name multipass \
    --cpus 2 \
    --mem 4G \
    --disk 20G \
    --cloud-init ${CLOUDCONF_PATH} \
    --mount ${GITROOT_DIR}:/src \
    20.04