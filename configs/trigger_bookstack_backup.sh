#!/bin/bash

service=bookstack_bookstack
task="bash /bookstack_backup.sh"


matchedContainers=$(docker ps -q -f "label=com.docker.swarm.service.name=$service" | head -n1)
lineCount=$(echo "$matchedContainers" | awk 'NF' | wc -l)

docker exec -u 0 $matchedContainers $task
