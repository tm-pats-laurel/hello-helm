# Docker Compose vs Helm/Kubernetes: Concept Mapping

This guide helps you understand how your Docker Compose setup translates to Helm/Kubernetes concepts.

## Side-by-Side Comparison

### Your Docker Compose Setup

```yaml
# compose.yml
services:
  backend:
    build: ./backend
    expose: ["8000"]
    environment:
      - DB_HOST=postgres
      - DB_NAME=appdb
    depends_on:
      postgres:
        condition: service_healthy
  
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: supersecret
      POSTGRES_DB: appdb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports: ["5432:5432"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
```

### Equivalent Helm/Kubernetes

```yaml
# values.yaml
image:
  repository: backend-app
  tag: latest

service:
  port: 8000

env:
  - name: DB_HOST
    value: my-backend-postgres
  - name: DB_NAME
    valueFrom:
      secretKeyRef:
        name: postgres-secret
        key: database

postgres:
  enabled: true
  image:
    repository: postgres
    tag: "15-alpine"
  auth:
    username: appuser
    password: supersecret
    database: appdb
  persistence:
    enabled: true
    size: 1Gi
```

## Concept Mapping

| Docker Compose | Kubernetes/Helm | Notes |
|----------------|-----------------|-------|
| `service` | `Deployment` + `Service` | One compose service = deployment + service |
| `image: nginx` | `image: nginx` | Same concept |
| `build: ./backend` | Pre-built image required | Build before deploying |
| `ports: ["8000:8000"]` | `Service.spec.ports` | Maps port to service |
| `expose: ["8000"]` | `Service.spec.ports` | Internal exposure |
| `environment:` | `env:` in Pod spec | Environment variables |
| `volumes:` | `PersistentVolumeClaim` | Persistent storage |
| `depends_on:` | `initContainers` | Wait for dependencies |
| `healthcheck:` | `livenessProbe` + `readinessProbe` | Health checks |
| `restart: unless-stopped` | Default behavior | Pods auto-restart |
| `networks:` | `Service` networking | Automatic DNS |

## Key Differences

### 1. Building vs Pre-built Images

**Docker Compose:**
```yaml
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
```
- Builds image on the fly
- Easy for development

**Helm/Kubernetes:**
```bash
# Build manually first
docker build -t backend-app:latest ./backend

# Load into cluster
minikube image load backend-app:latest
```
- Images must be pre-built
- Pushed to registry (in production)
- More explicit, better for CI/CD

### 2. Networking

**Docker Compose:**
```yaml
services:
  backend:
    environment:
      - DB_HOST=postgres  # Just use service name
```
- Automatic service discovery
- Service names as hostnames

**Helm/Kubernetes:**
```yaml
env:
  - name: DB_HOST
    value: "{{ .Release.Name }}-postgres"
    # Becomes: my-backend-postgres
```
- Service DNS: `<service-name>.<namespace>.svc.cluster.local`
- Short name works within same namespace: `my-backend-postgres`
- More flexible, more complex

### 3. Storage

**Docker Compose:**
```yaml
volumes:
  postgres_data:  # Named volume

services:
  postgres:
    volumes:
      - postgres_data:/var/lib/postgresql/data
```
- Simple named volumes
- Managed by Docker

**Helm/Kubernetes:**
```yaml
volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 1Gi
```
- PersistentVolumeClaim (PVC)
- PersistentVolume (PV)
- StorageClass
- More powerful, more complex

### 4. Secrets

**Docker Compose:**
```yaml
environment:
  POSTGRES_PASSWORD: supersecret  # Plain text!
```
- Usually plain text
- Can use Docker secrets (swarm mode)

**Helm/Kubernetes:**
```yaml
# Secret (base64 encoded)
apiVersion: v1
kind: Secret
data:
  password: c3VwZXJzZWNyZXQ=

# Pod references it
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-secret
        key: password
```
- Dedicated Secret resource
- Base64 encoded (not encrypted by default!)
- Can integrate with secret managers

### 5. Dependencies

**Docker Compose:**
```yaml
depends_on:
  postgres:
    condition: service_healthy
```
- Built-in dependency management
- Waits for health checks

**Helm/Kubernetes:**
```yaml
initContainers:
  - name: wait-for-postgres
    image: busybox
    command: ['sh', '-c', 'until nc -z postgres 5432; do sleep 2; done']
```
- Use init containers
- More explicit control
- More flexible

### 6. Configuration Management

**Docker Compose:**
- Everything in one `compose.yml`
- Override with `compose.override.yml`
- Environment files (`.env`)

**Helm:**
- Templates in `templates/`
- Values in `values.yaml`
- Override with `-f custom-values.yaml`
- Environment-specific value files
- More powerful templating

## Full Translation Example

### Docker Compose Backend Service

```yaml
services:
  backend:
    build: ./backend
    expose: ["8000"]
    volumes:
      - ./backend/app:/app/app
    environment:
      - PYTHONUNBUFFERED=1
      - DB_HOST=postgres
      - DB_NAME=appdb
      - DB_USER=appuser
      - DB_PASSWORD=supersecret
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
```

### Helm Equivalent

**Deployment** (deployment.yaml):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  template:
    spec:
      # Equivalent to depends_on
      initContainers:
      - name: wait-for-postgres
        image: busybox
        command: ['sh', '-c', 'until nc -z postgres 5432; do sleep 2; done']
      
      containers:
      - name: backend
        image: backend-app:latest  # Pre-built
        ports:
        - containerPort: 8000
        
        # Equivalent to environment
        env:
        - name: PYTHONUNBUFFERED
          value: "1"
        - name: DB_HOST
          value: postgres
        - name: DB_NAME
          value: appdb
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        
        # Note: volumes for hot-reload not typically used in K8s
        # Use Skaffold or Tilt for dev hot-reload
```

**Service** (service.yaml):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
  selector:
    app: backend
```

## When to Use What?

### Use Docker Compose When:

✅ Local development (single machine)
✅ Simple applications
✅ Quick prototyping
✅ CI/CD testing
✅ You need easy hot-reload
✅ Small team, simple deployments

### Use Kubernetes/Helm When:

✅ Production deployments
✅ Multi-node clusters
✅ High availability needed
✅ Auto-scaling required
✅ Complex microservices
✅ Enterprise environments
✅ Cloud-native applications
✅ Need advanced features (service mesh, operators, etc.)

## Best Practices

### Development Workflow

```
Local Dev (Docker Compose)
    ↓
    Test with Minikube/Kind (Helm)
    ↓
    Staging Environment (Helm)
    ↓
    Production (Helm)
```

### Keeping Both in Sync

1. **Use same base images**
   ```yaml
   # compose.yml
   image: postgres:15-alpine
   
   # values.yaml
   postgres:
     image:
       repository: postgres
       tag: "15-alpine"
   ```

2. **Same environment variables**
   - Keep a shared `.env.example`
   - Document all variables
   
3. **Same ports**
   - Backend always on 8000
   - PostgreSQL always on 5432

4. **Similar naming**
   ```yaml
   # Compose
   services:
     backend:
     postgres:
   
   # Helm
   Release: my-backend
   Services:
     - my-backend (FastAPI)
     - my-backend-postgres
   ```

## Common Gotchas

### 1. Image Building

❌ **Mistake:**
```yaml
# Won't work - Helm doesn't build
image:
  repository: ./backend
```

✅ **Correct:**
```bash
# Build first
docker build -t backend-app:latest ./backend
minikube image load backend-app:latest

# Then reference
image:
  repository: backend-app
  tag: latest
```

### 2. Service DNS

❌ **Mistake:**
```yaml
DB_HOST: postgres  # Might not resolve
```

✅ **Correct:**
```yaml
# Use full release name
DB_HOST: "{{ .Release.Name }}-postgres"
# Or full DNS
DB_HOST: my-backend-postgres.default.svc.cluster.local
```

### 3. Volumes in Development

❌ **Don't do this in K8s:**
```yaml
volumes:
  - ./backend/app:/app/app  # Host path mounting is problematic
```

✅ **Instead:**
- Rebuild image for code changes
- Or use Skaffold/Tilt for dev workflow
- Or use kubectl cp for quick tests

### 4. Plain Text Secrets

❌ **Bad:**
```yaml
env:
  - name: DB_PASSWORD
    value: supersecret  # Plain text in values.yaml
```

✅ **Better:**
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-secret
        key: password
```

✅ **Best (Production):**
- Use external secret manager
- Use Sealed Secrets
- Use SOPS
- Never commit secrets to git

## Migration Checklist

Moving from Docker Compose to Helm:

- [ ] Build all images with proper tags
- [ ] Create values.yaml with all configuration
- [ ] Convert environment variables
- [ ] Set up secrets properly
- [ ] Configure storage (PVCs)
- [ ] Add health checks (probes)
- [ ] Set resource limits
- [ ] Test in local cluster (minikube/kind)
- [ ] Document deployment process
- [ ] Set up CI/CD pipeline
- [ ] Plan rollout strategy

## Summary

| Aspect | Docker Compose | Helm/Kubernetes |
|--------|---------------|-----------------|
| **Complexity** | Simple | Complex |
| **Learning Curve** | Easy | Steep |
| **Use Case** | Dev, small apps | Production, scale |
| **Orchestration** | Single host | Multi-node cluster |
| **Networking** | Simple | Advanced |
| **Storage** | Volumes | PV/PVC |
| **Secrets** | Basic | Advanced |
| **Scaling** | Manual | Automatic |
| **HA** | Limited | Built-in |
| **Templating** | No | Yes (Helm) |

Both are valuable tools! Use Compose for development and simple deployments, use Kubernetes/Helm for production and complex applications.

