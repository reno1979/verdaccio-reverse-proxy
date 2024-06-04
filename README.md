# verdaccio-reverse-proxy

Docker setup for a local npm registry using the default registry url. (registry.npmjs.org)
Based on the [https-portal-example](https://github.com/verdaccio/verdaccio/blob/master/docker-examples/v6/proxy/https-portal-example/README.md)  

This guide will walk you through setting up a local NPM registry using Verdaccio in a Docker container. This setup can help improve the stability and speed of NPM installations inside Docker containers. This guide assumes you're working on a Windows 11 machine with WSL2, Docker, and Docker Compose installed.

## Problem Statement

While installing NPM packages in multiple Docker containers, the process often failed due to `ECONNRESET` errors or timeouts. These issues occurred randomly and increasing the retry and timeout values for NPM didn't resolve them. The goal is to improve the reliability and speed of NPM installations in Docker containers.

## Prerequisites

- Windows 11 with WSL2
- Docker and Docker Compose ([a guide to run docker without using docker desktop](https://dev.to/felipecrs/simply-run-docker-on-wsl2-3o8))
- A Linux environment (Ubuntu)

## Prepare

### Step 1: Clone this repo

```sh
git clone git@github.com:reno1979/verdaccio-reverse-proxy.git
```

or

```sh
git clone git@github.com:reno1979/verdaccio-reverse-proxy.git
```

### Step 2: Update the hosts File

Make registry.npmjs.org redirect back to the IP address of the docker0 network interface. 

The default address for the docker0 network interface is `127.17.0.1`, to be on the safe side let us validate this: 

```sh
$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')
```

If you're using Docker Desktop on Windows or Mac, `host.docker.internal` should resolve to the internal IP address used by the host. However, this is not the case on Docker for Linux. 

You can then use this IP address in your `/etc/hosts` file:

```sh
DOCKER_HOST_IP=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')

echo "${DOCKER_HOST_IP} registry.npmjs.org" | sudo tee -a /etc/hosts > /dev/null
echo "${DOCKER_HOST_IP} host.docker.internal" | sudo tee -a /etc/hosts > /dev/null
```

This script will add an entry to your `/etc/hosts` file, mapping the Docker host IP address to `host.docker.internal` and `registry.npmjs.org`.

#### 2.1 Docker compose extra_hosts

To be sure the Docker containers also use your local NPM registry, we need to point them to the correct IP address by adding a new rule inside their hosts file. 
With the `extra_hosts` inside a Docker Compose yaml file we can.

First we need to register the Docker Host IP address as an environment variable, we want  it to be available in each session so we place the following line inside `~/.bashrc`

```sh
DOCKER_HOST_IP=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')

echo "export LOCAL_NPM_REGISTRY_IP_ADDRESS=${DOCKER_HOST_IP}" | tee -a ~/.bashrc > /dev/null
``` 

When you are not using Docker Desktop you might want to update your docker-compose.yml files to also include include the host.docker.internal setting:

```yaml
extra_hosts:
  - host.docker.internal:host-gateway
  - registry.npmjs.org:${LOCAL_NPM_REGISTRY_IP_ADDRESS:-registry.npmjs.org}
```

The `extra_hosts` to `registry.npmjs.org` addes a rule inside the Docker Container hosts file to make the address `registry.npmjs.org` point to the IP address of your local NPM registry, and has a fallback to the actual address `registry.npmjs.org` 

## Usage

To run the containers, run the following commands in this repository folder, it should start the containers in detach mode.

```sh
docker compose up -d
```

To recreate the nginx image you can force the build.

```sh
docker compose up --build -d
```

To force recreate the images.

```sh
docker compose up --build --force-recreate  -d
```

To stop all containers

```sh
docker compose stop
```

## NPM and self-signed certificates

Be aware of disabling strict SSL in the `./npmrc` config file as explained [here](https://stackoverflow.com/questions/9626990/receiving-error-error-ssl-error-self-signed-cert-in-chain-while-using-npm).

```sh
npm config set strict-ssl false
npm config set registry https://registry.npmjs.org
```

By also explicitly setting the registry to `https://registry.npmjs.org` we maker sure that this address is used inside the `package-lock.json` file.

## Logs

You can view the Verdaccio logs

```sh
docker logs -f verdaccio-https
```

## Login

If you want to login into the Verdaccio instance created via these Docker Examples, please try:

Username: bor
Password: bor

### Change credentials

The credentials are based on the `htpasswd` file inside the config folder.
By replacing this you can change the credentials. 

To create a .htpasswd file, you can use the htpasswd utility that comes with Apache.

If htpasswd is not installed on your system, you can install it by installing the apache2-utils package. 

```sh
sudo apt-get update
sudo apt-get install apache2-utils
```

Use the htpasswd command to create a new file and store a username and password. Replace username with your desired username and your_password_file with the name of your password file.

You will be prompted to enter and confirm your password. After you've done that, htpasswd will create a new file with the specified name and store your username and hashed password.

```sh
htpasswd -cB your_password_file username
```

## Automate

Let us automate the described steps (except the cloning of the repo part).
Make sure you have cloned the repo described in [Step 1](#step-1-clone-this-repo)

Within the scripts folder you wil find the `npm_registry_set.sh` file.
Make sure the scripts gets started on each session, by adding it to `~/.bashrc`

Open the `~/.bashrc` file, for example with `vi`.

```sh
vi ~/.bashrc
```

and at the end of the file place these lines:

```bash
# The URL of your custom npm registry
# execute the script npm_registry_set.sh inside the home folder
EXPORT VERDACCIO_REVERSE_PROXY_PROJECT_DIR=~/projects/verdaccio-reverse-proxy
~/projects/verdaccio-reverse-proxy/scripts/npm_registry_set.sh
```

Make sure the `/projects/verdaccio-reverse-proxy/` part matches the actual location on your machine, and set the environment variable `VERDACCIO_REVERSE_PROXY_PROJECT_DIR` 

To make sure you do not get promted for the `sudo` pasword when you start a new session, we need to make the `sudo` part of the script allowed for the user without a password.

```sh
sudo visudo
```

and at the end of the file place these lines:

```
<username> ALL=(ALL:ALL) NOPASSWD: /usr/bin/tee -a /etc/hosts
```

Make sure you replace <username> with your username.

We can now test our script:

```sh
source ~/scripts/npm_registry_set.sh
```

## Undo Changes

If you want to undo the changes made by following the instructions in this guide, you can follow these steps:

### Step 1: Remove Docker Containers

First, navigate to the project directory and stop the Docker containers:

```sh
cd $PROJECT_DIR
docker compose down
```

### Step 2: Remove Docker Volumes

If you want to remove the Docker volumes as well, you can do so with the following commands:

```sh
docker volume rm verdaccio-reverse-proxy_storage
docker volume rm verdaccio-reverse-proxy_plugins
```

Please note that this will delete all data stored in the volumes.

### Step 3: Revert Changes to the Hosts File

To revert the changes made to the `/etc/hosts` file, you can use a text editor like `vi`:

```sh
sudo vi /etc/hosts
```

In the editor, find the line that contains `registry.npmjs.org` and the Docker host IP address, and delete it. Then, save and close the file.

### Step 4: Unset Environment Variable

If you've set the `VERDACCIO_REVERSE_PROXY_PROJECT_DIR` environment variable and want to unset it, you can do so with the following command:

```sh
unset VERDACCIO_REVERSE_PROXY_PROJECT_DIR
```

After following these steps, all changes made by following the instructions in this guide should be undone.

### Step 5: Undo Automation in .bashrc

If you've added commands to your .bashrc file to automatically start the Docker containers, you can undo this by removing those commands.

1. Open your .bashrc file in a text editor:

```sh 
vi ~/.bashrc
```

2. Find the following lines:

```sh
export VERDACCIO_REVERSE_PROXY_PROJECT_DIR = <your project path>
cd $VERDACCIO_REVERSE_PROXY_PROJECT_DIR
docker compose up -d
```

3. Delete these lines, then save and close the file.

4. To make the changes take effect, you can either close and reopen your terminal, or run the following command:

```sh 
source ~/.bashrc
```

After following these steps, the Docker containers will no longer start automatically when you open a new bash shell.

## Conclusion

You now have a local NPM registry running in a Docker container with Verdaccio. This setup should improve the speed and reliability of NPM installations in your Docker containers. Happy coding! 🚀

