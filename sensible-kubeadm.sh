#!/usr/bin/env sh
ENCRYPTION_CONFIGURATION_FILE=$(mktemp)
CLUSTER_CONFIGURATION_FILE=$(mktemp)

cat <<EOF > "$ENCRYPTION_CONFIGURATION_FILE"
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $(head -c32 /dev/urandom | base64)
      - identity: {}
EOF

echo "Encryption configuration: $ENCRYPTION_CONFIGURATION_FILE"

cat <<EOF > "$CLUSTER_CONFIGURATION_FILE"
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.24.0
featureGates:
  SeccompDefault: true
apiServer:
  extraArgs:
    anonymous-auth: "false"
    encryption-provider-config: $ENCRYPTION_CONFIGURATION_FILE
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
seccompDefault: true
EOF

echo "Cluster configuration: $CLUSTER_CONFIGURATION_FILE"
