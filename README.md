LLaMA Server with KubeRay Architecture

Overview
This repository provides a comprehensive solution for deploying a LLaMA.cpp server within Kubernetes using KubeRay, with integrated monitoring through Prometheus and Grafana. The architecture includes a CI/CD pipeline that automates the entire build, test, and deployment process.


Architecture Components
LLaMA Server: A high-performance C++ implementation of LLaMA (Large Language Model Meta AI) that serves as the core inference engine.

Ray Framework: Distributed computing framework that facilitates scaling the LLaMA server.

KubeRay: Kubernetes operator for managing Ray clusters.

Prometheus: Monitoring and alerting toolkit.

Grafana: Visualization and analytics platform for metrics.

Helm: Kubernetes package manager used for deploying all components.

KIND: Kubernetes IN Docker, used for local testing.

Directory Structure
.
├── .github/
│   └── workflows/         # CI/CD pipeline definitions
│       └── ci-cd.yml      # Main CI/CD workflow
├── configs/
│   └── supervisord.conf   # Supervisor configuration for process management
├── docker/
│   └── Dockerfile         # Main Dockerfile for LLaMA server
├── helm/
│   └── llama-server/      # Helm chart for LLaMA server with KubeRay
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── pvc.yaml
│           ├── ray-cluster.yaml  # KubeRay cluster definition
│           ├── ray-service.yaml  # KubeRay service definition
│           └── service.yaml
├── metrics/
│   └── exporter.py        # Prometheus metrics exporter
├── monitoring/
│   ├── prometheus-values.yaml     # Prometheus configuration
│   └── dashboards/
│       └── llama-dashboard.json   # Grafana dashboard definition
├── ray_serve/
│   └── llama_serve.py     # Ray Serve application script
├── scripts/
│   ├── setup-kind.sh      # Script to set up KIND cluster
│   └── test-ray-service.py  # Testing script for Ray service
└── README.md              # This file

Setup Process
Prerequisites
Before starting, ensure you have the following tools installed:
Docker
Kubernetes CLI (kubectl)
Helm
Python 3.8+
KIND (for local development)

Step 1: Clone the Repository
git clone https://github.com/obike007/llama-kuberay.git
cd llama-kuberay

Step 2: Set Up Local Kubernetes with KIND
Create a local Kubernetes cluster for development and testing:
chmod +x scripts/setup-kind.sh
./scripts/setup-kind.sh

This script:
Creates a KIND cluster with port mappings
Sets up a default StorageClass
Configures Kubernetes for local development

Step 3: Build Docker Images
Build the LLaMA server and Ray service images:
# Build LLaMA server image
docker build -t llama-server:latest .
# Build Ray image
docker build -t llama-ray:latest -f Dockerfile.ray .

Step 4: Load Images into KIND
kind load docker-image llama-server:latest --name llama-cluster
kind load docker-image llama-ray:latest --name llama-cluster

Step 5: Set Up Monitoring
Install Prometheus and Grafana for monitoring:
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
# Create monitoring namespace
kubectl create namespace monitoring
# Install Prometheus and Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-values.yaml

Step 6: Install KubeRay Operator
# Add KubeRay Helm repository
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update
# Create namespace for KubeRay
kubectl create namespace ray-system
# Install KubeRay operator
helm install kuberay-operator kuberay/kuberay-operator \
  --namespace ray-system

Step 7: Deploy LLaMA with KubeRay
Step 8: Test the Deployment

Using the Architecture
Access LLaMA Server API
The LLaMA server API is available at:
http://localhost:30085/

Access Monitoring Dashboards
Prometheus: http://localhost:30900
Grafana: http://localhost:30300 (admin/admin)

Access Ray Dashboard
The Ray dashboard is available at:
http://localhost:8265

Security Considerations
This deployment is set up for development and testing. For production:

Secure endpoints with proper authentication
Use network policies to restrict traffic
Configure resource limits appropriately
Use Kubernetes Secrets instead of ConfigMaps for sensitive data
Set up proper RBAC controls
Troubleshooting
Common Issues
Pods stuck in Pending state:
Check for resource constraints with kubectl describe pod <pod-name>
Ensure PVCs are bound with kubectl get pvc -n llama
Ray cluster not starting:
Check logs with kubectl logs -n llama -l ray.io/node-type=head
Verify KubeRay operator is running with kubectl get pods -n ray-system
Model loading issues:
Check if model file exists in PVC
Check if model format is compatible with LLaMA server
Metrics not showing in Grafana:
Verify ServiceMonitor is created and working
Check Prometheus target status at http://localhost:30900/targets

Contributing
Fork the repository
Create a feature branch
Make your changes
Create a pull request

License
This project is licensed under the MIT License - see the LICENSE file for details.
