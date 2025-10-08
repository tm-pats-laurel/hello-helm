# Helm Chart Creation Walkthrough

A step-by-step guide explaining how the backend Helm chart was built from scratch.

## 📋 Table of Contents

1. [Overview](#overview)
2. [File Creation Sequence](#file-creation-sequence)
3. [Files We Created/Modified](#files-we-createdmodified)
4. [Files We Didn't Touch (and Why)](#files-we-didnt-touch-and-why)
5. [Deployment Command Sequence](#deployment-command-sequence)
6. [How Everything Works Together](#how-everything-works-together)

---

## Overview

When building a Helm chart from scratch, you typically start with:
1. **Chart metadata** (Chart.yaml)
2. **Default configuration** (values.yaml)
3. **Kubernetes resource templates** (templates/)
4. **Helper functions** (templates/_helpers.tpl)
5. **Deployment scripts and docs**

Let's walk through each step as if you're creating this from scratch.

---

## File Creation Sequence

### Phase 1: Chart Foundation (Start Here)

#### **Step 1: Create Chart.yaml**

**Purpose:** Defines the chart itself - its name, version, and metadata.

**What we did:**
```yaml
apiVersion: v2
name: backend
description: A Helm chart for Kubernetes
type: application
version: 0.1.0          # Chart version
appVersion: "0.1.0"     # Application version
```

**Why this first?**
- Helm requires this file to recognize it as a valid chart
- Defines the chart identity
- Without this, `helm install` will fail

**Key fields:**
- `name`: Chart name (must match directory name)
- `version`: Semantic version of the chart itself
- `appVersion`: Version of your application (FastAPI backend)

---

#### **Step 2: Create values.yaml**

**Purpose:** Default configuration values that can be overridden during installation.

**What we configured:**
```yaml
# Application configuration
replicaCount: 1
image:
  repository: backend-app
  tag: latest
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: ClusterIP
  port: 8000

# Health checks
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5

# Resources
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Environment variables
env:
  PYTHONUNBUFFERED: "1"

# PostgreSQL configuration
postgres:
  enabled: true
  image:
    repository: postgres
    tag: "15-alpine"
  auth:
    database: appdb
    username: appuser
    password: supersecret
  persistence:
    enabled: true
    size: 1Gi
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
```

**Why second?**
- Templates reference these values
- Defines the "contract" of what can be configured
- Makes it clear what the chart supports

**Key sections:**
- **Application config**: Image, replicas, resources
- **Service config**: How to expose the app
- **Health checks**: Liveness and readiness probes
- **PostgreSQL config**: Database settings

---

### Phase 2: Kubernetes Resource Templates

Templates generate actual Kubernetes manifests. They use Go templating to inject values.

#### **Step 3: Create templates/_helpers.tpl**

**Purpose:** Reusable template functions to avoid repetition.

**What it provides:**
```go
{{/* Generate the full name */}}
{{- define "backend.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name }}
{{- end }}
{{- end }}

{{/* Common labels */}}
{{- define "backend.labels" -}}
helm.sh/chart: {{ include "backend.chart" . }}
app.kubernetes.io/name: {{ include "backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

**Why this early?**
- Other templates will reference these helpers
- Ensures consistency across all resources
- DRY principle (Don't Repeat Yourself)

**Common helpers:**
- `backend.fullname`: Generates unique names
- `backend.labels`: Standard Kubernetes labels
- `backend.selectorLabels`: Labels for pod selection
- `backend.serviceAccountName`: Service account name

---

#### **Step 4: Create templates/deployment.yaml**

**Purpose:** Defines how to run your FastAPI application.

**What we configured:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "backend.fullname" . }}
  labels:
    {{- include "backend.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "backend.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "backend.labels" . | nindent 8 }}
    spec:
      # Wait for PostgreSQL
      initContainers:
      - name: wait-for-postgres
        image: busybox:1.36
        command: ['sh', '-c']
        args:
        - |
          until nc -z {{ .Release.Name }}-postgres 5432; do
            echo "Waiting for postgres..."
            sleep 2
          done
      
      # Main container
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.port }}
        
        # Environment variables
        env:
        {{- range $key, $value := .Values.env }}
        - name: {{ $key }}
          value: {{ $value | quote }}
        {{- end }}
        # Database connection (if postgres enabled)
        {{- if .Values.postgres.enabled }}
        - name: DB_HOST
          value: {{ printf "%s-postgres" .Release.Name | quote }}
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: {{ printf "%s-postgres-secret" .Release.Name }}
              key: database
        # ... etc
        {{- end }}
        
        # Health checks
        livenessProbe:
          {{- toYaml .Values.livenessProbe | nindent 10 }}
        readinessProbe:
          {{- toYaml .Values.readinessProbe | nindent 10 }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

**Key features:**
1. **Init container**: Waits for PostgreSQL before starting
2. **Environment variables**: Two types:
   - Simple values from `values.yaml`
   - Secret references for database credentials
3. **Health probes**: Kubernetes uses these to know when app is ready
4. **Resource limits**: Prevents resource exhaustion

**Template functions used:**
- `{{ include "backend.fullname" . }}`: Get the full name
- `{{ .Values.replicaCount }}`: Reference values
- `{{ .Release.Name }}`: Current release name
- `{{- toYaml .Values.resources | nindent 10 }}`: Convert YAML and indent

---

#### **Step 5: Create templates/service.yaml**

**Purpose:** Exposes your application within the cluster.

**What it does:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "backend.fullname" . }}
  labels:
    {{- include "backend.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: http
    protocol: TCP
    name: http
  selector:
    {{- include "backend.selectorLabels" . | nindent 4 }}
```

**Why this matters:**
- Creates DNS name: `<release-name>` in the namespace
- Routes traffic to backend pods
- Load balances across multiple replicas

**Already existed** in the starter template, so we didn't need to create it.

---

### Phase 3: PostgreSQL Resources (What We Added)

#### **Step 6: Create templates/postgres-secret.yaml**

**Purpose:** Securely stores database credentials.

**What we created:**
```yaml
{{- if .Values.postgres.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Release.Name }}-postgres-secret
  labels:
    {{- include "backend.labels" . | nindent 4 }}
    app.kubernetes.io/component: database
type: Opaque
data:
  username: {{ .Values.postgres.auth.username | b64enc | quote }}
  password: {{ .Values.postgres.auth.password | b64enc | quote }}
  database: {{ .Values.postgres.auth.database | b64enc | quote }}
{{- end }}
```

**Key points:**
- `{{- if .Values.postgres.enabled }}`: Only create if postgres is enabled
- `b64enc`: Base64 encodes the values (Kubernetes requirement)
- `type: Opaque`: Standard secret type
- Referenced by both backend deployment and postgres statefulset

**Security note:**
- In production, use external secret managers
- Don't commit secrets to git
- This is OK for local development

---

#### **Step 7: Create templates/postgres-statefulset.yaml**

**Purpose:** Runs PostgreSQL with stable storage and identity.

**Why StatefulSet (not Deployment)?**
- **Stable network identity**: Pod name stays same across restarts
- **Persistent storage**: Data survives pod restarts
- **Ordered deployment**: Ensures data consistency

**What we created:**
```yaml
{{- if .Values.postgres.enabled }}
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ .Release.Name }}-postgres
  labels:
    {{- include "backend.labels" . | nindent 4 }}
    app.kubernetes.io/component: database
spec:
  serviceName: {{ .Release.Name }}-postgres
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "backend.name" . }}-postgres
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "backend.name" . }}-postgres
        app.kubernetes.io/instance: {{ .Release.Name }}
        app.kubernetes.io/component: database
    spec:
      containers:
      - name: postgres
        image: "{{ .Values.postgres.image.repository }}:{{ .Values.postgres.image.tag }}"
        ports:
        - name: postgres
          containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: {{ .Release.Name }}-postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .Release.Name }}-postgres-secret
              key: password
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: {{ .Release.Name }}-postgres-secret
              key: database
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - exec pg_isready -U {{ .Values.postgres.auth.username }} -h 127.0.0.1
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - exec pg_isready -U {{ .Values.postgres.auth.username }} -h 127.0.0.1
  # Persistent storage
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: {{ .Values.postgres.persistence.size }}
{{- end }}
```

**Key features:**
1. **Environment from Secret**: Credentials from secret we created
2. **Volume mount**: Data stored in `/var/lib/postgresql/data`
3. **Health checks**: Uses `pg_isready` to verify PostgreSQL is up
4. **VolumeClaimTemplate**: Automatically creates PVC for each pod

**Important:**
- `serviceName`: Must match the Service we create next
- `PGDATA`: Tells PostgreSQL where to store data
- `volumeClaimTemplates`: Creates PVC automatically

---

#### **Step 8: Create templates/postgres-service.yaml**

**Purpose:** Provides stable DNS for PostgreSQL StatefulSet.

**What we created:**
```yaml
{{- if .Values.postgres.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-postgres
  labels:
    {{- include "backend.labels" . | nindent 4 }}
    app.kubernetes.io/component: database
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: postgres
    protocol: TCP
    name: postgres
  selector:
    app.kubernetes.io/name: {{ include "backend.name" . }}-postgres
    app.kubernetes.io/instance: {{ .Release.Name }}
  clusterIP: None  # Headless service
{{- end }}
```

**Why headless service?**
- `clusterIP: None`: No load balancing (StatefulSets need direct pod access)
- Provides DNS: `<release-name>-postgres.<namespace>.svc.cluster.local`
- StatefulSet pods get: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`

**How backend connects:**
```bash
DB_HOST=my-backend-postgres  # Short name works in same namespace
# Full: my-backend-postgres.default.svc.cluster.local
```

---

### Phase 4: Supporting Files

#### **Step 9: Create templates/serviceaccount.yaml**

**Already existed** - provides identity for pods.

**Purpose:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "backend.serviceAccountName" . }}
  labels:
    {{- include "backend.labels" . | nindent 4 }}
```

**Why needed:**
- Required by some Kubernetes security policies
- Can be used for RBAC (Role-Based Access Control)
- Good practice even if not strictly required

---

#### **Step 10: Create .helmignore**

**Already existed** - tells Helm what files to ignore when packaging.

**Contents:**
```
.DS_Store
.git/
.gitignore
.vscode/
*.swp
*.bak
*.tmp
```

**Purpose:**
- Reduces chart package size
- Keeps development files out of production
- Similar to `.gitignore` but for Helm

---

#### **Step 11: Create templates/NOTES.txt**

**Already existed** - shows instructions after deployment.

**Purpose:**
- Displayed after `helm install` or `helm upgrade`
- Provides next steps to user
- Dynamically generated based on service type

**Example output:**
```
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods ... -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl port-forward $POD_NAME 8080:$CONTAINER_PORT
```

---

### Phase 5: Deployment Helpers

#### **Step 12: Create values-local.yaml**

**Purpose:** Example values for local development.

**What we created:**
```yaml
# Lower resources for local dev
resources:
  limits:
    cpu: 300m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 128Mi

postgres:
  enabled: true
  persistence:
    enabled: true
    size: 1Gi
    storageClass: ""  # Uses default (works with minikube/kind)
```

**Why useful:**
- Users can install with: `helm install my-backend . -f values-local.yaml`
- Shows examples of customization
- Optimized for local development

---

#### **Step 13: Create deploy-local.sh**

**Purpose:** Automates the deployment process.

**What it does:**
```bash
#!/bin/bash
# 1. Detects minikube/kind
# 2. Builds image if needed
# 3. Loads image into cluster
# 4. Installs/upgrades Helm release
# 5. Shows status and helpful commands
```

**Why helpful:**
- One command to deploy everything
- Handles minikube vs kind differences
- Provides clear feedback

---

## Files We Didn't Touch (and Why)

### **templates/ingress.yaml** ❌ Not Deleted

**Purpose:** Exposes service externally via HTTP/HTTPS.

**Why we kept it:**
- Useful for production deployments
- Users might want to add external access later
- Disabled by default: `ingress.enabled: false`

**When you'd use it:**
```yaml
# values.yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: backend.example.com
      paths:
        - path: /
          pathType: Prefix
```

**What it creates:**
- External URL: `https://backend.example.com`
- TLS termination
- Path-based routing

---

### **templates/hpa.yaml** ❌ Not Deleted

**Purpose:** Horizontal Pod Autoscaler - automatically scales pods based on CPU/memory.

**Why we kept it:**
- Essential for production
- Auto-scaling based on load
- Disabled by default: `autoscaling.enabled: false`

**When you'd enable it:**
```yaml
# values.yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

**What it does:**
- Monitors CPU usage
- Scales from 2 to 10 pods automatically
- Handles traffic spikes

---

### **templates/httproute.yaml** ❌ Not Deleted

**Purpose:** Gateway API (newer alternative to Ingress).

**Why we kept it:**
- Modern way to expose services
- More powerful than Ingress
- Disabled by default: `httpRoute.enabled: false`

**When you'd use it:**
```yaml
# values.yaml
httpRoute:
  enabled: true
  parentRefs:
  - name: my-gateway
  hostnames:
  - backend.example.com
```

**What it provides:**
- Advanced routing (headers, methods, query params)
- Better multi-cluster support
- More flexible than Ingress

---

### **templates/tests/** ❌ Not Deleted

**Purpose:** Helm tests to verify deployment.

**Why we kept it:**
- Good practice to have tests
- Can run with: `helm test <release-name>`
- Validates deployment worked

**Example test:**
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
    args: ['{{ include "backend.fullname" . }}:{{ .Values.service.port }}/health']
  restartPolicy: Never
```

---

## Deployment Command Sequence

### **Phase 1: Preparation**

```bash
# 1. Start Kubernetes cluster
minikube start
# or
kind create cluster --name hello-helm

# 2. Verify kubectl works
kubectl cluster-info
kubectl get nodes
```

**What happens:**
- Kubernetes cluster starts
- kubectl configured to talk to cluster
- Cluster ready to accept deployments

---

### **Phase 2: Build Application Image**

```bash
# 3. Build Docker image
cd backend
docker build -f Dockerfile.prod -t backend-app:latest .
```

**What happens:**
- Multi-stage build:
  1. Builder stage: Installs dependencies with uv
  2. Final stage: Copies app, runs as non-root user
- Creates image: `backend-app:latest`

**Dockerfile.prod key steps:**
```dockerfile
# Stage 1: Build
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder
WORKDIR /app
RUN uv sync --locked --no-dev

# Stage 2: Runtime
FROM python:3.12-slim-bookworm
COPY --from=builder /app /app
USER nonroot
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

### **Phase 3: Load Image into Cluster**

```bash
# 4. Load image (minikube)
minikube image load backend-app:latest

# OR (kind)
kind load docker-image backend-app:latest --name hello-helm
```

**What happens:**
- Image copied from Docker to cluster's container runtime
- Pods can now use `imagePullPolicy: IfNotPresent`
- No need to push to registry for local development

**Why needed:**
- Minikube/kind have separate Docker daemons
- They can't see your local Docker images
- Docker Desktop doesn't need this step

---

### **Phase 4: Deploy with Helm**

```bash
# 5. Install Helm chart
cd helm_charts/backend
helm install my-backend .

# OR with custom values
helm install my-backend . -f values-local.yaml
```

**What Helm does internally:**

**Step 5.1: Template Rendering**
```bash
# Helm processes templates
{{ .Release.Name }}          → my-backend
{{ .Values.image.repository }}  → backend-app
{{ include "backend.fullname" . }} → my-backend
```

**Step 5.2: Generate Manifests**
- Combines all templates with values
- Produces valid Kubernetes YAML
- You can see this with: `helm template my-backend .`

**Step 5.3: Create Resources in Order**

```
1. Namespace (if needed)
2. Secret (postgres-secret)
3. ServiceAccount
4. Service (backend and postgres)
5. StatefulSet (postgres)
6. Deployment (backend with init container)
```

**Why this order?**
- Secrets must exist before pods reference them
- Services should exist before pods (for DNS)
- StatefulSet creates PVC before pods start

---

### **Phase 5: Kubernetes Resource Creation**

#### **5a. Secret Created**
```bash
kubectl get secret my-backend-postgres-secret
```

**What's stored:**
```yaml
data:
  username: YXBwdXNlcg==     # base64(appuser)
  password: c3VwZXJzZWNyZXQ=  # base64(supersecret)
  database: YXBwZGI=          # base64(appdb)
```

#### **5b. Services Created**
```bash
kubectl get svc
```

**Output:**
```
NAME                    TYPE        CLUSTER-IP      PORT(S)
my-backend              ClusterIP   10.96.1.100     8000/TCP
my-backend-postgres     ClusterIP   None            5432/TCP
```

**DNS entries created:**
- `my-backend` → Points to backend pods
- `my-backend-postgres` → Points to postgres pod

#### **5c. PostgreSQL StatefulSet Started**
```bash
kubectl get statefulset
```

**What happens:**
1. PVC created: `postgres-data-my-backend-postgres-0`
2. PV automatically provisioned (if storage class exists)
3. Pod created: `my-backend-postgres-0`
4. PostgreSQL starts, initializes database
5. Readiness probe passes

**Timeline:**
```
0s:  StatefulSet created
5s:  PVC bound
10s: Pod starting
15s: PostgreSQL initializing
20s: Ready to accept connections ✓
```

#### **5d. Backend Deployment Started**
```bash
kubectl get deployment
kubectl get pods
```

**What happens:**

**Phase 1: Init Container**
```
0s:  Pod created
2s:  Init container starts (wait-for-postgres)
3s:  Checking: nc -z my-backend-postgres 5432
     ... waiting ...
20s: PostgreSQL ready! Init container completes ✓
```

**Phase 2: Main Container**
```
20s: Backend container starts
22s: Python/FastAPI loading
25s: Database connection established
27s: FastAPI app started
30s: Liveness probe (first check after 30s delay)
35s: Liveness probe passed ✓
30s: Readiness probe (first check after 10s delay)
35s: Readiness probe passed ✓
```

**Pod marked Ready** → Service sends traffic to it

---

### **Phase 6: Verify Deployment**

```bash
# 6. Check all resources
kubectl get all -l app.kubernetes.io/instance=my-backend
```

**Expected output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
pod/my-backend-xxxx-xxxx          1/1     Running   0          1m
pod/my-backend-postgres-0         1/1     Running   0          1m

NAME                          TYPE        CLUSTER-IP     PORT(S)
service/my-backend            ClusterIP   10.96.1.100    8000/TCP
service/my-backend-postgres   ClusterIP   None           5432/TCP

NAME                         READY   UP-TO-DATE   AVAILABLE
deployment.apps/my-backend   1/1     1            1

NAME                                   DESIRED   CURRENT   READY
replicaset.apps/my-backend-xxxx        1         1         1

NAME                                   READY
statefulset.apps/my-backend-postgres   1/1
```

**✓ All resources running!**

---

### **Phase 7: Access the Application**

```bash
# 7. Port-forward to access locally
kubectl port-forward svc/my-backend 8000:8000
```

**What happens:**
```
1. kubectl creates tunnel: localhost:8000 → cluster:8000
2. Cluster routes to service: my-backend
3. Service load-balances to pod(s)
4. Request reaches FastAPI on pod port 8000
```

**Test it:**
```bash
# Health check
curl http://localhost:8000/health
# {"status":"ok"}

# Create item (tests database)
curl -X POST http://localhost:8000/items \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"From K8s"}'
# {"title":"Test","description":"From K8s","id":1}

# List items
curl http://localhost:8000/items
# [{"title":"Test","description":"From K8s","id":1}]
```

---

## How Everything Works Together

### **The Complete Flow**

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  1. User: helm install my-backend .                │    │
│  └────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────┐    │
│  │  2. Helm renders templates with values            │    │
│  │     - Chart.yaml provides metadata                 │    │
│  │     - values.yaml provides configuration           │    │
│  │     - _helpers.tpl provides functions              │    │
│  │     - templates/*.yaml generate resources          │    │
│  └────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────┐    │
│  │  3. Kubernetes creates resources                   │    │
│  └────────────────────────────────────────────────────┘    │
│                           │                                  │
│          ┌────────────────┼────────────────┐                │
│          ▼                ▼                ▼                │
│   ┌───────────┐    ┌──────────┐    ┌─────────────┐        │
│   │  Secret   │    │ Services │    │ServiceAcct  │        │
│   │ postgres- │    │ -backend │    │             │        │
│   │  secret   │    │ -postgres│    │             │        │
│   └─────┬─────┘    └────┬─────┘    └─────────────┘        │
│         │               │                                   │
│         │   References  │ Provides DNS                      │
│         │               │                                   │
│   ┌─────▼──────────┐   │  ┌──────────────────┐            │
│   │  StatefulSet   │◄──┘  │   Deployment     │            │
│   │   (postgres)   │      │   (backend)      │            │
│   │                │      │                  │            │
│   │  ┌──────────┐  │      │  ┌────────────┐  │            │
│   │  │  Pod:    │  │      │  │ Init       │  │            │
│   │  │ postgres-0│ │      │  │ Container  │──┼──────┐     │
│   │  │          │  │      │  │ (waits)    │  │      │     │
│   │  └────┬─────┘  │      │  └─────┬──────┘  │      │     │
│   └───────┼────────┘      │        │         │      │     │
│           │               │        ▼         │      │     │
│           │               │  ┌────────────┐  │      │     │
│     Stores data           │  │  Backend   │  │  Checks    │
│           │               │  │  Container │  │  postgres  │
│           ▼               │  │  (FastAPI) │  │      │     │
│   ┌─────────────┐         │  └─────┬──────┘  │      │     │
│   │     PVC     │         └────────┼─────────┘      │     │
│   │ postgres-   │                  │                │     │
│   │   data      │◄─────Connects────┘                │     │
│   │   (1Gi)     │        to DB                      │     │
│   └─────┬───────┘                                   │     │
│         │                                           │     │
│         ▼                                           ▼     │
│   ┌─────────────┐                            Ready when   │
│   │     PV      │                            postgres     │
│   │  (Actual    │                            accepts      │
│   │  Storage)   │                            connections  │
│   └─────────────┘                                         │
│                                                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │  4. User: kubectl port-forward svc/my-backend      │  │
│  └────────────────────────────────────────────────────┘  │
│                           │                                │
│      localhost:8000 ──────┼──► Service ──► Backend Pod    │
│                                                            │
└─────────────────────────────────────────────────────────────┘
```

### **Environment Variable Flow**

```
values.yaml:
  env:
    PYTHONUNBUFFERED: "1"
  postgres:
    auth:
      username: appuser
      password: supersecret
      database: appdb

         │
         ▼
templates/postgres-secret.yaml:
  data:
    username: {{ .Values.postgres.auth.username | b64enc }}
    password: {{ .Values.postgres.auth.password | b64enc }}
    database: {{ .Values.postgres.auth.database | b64enc }}
    
         │
         ▼
Secret created in K8s:
  my-backend-postgres-secret
    username: YXBwdXNlcg==
    password: c3VwZXJzZWNyZXQ=
    database: YXBwZGI=
    
         │
         ▼
templates/deployment.yaml:
  env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: my-backend-postgres-secret
        key: username
        
         │
         ▼
Backend Pod receives:
  DB_USER=appuser
  DB_PASSWORD=supersecret
  DB_NAME=appdb
  DB_HOST=my-backend-postgres
  
         │
         ▼
FastAPI connects to:
  postgresql+asyncpg://appuser:supersecret@my-backend-postgres:5432/appdb
```

---

## Key Takeaways

### **File Creation Order Summary**

1. **Chart.yaml** - Chart metadata (required first)
2. **values.yaml** - Configuration defaults
3. **templates/_helpers.tpl** - Reusable functions
4. **templates/deployment.yaml** - Main application
5. **templates/service.yaml** - Networking (existed)
6. **templates/postgres-secret.yaml** - Credentials (new)
7. **templates/postgres-statefulset.yaml** - Database (new)
8. **templates/postgres-service.yaml** - Database DNS (new)
9. **templates/serviceaccount.yaml** - Identity (existed)
10. **values-local.yaml** - Example values (new)
11. **deploy-local.sh** - Automation script (new)

### **Files We Kept (Not Using Yet)**

- **ingress.yaml** - External HTTP access (future)
- **hpa.yaml** - Auto-scaling (production feature)
- **httproute.yaml** - Gateway API (modern alternative)
- **NOTES.txt** - Post-install instructions (helpful)
- **.helmignore** - Package exclusions (necessary)

### **Command Flow**

```
Build Image → Load to Cluster → Helm Install → K8s Creates Resources → Verify → Access
```

### **Resource Dependencies**

```
Secret ──→ StatefulSet (postgres)
          └──→ Service (postgres)
                └──→ Deployment (backend init container waits)
                      └──→ Service (backend)
                            └──→ Ready! ✓
```

---

**Next:** Try modifying values.yaml and running `helm upgrade my-backend .` to see changes!

