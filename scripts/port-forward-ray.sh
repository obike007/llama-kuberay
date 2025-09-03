#!/bin/bash
NAMESPACE=${1:-llama}
SERVICE=${2:-llama-ray-cluster-head-svc}

echo "Port forwarding Ray dashboard from ${NAMESPACE}/${SERVICE}..."
kubectl -n ${NAMESPACE} port-forward service/${SERVICE} 8265:8265