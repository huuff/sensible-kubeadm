#!/usr/bin/env sh
set -eu

# When in doubt, check this guide https://faun.pub/install-a-kubernetes-cluster-on-hetzner-cloud-200d4fb6a423

echo "Setting up Hetzner's Cloud Controller Manager"

read -rp "Enter your hcloud token: " HCLOUD_API_TOKEN
read -rp "Enter your hcloud network: " HCLOUD_NETWORK

kubectl -n kube-system create secret generic hcloud --from-literal=token="$HCLOUD_API_TOKEN" --from-literal=network="$HCLOUD_NETWORK"

kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm-networks.yaml

echo "Setting up Hetzner's CSI driver"

kubectl -n kube-system create secret generic hcloud-csi --from-literal=token="$HCLOUD_API_TOKEN"

kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/v1.6.0/deploy/kubernetes/hcloud-csi.yml
