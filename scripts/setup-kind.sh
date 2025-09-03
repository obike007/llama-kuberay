
#!/bin/bash
set -e

# Configuration
CLUSTER_NAME="llama-cluster"

# Create a cluster configuration file
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30090
    hostPort: 30090
    protocol: TCP
  - containerPort: 30300
    hostPort: 30300
    protocol: TCP
  - containerPort: 30900
    hostPort: 30900
    protocol: TCP
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
EOF

# Check if cluster exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "KIND cluster '${CLUSTER_NAME}' already exists. Deleting..."
    kind delete cluster --name "${CLUSTER_NAME}"
fi

# Create KIND cluster
echo "Creating KIND cluster '${CLUSTER_NAME}'..."
kind create cluster --name "${CLUSTER_NAME}" --config kind-config.yaml

echo "KIND cluster '${CLUSTER_NAME}' created successfully."
kubectl cluster-info

# Create default StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
EOF

echo "Default StorageClass created."
kubectl get storageclass