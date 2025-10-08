# 🎓 Helm Charts Learning Guide

A comprehensive guide to understanding and deploying your full-stack application with Helm charts.

## 📖 What You'll Learn

This guide teaches you how to deploy a FastAPI backend with PostgreSQL database using Helm charts in Kubernetes, following your company's pattern of separate component charts.

## 🏗️ Your Application Architecture

```
┌─────────────────────────────────────────────┐
│         Full Stack Application              │
├─────────────────────────────────────────────┤
│  Frontend (Next.js)  │  Backend (FastAPI)   │
│       Port: 3000     │     Port: 8000       │
│                      │         ↓            │
│                      │   PostgreSQL 15      │
│                      │     Port: 5432       │
└─────────────────────────────────────────────┘
```

## 📚 Documentation Structure

### 🚀 Getting Started (Start Here!)

1. **[QUICK-START.md](../helm_charts/backend/QUICK-START.md)**
   - Deploy in 5 minutes
   - Perfect for first-time users
   - 3 simple steps to get running

2. **[DEPLOYMENT.md](DEPLOYMENT.md)**
   - Comprehensive deployment guide
   - Step-by-step instructions
   - Troubleshooting tips
   - All Kubernetes flavors (minikube/kind/Docker Desktop)

### 📖 Understanding the Concepts

3. **[DOCKER-COMPOSE-VS-HELM.md](DOCKER-COMPOSE-VS-HELM.md)**
   - Compare Docker Compose to Kubernetes/Helm
   - Concept mapping
   - Translation examples
   - When to use what

4. **[STRUCTURE.md](../helm_charts/backend/STRUCTURE.md)**
   - Deep dive into Helm chart structure
   - How templates work
   - Values flow
   - Debugging techniques

### 📘 Reference Documentation

5. **[Backend Helm Chart README](../helm_charts/backend/README.md)**
   - Complete chart documentation
   - Configuration options
   - Customization examples
   - Security considerations

## 🎯 Learning Path

### Level 1: Beginner (Deploy and Use)

**Goal:** Get the application running in Kubernetes

1. ✅ Read [QUICK-START.md](../helm_charts/backend/QUICK-START.md)
2. ✅ Deploy to local Kubernetes cluster
3. ✅ Access the API and test endpoints
4. ✅ View logs and check pod status

**Commands to Know:**
```bash
helm install <name> <chart>
kubectl get pods
kubectl logs <pod-name>
kubectl port-forward svc/<service> 8000:8000
```

### Level 2: Intermediate (Understand and Modify)

**Goal:** Understand how Helm charts work and customize them

1. ✅ Read [DOCKER-COMPOSE-VS-HELM.md](DOCKER-COMPOSE-VS-HELM.md)
2. ✅ Study [STRUCTURE.md](../helm_charts/backend/STRUCTURE.md)
3. ✅ Modify `values.yaml` (change replicas, resources)
4. ✅ Create custom values file (`values-dev.yaml`)
5. ✅ Understand templates and how values flow

**Commands to Know:**
```bash
helm template <name> <chart>        # Render templates
helm upgrade <name> <chart>         # Apply changes
helm get values <name>              # View current values
helm rollback <name>                # Undo changes
```

### Level 3: Advanced (Design and Build)

**Goal:** Create and maintain Helm charts for your projects

1. ✅ Read [Backend Chart README](../helm_charts/backend/README.md) completely
2. ✅ Study all template files in detail
3. ✅ Create charts for other components (frontend)
4. ✅ Implement production-ready configurations
5. ✅ Set up CI/CD pipelines

**Commands to Know:**
```bash
helm create <chart-name>            # Create new chart
helm package <chart>                # Package chart
helm lint <chart>                   # Validate chart
helm test <release>                 # Run tests
```

## 🔍 Understanding Your Backend Deployment

### What Gets Deployed?

When you run `helm install my-backend backend/`, these resources are created:

#### 1. Backend Application (FastAPI)

**Resource:** Deployment
- **Purpose:** Runs your FastAPI application
- **Replicas:** 1 (configurable)
- **Port:** 8000
- **Image:** `backend-app:latest`
- **Environment Variables:**
  - `PYTHONUNBUFFERED=1`
  - `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` (from Secret)

**Resource:** Service (ClusterIP)
- **Purpose:** Exposes backend internally
- **Name:** `my-backend`
- **Port:** 8000 → 8000

#### 2. PostgreSQL Database

**Resource:** StatefulSet
- **Purpose:** Runs PostgreSQL database
- **Replicas:** 1
- **Port:** 5432
- **Image:** `postgres:15-alpine`
- **Storage:** 1Gi persistent volume

**Resource:** Service (Headless)
- **Purpose:** Stable network identity for StatefulSet
- **Name:** `my-backend-postgres`
- **Port:** 5432 → 5432

#### 3. Supporting Resources

**Resource:** Secret
- **Purpose:** Stores database credentials (base64 encoded)
- **Name:** `my-backend-postgres-secret`
- **Keys:** `username`, `password`, `database`

**Resource:** PersistentVolumeClaim
- **Purpose:** Requests storage for PostgreSQL data
- **Name:** `postgres-data-my-backend-postgres-0`
- **Size:** 1Gi

**Resource:** ServiceAccount
- **Purpose:** Identity for pods (required by some policies)
- **Name:** `my-backend`

## 🎨 Customization Examples

### Example 1: Scale Backend to 3 Replicas

```yaml
# values-prod.yaml
replicaCount: 3

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 256Mi
```

Deploy:
```bash
helm upgrade my-backend backend/ -f values-prod.yaml
```

### Example 2: Use External Database

```yaml
# values-external-db.yaml
postgres:
  enabled: false  # Disable built-in PostgreSQL

env:
  - name: PYTHONUNBUFFERED
    value: "1"
  - name: DB_HOST
    value: "external-postgres.example.com"
  - name: DB_NAME
    value: "production_db"
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: external-db-secret
        key: username
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: external-db-secret
        key: password
```

### Example 3: Add More Environment Variables

```yaml
# values.yaml
env:
  - name: PYTHONUNBUFFERED
    value: "1"
  - name: DB_HOST
    value: "{{ .Release.Name }}-postgres"
  # ... existing vars ...
  
  # Add custom vars
  - name: LOG_LEVEL
    value: "INFO"
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: api-keys
        key: backend-key
  - name: FEATURE_FLAG_X
    value: "true"
```

## 🔧 Common Tasks

### Task 1: Update Application Code

```bash
# 1. Modify code
vim backend/app/main.py

# 2. Rebuild image
cd backend
docker build -f Dockerfile.prod -t backend-app:v2.0 .

# 3. Update values.yaml
# image:
#   tag: "v2.0"

# 4. Load image (for local)
minikube image load backend-app:v2.0

# 5. Upgrade release
helm upgrade my-backend helm_charts/backend/ \
  --set image.tag=v2.0
```

### Task 2: Change Database Password

```bash
# 1. Update values.yaml
# postgres:
#   auth:
#     password: "newSecurePassword123"

# 2. Upgrade (this will recreate secret)
helm upgrade my-backend helm_charts/backend/

# 3. Restart postgres to use new password
kubectl delete pod my-backend-postgres-0
```

### Task 3: Access Database Directly

```bash
# Port forward
kubectl port-forward svc/my-backend-postgres 5432:5432

# Connect with psql
psql -h localhost -U appuser -d appdb
# Password: supersecret (or whatever you configured)

# Or exec into pod
kubectl exec -it my-backend-postgres-0 -- psql -U appuser -d appdb
```

### Task 4: View All Resources

```bash
# All resources for this release
kubectl get all -l app.kubernetes.io/instance=my-backend

# More details
helm status my-backend
helm get all my-backend

# View rendered manifests
helm get manifest my-backend
```

## 🐛 Troubleshooting Guide

### Problem: Pods Not Starting

```bash
# 1. Check pod status
kubectl get pods

# 2. Describe pod for events
kubectl describe pod <pod-name>

# 3. Check logs
kubectl logs <pod-name>

# 4. Check previous logs (if crashed)
kubectl logs <pod-name> --previous
```

**Common Causes:**
- Image not found → Load image into cluster
- Init container failing → Check postgres is running
- Health check failing → Check `/health` endpoint
- Resource limits → Increase in values.yaml

### Problem: Cannot Connect to Database

```bash
# 1. Check postgres pod
kubectl get pod my-backend-postgres-0

# 2. Check postgres logs
kubectl logs my-backend-postgres-0

# 3. Verify secret
kubectl get secret my-backend-postgres-secret -o yaml

# 4. Test connection from backend pod
kubectl exec -it <backend-pod> -- env | grep DB_
```

### Problem: PVC Pending

```bash
# Check PVC status
kubectl get pvc

# Check if storage class exists
kubectl get storageclass

# For minikube, enable storage
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
```

## 📊 Architecture Comparison

### Docker Compose (Development)

```yaml
services:
  backend: { image, environment, depends_on }
  postgres: { image, environment, volumes }
```

**Pros:** Simple, fast, great for local dev
**Cons:** Single host, limited scaling, no orchestration

### Helm/Kubernetes (Production)

```yaml
templates/
  deployment.yaml      # Backend app
  service.yaml         # Networking
  postgres-statefulset.yaml  # Database
  postgres-service.yaml
  secret.yaml          # Credentials
```

**Pros:** Scalable, HA, production-ready, auto-healing
**Cons:** Complex, steeper learning curve

## 🎓 Key Concepts to Understand

### 1. Helm Charts

- **Chart:** Package of Kubernetes resources
- **Values:** Configuration parameters
- **Templates:** YAML with Go templating
- **Release:** Installed instance of a chart

### 2. Kubernetes Resources

- **Deployment:** Manages pods (stateless apps)
- **StatefulSet:** Manages pods with state (databases)
- **Service:** Networking and load balancing
- **Secret:** Sensitive data (passwords, keys)
- **PVC/PV:** Persistent storage

### 3. Template Syntax

```yaml
{{ .Values.image.repository }}     # Access values
{{ .Release.Name }}                # Release info
{{ include "backend.labels" . }}   # Include helpers
{{- if .Values.postgres.enabled }} # Conditionals
{{- range .Values.env }}           # Loops
{{ tpl .value $ | quote }}         # Functions
```

## 🚀 Production Readiness Checklist

Before deploying to production:

- [ ] Use specific image tags (not `latest`)
- [ ] Set resource limits and requests
- [ ] Use external secret management (Vault, etc.)
- [ ] Configure proper health checks
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure logging (ELK, Loki)
- [ ] Add network policies
- [ ] Enable RBAC
- [ ] Set up backups for PostgreSQL
- [ ] Configure ingress with TLS
- [ ] Test disaster recovery
- [ ] Document runbooks

## 📚 Additional Resources

### Official Documentation

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)

### Useful Tools

- **k9s**: Terminal UI for Kubernetes
- **Lens**: Kubernetes IDE
- **Skaffold**: Dev workflow automation
- **Tilt**: Local Kubernetes dev
- **helm-diff**: Show changes before upgrade

### Commands Cheat Sheet

```bash
# Helm
helm install <name> <chart>
helm upgrade <name> <chart>
helm uninstall <name>
helm list
helm status <name>
helm rollback <name>

# Kubectl
kubectl get pods
kubectl logs <pod>
kubectl describe pod <pod>
kubectl exec -it <pod> -- /bin/sh
kubectl port-forward svc/<service> <local>:<remote>
kubectl delete pod <pod>

# Debug
helm template <name> <chart>
helm install <name> <chart> --dry-run --debug
kubectl get events --sort-by='.lastTimestamp'
```

## 🎯 Next Steps

1. **Deploy the Backend:**
   - Follow [QUICK-START.md](../helm_charts/backend/QUICK-START.md)
   - Get hands-on experience

2. **Understand the Setup:**
   - Read [STRUCTURE.md](../helm_charts/backend/STRUCTURE.md)
   - Examine each template file

3. **Apply to Your Project:**
   - Create Helm chart for frontend
   - Follow the same pattern
   - Add nginx/ingress as needed

4. **Level Up:**
   - Add monitoring
   - Set up CI/CD
   - Implement GitOps (ArgoCD/Flux)

## 💡 Key Takeaways

1. **Helm charts** package Kubernetes resources into reusable templates
2. **Values.yaml** is your main configuration file
3. **Templates** use Go templating to generate manifests
4. **StatefulSets** are for stateful apps like databases
5. **Secrets** store sensitive data (use external managers in prod)
6. **Init containers** handle dependencies
7. **Services** provide networking between components
8. **PVCs** request persistent storage

## 🤝 Getting Help

- Check the troubleshooting sections in each guide
- Use `kubectl describe` and `kubectl logs` for debugging
- Render templates with `helm template` to see what's generated
- Test with `--dry-run` before applying changes

Good luck with your Kubernetes journey! 🎉

