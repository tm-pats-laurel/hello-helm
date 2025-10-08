# Frontend Quick Start

Deploy Next.js frontend in 5 minutes!

## Prerequisites

✅ Backend deployed (`make helm-backend`)  
✅ Docker, Kubernetes, Helm, kubectl installed  
✅ Minikube/kind running

## Deploy in 3 Steps

### Step 1: Build & Load Image

```bash
# Build
cd frontend
docker build -f Dockerfile.prod -t frontend-app:latest .

# Load into cluster
minikube image load frontend-app:latest
# OR for kind:
# kind load docker-image frontend-app:latest
```

### Step 2: Deploy with Helm

```bash
cd ../helm_charts/frontend

# Option A: Use script (recommended)
./deploy-local.sh

# Option B: Manual
helm install my-frontend . --set backend.releaseName=my-backend
```

### Step 3: Access

```bash
kubectl port-forward svc/my-frontend 3000:3000
```

Open: **http://localhost:3000**

## Even Faster: Use Make

```bash
# From project root - does everything!
make helm-frontend

# Access
make pf-frontend
```

## Verify It Works

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/instance=my-frontend

# View logs
kubectl logs -l app.kubernetes.io/name=frontend -f

# Check backend connection
kubectl logs -l app.kubernetes.io/name=frontend | grep "http://my-backend:8000"
```

## Test the Application

1. Open http://localhost:3000
2. Create an item (form on page)
3. See it appear in the list
4. Edit/delete items
5. Refresh page - data persists!

## Backend Connection

Frontend automatically connects to backend via:
```
BACKEND_URL=http://my-backend:8000
```

**How it works:**
- Browser → `http://localhost:3000/api/items`
- Next.js API route → `http://my-backend:8000/items` (internal)
- FastAPI → PostgreSQL
- Response back to browser

## Make Commands

```bash
make helm-frontend          # Complete deployment
make pf-frontend           # Port-forward to 3000
make frontend-logs         # View logs
make frontend-status       # Check resources
make helm-destroy-frontend # Clean up
```

## Full Stack Deployment

Deploy everything at once:

```bash
make helm-fullstack

# Access frontend
make pf-frontend
# → http://localhost:3000

# Access backend (optional)
make pf-backend
# → http://localhost:8000/docs
```

## Troubleshooting

### Image not found?
```bash
# Minikube
minikube image load frontend-app:latest

# Kind
kind load docker-image frontend-app:latest
```

### Pod not starting?
```bash
kubectl describe pod -l app.kubernetes.io/name=frontend
kubectl logs -l app.kubernetes.io/name=frontend
```

### Can't connect to backend?
```bash
# Verify backend is running
kubectl get pods -l app.kubernetes.io/instance=my-backend

# Test from frontend pod
kubectl exec -it <frontend-pod> -- wget -O- http://my-backend:8000/health
```

## Clean Up

```bash
# Frontend only
make helm-destroy-frontend

# Everything (backend + frontend)
make helm-destroy-fullstack
```

## Next Steps

- Read [README.md](README.md) for full documentation
- See [STRUCTURE.md](STRUCTURE.md) for chart internals
- Check [../../docs/](../../docs/) for project docs

Happy deploying! 🚀

