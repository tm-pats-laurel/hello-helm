# 🚀 Quick Start Guide

Get your FastAPI backend + PostgreSQL running in Kubernetes in 5 minutes!

## Prerequisites

- ✅ Docker installed
- ✅ Kubernetes cluster running (minikube/kind/Docker Desktop)
- ✅ Helm 3.x installed
- ✅ kubectl installed and configured

## 3-Step Deployment

### Step 1: Build the Image

```bash
cd /home/pats/practice/hello-helm/backend
docker build -f Dockerfile.prod -t backend-app:latest .
```

### Step 2: Load Image into Cluster

**Minikube:**
```bash
minikube image load backend-app:latest
```

**Kind:**
```bash
kind load docker-image backend-app:latest
```

**Docker Desktop:**
Skip this step - images are automatically available!

### Step 3: Deploy with Helm

```bash
cd /home/pats/practice/hello-helm/helm_charts/backend
./deploy-local.sh my-backend
```

That's it! 🎉

## Verify Deployment

```bash
# Check pods
kubectl get pods

# You should see:
# NAME                           READY   STATUS    RESTARTS   AGE
# my-backend-xxxxxxxxx-xxxxx     1/1     Running   0          1m
# my-backend-postgres-0          1/1     Running   0          1m
```

## Access Your API

```bash
# Port forward
kubectl port-forward svc/my-backend 8000:8000

# In another terminal or browser:
curl http://localhost:8000/health
# {"status":"ok"}

# Open API docs
open http://localhost:8000/docs
```

## Test It

```bash
# Create an item
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"title":"Hello Kubernetes","description":"My first K8s deployment!"}'

# List items
curl http://localhost:8000/items
```

## What Just Happened?

Your Helm chart deployed:

1. **FastAPI Backend** - Your Python application
2. **PostgreSQL 15** - Database with persistent storage
3. **Secret** - Database credentials (secure!)
4. **Services** - Networking between components
5. **Init Container** - Waits for DB before starting backend

## Useful Commands

```bash
# View logs
kubectl logs -l app.kubernetes.io/name=backend -f

# View all resources
kubectl get all -l app.kubernetes.io/instance=my-backend

# Access PostgreSQL
kubectl port-forward svc/my-backend-postgres 5432:5432
psql -h localhost -U appuser -d appdb

# Restart backend (after code changes)
kubectl rollout restart deployment/my-backend

# Uninstall everything
helm uninstall my-backend
kubectl delete pvc postgres-data-my-backend-postgres-0
```

## Make Changes

### Update Your Code

```bash
# 1. Edit code in backend/app/
# 2. Rebuild image
cd backend
docker build -f Dockerfile.prod -t backend-app:latest .

# 3. Reload into cluster
minikube image load backend-app:latest  # or kind load

# 4. Restart pods
kubectl rollout restart deployment/my-backend
```

### Update Configuration

```bash
# Edit values.yaml, then:
helm upgrade my-backend .
```

## Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**Image not found?**
```bash
# Verify image is loaded
minikube image ls | grep backend-app
# Or reload it
minikube image load backend-app:latest
```

**Can't connect to database?**
```bash
kubectl logs my-backend-postgres-0
kubectl get pvc
```

## Next Steps

- 📚 Read [STRUCTURE.md](STRUCTURE.md) to understand the chart
- 📖 Check [README.md](README.md) for detailed documentation
- 🔄 See [DOCKER-COMPOSE-VS-HELM.md](../../docs/DOCKER-COMPOSE-VS-HELM.md) for concept mapping
- 🚢 Review [DEPLOYMENT.md](../../docs/DEPLOYMENT.md) for full deployment guide

## Need Help?

Check the full documentation:
- [Backend Helm Chart README](README.md)
- [Deployment Guide](../../docs/DEPLOYMENT.md)
- [Structure Documentation](STRUCTURE.md)

Happy Helming! ⎈

