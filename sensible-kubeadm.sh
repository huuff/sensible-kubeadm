#!/usr/bin/env sh

CONTROL_PLANE_ENDPOINT="$1"
APISERVER_ADVERTISE_ADDRESS="$2"
POD_CIDR=${3:-"10.0.0.0/16"}

CONFIG_ROOT_DIR=/etc/kubernetes/kubeadm-config
mkdir -p "$CONFIG_ROOT_DIR"
ENCRYPTION_CONFIGURATION_FILE="$CONFIG_ROOT_DIR/encryptionconfiguration.yaml"
KUBEADM_CONFIG_FILE="$CONFIG_ROOT_DIR/kubeadmconfig.yaml"
AUDIT_POLICY_FILE="$CONFIG_ROOT_DIR/policy.yaml"

# TODO: Use files and envsubst instead of inlining the yamls here?

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

#echo "Encryption configuration: $ENCRYPTION_CONFIGURATION_FILE"

cp ./policy.yaml "$AUDIT_POLICY_FILE"
#echo "Audit policy configyration: $AUDIT_POLICY_FILE"

cat <<EOF > "$KUBEADM_CONFIG_FILE"
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.24.0
controlPlaneEndpoint="$CONTROL_PLANE_ENDPOINT"
networking:
  podSubnet: "$POD_CIDR"
featureGates:
  SeccompDefault: true
apiServer:
  extraArgs:
    anonymous-auth: "false"
    encryption-provider-config: $ENCRYPTION_CONFIGURATION_FILE
    audit-policy-file: $AUDIT_POLICY_FILE
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
seccompDefault: true
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$APISERVER_ADVERTISE_ADDRESS"
  bindPort: 6443
EOF

echo "kubeadm configuration: $KUBEADM_CONFIG_FILE"

