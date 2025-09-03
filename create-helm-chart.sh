#!/bin/bash
# Script to create the Helm chart structure

# Create base directories
mkdir -p helm/llama-server/templates

# Create Chart.yaml
cat > helm/llama-server/Chart.yaml << 'EOF'
apiVersion: v2
name: llama-server
description: A Helm chart for LLaMA.cpp server with Prometheus monitoring
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: Your Name
    email: your.email@example.com
keywords:
  - llm
  - llama
  - ai
  - inference
EOF

# Create values.yaml
cat > helm/llama-server/values.yaml << 'EOF'
# Default values for llama-server
nameOverride: ""
fullnameOverride: ""

replicaCount: 1

image:
  repository: yourusername/llama-server  # Replace with your Docker Hub username
  tag: latest
  pullPolicy: IfNotPresent

imagePullSecrets: []
podAnnotations: {}
podSecurityContext: {}
securityContext: {}

service:
  type: NodePort
  llama:
    port: 8084
    nodePort: 30080
  metrics:
    port: 9090
    nodePort: 30090

resources:
  limits:
    cpu: 2
    memory: 4Gi
  requests:
    cpu: 1
    memory: 2Gi

persistence:
  enabled: true
  size: 5Gi
  mountPath: /models
  storageClass: standard

modelConfig:
  downloadModel: true
  modelUrl: "https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/resolve/main/llama-2-7b-chat.Q4_K_M.gguf"
  modelFileName: "model.gguf"

# Prometheus ServiceMonitor configuration
serviceMonitor:
  enabled: true
  namespace: monitoring
  interval: 15s
  scrapeTimeout: 10s
  labels: {}

# Optional ingress
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: llama.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

# Server configuration
server:
  context: 2048
  threads: 4
  batchSize: 512
  keepAlive: -1  # -1 means infinity
  verbose: true
  enableSlots: true
  nCtx: 2048

nodeSelector: {}
tolerations: []
affinity: {}
EOF

# Create _helpers.tpl
cat > helm/llama-server/templates/_helpers.tpl << 'EOF'
{{/*
Expand the name of the chart.
*/}}
{{- define "llama-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "llama-server.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "llama-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "llama-server.labels" -}}
helm.sh/chart: {{ include "llama-server.chart" . }}
{{ include "llama-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "llama-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "llama-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
EOF

# Create deployment.yaml
cat > helm/llama-server/templates/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "llama-server.fullname" . }}
  labels:
    {{- include "llama-server.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "llama-server.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "llama-server.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      initContainers:
        {{- if .Values.modelConfig.downloadModel }}
        - name: model-downloader
          image: curlimages/curl:7.82.0
          command:
            - sh
            - -c
            - |
              echo "Downloading model from {{ .Values.modelConfig.modelUrl }}..."
              if [ ! -f /models/{{ .Values.modelConfig.modelFileName }} ]; then
                curl -L {{ .Values.modelConfig.modelUrl }} -o /models/{{ .Values.modelConfig.modelFileName }}
                echo "Download complete."
              else
                echo "Model file already exists, skipping download."
              fi
          volumeMounts:
            - name: models
              mountPath: /models
        {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 8084
              protocol: TCP
            - name: metrics
              containerPort: 9090
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 60
            periodSeconds: 30
            timeoutSeconds: 5
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 15
            timeoutSeconds: 5
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: models
              mountPath: /models
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumes:
        - name: models
          {{- if .Values.persistence.enabled }}
          persistentVolumeClaim:
            claimName: {{ include "llama-server.fullname" . }}-models
          {{- else }}
          emptyDir: {}
          {{- end }}
EOF

# Create service.yaml
cat > helm/llama-server/templates/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "llama-server.fullname" . }}
  labels:
    {{- include "llama-server.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.llama.port }}
      targetPort: http
      protocol: TCP
      name: http
      {{- if and (eq .Values.service.type "NodePort") .Values.service.llama.nodePort }}
      nodePort: {{ .Values.service.llama.nodePort }}
      {{- end }}
    - port: {{ .Values.service.metrics.port }}
      targetPort: metrics
      protocol: TCP
      name: metrics
      {{- if and (eq .Values.service.type "NodePort") .Values.service.metrics.nodePort }}
      nodePort: {{ .Values.service.metrics.nodePort }}
      {{- end }}
  selector:
    {{- include "llama-server.selectorLabels" . | nindent 4 }}
EOF

# Create pvc.yaml
cat > helm/llama-server/templates/pvc.yaml << 'EOF'
{{- if .Values.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "llama-server.fullname" . }}-models
  labels:
    {{- include "llama-server.labels" . | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  {{- if .Values.persistence.storageClass }}
  storageClassName: {{ .Values.persistence.storageClass }}
  {{- end }}
  resources:
    requests:
      storage: {{ .Values.persistence.size }}
{{- end }}
EOF

# Create servicemonitor.yaml
cat > helm/llama-server/templates/servicemonitor.yaml << 'EOF'
{{- if .Values.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "llama-server.fullname" . }}
  {{- if .Values.serviceMonitor.namespace }}
  namespace: {{ .Values.serviceMonitor.namespace }}
  {{- end }}
  labels:
    {{- include "llama-server.labels" . | nindent 4 }}
    {{- with .Values.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  endpoints:
    - port: metrics
      interval: {{ .Values.serviceMonitor.interval }}
      scrapeTimeout: {{ .Values.serviceMonitor.scrapeTimeout }}
      path: /metrics
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
  selector:
    matchLabels:
      {{- include "llama-server.selectorLabels" . | nindent 6 }}
{{- end }}
EOF

# Create configmap.yaml
cat > helm/llama-server/templates/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "llama-server.fullname" . }}-config
  labels:
    {{- include "llama-server.labels" . | nindent 4 }}
data:
  server-config.json: |
    {
      "model": "/models/{{ .Values.modelConfig.modelFileName }}",
      "ctx_size": {{ .Values.server.nCtx }},
      "batch_size": {{ .Values.server.batchSize }},
      "threads": {{ .Values.server.threads }},
      "keep_alive": {{ .Values.server.keepAlive }},
      "verbose": {{ .Values.server.verbose }}
    }
EOF

# Create ingress.yaml
cat > helm/llama-server/templates/ingress.yaml << 'EOF'
{{- if .Values.ingress.enabled -}}
{{- $fullName := include "llama-server.fullname" . -}}
{{- $svcPort := .Values.service.llama.port -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "llama-server.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
EOF

echo "Helm chart created successfully in ./helm/llama-server/"