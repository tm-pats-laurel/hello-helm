# Backend Helm Chart

This Helm chart deploys the FastAPI backend application along with PostgreSQL 15 database.

## Components

This chart includes:
- **FastAPI Application**: Your Python backend (port 8000)
- **PostgreSQL 15**: Database server (port 5432)
- **Secret**: For database credentials
- **Services**: ClusterIP services for both components
- **StatefulSet**: For PostgreSQL with persistent storage

## Prerequisites

- Kubernetes cluster (minikube, kind, Docker Desktop, etc.)
- Helm 3.x installed
- kubectl configured

## Quick Start for Local Development

### 1. Build Your Backend Docker Image

First, build your backend image locally:

```bash
cd /home/pats/practice/hello-helm/backend
docker build -f Dockerfile.prod -t backend-app:latest .
```

For minikube, load the image:
```bash
minikube image load backend-app:latest
```

For kind:
```bash
kind load docker-image backend-app:latest
```

### 2. Install the Chart

From the `helm_charts` directory:

```bash
# Install with default values
helm install my-backend backend/

# Or with custom release name
helm install fastapi-demo backend/
```

### 3. Check Status

```bash
# Check all resources
kubectl get all -l app.kubernetes.io/instance=my-backend

# Check pods
kubectl get pods

# Check services
kubectl get svc

# Check persistent volume claims
kubectl get pvc
```

### 4. Access the Application

```bash
# Port forward to access locally
kubectl port-forward svc/my-backend 8000:8000

# Then visit: http://localhost:8000/health
# API docs: http://localhost:8000/docs
```

## Configuration

### Key Values in `values.yaml`

#### Backend Application
```yaml
image:
  repository: backend-app  # Your image name
  tag: "latest"

service:
  port: 8000  # FastAPI port

replicaCount: 1  # Number of backend pods
```

#### PostgreSQL Database
```yaml
postgres:
  enabled: true  # Set to false to disable
  
  auth:
    database: appdb
    username: appuser
    password: supersecret  # CHANGE THIS!
  
  persistence:
    enabled: true
    size: 1Gi
```

#### Environment Variables

The backend automatically receives:
- `PYTHONUNBUFFERED=1`
- `DB_HOST` - PostgreSQL service name
- `DB_NAME` - From secret
- `DB_USER` - From secret
- `DB_PASSWORD` - From secret

## Customization Examples

### Using Different Database Credentials

Create a custom values file `values-local.yaml`:

```yaml
postgres:
  auth:
    database: myapp
    username: myuser
    password: mypassword123
```

Install with:
```bash
helm install my-backend backend/ -f values-local.yaml
```

### Using External PostgreSQL

If you want to use an external database:

```yaml
postgres:
  enabled: false  # Disable built-in PostgreSQL

env:
  - name: DB_HOST
    value: "external-postgres.example.com"
  - name: DB_NAME
    value: "proddb"
  # Add secret references for credentials
```

### Adjusting Resources

For development (lower resources):
```yaml
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 128Mi

postgres:
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
```

### Multiple Replicas

```yaml
replicaCount: 3  # Run 3 backend pods

postgres:
  # Note: This chart uses StatefulSet with 1 replica
  # For HA PostgreSQL, consider using a specialized chart
```

## Useful Commands

### Upgrade the Release

```bash
# After making changes to values or templates
helm upgrade my-backend backend/

# With custom values
helm upgrade my-backend backend/ -f values-local.yaml
```

### Uninstall

```bash
helm uninstall my-backend

# PVC might need manual cleanup
kubectl delete pvc postgres-data-my-backend-postgres-0
```

### Debug

```bash
# Render templates without installing
helm template my-backend backend/

# Dry run
helm install my-backend backend/ --dry-run --debug

# Check logs
kubectl logs -l app.kubernetes.io/name=backend
kubectl logs -l app.kubernetes.io/component=database
```

### Access PostgreSQL Directly

```bash
# Port forward
kubectl port-forward svc/my-backend-postgres 5432:5432

# Connect with psql
psql -h localhost -U appuser -d appdb
# Password: supersecret
```

## Architecture

```
┌─────────────────────────────────────┐
│         Kubernetes Cluster          │
│                                     │
│  ┌──────────────┐  ┌─────────────┐ │
│  │   Backend    │  │ PostgreSQL  │ │
│  │  Deployment  │──│ StatefulSet │ │
│  │  (FastAPI)   │  │             │ │
│  │  Port: 8000  │  │ Port: 5432  │ │
│  └──────────────┘  └─────────────┘ │
│         │                  │        │
│  ┌──────────────┐  ┌─────────────┐ │
│  │   Backend    │  │  Postgres   │ │
│  │   Service    │  │  Service    │ │
│  └──────────────┘  └─────────────┘ │
│                           │         │
│                    ┌─────────────┐  │
│                    │     PVC     │  │
│                    │  (1Gi data) │  │
│                    └─────────────┘  │
└─────────────────────────────────────┘
```

## Security Notes

⚠️ **Important for Production:**

1. **Secrets**: Don't store passwords in `values.yaml` for production
   - Use Kubernetes Secrets
   - Use external secret managers (HashiCorp Vault, AWS Secrets Manager, etc.)
   - Use Sealed Secrets or SOPS

2. **Image Tags**: Use specific version tags, not `latest`

3. **Resources**: Always set resource limits

4. **Security Context**: Enable and configure securityContext

5. **Network Policies**: Add network policies to restrict traffic

## Troubleshooting

### Backend Pod Not Starting

```bash
# Check pod status
kubectl describe pod -l app.kubernetes.io/name=backend

# Check logs
kubectl logs -l app.kubernetes.io/name=backend --tail=50

# Common issues:
# - Image not found (wrong repository or tag)
# - PostgreSQL not ready (check init container logs)
# - Wrong environment variables
```

### Database Connection Issues

```bash
# Check postgres pod
kubectl logs -l app.kubernetes.io/component=database

# Verify service
kubectl get svc | grep postgres

# Test connection from backend pod
kubectl exec -it <backend-pod-name> -- env | grep DB_
```

### Storage Issues

```bash
# Check PVC
kubectl get pvc

# Check storage class
kubectl get storageclass

# If PVC is pending, you might need to:
# - Install a storage provisioner
# - Use hostPath for local dev (not recommended)
```

## Next Steps

1. Add Ingress for external access
2. Configure TLS/SSL
3. Add monitoring (Prometheus metrics)
4. Set up CI/CD pipeline
5. Add network policies
6. Configure backup strategies for PostgreSQL

## Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Concepts](https://kubernetes.io/docs/concepts/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Secrets Management](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Project Documentation](../../docs/) - Main project docs

