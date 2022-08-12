#!/bin/bash


if [[ -z "$RUNNER_VERSION" ]]; then
  echo "RUNNER_VERSION should be set in environment"
  exit 1
fi

if [[ -z "$RUNNER_SUFFIX" ]]; then
  echo "RUNNER_NAME should be set in environment"
  exit 1
fi

if [[ -z "$TOKEN" ]]; then
  echo "TOKEN should be set in environment"
  exit 1
fi

URL=https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
echo "Downloading $URL"
curl -o actions-runner.tar.gz -L $URL
tar xzf actions-runner.tar.gz

alias docker=podman
./config.sh --url https://github.com/rammpeter/Panorama_Gem --token $TOKEN --name panorama_gem_docker_runner_${RUNNER_SUFFIX} --unattended
./run.sh