# Next Steps: Beyond Basic Deployment

After successfully deploying your full-stack application, here are advanced topics and improvements you can implement.

## Table of Contents

1. [Managing Updates & Rollbacks](#managing-updates--rollbacks)
2. [Adding NGINX Ingress (Public Access)](#adding-nginx-ingress-public-access)
3. [Secrets Management](#secrets-management)
4. [Monitoring & Observability](#monitoring--observability)
5. [CI/CD Pipelines](#cicd-pipelines)
6. [Production Readiness](#production-readiness)
7. [Performance Optimization](#performance-optimization)
8. [Security Hardening](#security-hardening)
9. [Multi-Environment Setup](#multi-environment-setup)
10. [Advanced Helm Features](#advanced-helm-features)

---

## Managing Updates & Rollbacks

### Updating Your Application

#### Scenario: You made code changes and want to deploy them

**Step 1: Make changes to your code**
```bash
# Example: Update backend
cd backend/app
# Edit some files...
```

**Step 2: Rebuild image with new tag**
```bash
# Build with version tag
cd /home/pats/practice/hello-helm
docker build -f backend/Dockerfile.prod -t backend-app:v1.1.0 backend/

# Load into cluster
minikube image load backend-app:v1.1.0
```

**Step 3: Upgrade Helm release**
```bash
# Upgrade with new image tag
helm upgrade my-backend helm_charts/backend/ \
  --set image.tag=v1.1.0 \
  --atomic --timeout 5m

# Watch the rollout
kubectl rollout status deployment/my-backend
```

**What happens:**
- Helm creates a new revision
- Kubernetes performs a rolling update
- Old pods are replaced one by one
- Zero downtime deployment!

#### Quick Update (Development)

For rapid iteration in development:

```bash
# Rebuild with latest tag
make build-backend
make load-backend

# Force pod restart (pulls new image)
kubectl rollout restart deployment/my-backend

# Watch it
kubectl get pods -w
```

### Rollback Strategies

#### View Release History

```bash
# See all revisions
helm history my-backend

# Output:
# REVISION  UPDATED                   STATUS      CHART          APP VERSION  DESCRIPTION
# 1         Mon Jan 1 10:00:00 2024   superseded  backend-0.1.0  0.1.0        Install complete
# 2         Mon Jan 1 11:00:00 2024   deployed    backend-0.1.0  0.1.0        Upgrade complete
```

#### Rollback to Previous Version

```bash
# Rollback to previous revision
helm rollback my-backend

# OR rollback to specific revision
helm rollback my-backend 1

# Check status
kubectl get pods
```

#### Automatic Rollback

Use `--atomic` flag (already in deploy scripts):

```bash
helm upgrade my-backend helm_charts/backend/ \
  --set image.tag=v1.2.0 \
  --atomic

# If upgrade fails, automatically rolls back!
```

### Upgrade Strategies

#### 1. Zero-Downtime Rolling Update (Default)

```yaml
# In deployment.yaml (already configured)
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0  # Keep all pods running
      maxSurge: 1        # Create 1 extra pod during update
```

#### 2. Blue-Green Deployment

```bash
# Deploy new version as separate release
helm install my-backend-v2 helm_charts/backend/ \
  --set image.tag=v2.0.0

# Test the new version
kubectl port-forward svc/my-backend-v2 8001:8000

# Switch traffic (update frontend backend.releaseName)
helm upgrade my-frontend helm_charts/frontend/ \
  --set backend.releaseName=my-backend-v2

# Remove old version
helm uninstall my-backend
```

#### 3. Canary Deployment

```bash
# Deploy canary with 1 replica
helm install my-backend-canary helm_charts/backend/ \
  --set replicaCount=1 \
  --set image.tag=v2.0.0

# Monitor metrics/errors
kubectl logs -l app.kubernetes.io/instance=my-backend-canary -f

# If good, upgrade main release
helm upgrade my-backend helm_charts/backend/ \
  --set image.tag=v2.0.0

# Remove canary
helm uninstall my-backend-canary
```

---

## Adding NGINX Ingress (Public Access)

### Why Ingress?

Instead of port-forwarding, expose your app publicly with a domain name.

**Before (Port-Forward):**
```
Browser → kubectl port-forward → Pod
```

**After (Ingress):**
```
Browser → NGINX Ingress → Service → Pod
```

### Step 1: Install NGINX Ingress Controller

#### Minikube
```bash
minikube addons enable ingress

# Verify
kubectl get pods -n ingress-nginx
```

#### Kind
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for it
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

#### Generic Kubernetes
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

### Step 2: Enable Ingress in Helm Charts

#### Frontend Ingress

Edit `helm_charts/frontend/values.yaml`:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # Optional: for SSL
  hosts:
    - host: myapp.local
      paths:
        - path: /
          pathType: Prefix
  # tls:  # Optional: enable HTTPS
  #   - secretName: myapp-tls
  #     hosts:
  #       - myapp.local
```

Deploy:
```bash
helm upgrade my-frontend helm_charts/frontend/ -f helm_charts/frontend/values.yaml
```

#### Add Host Entry (Local Development)

```bash
# Get Ingress IP
kubectl get ingress

# Add to /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
echo "$(minikube ip) myapp.local" | sudo tee -a /etc/hosts
```

### Step 3: Access Your App

```bash
# Open browser
http://myapp.local
```

No more port-forwarding! 🎉

### Advanced Ingress: Path-Based Routing

Route different paths to different services:

```yaml
# ingress-combined.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fullstack-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: myapp.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-frontend
                port:
                  number: 3000
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: my-backend
                port:
                  number: 8000
```

Apply:
```bash
kubectl apply -f ingress-combined.yaml
```

### HTTPS with Cert-Manager (Optional)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Update ingress to enable TLS (see values.yaml above)
```

---

## Secrets Management

### Current Approach: Plain Secrets

Currently, secrets are in `values.yaml`:

```yaml
postgres:
  auth:
    password: supersecret  # ❌ Not secure for production
```

### Better Approaches

#### 1. External Secrets Operator

**Install:**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system --create-namespace
```

**Use with AWS Secrets Manager / GCP Secret Manager / Azure Key Vault:**

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: my-backend-postgres-secret
  data:
    - secretKey: password
      remoteRef:
        key: prod/postgres/password
```

#### 2. Sealed Secrets

**Install:**
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

**Encrypt secrets:**
```bash
# Create secret
kubectl create secret generic postgres-secret \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Commit sealed-secret.yaml to Git (it's encrypted!)
kubectl apply -f sealed-secret.yaml
```

#### 3. Helm Secrets Plugin

```bash
# Install plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Create secrets file
cat > helm_charts/backend/secrets.yaml <<EOF
postgres:
  auth:
    password: supersecret
EOF

# Encrypt with SOPS
sops -e -i helm_charts/backend/secrets.yaml

# Deploy with secrets
helm upgrade my-backend helm_charts/backend/ \
  -f helm_charts/backend/values.yaml \
  -f helm_charts/backend/secrets.yaml
```

---

## Monitoring & Observability

### Install Prometheus + Grafana

#### Using kube-prometheus-stack

```bash
# Add repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3001:80

# Login: admin / prom-operator (default)
# Open: http://localhost:3001
```

#### Add Custom Metrics to Your App

**Backend (FastAPI):**

```bash
# Install prometheus client
cd backend
poetry add prometheus-fastapi-instrumentator
```

```python
# backend/main.py
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()
Instrumentator().instrument(app).expose(app)  # Adds /metrics endpoint
```

**Deploy and verify:**
```bash
kubectl port-forward svc/my-backend 8000:8000
curl http://localhost:8000/metrics
```

#### Create Dashboards

1. Open Grafana (http://localhost:3001)
2. Add Prometheus datasource (already configured)
3. Import dashboard ID: `1860` (Node Exporter)
4. Create custom dashboard for your app metrics

### Logging with Loki

```bash
# Install Loki stack
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true

# Logs appear in Grafana automatically!
```

### Distributed Tracing with Jaeger

```bash
# Install Jaeger
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm install jaeger jaegertracing/jaeger \
  --namespace monitoring

# Access UI
kubectl port-forward -n monitoring svc/jaeger-query 16686:16686
```

---

## CI/CD Pipelines

### GitHub Actions Example

`.github/workflows/deploy.yml`:

```yaml
name: Deploy to Kubernetes

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBECONFIG }}
      
      - name: Build backend image
        run: |
          docker build -f backend/Dockerfile.prod -t backend-app:${{ github.sha }} backend/
          docker tag backend-app:${{ github.sha }} backend-app:latest
      
      - name: Push to registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push backend-app:${{ github.sha }}
          docker push backend-app:latest
      
      - name: Deploy with Helm
        run: |
          helm upgrade --install my-backend helm_charts/backend/ \
            --set image.tag=${{ github.sha }} \
            --atomic --timeout 5m

  deploy-frontend:
    needs: deploy-backend
    runs-on: ubuntu-latest
    steps:
      # Similar steps for frontend
```

### GitLab CI Example

`.gitlab-ci.yml`:

```yaml
stages:
  - build
  - deploy

build-backend:
  stage: build
  script:
    - docker build -f backend/Dockerfile.prod -t $CI_REGISTRY_IMAGE/backend:$CI_COMMIT_SHA backend/
    - docker push $CI_REGISTRY_IMAGE/backend:$CI_COMMIT_SHA

deploy-backend:
  stage: deploy
  script:
    - helm upgrade --install my-backend helm_charts/backend/ \
        --set image.repository=$CI_REGISTRY_IMAGE/backend \
        --set image.tag=$CI_COMMIT_SHA \
        --atomic
  environment:
    name: production
    url: https://myapp.example.com
```

### ArgoCD (GitOps)

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Create application
argocd app create my-fullstack \
  --repo https://github.com/yourusername/hello-helm \
  --path helm_charts/backend \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Enable auto-sync
argocd app set my-fullstack --sync-policy automated
```

---

## Production Readiness

### 1. Resource Limits & Requests

**Configure properly in values.yaml:**

```yaml
resources:
  limits:
    cpu: 1000m      # Maximum CPU
    memory: 1Gi     # Maximum memory
  requests:
    cpu: 250m       # Guaranteed CPU
    memory: 256Mi   # Guaranteed memory
```

**Why it matters:**
- Prevents one app from consuming all cluster resources
- Enables proper scheduling
- Required for autoscaling

### 2. Health Checks

**Already configured, but verify:**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
```

### 3. Pod Disruption Budgets

Prevent too many pods from being down during maintenance:

```yaml
# pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: backend
```

### 4. Network Policies

Restrict pod-to-pod communication:

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: backend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: frontend
      ports:
        - protocol: TCP
          port: 8000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: database
      ports:
        - protocol: TCP
          port: 5432
```

### 5. Horizontal Pod Autoscaler

**Enable in values.yaml:**

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

**Deploy:**
```bash
helm upgrade my-backend helm_charts/backend/ \
  --set autoscaling.enabled=true

# Watch it scale
kubectl get hpa -w
```

### 6. Backup Strategy

**Postgres backups with CronJob:**

```yaml
# backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: postgres:15-alpine
              command:
                - /bin/sh
                - -c
                - pg_dump -h my-backend-postgres -U appuser appdb | gzip > /backups/backup-$(date +%Y%m%d-%H%M%S).sql.gz
              env:
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: my-backend-postgres-secret
                      key: password
              volumeMounts:
                - name: backups
                  mountPath: /backups
          volumes:
            - name: backups
              persistentVolumeClaim:
                claimName: postgres-backups
          restartPolicy: OnFailure
```

---

## Performance Optimization

### 1. Enable Caching

**Frontend (Next.js):**

```dockerfile
# Dockerfile.prod - Add Redis
FROM node:20-alpine
# ... install Redis client
```

**Backend (FastAPI with Redis):**

```python
from fastapi_cache import FastAPICache
from fastapi_cache.backends.redis import RedisBackend
from redis import asyncio as aioredis

@app.on_event("startup")
async def startup():
    redis = aioredis.from_url("redis://my-redis:6379")
    FastAPICache.init(RedisBackend(redis), prefix="fastapi-cache")
```

**Deploy Redis:**
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-redis bitnami/redis --set auth.enabled=false
```

### 2. Database Connection Pooling

Already configured in `backend/app/database.py`, but tune:

```python
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_size=20,          # Adjust based on load
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=3600,
)
```

### 3. CDN for Static Assets

Use CloudFront, Cloudflare, or similar:

```yaml
# frontend values.yaml
env:
  NEXT_PUBLIC_CDN_URL: "https://cdn.example.com"
```

### 4. Database Indexing

```sql
-- Add indexes for common queries
CREATE INDEX idx_items_created_at ON items(created_at);
CREATE INDEX idx_items_name ON items(name);
```

---

## Security Hardening

### 1. Pod Security Standards

```yaml
# In deployment.yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
  
containers:
  - name: backend
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
```

### 2. Image Scanning

```bash
# Install Trivy
brew install aquasecurity/trivy/trivy

# Scan images
trivy image backend-app:latest
trivy image frontend-app:latest
```

### 3. Network Policies (See Production Readiness section)

### 4. RBAC (Role-Based Access Control)

```yaml
# rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backend-role
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backend-rolebinding
subjects:
  - kind: ServiceAccount
    name: backend-sa
roleRef:
  kind: Role
  name: backend-role
  apiGroup: rbac.authorization.k8s.io
```

---

## Multi-Environment Setup

### Directory Structure

```
helm_charts/
├── backend/
│   ├── values.yaml              # Base values
│   ├── values-dev.yaml         # Dev overrides
│   ├── values-staging.yaml     # Staging overrides
│   └── values-prod.yaml        # Production overrides
```

### values-dev.yaml

```yaml
replicaCount: 1
resources:
  limits:
    cpu: 200m
    memory: 256Mi
postgres:
  persistence:
    size: 1Gi
```

### values-prod.yaml

```yaml
replicaCount: 3
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
autoscaling:
  enabled: true
postgres:
  persistence:
    size: 50Gi
  resources:
    limits:
      cpu: 4000m
      memory: 4Gi
```

### Deploy to Different Environments

```bash
# Development
helm upgrade --install my-backend helm_charts/backend/ \
  -f helm_charts/backend/values-dev.yaml \
  --namespace dev --create-namespace

# Staging
helm upgrade --install my-backend helm_charts/backend/ \
  -f helm_charts/backend/values-staging.yaml \
  --namespace staging --create-namespace

# Production
helm upgrade --install my-backend helm_charts/backend/ \
  -f helm_charts/backend/values-prod.yaml \
  --namespace prod --create-namespace
```

---

## Advanced Helm Features

### 1. Chart Dependencies

Create umbrella chart that includes both backend and frontend:

```yaml
# helm_charts/fullstack/Chart.yaml
apiVersion: v2
name: fullstack
version: 0.1.0
dependencies:
  - name: backend
    version: 0.1.0
    repository: file://../backend
  - name: frontend
    version: 0.1.0
    repository: file://../frontend
```

```bash
# Build dependencies
helm dependency build helm_charts/fullstack/

# Deploy everything at once
helm install my-app helm_charts/fullstack/
```

### 2. Helm Hooks

Execute jobs at specific times:

```yaml
# templates/migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
        - name: migration
          image: backend-app:latest
          command: ["alembic", "upgrade", "head"]
```

### 3. Template Tests

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "backend.fullname" . }}-test-connection"
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "backend.fullname" . }}:8000/health']
  restartPolicy: Never
```

Run tests:
```bash
helm test my-backend
```

---

## Quick Reference

### Update Workflow

```bash
# 1. Make code changes
# 2. Rebuild image
make build-backend
make load-backend

# 3. Upgrade release
helm upgrade my-backend helm_charts/backend/ --set image.tag=v1.1.0

# 4. Verify
kubectl rollout status deployment/my-backend
```

### Rollback Workflow

```bash
# 1. Check history
helm history my-backend

# 2. Rollback
helm rollback my-backend [REVISION]

# 3. Verify
kubectl get pods
```

### Ingress Workflow

```bash
# 1. Enable ingress addon
minikube addons enable ingress

# 2. Update values.yaml
# ingress.enabled: true

# 3. Deploy
helm upgrade my-frontend helm_charts/frontend/

# 4. Access
http://myapp.local
```

---

## What to Implement Next?

**Priority Order:**

1. ✅ **NGINX Ingress** - Stop using port-forward
2. ✅ **Monitoring** - Know when things break
3. ✅ **CI/CD** - Automate deployments
4. ✅ **Secrets Management** - Secure your passwords
5. ✅ **Autoscaling** - Handle traffic spikes
6. ✅ **Backups** - Don't lose data

**Choose based on your needs!**

---

## Resources

- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Production Checklist](https://learnk8s.io/production-best-practices)
- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

Happy scaling! 🚀

