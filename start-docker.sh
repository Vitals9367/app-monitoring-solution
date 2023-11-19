#!/bin/bash

# Load variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "Environment variables loaded from .env file"
else
    echo ".env file not found"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    printf "Docker is not installed. Please install Docker and try again.\n"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    printf "Docker is not running. Please start Docker and try again\n."
    exit 1
fi

# Check if --skip-setup or --clean flags were provided
skip_setup=false
clean=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --skip-setup)
      skip_setup=true
      ;;
    --clean)
      clean=true
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# Cleanup old installation if --clean flag is present
if [ "$clean" = true ]; then
    printf "\nCleaning up old instalaltion...\n"
    # Remove exited setup container to prevent script from failing
    docker rm $(docker ps -a -f status=exited -f status=created -q)
    # Remove everything else
    docker-compose down -v

    if [ $? -ne 0 ]; then
        exit 1
    fi

fi

# Skip ELK stack setup if --skip-setup flag is present
if [ "$skip_setup" = false ]; then
    printf "\nSetting up ELK stack...\n"
    docker-compose up setup

    if [ $? -ne 0 ]; then
        exit 1
    fi

fi

# Spin up containers
printf "\nStarting the containers...\n"
docker-compose up -d

if [ $? -ne 0 ]; then
  exit 1
fi

# -------- Info messages --------
printf "\nDocker startup completed!\n\n"

if [ "$skip_setup" = true ] && [ "$clean" = true ]; then
    printf "WARNING: you used both --clean and --skip-setup options at once!\n"
    printf "This resulted in ELK stack not having any users and roles created."
    printf "\nSystem won't work as expected\n\n"
fi

printf "Access services using these domains:

  Kibana: http://kibana.docker.localhost
    Username: elastic
    Password: $KIBANA_SYSTEM_PASSWORD
  Grafana: http://grafana.docker.localhost
    Username: admin
    Password: admin
  Prometheus: http://prometheus.docker.localhost
    No auhentication
  Nginx: http://nginx.docker:4040.localhost/
    No auhentication
  Nginx-metric-exporter: http://nginx-metric-exporter.docker.localhost:9133/metrics
    No auhentication

"
