#!/bin/bash

while read -r NODE; do
   read -r IP_END
   read -r DISK

   echo "installing $NODE (ip 192.168.122.$IP_END, disk $DISK)..."

   ./create_node.sh "$NODE" "$IP_END" "$DISK"

   echo "installing $NODE (ip 192.168.122.$IP_END, disk $DISK)... done"

done < <(cat nodes.yaml | yq -r '.nodes[] | .name, .ip_end, .disk')
