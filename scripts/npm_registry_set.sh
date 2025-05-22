#!/bin/bash

# Inside npm_registry_set.sh, at the top
if [ "$NPM_REGISTRY_ALREADY_SETUP" = "true" ]; then
    exit 0
fi
export NPM_REGISTRY_ALREADY_SETUP=true

# Use the value of the environment variable VERDACCIO_REVERSE_PROXY_PROJECT_DIR, or set a default value if it's not set
PROJECT_DIR=${VERDACCIO_REVERSE_PROXY_PROJECT_DIR:-~/projects/verdaccio-reverse-proxy}

# Navigate to the directory containing the docker-compose.yaml file
cd $PROJECT_DIR

# Define container name
CONTAINER_NAME="verdaccio-https"

# Check if the Verdaccio Docker container exists
if [ -n "$(docker ps -a -f name=${CONTAINER_NAME} -q)" ]; then
    # If the container exists, check if it's running
    if [ "$(docker inspect -f '{{.State.Running}}' ${CONTAINER_NAME})" = "false" ]; then
        echo "Starting Verdaccio Docker container..."
        docker start ${CONTAINER_NAME}
    else
        echo "Verdaccio Docker container is already running."
    fi
else
    # If the container does not exist, run it
    echo "Running Verdaccio Docker container in the background..."
    docker compose up -d
fi

# Print how to view the Verdaccio logs
echo "You can view the Verdaccio logs with the following command:"
echo "docker logs -f ${CONTAINER_NAME}"
echo "------------------------"
echo "Using custom registry: http://host.docker.internal:4873"

# Set npm registry to local Verdaccio
export NPM_CONFIG_REGISTRY=http://host.docker.internal:4873
export NPM_CONFIG_STRICT_SSL=false

# Get the IP address of the docker0 network interface
DOCKER_HOST_IP=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')

# Add host.docker.internal to /etc/hosts if not already present
if ! grep -q "host.docker.internal" /etc/hosts; then
    echo "${DOCKER_HOST_IP} host.docker.internal" | sudo tee -a /etc/hosts > /dev/null
fi
