#!/bin/bash

service=bookstack_bookstack
task="bash /bookstack_backup.sh"

matchedContainers=$(docker ps -q -f "label=com.docker.swarm.service.name=$service" | head -n1)
lineCount=$(echo "$matchedContainers" | awk 'NF' | wc -l)

if [ "$lineCount" -eq "1" ]; then
    docker exec -u 0 $matchedContainers $task
else
    echo "did not find a container running service $service"
fi
