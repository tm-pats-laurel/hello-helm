# Makefile Commands Guide

Quick reference for managing your full-stack application with Make.

## 🚀 Quick Start

### Deploy Backend to Kubernetes (One Command)

```bash
make helm-backend
```

This will:
1. Build the production Docker image
2. Load it into minikube
3. Deploy with Helm

Then access it:
```bash
make pf-backend
# Visit: http://localhost:8000/docs
```

## 📋 All Available Commands

### Docker Compose (Local Development)

```bash
make local-backend        # Run backend only with Docker Compose
make local-frontend       # Run frontend only with Docker Compose
make local-env           # Run full stack with Docker Compose
```

### Backend Helm Deployment

```bash
make build-backend        # Build production backend image
make load-backend         # Load backend image into minikube
make helm-local-backend   # Deploy backend with Helm
make helm-backend         # Build + Load + Deploy (complete workflow)
make helm-destroy-backend # Destroy backend deployment & clean up
```

### Backend Operations

```bash
make pf-backend           # Port-forward backend (http://localhost:8000)
make backend-logs         # View backend application logs (follows)
make backend-status       # Show all backend resources
make backend-pods         # Show backend pods
```

### PostgreSQL Operations

```bash
make postgres-logs        # View PostgreSQL logs (follows)
make pf-postgres          # Port-forward PostgreSQL (localhost:5432)
```

### Help

```bash
make help                 # Show all available commands
```

## 🎯 Common Workflows

### First Time Setup

```bash
# Start minikube
minikube start

# Deploy everything
make helm-backend

# Check status
make backend-status

# Access API
make pf-backend
# Then visit: http://localhost:8000/docs
```

### Development Cycle

```bash
# 1. Make code changes in backend/app/

# 2. Rebuild and redeploy
make helm-backend

# 3. Check logs
make backend-logs

# 4. Test
make pf-backend
curl http://localhost:8000/health
```

### Viewing Logs

```bash
# Backend application logs
make backend-logs

# PostgreSQL logs
make postgres-logs

# Both in separate terminals
make backend-logs &
make postgres-logs &
```

### Accessing Services

```bash
# Backend API (in one terminal)
make pf-backend
# Visit: http://localhost:8000/docs

# PostgreSQL (in another terminal)
make pf-postgres
# Connect: psql -h localhost -U appuser -d appdb
```

### Cleanup

```bash
# Destroy all backend resources (including database)
make helm-destroy-backend

# Or just uninstall Helm release (keeps PVC)
helm uninstall my-backend
```

## 🔧 Customization

You can override default variables:

```bash
# Use different image name/tag
make build-backend BACKEND_IMAGE=myapp BACKEND_TAG=v1.2.3

# Use different release name
make helm-backend RELEASE_NAME=dev-backend

# Use different namespace
make backend-status NAMESPACE=staging
```

### Default Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKEND_IMAGE` | `backend-app` | Docker image name |
| `BACKEND_TAG` | `latest` | Docker image tag |
| `RELEASE_NAME` | `my-backend` | Helm release name |
| `NAMESPACE` | `default` | Kubernetes namespace |

### Examples

```bash
# Deploy with custom image tag
make helm-backend BACKEND_TAG=v2.0.0

# View logs from different release
make backend-logs RELEASE_NAME=staging-backend

# Deploy to different namespace
make helm-local-backend NAMESPACE=development
```

## 📝 Command Details

### `make build-backend`

Builds the production Docker image using `Dockerfile.prod`.

**What it does:**
```bash
cd backend && docker build -f Dockerfile.prod -t backend-app:latest .
```

**When to use:** After making code changes

### `make load-backend`

Loads the Docker image into minikube's Docker daemon.

**What it does:**
```bash
minikube image load backend-app:latest
```

**When to use:** After building image, before deploying

**Note:** For kind, use: `kind load docker-image backend-app:latest`

### `make helm-local-backend`

Deploys backend using the automated deployment script.

**What it does:**
```bash
cd helm_charts/backend && ./deploy-local.sh my-backend
```

**When to use:** After image is loaded into cluster

### `make helm-backend`

Complete workflow: build → load → deploy.

**What it does:** Runs build-backend, load-backend, and helm-local-backend in sequence.

**When to use:** Complete deployment from scratch or after code changes

### `make pf-backend`

Port-forwards the backend service to localhost:8000.

**What it does:**
```bash
kubectl port-forward svc/my-backend 8000:8000
```

**When to use:** To access the API locally

**Access:**
- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- Health: http://localhost:8000/health

### `make backend-logs`

Shows live logs from the backend application.

**What it does:**
```bash
kubectl logs -l app.kubernetes.io/name=backend -f
```

**When to use:** Debugging, monitoring

**Tip:** Press `Ctrl+C` to stop following logs

### `make backend-status`

Shows all Kubernetes resources for the backend deployment.

**Shows:**
- Pods
- Services
- Deployments
- ReplicaSets
- StatefulSets (PostgreSQL)

**When to use:** Check deployment health, troubleshooting

### `make backend-pods`

Shows just the pods for quick status check.

**When to use:** Quick health check

### `make helm-destroy-backend`

Completely removes the backend deployment and all resources.

**What it does:**
1. Uninstalls Helm release
2. Deletes PVC (removes database data!)

**⚠️ Warning:** This deletes all database data!

**When to use:** Starting fresh, cleaning up

### `make postgres-logs`

Shows live logs from PostgreSQL.

**When to use:** Database troubleshooting

### `make pf-postgres`

Port-forwards PostgreSQL to localhost:5432.

**Connect with:**
```bash
psql -h localhost -U appuser -d appdb
# Password: supersecret
```

## 🐛 Troubleshooting

### "No rule to make target"

Make sure you're in the project root directory:
```bash
cd /home/pats/practice/hello-helm
make help
```

### Image not found in minikube

Rebuild and reload:
```bash
make build-backend
make load-backend
```

Or just:
```bash
make helm-backend
```

### Pods stuck in Init

Check if PostgreSQL is ready:
```bash
make backend-pods
make postgres-logs
```

### Can't connect after port-forward

Make sure pod is running:
```bash
make backend-pods
```

Check logs for errors:
```bash
make backend-logs
```

### Changes not reflected

Rebuild and redeploy:
```bash
make helm-backend
```

Or restart deployment:
```bash
kubectl rollout restart deployment/my-backend
```

## 📚 Related Documentation

- [QUICK-START.md](../helm_charts/backend/QUICK-START.md) - 5-minute deployment guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Comprehensive deployment guide
- [HELM-LEARNING-GUIDE.md](HELM-LEARNING-GUIDE.md) - Learn Helm concepts
- [Backend Helm Chart README](../helm_charts/backend/README.md) - Chart documentation

## 💡 Tips

1. **Always check status:** `make backend-status` is your friend
2. **Watch logs:** Run `make backend-logs` in a separate terminal
3. **Use help:** `make help` shows all commands
4. **Override variables:** Customize with `make command VAR=value`
5. **Clean slate:** `make helm-destroy-backend` removes everything

## 🎯 Examples

### Deploy and test

```bash
# Deploy
make helm-backend

# Check status
make backend-status

# Access API (in terminal 1)
make pf-backend

# View logs (in terminal 2)
make backend-logs

# Test API (in terminal 3)
curl http://localhost:8000/health
curl http://localhost:8000/items
```

### Update code

```bash
# Edit code
vim backend/app/main.py

# Rebuild and redeploy
make helm-backend

# Check logs
make backend-logs

# Test
make pf-backend
```

### Database access

```bash
# Port-forward PostgreSQL
make pf-postgres

# In another terminal
psql -h localhost -U appuser -d appdb

# Run queries
SELECT * FROM items;
```

### Complete cleanup

```bash
# Remove everything
make helm-destroy-backend

# Verify
kubectl get all -l app.kubernetes.io/instance=my-backend
# Should show: No resources found
```

---

**Pro tip:** Add `alias k=kubectl` and `alias h=helm` to your `.zshrc` for faster typing! 🚀

