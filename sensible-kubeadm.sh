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

read -rp "Enter your cloud provider [external]: " CLOUD_PROVIDER
CLOUD_PROVIDER=${CLOUD_PROVIDER:-external}

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
serverTLSBootstrap: true # metrics-server won't work without this
cgroupDriver: systemd
featureGates:
  SeccompDefault: true
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$APISERVER_ADVERTISE_ADDRESS"
  bindPort: 6443
nodeRegistration:
  kubeletExtraArgs:
    "cloud-provider": "$CLOUD_PROVIDER"
EOF

kubeadm init --config "$KUBEADM_CONFIG_FILE"

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "Installing calico network plugin..."
# TODO: Maybe allow other network plugins?
kubectl create -f https://projectcalico.docs.tigera.io/manifests/tigera-operator.yaml
curl -sN https://projectcalico.docs.tigera.io/manifests/custom-resources.yaml |  sed -e "s|192.168.0.0/16|$POD_CIDR|g" | kubectl create -f -

echo "All done! You should have the join commands up in the logs"
echo "Please remember that you have to set the cloud provider on every node, so before joining you have to use:"

cat <<FEO
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS=--cloud-provider=$CLOUD_PROVIDER
EOF
FEO

# TODO: Automate approving CSRs, at least the first ones
echo "================"
echo "Also note, since you've choosen 'serverTLSBootstrap' (so metrics-server works out of the box)"
echo "you'll have to manually approve CSRs (check any pending ones with 'kubectl get csr')"
echo "with 'kubectl certificate «csr name»'. Note that you'll also have to do this when the certificates"
echo "rotate a year from now."
