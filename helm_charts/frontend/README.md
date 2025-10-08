# Frontend Helm Chart

Helm chart for deploying the Next.js frontend application on Kubernetes.

## Overview

This chart deploys:
- **Next.js 15** application (React, TypeScript, Tailwind)
- **Service** on port 3000 (ClusterIP)
- **Backend connection** via environment variable

## Prerequisites

- Kubernetes cluster (minikube, kind, or Docker Desktop)
- Helm 3.x
- kubectl configured
- Backend already deployed (`my-backend`)

## Quick Start

```bash
# Build and load image
cd /home/pats/practice/hello-helm/frontend
docker build -f Dockerfile.prod -t frontend-app:latest .
minikube image load frontend-app:latest  # or: kind load docker-image

# Deploy
cd ../helm_charts/frontend
helm install my-frontend . --set backend.releaseName=my-backend

# Access
kubectl port-forward svc/my-frontend 3000:3000
```

Visit: http://localhost:3000

## Configuration

### Key Values

```yaml
# Image
image:
  repository: frontend-app
  tag: latest
  pullPolicy: IfNotPresent

# Service
service:
  type: ClusterIP
  port: 3000

# Backend connection
backend:
  releaseName: "my-backend"  # Backend Helm release name
  port: 8000
  # OR use custom URL:
  # customUrl: "http://backend.prod.svc.cluster.local:8000"

# Resources
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Environment
env:
  NODE_ENV: "production"
```

### Backend Connection

**How it works:**
1. Set `backend.releaseName` in values.yaml
2. Helm generates: `BACKEND_URL=http://my-backend:8000`
3. Next.js API routes use this to proxy requests
4. Kubernetes DNS resolves `my-backend` to backend service

**Example configurations:**

```yaml
# Same namespace (default)
backend:
  releaseName: "my-backend"

# Different namespace
backend:
  customUrl: "http://my-backend.production.svc.cluster.local:8000"

# External API
backend:
  customUrl: "https://api.example.com"
```

## Installation

### Standard Installation

```bash
helm install my-frontend .
```

### Custom Values

```bash
# With custom backend
helm install my-frontend . \
  --set backend.releaseName=custom-backend

# With custom values file
helm install my-frontend . -f values-prod.yaml

# Different namespace
helm install my-frontend . -n production --create-namespace
```

### Using the Deployment Script

```bash
# Automated: build, load, deploy
./deploy-local.sh my-frontend default my-backend

# Arguments:
# $1 = Frontend release name
# $2 = Namespace
# $3 = Backend release name
```

## Upgrade

```bash
# Change backend connection
helm upgrade my-frontend . \
  --set backend.releaseName=new-backend

# Update image tag
helm upgrade my-frontend . \
  --set image.tag=v2.0.0

# Enable ingress
helm upgrade my-frontend . \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=myapp.example.com
```

## Uninstall

```bash
helm uninstall my-frontend
```

## Verification

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/instance=my-frontend

# Check service
kubectl get svc my-frontend

# View logs
kubectl logs -l app.kubernetes.io/name=frontend -f

# Check backend connection
kubectl logs -l app.kubernetes.io/name=frontend | grep BACKEND_URL
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod -l app.kubernetes.io/name=frontend

# Check logs
kubectl logs -l app.kubernetes.io/name=frontend

# Common issues:
# - Image not loaded (minikube: minikube image load frontend-app:latest)
# - Wrong image tag
# - Resource limits too low
```

### Can't Connect to Backend

```bash
# Test from frontend pod
kubectl exec -it <frontend-pod> -- wget -O- http://my-backend:8000/health

# Check BACKEND_URL env var
kubectl exec -it <frontend-pod> -- env | grep BACKEND_URL

# Verify backend is running
kubectl get pods -l app.kubernetes.io/instance=my-backend
```

### Page Won't Load

```bash
# Check if service exists
kubectl get svc my-frontend

# Verify port-forward
kubectl port-forward svc/my-frontend 3000:3000

# Check readiness probe
kubectl get pods -l app.kubernetes.io/name=frontend
# Should show 1/1 READY
```

## Advanced Configuration

### Enable Ingress (External Access)

```yaml
# values.yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.example.com
```

### Enable Auto-Scaling

```yaml
# values.yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Custom Resources

```yaml
# values.yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 256Mi
```

### Multiple Replicas

```yaml
# values.yaml
replicaCount: 3
```

## Make Commands

```bash
make helm-frontend          # Build + Load + Deploy
make pf-frontend           # Port-forward
make frontend-logs         # View logs
make frontend-status       # Show resources
make helm-destroy-frontend # Clean up
```

## Architecture

```
┌─────────────────────────────────────┐
│       Kubernetes Cluster            │
│                                     │
│  ┌──────────────────────┐          │
│  │  Frontend Deployment │          │
│  │  ┌────────────────┐  │          │
│  │  │ Next.js Pod    │  │          │
│  │  │ Port: 3000     │  │          │
│  │  │ BACKEND_URL    │──┼─────┐    │
│  │  └────────────────┘  │     │    │
│  └──────────────────────┘     │    │
│           │                   │    │
│  ┌────────▼────────┐          │    │
│  │ Frontend Service│          │    │
│  │ ClusterIP :3000 │          │    │
│  └─────────────────┘          │    │
│                               │    │
│                               ▼    │
│  ┌────────────────────────────┐   │
│  │   Backend Service          │   │
│  │   my-backend:8000          │   │
│  └────────────────────────────┘   │
└─────────────────────────────────────┘
```

## API Routes (BFF Pattern)

Frontend acts as Backend-for-Frontend:

```
Browser → /api/items → Next.js API Route → http://my-backend:8000/items → FastAPI
```

**Benefits:**
- No CORS issues
- Backend stays internal
- Can add auth/middleware
- Security layer

## Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Project Docs](../../docs/)

