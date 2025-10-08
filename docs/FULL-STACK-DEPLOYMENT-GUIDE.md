# Full-Stack Deployment Guide

Complete guide for deploying the Next.js + FastAPI full-stack application with Helm on Kubernetes.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start (5 minutes)](#quick-start-5-minutes)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Verification](#verification)
6. [Accessing Services](#accessing-services)
7. [Troubleshooting](#troubleshooting)
8. [Cleanup](#cleanup)

## Overview

**What you'll deploy:**

```
┌─────────────────────────────────────────────┐
│         Kubernetes Cluster                  │
│                                             │
│  ┌──────────────┐    ┌──────────────┐     │
│  │   Frontend   │───▶│   Backend    │     │
│  │   Next.js    │    │   FastAPI    │     │
│  │   Port 3000  │    │   Port 8000  │     │
│  └──────────────┘    └──────────────┘     │
│                              │             │
│                      ┌───────▼────────┐    │
│                      │   PostgreSQL   │    │
│                      │   Port 5432    │    │
│                      └────────────────┘    │
└─────────────────────────────────────────────┘
```

**Components:**
- **Frontend**: Next.js 15 (React, TypeScript, Tailwind CSS)
- **Backend**: FastAPI (Python, async)
- **Database**: PostgreSQL 15 (StatefulSet with persistent storage)

**Communication:**
- Frontend → Backend: Kubernetes DNS (`http://my-backend:8000`)
- Backend → Database: Kubernetes DNS (`my-backend-postgres:5432`)
- Browser → Frontend: Port-forward (`localhost:3000`)

## Prerequisites

### Required Tools

```bash
# Check if installed
docker --version
kubectl version --client
helm version
minikube version  # OR kind version

# Install if missing:
# - Docker: https://docs.docker.com/get-docker/
# - kubectl: https://kubernetes.io/docs/tasks/tools/
# - Helm: https://helm.sh/docs/intro/install/
# - minikube: https://minikube.sigs.k8s.io/docs/start/
# - kind: https://kind.sigs.k8s.io/docs/user/quick-start/
```

### Start Kubernetes

**Minikube:**
```bash
minikube start --driver=docker
minikube status
```

**Kind:**
```bash
kind create cluster --name hello-helm
kubectl cluster-info
```

**Docker Desktop:**
- Enable Kubernetes in settings
- Wait for it to start

### Verify Setup

```bash
kubectl get nodes
# Should show 1+ nodes in Ready state

kubectl get namespaces
# Should list default namespace
```

## Quick Start (5 minutes)

For those who want to deploy immediately:

```bash
# Clone repository
cd /home/pats/practice/hello-helm

# Deploy everything
make helm-fullstack

# Wait for pods to be ready (1-2 minutes)
kubectl get pods -w
# Ctrl+C when all show 1/1 READY

# Access frontend
make pf-frontend
# Open: http://localhost:3000

# (Optional) Access backend
make pf-backend
# Open: http://localhost:8000/docs
```

**That's it!** Your full-stack app is running.

## Step-by-Step Deployment

### Step 1: Deploy Backend

#### 1.1 Build Backend Image

```bash
cd /home/pats/practice/hello-helm
make build-backend
```

**What this does:**
- Builds production Docker image from `backend/Dockerfile.prod`
- Multi-stage build (dependencies → app)
- Tags as `backend-app:latest`

#### 1.2 Load Image into Cluster

```bash
make load-backend
```

**Minikube:** Loads image into minikube's Docker daemon  
**Kind:** Loads image into kind cluster nodes

#### 1.3 Deploy with Helm

```bash
make helm-local-backend
```

**What this deploys:**
- Backend Deployment (FastAPI app)
- PostgreSQL StatefulSet (persistent database)
- Services (ClusterIP for both)
- Secret (database credentials)
- PersistentVolumeClaim (1Gi for PostgreSQL)

#### 1.4 Verify Backend

```bash
# Check pods
kubectl get pods

# Should see:
# my-backend-xxxxx       1/1  Running
# my-backend-postgres-0  1/1  Running

# View logs
kubectl logs -l app.kubernetes.io/name=backend -f
```

### Step 2: Deploy Frontend

#### 2.1 Build Frontend Image

```bash
make build-frontend
```

**What this does:**
- Builds production Next.js image from `frontend/Dockerfile.prod`
- Multi-stage build (deps → build → production)
- Tags as `frontend-app:latest`

#### 2.2 Load Image into Cluster

```bash
make load-frontend
```

#### 2.3 Deploy with Helm

```bash
make helm-local-frontend
```

**What this deploys:**
- Frontend Deployment (Next.js app)
- Service (ClusterIP on port 3000)
- ServiceAccount
- Injects `BACKEND_URL=http://my-backend:8000`

#### 2.4 Verify Frontend

```bash
# Check pods
kubectl get pods

# Should see:
# my-frontend-xxxxx      1/1  Running
# my-backend-xxxxx       1/1  Running
# my-backend-postgres-0  1/1  Running

# View logs
kubectl logs -l app.kubernetes.io/name=frontend -f
```

### Step 3: All-in-One (Alternative)

Instead of Steps 1-2, run:

```bash
make helm-fullstack
```

This runs:
1. `make helm-backend` (build, load, deploy backend)
2. `make helm-frontend` (build, load, deploy frontend)

## Verification

### Check All Resources

```bash
# Pods
kubectl get pods

# Services
kubectl get svc

# StatefulSets
kubectl get statefulset

# PVCs
kubectl get pvc

# Secrets
kubectl get secrets
```

### Check Logs

```bash
# Frontend logs
make frontend-logs

# Backend logs
make backend-logs

# PostgreSQL logs
make postgres-logs
```

### Test Backend Health

```bash
# Port-forward backend
make pf-backend &

# Test health endpoint
curl http://localhost:8000/health
# Should return: {"status":"healthy"}

# Test API
curl http://localhost:8000/items
# Should return: []
```

### Test Frontend-Backend Connection

```bash
# Port-forward frontend
make pf-frontend &

# From frontend pod, test backend
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].metadata.name}') -- \
  wget -O- http://my-backend:8000/health

# Should return: {"status":"healthy"}
```

## Accessing Services

### Access Frontend

```bash
# Terminal 1: Port-forward
make pf-frontend

# Open browser
# → http://localhost:3000
```

**What you'll see:**
- Items Manager UI
- Form to create items
- List of items (initially empty)

### Access Backend (Optional)

```bash
# Terminal 2: Port-forward
make pf-backend

# Open browser
# → http://localhost:8000/docs
```

**What you'll see:**
- FastAPI Swagger UI
- Interactive API documentation
- Try endpoints directly

### Access PostgreSQL (Advanced)

```bash
# Terminal 3: Port-forward
make pf-postgres

# Connect with psql
psql -h localhost -U appuser -d appdb
# Password: supersecret

# Inside psql:
\dt            # List tables
SELECT * FROM items;
```

## Test Full-Stack Flow

### Create an Item

1. Open http://localhost:3000
2. Fill form: Name = "Test Item", Description = "My first item"
3. Click "Add Item"
4. See item appear in list below

**What happens:**
```
Browser → POST /api/items
   ↓
Next.js API Route (frontend pod)
   ↓
http://my-backend:8000/items
   ↓
FastAPI Backend
   ↓
PostgreSQL Database
   ↓
Response back to browser
```

### Verify Persistence

```bash
# Restart frontend pod
kubectl delete pod -l app.kubernetes.io/name=frontend

# Wait for new pod
kubectl get pods -w

# Port-forward again
make pf-frontend

# Refresh browser
# → Items still there! (data in PostgreSQL)
```

### Check Backend Logs

```bash
make backend-logs

# You should see:
# POST /items - 200 OK
# GET /items - 200 OK
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods

# Describe problematic pod
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Common issues:
# - Image not loaded → run make load-backend or make load-frontend
# - Resource limits → check cluster resources (kubectl top nodes)
# - Init container failing → wait for dependencies
```

### Image Pull Errors

```bash
# ImagePullBackOff or ErrImagePull

# Solution: Ensure image is loaded
make load-backend
make load-frontend

# Verify images in cluster
minikube image ls | grep -E "backend-app|frontend-app"
# OR
docker exec -it kind-control-plane crictl images | grep -E "backend-app|frontend-app"
```

### Frontend Can't Connect to Backend

```bash
# Check BACKEND_URL environment variable
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].metadata.name}') -- \
  env | grep BACKEND_URL

# Should show: BACKEND_URL=http://my-backend:8000

# Test connection from frontend pod
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].metadata.name}') -- \
  wget -O- http://my-backend:8000/health

# Should return: {"status":"healthy"}
```

### Backend Can't Connect to Database

```bash
# Check PostgreSQL pod
kubectl get pod -l app.kubernetes.io/component=database

# Check database logs
make postgres-logs

# Check backend environment variables
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=backend -o jsonpath='{.items[0].metadata.name}') -- \
  env | grep DB_

# Should show:
# DB_HOST=my-backend-postgres
# DB_NAME=appdb
# DB_USER=appuser
# DB_PASSWORD=supersecret
```

### Port-Forward Not Working

```bash
# Kill existing port-forwards
pkill -f "kubectl port-forward"

# Check if ports are in use
lsof -i :3000
lsof -i :8000

# Try again
make pf-frontend
```

### Database Data Lost After Restart

```bash
# Check PVC status
kubectl get pvc

# Should show:
# postgres-data-my-backend-postgres-0  Bound

# If missing, recreate
kubectl delete statefulset my-backend-postgres
helm upgrade my-backend helm_charts/backend/
```

### Helm Release Issues

```bash
# Check release status
helm list

# See release history
helm history my-backend
helm history my-frontend

# Rollback if needed
helm rollback my-backend
helm rollback my-frontend

# Force reinstall
make helm-destroy-fullstack
make helm-fullstack
```

## Advanced Operations

### Update Backend Image

```bash
# Make code changes
cd backend

# Rebuild
make build-backend
make load-backend

# Upgrade release (triggers rolling update)
helm upgrade my-backend helm_charts/backend/ --set image.tag=latest

# Watch rollout
kubectl rollout status deployment/my-backend
```

### Update Frontend Image

```bash
# Make code changes
cd frontend

# Rebuild
make build-frontend
make load-frontend

# Upgrade release
helm upgrade my-frontend helm_charts/frontend/ --set image.tag=latest

# Watch rollout
kubectl rollout status deployment/my-frontend
```

### Scale Replicas

```bash
# Scale frontend
kubectl scale deployment/my-frontend --replicas=3

# Check pods
kubectl get pods -l app.kubernetes.io/name=frontend

# Scale back
kubectl scale deployment/my-frontend --replicas=1
```

### View Resource Usage

```bash
# Enable metrics server (if not enabled)
minikube addons enable metrics-server

# View node resources
kubectl top nodes

# View pod resources
kubectl top pods
```

### Change Backend Release Name

```bash
# Deploy backend with custom name
helm install custom-backend helm_charts/backend/

# Deploy frontend pointing to custom backend
helm install my-frontend helm_charts/frontend/ \
  --set backend.releaseName=custom-backend
```

## Cleanup

### Remove Everything

```bash
make helm-destroy-fullstack
```

**This removes:**
- Frontend deployment and service
- Backend deployment and service
- PostgreSQL StatefulSet and service
- PVC (database storage)
- Secrets
- ServiceAccounts

### Remove Backend Only

```bash
make helm-destroy-backend
```

### Remove Frontend Only

```bash
make helm-destroy-frontend
```

### Stop Kubernetes Cluster

**Minikube:**
```bash
minikube stop
# OR completely delete:
minikube delete
```

**Kind:**
```bash
kind delete cluster --name hello-helm
```

**Docker Desktop:**
- Disable Kubernetes in settings

## Configuration Options

### Backend Configuration

Edit `helm_charts/backend/values.yaml`:

```yaml
# Change database credentials
postgres:
  auth:
    database: mydb
    username: myuser
    password: mypassword

# Adjust resources
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
```

Apply:
```bash
helm upgrade my-backend helm_charts/backend/
```

### Frontend Configuration

Edit `helm_charts/frontend/values.yaml`:

```yaml
# Change backend connection
backend:
  releaseName: "custom-backend"
  port: 8000

# Adjust resources
resources:
  limits:
    cpu: 1000m
    memory: 1Gi

# Enable autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
```

Apply:
```bash
helm upgrade my-frontend helm_charts/frontend/
```

## Make Command Reference

```bash
# Backend
make build-backend        # Build image
make load-backend        # Load into cluster
make helm-backend        # Complete workflow
make pf-backend          # Port-forward
make backend-logs        # View logs
make backend-status      # Show resources
make helm-destroy-backend # Clean up

# Frontend
make build-frontend       # Build image
make load-frontend       # Load into cluster
make helm-frontend       # Complete workflow
make pf-frontend         # Port-forward
make frontend-logs       # View logs
make frontend-status     # Show resources
make helm-destroy-frontend # Clean up

# Full Stack
make helm-fullstack       # Deploy everything
make helm-destroy-fullstack # Remove everything

# Database
make postgres-logs       # View PostgreSQL logs
make pf-postgres         # Port-forward PostgreSQL

# Help
make help                # Show all commands
```

## Next Steps

1. **Customize**: Edit `values.yaml` files for your needs
2. **Add Ingress**: Enable external access without port-forwarding
3. **Enable TLS**: Add SSL certificates
4. **Add Monitoring**: Prometheus + Grafana
5. **CI/CD**: Automate deployments with GitHub Actions
6. **Production**: Deploy to cloud Kubernetes (EKS, GKE, AKS)

## Resources

- [Backend Chart README](../helm_charts/backend/README.md)
- [Frontend Chart README](../helm_charts/frontend/README.md)
- [Backend Quick Start](../helm_charts/backend/QUICK-START.md)
- [Frontend Quick Start](../helm_charts/frontend/QUICK-START.md)
- [Makefile Guide](MAKEFILE-GUIDE.md)
- [Helm Learning Guide](HELM-LEARNING-GUIDE.md)

---

**Need help?** Check the troubleshooting section or consult the chart-specific README files.

Happy deploying! 🚀⎈

