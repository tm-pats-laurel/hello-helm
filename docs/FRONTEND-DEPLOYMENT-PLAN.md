# Frontend Deployment Plan - Complete Task List

A comprehensive step-by-step guide to deploy your Next.js frontend with Helm, connected to the FastAPI backend.

## 📋 Overview

### What We're Building

- **Frontend**: Next.js 15 app with TypeScript and Tailwind CSS
- **Backend Connection**: Via `BACKEND_URL` environment variable (runtime)
- **Deployment**: Kubernetes with Helm charts
- **Pattern**: Same as backend - separate chart in `helm_charts/frontend/`

### Architecture

```
┌─────────────────────────────────────────┐
│      Kubernetes Cluster                 │
│                                         │
│  ┌──────────────┐    ┌──────────────┐  │
│  │   Frontend   │───→│   Backend    │  │
│  │  (Next.js)   │    │  (FastAPI)   │  │
│  │  Port: 3000  │    │  Port: 8000  │  │
│  └──────────────┘    └──────┬───────┘  │
│                              │          │
│                      ┌───────▼──────┐   │
│                      │  PostgreSQL  │   │
│                      │  Port: 5432  │   │
│                      └──────────────┘   │
└─────────────────────────────────────────┘
```

### How Backend Connection Works

1. **Environment Variable**: `BACKEND_URL` set at runtime
2. **Next.js API Routes**: Proxy requests to backend
3. **Service Discovery**: Uses Kubernetes DNS
   - Frontend: `http://my-frontend:3000`
   - Backend: `http://my-backend:8000`

---

## 📝 Complete Task List

### Phase 1: Helm Chart Foundation

#### ✅ Task 1: Create Chart.yaml

**File**: `helm_charts/frontend/Chart.yaml`

**What to do:**
```yaml
apiVersion: v2
name: frontend
description: A Helm chart for Next.js frontend application
type: application
version: 0.1.0
appVersion: "0.1.0"
```

**Why:**
- Required by Helm to recognize as valid chart
- Defines chart identity and version

**Time**: 2 minutes

---

#### ✅ Task 2: Create values.yaml

**File**: `helm_charts/frontend/values.yaml`

**What to do:**
```yaml
# Default values for frontend
replicaCount: 1

image:
  repository: frontend-app
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  automount: true
  annotations: {}
  name: ""

podAnnotations: {}
podLabels: {}

podSecurityContext: {}

securityContext: {}

service:
  type: ClusterIP
  port: 3000

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80

volumes: []
volumeMounts: []

nodeSelector: {}
tolerations: []
affinity: {}

# ============================================
# Frontend Application Configuration
# ============================================

env:
  NODE_ENV: "production"

# Backend connection
backend:
  # Name of the backend Helm release
  # This will construct: http://<releaseName>:8000
  releaseName: "my-backend"
  port: 8000
  # Or set custom URL:
  # customUrl: "http://my-custom-backend:8000"
```

**Why:**
- Provides default configuration
- Makes chart customizable
- Follows same pattern as backend chart

**Time**: 10 minutes

---

### Phase 2: Kubernetes Templates

#### ✅ Task 3: Create templates/_helpers.tpl

**File**: `helm_charts/frontend/templates/_helpers.tpl`

**What to do:**
Copy from backend and adjust:

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "frontend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "frontend.fullname" -}}
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
{{- define "frontend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "frontend.labels" -}}
helm.sh/chart: {{ include "frontend.chart" . }}
{{ include "frontend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "frontend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "frontend.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Backend URL
*/}}
{{- define "frontend.backendUrl" -}}
{{- if .Values.backend.customUrl }}
{{- .Values.backend.customUrl }}
{{- else }}
{{- printf "http://%s:%d" .Values.backend.releaseName (int .Values.backend.port) }}
{{- end }}
{{- end }}
```

**Why:**
- Provides reusable template functions
- Maintains consistency
- Includes special helper for backend URL

**Time**: 5 minutes

---

#### ✅ Task 4: Create templates/deployment.yaml

**File**: `helm_charts/frontend/templates/deployment.yaml`

**What to do:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "frontend.fullname" . }}
  labels:
    {{- include "frontend.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "frontend.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "frontend.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "frontend.serviceAccountName" . }}
      {{- with .Values.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          {{- with .Values.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            # Backend URL for API routes
            - name: BACKEND_URL
              value: {{ include "frontend.backendUrl" . | quote }}
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
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
```

**Key points:**
- Sets `BACKEND_URL` environment variable
- Uses helper function to construct backend URL
- Health checks on root path `/`

**Time**: 10 minutes

---

#### ✅ Task 5: Create templates/service.yaml

**File**: `helm_charts/frontend/templates/service.yaml`

**What to do:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "frontend.fullname" . }}
  labels:
    {{- include "frontend.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "frontend.selectorLabels" . | nindent 4 }}
```

**Why:**
- Exposes frontend on port 3000
- ClusterIP for internal access
- Can be accessed by other services

**Time**: 3 minutes

---

#### ✅ Task 6: Create templates/serviceaccount.yaml

**File**: `helm_charts/frontend/templates/serviceaccount.yaml`

**What to do:**
```yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "frontend.serviceAccountName" . }}
  labels:
    {{- include "frontend.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
{{- end }}
```

**Why:**
- Provides identity for pods
- Good practice for RBAC

**Time**: 2 minutes

---

### Phase 3: Optional Templates (Keep for Future)

Copy these from `helm_charts/backend/templates/`:
- `ingress.yaml` - For external access
- `hpa.yaml` - For auto-scaling
- `httproute.yaml` - For Gateway API

**Why keep them:**
- Production features
- Disabled by default
- No harm in having them

**Time**: 2 minutes (just copy)

---

### Phase 4: Support Files

#### ✅ Task 7: Create .helmignore

**File**: `helm_charts/frontend/.helmignore`

**What to do:**
```
.DS_Store
.git/
.gitignore
.bzr/
.bzrignore
.hg/
.hgignore
.svn/
*.swp
*.bak
*.tmp
*.orig
*~
.project
.idea/
*.tmproj
.vscode/
```

**Why:**
- Excludes unnecessary files from chart package

**Time**: 1 minute

---

#### ✅ Task 8: Create templates/NOTES.txt

**File**: `helm_charts/frontend/templates/NOTES.txt`

**What to do:**
```
1. Get the application URL by running these commands:
{{- if contains "NodePort" .Values.service.type }}
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "frontend.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
     NOTE: It may take a few minutes for the LoadBalancer IP to be available.
           You can watch its status by running 'kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "frontend.fullname" . }}'
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "frontend.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
  echo http://$SERVICE_IP:{{ .Values.service.port }}
{{- else if contains "ClusterIP" .Values.service.type }}
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "frontend.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace {{ .Release.Namespace }} $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:3000 to use your application"
  kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 3000:$CONTAINER_PORT
{{- end }}

2. The frontend is configured to connect to backend at:
   {{ include "frontend.backendUrl" . }}
```

**Why:**
- Shows helpful commands after installation
- Displays backend URL configuration

**Time**: 5 minutes

---

### Phase 5: Deployment Automation

#### ✅ Task 9: Create deploy-local.sh

**File**: `helm_charts/frontend/deploy-local.sh`

**What to do:**
```bash
#!/bin/bash
# Quick deployment script for local Kubernetes (minikube/kind)

set -e

RELEASE_NAME="${1:-my-frontend}"
NAMESPACE="${2:-default}"
BACKEND_RELEASE="${3:-my-backend}"

echo "🚀 Deploying Frontend Helm Chart"
echo "================================"
echo "Release Name: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Backend Release: $BACKEND_RELEASE"
echo ""

# Check if we're using minikube or kind
if kubectl config current-context | grep -q "minikube"; then
    echo "📦 Detected minikube - checking if image exists locally..."
    if ! minikube image ls | grep -q "frontend-app:latest"; then
        echo "⚠️  Image 'frontend-app:latest' not found in minikube"
        echo "Building and loading image..."
        cd ../../frontend
        docker build -f Dockerfile.prod -t frontend-app:latest .
        minikube image load frontend-app:latest
        cd ../helm_charts/frontend
        echo "✅ Image loaded into minikube"
    else
        echo "✅ Image already exists in minikube"
    fi
elif kubectl config current-context | grep -q "kind"; then
    echo "📦 Detected kind - checking if image exists..."
    echo "⚠️  Make sure to run: kind load docker-image frontend-app:latest"
    echo "Building image..."
    cd ../../frontend
    docker build -f Dockerfile.prod -t frontend-app:latest .
    echo "Loading into kind..."
    kind load docker-image frontend-app:latest
    cd ../helm_charts/frontend
    echo "✅ Image loaded into kind"
fi

echo ""
echo "📝 Installing Helm chart..."

# Check if release already exists
if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    echo "⚠️  Release '$RELEASE_NAME' already exists. Upgrading..."
    helm upgrade $RELEASE_NAME . -n $NAMESPACE \
      --set backend.releaseName=$BACKEND_RELEASE
else
    echo "🆕 Installing new release..."
    helm install $RELEASE_NAME . -n $NAMESPACE \
      --set backend.releaseName=$BACKEND_RELEASE
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Status:"
kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE
echo ""
echo "🔍 Useful commands:"
echo "  Watch pods:    kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -w"
echo "  Frontend logs: kubectl logs -l app.kubernetes.io/name=frontend -n $NAMESPACE -f"
echo "  Port forward:  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME 3000:3000"
echo "  Uninstall:     helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
echo "🌐 After port-forwarding, access at:"
echo "  http://localhost:3000"
echo ""
echo "Backend URL configured as: http://$BACKEND_RELEASE:8000"
```

**Why:**
- Automates build, load, and deploy
- Detects minikube vs kind
- Configures backend connection

**Time**: 15 minutes

---

#### ✅ Task 10: Make script executable

**Command:**
```bash
chmod +x helm_charts/frontend/deploy-local.sh
```

**Time**: 10 seconds

---

### Phase 6: Makefile Commands

#### ✅ Task 11: Add Frontend Commands to Makefile

**File**: `Makefile`

**What to add:**
```makefile
# Frontend configuration
FRONTEND_IMAGE ?= frontend-app
FRONTEND_TAG ?= latest
FRONTEND_RELEASE ?= my-frontend

# ============================================
# Frontend Helm Commands
# ============================================

# Build the production frontend image
build-frontend:
	@echo "🔨 Building frontend production image..."
	cd frontend && docker build -f Dockerfile.prod -t $(FRONTEND_IMAGE):$(FRONTEND_TAG) .
	@echo "✅ Frontend image built: $(FRONTEND_IMAGE):$(FRONTEND_TAG)"

# Load frontend image into minikube
load-frontend:
	@echo "📦 Loading frontend image into minikube..."
	minikube image load $(FRONTEND_IMAGE):$(FRONTEND_TAG)
	@echo "✅ Frontend image loaded into minikube"

# Deploy frontend using the automated script
helm-local-frontend:
	@echo "🚀 Deploying frontend with Helm..."
	cd helm_charts/frontend && ./deploy-local.sh $(FRONTEND_RELEASE) $(NAMESPACE) $(RELEASE_NAME)

# Build, load, and deploy frontend (complete workflow)
helm-frontend: build-frontend load-frontend helm-local-frontend
	@echo "✅ Frontend deployment complete!"

# Port-forward frontend service
pf-frontend:
	@echo "🌐 Port-forwarding frontend service..."
	@echo "Access at: http://localhost:3000"
	kubectl port-forward -n $(NAMESPACE) svc/$(FRONTEND_RELEASE) 3000:3000

# View frontend logs
frontend-logs:
	@echo "📋 Viewing frontend logs..."
	kubectl logs -l app.kubernetes.io/name=frontend -n $(NAMESPACE) -f

# Destroy frontend deployment
helm-destroy-frontend:
	@echo "🗑️  Destroying frontend deployment..."
	helm uninstall $(FRONTEND_RELEASE) -n $(NAMESPACE) || true
	@echo "✅ Frontend resources cleaned up"

# Show frontend resources
frontend-status:
	@echo "📊 Frontend deployment status:"
	@kubectl get all -l app.kubernetes.io/instance=$(FRONTEND_RELEASE) -n $(NAMESPACE)

# Show frontend pods
frontend-pods:
	@kubectl get pods -l app.kubernetes.io/instance=$(FRONTEND_RELEASE) -n $(NAMESPACE)

# ============================================
# Full Stack Deployment
# ============================================

# Deploy entire stack (backend + frontend)
helm-fullstack: helm-backend helm-frontend
	@echo "✅ Full stack deployment complete!"
	@echo ""
	@echo "🎉 Your application is ready!"
	@echo ""
	@echo "Access instructions:"
	@echo "  Backend:  kubectl port-forward svc/$(RELEASE_NAME) 8000:8000"
	@echo "  Frontend: kubectl port-forward svc/$(FRONTEND_RELEASE) 3000:3000"

# Destroy entire stack
helm-destroy-fullstack: helm-destroy-backend helm-destroy-frontend
	@echo "✅ Full stack destroyed!"

# Update .PHONY
.PHONY: build-frontend load-frontend helm-local-frontend helm-frontend \
	pf-frontend frontend-logs helm-destroy-frontend frontend-status frontend-pods \
	helm-fullstack helm-destroy-fullstack
```

**Why:**
- Consistent with backend commands
- Full stack deployment support
- Easy to use

**Time**: 20 minutes

---

### Phase 7: Documentation

#### ✅ Task 12: Create Frontend Chart README

**File**: `helm_charts/frontend/README.md`

**Content:** (Similar to backend README but for frontend)
- Chart overview
- Configuration options
- Backend connection setup
- Deployment instructions
- Troubleshooting

**Time**: 30 minutes

---

#### ✅ Task 13: Create Frontend QUICK-START

**File**: `helm_charts/frontend/QUICK-START.md`

**Content:**
```markdown
# Frontend Quick Start

Deploy Next.js frontend in 5 minutes!

## Prerequisites
- Backend already deployed (`my-backend`)
- Docker, Kubernetes (minikube/kind), Helm, kubectl

## Quick Deploy

### Step 1: Build Image
```bash
cd frontend
docker build -f Dockerfile.prod -t frontend-app:latest .
```

### Step 2: Load into Cluster
```bash
# Minikube
minikube image load frontend-app:latest

# Kind
kind load docker-image frontend-app:latest
```

### Step 3: Deploy
```bash
cd helm_charts/frontend
./deploy-local.sh my-frontend default my-backend
```

### Step 4: Access
```bash
kubectl port-forward svc/my-frontend 3000:3000
```

Visit: http://localhost:3000

## Backend Connection

Frontend connects to backend via environment variable:
- `BACKEND_URL=http://my-backend:8000`
- Set automatically from `backend.releaseName` in values.yaml

## Make Commands

```bash
# Complete workflow
make helm-frontend

# Just deploy
make helm-local-frontend

# Port forward
make pf-frontend

# View logs
make frontend-logs

# Full stack
make helm-fullstack
```
```

**Time**: 15 minutes

---

#### ✅ Task 14: Update Main README

**File**: `README.md` (root)

**What to add:**
- Frontend deployment section
- Full stack deployment instructions
- Architecture diagram with frontend

**Time**: 10 minutes

---

#### ✅ Task 15: Create Frontend Deployment Guide

**File**: `docs/FRONTEND-DEPLOYMENT.md`

**Content:**
- Detailed deployment instructions
- Backend URL configuration options
- Environment variable explanation
- Troubleshooting frontend-specific issues

**Time**: 30 minutes

---

### Phase 8: Testing & Validation

#### ✅ Task 16: Deploy Backend First

**Commands:**
```bash
make helm-backend
kubectl get pods -l app.kubernetes.io/instance=my-backend
```

**Verify:**
- Backend pod running
- PostgreSQL pod running
- Backend accessible

**Time**: 5 minutes

---

#### ✅ Task 17: Deploy Frontend

**Commands:**
```bash
make helm-frontend
kubectl get pods -l app.kubernetes.io/instance=my-frontend
```

**Verify:**
- Frontend pod running
- No errors in logs

**Time**: 5 minutes

---

#### ✅ Task 18: Test Integration

**Commands:**
```bash
# Port forward both services
kubectl port-forward svc/my-backend 8000:8000 &
kubectl port-forward svc/my-frontend 3000:3000 &

# Test backend directly
curl http://localhost:8000/health

# Test frontend (in browser)
open http://localhost:3000
```

**Verify:**
- Frontend loads
- Can create items
- Items persist in database
- CRUD operations work

**Time**: 10 minutes

---

## 📊 Summary

### Files to Create

| Phase | Files | Count |
|-------|-------|-------|
| Chart Foundation | Chart.yaml, values.yaml | 2 |
| Templates | _helpers.tpl, deployment.yaml, service.yaml, serviceaccount.yaml | 4 |
| Optional | ingress.yaml, hpa.yaml, httproute.yaml | 3 |
| Support | .helmignore, NOTES.txt | 2 |
| Scripts | deploy-local.sh | 1 |
| Makefile | Frontend commands | 1 section |
| Documentation | README.md, QUICK-START.md, deployment guide | 3 |
| **Total** | | **16 files** |

### Time Estimates

- **Chart Setup**: 30 minutes
- **Templates**: 30 minutes  
- **Scripts & Automation**: 35 minutes
- **Documentation**: 1 hour 25 minutes
- **Testing**: 20 minutes
- **Total**: ~3 hours 20 minutes

### Make Commands Added

```bash
# Frontend specific
make build-frontend
make load-frontend
make helm-local-frontend
make helm-frontend
make pf-frontend
make frontend-logs
make helm-destroy-frontend
make frontend-status
make frontend-pods

# Full stack
make helm-fullstack
make helm-destroy-fullstack
```

---

## 🎯 Key Decisions

### 1. Backend URL Configuration

**Decision**: Use runtime environment variable

**Why:**
- No rebuild needed when backend URL changes
- Works in any environment
- Kubernetes DNS for service discovery

**Implementation:**
```yaml
# values.yaml
backend:
  releaseName: "my-backend"  # → http://my-backend:8000
  
# Or custom:
backend:
  customUrl: "http://custom-backend.prod.svc.cluster.local:8000"
```

### 2. No Build-Time Configuration

**Why NOT use Next.js build-time env vars:**
- Would require rebuild for each environment
- Less flexible
- Runtime is better for Kubernetes

**Next.js handles runtime env vars** in API routes:
```typescript
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8000'
```

### 3. Service Discovery

**How it works:**
```
Frontend Pod → BACKEND_URL env var → http://my-backend:8000
                                              ↓
                                      Kubernetes DNS resolves
                                              ↓
                                      Backend Service
                                              ↓
                                      Backend Pods
```

### 4. No Init Container Needed

**Why:**
- Frontend can start independently
- API routes fail gracefully
- User sees loading state
- Eventually connects when backend ready

---

## 🔍 Important Notes

### Backend URL Pattern

**Format**: `http://<release-name>:<port>`

**Examples:**
```yaml
# Same namespace
backend:
  releaseName: "my-backend"
  # Results in: http://my-backend:8000

# Different namespace
backend:
  customUrl: "http://my-backend.production.svc.cluster.local:8000"

# External service
backend:
  customUrl: "https://api.example.com"
```

### Environment Variables in Next.js

**Server-side** (API routes):
```typescript
// ✅ Works - server-side
const BACKEND_URL = process.env.BACKEND_URL
```

**Client-side**:
```typescript
// ❌ Doesn't work - client can't see server env vars
// Next.js would need NEXT_PUBLIC_ prefix for client
```

**Our approach**:
- API routes proxy to backend
- Client makes requests to `/api/items`
- Server-side routes use `BACKEND_URL`

### Testing Checklist

- [ ] Backend deployed and healthy
- [ ] Frontend pod running
- [ ] Frontend can reach backend (check logs)
- [ ] Web UI loads
- [ ] Can create items
- [ ] Can edit items
- [ ] Can delete items
- [ ] Data persists (refresh page)

---

## 📚 Next Steps After Deployment

1. **Add Ingress** - External access
2. **Configure HPA** - Auto-scaling
3. **Add Monitoring** - Prometheus/Grafana
4. **Set up CI/CD** - Automated deployments
5. **Production Secrets** - External secret management

---

## 🆘 Troubleshooting

### Frontend Can't Connect to Backend

**Check:**
```bash
# 1. Verify backend is running
kubectl get pods -l app.kubernetes.io/instance=my-backend

# 2. Check frontend logs
kubectl logs -l app.kubernetes.io/name=frontend

# 3. Check BACKEND_URL env var
kubectl exec -it <frontend-pod> -- env | grep BACKEND_URL

# 4. Test DNS resolution
kubectl exec -it <frontend-pod> -- nslookup my-backend

# 5. Test connectivity
kubectl exec -it <frontend-pod> -- wget -O- http://my-backend:8000/health
```

### Frontend Pod Crash Loop

**Check:**
```bash
# View logs
kubectl logs <frontend-pod>

# Check events
kubectl describe pod <frontend-pod>

# Common issues:
# - Image not loaded
# - Port conflict
# - Resource limits too low
```

### Can't Access Frontend

**Check:**
```bash
# 1. Verify port-forward
kubectl port-forward svc/my-frontend 3000:3000

# 2. Check if service exists
kubectl get svc my-frontend

# 3. Check if pods are ready
kubectl get pods -l app.kubernetes.io/instance=my-frontend
```

---

Ready to start? Begin with **Task 1: Create Chart.yaml** and work through sequentially! 🚀

