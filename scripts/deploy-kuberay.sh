#!/bin/bash
set -e

# Variables
NAMESPACE=llama
RAY_VERSION=2.9.0
IMAGE_REPO=${1:-obike007/llama-ray}
IMAGE_TAG=${2:-latest}

# Create namespace if it doesn't exist
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Check if KubeRay operator is installed
if ! kubectl get crds | grep -q "rayclusters.ray.io"; then
  echo "KubeRay operator not found. Installing..."
  kubectl create namespace ray-system --dry-run=client -o yaml | kubectl apply -f -
  helm repo add kuberay https://ray-project.github.io/kuberay-helm/
  helm repo update
  helm install kuberay-operator kuberay/kuberay-operator -n ray-system --wait
else
  echo "KubeRay operator already installed"
fi

# Create PVC for models
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: llama-models
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Create dummy model for testing
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: dummy-model
  namespace: ${NAMESPACE}
data:
  model.gguf: |
    DUMMY_MODEL_DATA_FOR_TESTING_ONLY
EOF

# Copy dummy model to PVC
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: model-setup
  namespace: ${NAMESPACE}
spec:
  ttlSecondsAfterFinished: 100
  template:
    spec:
      containers:
      - name: model-setup
        image: busybox
        command: ["sh", "-c", "cp /dummy/model.gguf /models/model.gguf && echo 'Dummy model copied'"]
        volumeMounts:
        - name: dummy-model
          mountPath: /dummy
        - name: models
          mountPath: /models
      volumes:
      - name: dummy-model
        configMap:
          name: dummy-model
      - name: models
        persistentVolumeClaim:
          claimName: llama-models
      restartPolicy: Never
EOF

# Wait for the job to complete
kubectl -n ${NAMESPACE} wait --for=condition=complete --timeout=60s job/model-setup

# Deploy with Helm
helm upgrade --install llama-kuberay ./helm/llama-server \
  --namespace ${NAMESPACE} \
  --values ./helm/llama-server/values-kuberay.yaml \
  --set image.repository=${IMAGE_REPO} \
  --set image.tag=${IMAGE_TAG} \
  --set ray.version=${RAY_VERSION} \
  --timeout 10m

# Display deployment status
echo "Deployment started. Checking status..."
sleep 5
kubectl -n ${NAMESPACE} get pods
kubectl -n ${NAMESPACE} get raycluster,rayservice

echo "Ray dashboard will be available at: http://localhost:8265 (after port-forwarding)"
echo "LLaMA service will be available at: http://localhost:30085"

echo "To port-forward the Ray dashboard, run:"
echo "kubectl -n ${NAMESPACE} port-forward service/llama-ray-cluster-head-svc 8265:8265"

echo "To test the service, run:"
echo 'curl -X POST -H "Content-Type: application/json" -d '\''{"prompt":"Hello, my name is", "n_predict": 50}'\'' http://localhost:30085/'