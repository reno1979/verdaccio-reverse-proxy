#!/bin/bash

# Use the value of the environment variable VERDACCIO_REVERSE_PROXY_PROJECT_DIR, or set a default value if it's not set
PROJECT_DIR=${VERDACCIO_REVERSE_PROXY_PROJECT_DIR:-~/projects/verdaccio-reverse-proxy}

# Navigate to the directory containing the docker-compose.yaml file
cd $PROJECT_DIR

# Check if the container is running
if [ "$(docker ps -q -f name=verdaccio-https)" ]; then
    echo "The Verdaccio Https container is already running."
elif [ "$(docker ps -aq -f status=exited -f name=verdaccio-https)" ]; then
    # Cleanup
    echo "Removing exited Verdaccio Https container.."
    docker rm verdaccio-https
fi

# Start the containers
docker compose up -d
 
# Get the IP address of the docker0 network interface
DOCKER_HOST_IP=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')

# Check if the entry already exists in the /etc/hosts file
if ! grep -q "host.docker.internal" /etc/hosts; then
    # If the entry doesn't exist, add it
    echo "${DOCKER_HOST_IP} host.docker.internal" | sudo tee -a /etc/hosts > /dev/null
    echo "${DOCKER_HOST_IP} registry.npmjs.org" | sudo tee -a /etc/hosts > /dev/null
fi

# To be used in your project's Docker Compose files, to make sure the dockers use the local registry
# Example Docker Compose yaml setting file entry
# extra_hosts:
#  - host.docker.internal:host-gateway
#  - registry.npmjs.org:${LOCAL_NPM_REGISTRY_IP_ADDRESS:-registry.npmjs.org}
export LOCAL_NPM_REGISTRY_IP_ADDRESS=${DOCKER_HOST_IP}

# Tell node about our self signed certificate
export NODE_EXTRA_CA_CERTS="${PROJECT_DIR}/ssl/verdaccio-cert.pem"
export NPM_CONFIG_STRICT_SSL=false
export NPM_CONFIG_REGISTRY=https://registry.npmjs.org/

# Print how to view the Verdaccio logs
echo "You can view the Verdaccio logs with the following command:"
echo "docker logs -f verdaccio-https"
echo "------------------------------"
echo "registry.npmjs.org is now redirected to your local registry"
