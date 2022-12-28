#!/bin/bash

set -e

NODE="node-$1"
IP="192.168.122.$2"
DISK_SIZE=$3
DISK="$NODE/disk.qcow2"
ISO_CLOUDINIT="$NODE/cidata.iso"
USER_DATA="$NODE/user-data"
META_DATA="$NODE/meta-data"
SSH_SCRIPT="$NODE/ssh"
HOSTFILE="$NODE/hostfile"

BACKING_IMG="dependencies/jammy-server-cloudimg-amd64.img"

function log() {
    echo "$NODE: $1"
}

log "Init"

mkdir "./$NODE"
log "Creating disk $DISK"

if [ ! -f $BACKING_IMG ]; then
    log "Downloading $BACKING_IMG"
    curl https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -o $BACKING_IMG
fi

sudo qemu-img create -f qcow2 -F qcow2 -o backing_file="../$BACKING_IMG" "$DISK"
sudo qemu-img resize "$DISK" "$DISK_SIZE"
sudo qemu-img info "$DISK"

log "Created $DISK"

log "Creating Cloud-init ISO"

cat >$META_DATA <<EOF
instance-id: $NODE
local-hostname: $NODE

network-interfaces: |
  iface enp1s0 inet static
  address $IP
  network 192.168.122.0
  netmask 255.255.255.0
  broadcast 192.168.122.255
  gateway 192.168.122.1
EOF

PUB_KEY=$(cat "$HOME/.ssh/id_rsa.pub")

cat >$USER_DATA <<EOF
#cloud-config

users:
  - name: ubuntu
    ssh-authorized-keys:
      - $PUB_KEY
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash

# Set DNS
manage_resolv_conf: true
resolv_conf:
  nameservers: ['8.8.8.8', '1.1.1.1']

runcmd:
  - echo "AllowUsers ubuntu" >> /etc/ssh/sshd_config
  - sudo systemctl restart sshd

output:
  all: ">> /var/log/cloud-init.log"
EOF

cp $USER_DATA ./user-data
cp $META_DATA ./meta-data

sudo genisoimage -output "$ISO_CLOUDINIT" -volid cidata -joliet -rock user-data meta-data

rm user-data
rm meta-data

log "Installing node"

sudo virt-install \
    --connect qemu:///system \
    --virt-type kvm \
    --name "$NODE" \
    --ram 2048 \
    --vcpus=2 \
    --os-variant ubuntu22.04 \
    --disk path="$DISK,format=qcow2" \
    --disk "$ISO_CLOUDINIT,device=cdrom" \
    --import \
    --network bridge=virbr0 \
    --noautoconsole

cat >$SSH_SCRIPT <<EOF
#/bin/sh

ssh ubuntu@$IP
EOF

cat >$HOSTFILE <<EOF
$IP $NODE # managed by mpajkowski
EOF

cat $HOSTFILE | sudo tee -a /etc/hosts

chmod +x $SSH_SCRIPT

log "Done"
