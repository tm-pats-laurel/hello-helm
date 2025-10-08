# Deployment Guide: FastAPI Backend with Helm

This guide shows you how to deploy your FastAPI backend with PostgreSQL using Helm charts to a local Kubernetes cluster.

## Prerequisites

1. **Kubernetes Cluster** (choose one):
   - [Minikube](https://minikube.sigs.k8s.io/docs/start/)
   - [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
   - Docker Desktop with Kubernetes enabled

2. **Tools**:
   - Docker
   - Helm 3.x: `brew install helm` or [Install Guide](https://helm.sh/docs/intro/install/)
   - kubectl: Should come with your Kubernetes setup

## Quick Start (Local Development)

### Step 1: Start Your Kubernetes Cluster

**For Minikube:**
```bash
minikube start
# Verify
kubectl get nodes
```

**For Kind:**
```bash
kind create cluster --name hello-helm
# Verify
kubectl cluster-info --context kind-hello-helm
```

**For Docker Desktop:**
- Go to Docker Desktop settings
- Enable Kubernetes
- Click "Apply & Restart"

### Step 2: Build Your Backend Image

```bash
cd backend
docker build -f Dockerfile.prod -t backend-app:latest .
```

### Step 3: Load Image into Cluster

**For Minikube:**
```bash
minikube image load backend-app:latest
```

**For Kind:**
```bash
kind load docker-image backend-app:latest --name hello-helm
```

**For Docker Desktop:**
No need to load - it uses your local Docker images directly!

### Step 4: Deploy with Helm

**Option A: Quick Deploy (Automated)**
```bash
cd /home/pats/practice/hello-helm/helm_charts/backend
chmod +x deploy-local.sh
./deploy-local.sh my-backend
```

**Option B: Manual Deploy**
```bash
cd /home/pats/practice/hello-helm/helm_charts/backend

# Install the chart
helm install my-backend .

# Or with custom values
helm install my-backend . -f values-local.yaml
```

### Step 5: Check Deployment Status

```bash
# Watch pods come up
kubectl get pods -w

# Check all resources
kubectl get all

# Specific to this release
kubectl get pods -l app.kubernetes.io/instance=my-backend
```

You should see something like:
```
NAME                         READY   STATUS    RESTARTS   AGE
my-backend-xxxxxxxxx-xxxxx   1/1     Running   0          30s
my-backend-postgres-0        1/1     Running   0          30s
```

### Step 6: Access Your Application

```bash
# Port forward the backend service
kubectl port-forward svc/my-backend 8000:8000
```

Now open your browser:
- Health check: http://localhost:8000/health
- API docs: http://localhost:8000/docs
- Test the API: http://localhost:8000/items

### Step 7: Test the Application

```bash
# Create an item
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Item", "description": "From Kubernetes!"}'

# List items
curl http://localhost:8000/items

# Health check
curl http://localhost:8000/health
```

## Viewing Logs

```bash
# Backend logs
kubectl logs -l app.kubernetes.io/name=backend -f

# PostgreSQL logs
kubectl logs -l app.kubernetes.io/component=database -f

# Specific pod
kubectl logs my-backend-xxxxxxxxx-xxxxx -f
```

## Making Changes

### Update Application Code

1. Make changes to your FastAPI code
2. Rebuild the image:
   ```bash
   cd backend
   docker build -f Dockerfile.prod -t backend-app:latest .
   ```
3. Reload into cluster:
   ```bash
   # Minikube
   minikube image load backend-app:latest
   
   # Kind
   kind load docker-image backend-app:latest
   ```
4. Restart pods:
   ```bash
   kubectl rollout restart deployment/my-backend
   ```

### Update Helm Configuration

```bash
# Edit values.yaml, then:
helm upgrade my-backend helm_charts/backend/

# Or specify a values file:
helm upgrade my-backend helm_charts/backend/ -f custom-values.yaml
```

## Accessing PostgreSQL Directly

```bash
# Port forward PostgreSQL
kubectl port-forward svc/my-backend-postgres 5432:5432

# In another terminal, connect with psql
psql -h localhost -U appuser -d appdb
# Password: supersecret

# Or using kubectl exec
kubectl exec -it my-backend-postgres-0 -- psql -U appuser -d appdb
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe the pod to see events
kubectl describe pod <pod-name>

# Check init container logs (waits for postgres)
kubectl logs <pod-name> -c wait-for-postgres

# Check main container logs
kubectl logs <pod-name> -c backend
```

### Image Pull Errors

If you see `ImagePullBackOff`:
```bash
# Make sure image is loaded
minikube image ls | grep backend-app
kind load docker-image backend-app:latest

# Or change imagePullPolicy to IfNotPresent in values.yaml
```

### Database Connection Issues

```bash
# Check if postgres is running
kubectl get pods -l app.kubernetes.io/component=database

# Check postgres logs
kubectl logs my-backend-postgres-0

# Verify secret
kubectl get secret my-backend-postgres-secret -o yaml

# Test connection from backend pod
kubectl exec -it <backend-pod> -- env | grep DB_
```

### Storage Issues (PVC Pending)

```bash
# Check PVC status
kubectl get pvc

# For minikube, enable storage addon
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# For kind, it uses local storage by default
```

## Cleanup

### Uninstall Release
```bash
helm uninstall my-backend
```

### Delete PVC (if needed)
```bash
kubectl get pvc
kubectl delete pvc postgres-data-my-backend-postgres-0
```

### Stop Cluster
```bash
# Minikube
minikube stop

# Kind
kind delete cluster --name hello-helm
```

## Understanding What Was Deployed

Your Helm chart created:

1. **Backend Deployment**
   - Runs your FastAPI application
   - Has an init container that waits for PostgreSQL
   - Reads DB credentials from a Secret
   - Exposes port 8000

2. **Backend Service**
   - ClusterIP service
   - Routes traffic to backend pods
   - Named: `my-backend`

3. **PostgreSQL StatefulSet**
   - Runs PostgreSQL 15
   - Has persistent storage (1Gi)
   - Named: `my-backend-postgres`

4. **PostgreSQL Service**
   - Headless service for StatefulSet
   - Provides stable network identity
   - Named: `my-backend-postgres`

5. **Secret**
   - Contains database credentials
   - Named: `my-backend-postgres-secret`
   - Keys: username, password, database

6. **PersistentVolumeClaim**
   - 1Gi storage for PostgreSQL data
   - Survives pod restarts
   - Named: `postgres-data-my-backend-postgres-0`

## Next Steps

1. **Add the Frontend**: Deploy the frontend chart similarly
2. **Set up Ingress**: Use nginx-ingress for external access
3. **Add Monitoring**: Install Prometheus & Grafana
4. **CI/CD**: Automate builds and deployments
5. **Production**: Use proper secrets management, resource limits, etc.

## Useful Helm Commands

```bash
# List all releases
helm list

# Get release status
helm status my-backend

# Get release values
helm get values my-backend

# Rollback to previous version
helm rollback my-backend

# Show all resources
helm get manifest my-backend

# Dry run / debug
helm install my-backend . --dry-run --debug

# Template without installing
helm template my-backend .
```

## Resources

- [Helm Chart Documentation](../helm_charts/backend/README.md)
- [Helm Official Docs](https://helm.sh/docs/)
- [Kubernetes Tutorials](https://kubernetes.io/docs/tutorials/)
- [FastAPI Deployment Guide](https://fastapi.tiangolo.com/deployment/)

