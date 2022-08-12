#!/bin/bash

set -eu

GITROOT_DIR=$(git rev-parse --show-toplevel)
SCRIPT_DIR=$(cd $(dirname $0); pwd)
CLOUDCONF_PATH=${SCRIPT_DIR}/cloud-config.yaml
ZLS_VERSION=0.9.0
VM_NAME="multipass"

if [ ! -e ${CLOUDCONF_PATH} ]; then
    if [ ! -e ~/.ssh/multipass ]; then
        ssh-keygen -t rsa -b 4096 -C "$(uuidgen)" -f ~/.ssh/multipass
        cat >> ~/.ssh/config << _EOF_
Host ${VM_NAME}.local
    HostName ${VM_NAME}.local
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
  - xz-utils

runcmd:
 - sudo snap install --classic --beta zig
 - |-
  git clone https://github.com/zigtools/zls.git && \
  cd zls && git checkout refs/tags/${ZLS_VERSION} && \
  git submodule update --init --recursive && \
  zig build -Drelease-safe
_EOF_
fi

multipass delete ${VM_NAME} 2>/dev/null || :
multipass purge
multipass launch \
    --name ${VM_NAME} \
    --cpus 2 \
    --mem 4G \
    --disk 20G \
    --cloud-init ${CLOUDCONF_PATH} \
    --mount ${GITROOT_DIR}:/src \
    20.04