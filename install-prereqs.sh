#!/usr/bin/env bash
set -euo pipefail

# TODO: Overridable by env vars
containerd_version="1.6.5"
runc_version="1.1.4"
cni_plugins_version="1.1.1"

echo "SETTING UP KERNEL MODULES..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "INSTALLING CONTAINERD..."
wget "https://github.com/containerd/containerd/releases/download/v$containerd_version/containerd-$containerd_version-linux-amd64.tar.gz"
tar Cxzvf /usr/local "containerd-$containerd_version-linux-amd64.tar.gz" 
mkdir -p /usr/local/lib/systemd/system/
curl "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service" > /usr/local/lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

echo "INSTALLING RUNC..."
wget "https://github.com/opencontainers/runc/releases/download/v$runc_version/runc.amd64"
install -m 755 runc.amd64 /usr/local/sbin/runc

echo "INSTALLING CNI PLUGINS"
wget "https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v$cni_plugins_version.tgz"
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin "cni-plugins-linux-amd64-v$cni_plugins_version.tgz"

echo "SETTING SYSTEMD AS THE CGROUP DRIVER FOR CONTAINERD..."
mkdir -p /etc/containerd
cat <<EOF | tee /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF
