#!/bin/bash

while read -r NODE; do
   echo "removing $NODE..."

   ./remove_node.sh "$NODE"

   echo "removing $NODE... done"

done < <(cat nodes.yaml | yq -r '.nodes[] | .name')
