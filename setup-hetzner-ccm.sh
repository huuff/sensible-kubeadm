#!/usr/bin/env sh
set -eu

echo "Setting up Hetzner's Cloud Controller Manager"

read -rp "Enter your hcloud token: " HCLOUD_API_TOKEN
read -rp "Enter your hcloud network: " HCLOUD_NETWORK

kubectl -n kube-system create secret generic hcloud --from-literal=token="$HCLOUD_API_TOKEN" --from-literal=network="$HCLOUD_NETWORK"

kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm-networks.yaml

# TODO: Set up Hetzner's CSI driver!
# Follow this guide: https://faun.pub/install-a-kubernetes-cluster-on-hetzner-cloud-200d4fb6a423
