#!/bin/bash

NODE="node-$1"

sudo virsh destroy $NODE
sudo virsh undefine $NODE
sudo rm -rf $NODE

sudo sed -i "/$NODE # managed by mpajkowski/d" /etc/hosts
