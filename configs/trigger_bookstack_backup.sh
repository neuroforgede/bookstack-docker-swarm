#!/bin/bash

service=bookstack_bookstack
task="bash /bookstack_backup.sh"


serviceID=$(docker service ps -f name=$service -f desired-state=running $service -q --no-trunc |head -n1)
serviceName=$(docker service ps -f name=$service -f desired-state=running $service --format="{{.Name}}"| head -n1 )


docker exec -u 0 $serviceName"."$serviceID $task