#!/usr/bin/env sh
set -eu

CONTROL_PLANE_ENDPOINT="$1"
APISERVER_ADVERTISE_ADDRESS="$2"
POD_CIDR=${3:-"10.0.0.0/16"}

CONFIG_ROOT_DIR=/etc/kubernetes/kubeadm-config
mkdir -p "$CONFIG_ROOT_DIR"
ENCRYPTION_CONFIGURATION_FILE="$CONFIG_ROOT_DIR/encryptionconfiguration.yaml"
KUBEADM_CONFIG_FILE="$CONFIG_ROOT_DIR/kubeadmconfig.yaml"
AUDIT_POLICY_FILE="$CONFIG_ROOT_DIR/policy.yaml"

# TODO: Use files and envsubst instead of inlining the yamls here?

echo "Initializing control plane..."

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


cp ./policy.yaml "$AUDIT_POLICY_FILE"

cat <<EOF > "$KUBEADM_CONFIG_FILE"
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.24.0
controlPlaneEndpoint: "$CONTROL_PLANE_ENDPOINT"
networking:
  podSubnet: "$POD_CIDR"
apiServer:
  extraArgs:
    encryption-provider-config: $ENCRYPTION_CONFIGURATION_FILE
    audit-policy-file: $AUDIT_POLICY_FILE
  extraVolumes:
    - name: kubeadm-config
      hostPath: $CONFIG_ROOT_DIR
      mountPath: $CONFIG_ROOT_DIR
      readOnly: true
      pathType: DirectoryOrCreate
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
seccompDefault: true
featureGates:
  SeccompDefault: true
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$APISERVER_ADVERTISE_ADDRESS"
  bindPort: 6443
EOF

kubeadm init --config "$KUBEADM_CONFIG_FILE"

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "Installing calico operator..."
# TODO: Maybe allow other operators?
kubectl create -f https://projectcalico.docs.tigera.io/manifests/tigera-operator.yaml
curl -sN https://projectcalico.docs.tigera.io/manifests/custom-resources.yaml |  sed -e "s|192.168.0.0/16|$POD_CIDR|g" | kubectl create -f -
