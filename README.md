# bookstack-docker-swarm

Sample Docker Stack to set up bookstack.

# Used software

1. docker-stack-deploy for secret rotation (https://github.com/neuroforgede/docker-stack-deploy)
2. Hetzner Docker Volumes via costela/docker-volume-hetzner (see https://github.com/neuroforgede/swarmsible/tree/master/environments/test/test-swarm/stacks for a stack to install the driver)

# How-To

0. Install docker-stack-deploy
1. Check all configs, secrets and the bookstack.yml for any variables that need to be set up
2. Run deploy.sh (usage of DOCKER_HOST is recommended, see e.g. https://github.com/neuroforgede/swarmsible/blob/master/environments/test/test-swarm/bin/activate)