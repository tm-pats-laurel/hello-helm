# Backend Helm Chart Structure

## 📁 Directory Layout

```
backend/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default configuration values
├── values-local.yaml             # Local development values
├── README.md                     # Documentation
├── STRUCTURE.md                  # This file
├── deploy-local.sh              # Quick deployment script
│
├── templates/                    # Kubernetes manifests (templates)
│   ├── _helpers.tpl             # Template helpers/functions
│   ├── deployment.yaml          # Backend FastAPI deployment
│   ├── service.yaml             # Backend service
│   ├── serviceaccount.yaml      # Service account
│   ├── postgres-secret.yaml     # Database credentials
│   ├── postgres-statefulset.yaml # PostgreSQL database
│   ├── postgres-service.yaml    # PostgreSQL service
│   ├── ingress.yaml             # (Optional) Ingress config
│   ├── hpa.yaml                 # (Optional) Horizontal Pod Autoscaler
│   └── NOTES.txt                # Post-install notes
│
└── .helmignore                   # Files to ignore when packaging
```

## 🔑 Key Files Explained

### Chart.yaml
Defines the chart itself:
- **name**: `backend`
- **version**: `0.1.0` (chart version)
- **appVersion**: `0.1.0` (application version)
- **type**: `application`

### values.yaml
The main configuration file. Contains all customizable values:

```yaml
# Application settings
replicaCount: 1
image:
  repository: backend-app
  tag: latest

# Service settings
service:
  type: ClusterIP
  port: 8000

# Environment variables
env:
  - DB_HOST, DB_NAME, DB_USER, DB_PASSWORD

# PostgreSQL settings
postgres:
  enabled: true
  auth:
    database: appdb
    username: appuser
    password: supersecret
  persistence:
    enabled: true
    size: 1Gi
```

### Templates

#### deployment.yaml
Creates the FastAPI application Deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 1
  template:
    spec:
      initContainers:
        - wait-for-postgres  # Waits for DB
      containers:
        - name: backend
          image: backend-app:latest
          port: 8000
          env: [DB_HOST, DB_USER, ...]
          livenessProbe: /health
          readinessProbe: /health
```

#### service.yaml
Exposes the backend internally:
```yaml
apiVersion: v1
kind: Service
spec:
  type: ClusterIP
  ports:
    - port: 8000
  selector:
    app: backend
```

#### postgres-secret.yaml
Stores database credentials (base64 encoded):
```yaml
apiVersion: v1
kind: Secret
data:
  username: <base64>
  password: <base64>
  database: <base64>
```

#### postgres-statefulset.yaml
Manages PostgreSQL database:
```yaml
apiVersion: apps/v1
kind: StatefulSet
spec:
  serviceName: postgres
  replicas: 1
  volumeClaimTemplates:
    - postgres-data (1Gi)
  template:
    spec:
      containers:
        - name: postgres
          image: postgres:15-alpine
          env: [POSTGRES_USER, POSTGRES_PASSWORD, ...]
```

#### postgres-service.yaml
Headless service for StatefulSet:
```yaml
apiVersion: v1
kind: Service
spec:
  clusterIP: None  # Headless
  ports:
    - port: 5432
```

## 🎯 How Values Flow

```
values.yaml
    ↓
    ├──→ deployment.yaml → Backend Pods
    │    ├─ .Values.image.repository
    │    ├─ .Values.replicaCount
    │    ├─ .Values.env (environment vars)
    │    └─ .Values.resources
    │
    ├──→ service.yaml → Backend Service
    │    ├─ .Values.service.type
    │    └─ .Values.service.port
    │
    └──→ postgres-statefulset.yaml → PostgreSQL
         ├─ .Values.postgres.image.tag
         ├─ .Values.postgres.auth.*
         └─ .Values.postgres.persistence.size
```

## 🔄 Template Processing

When you run `helm install`, this happens:

1. **Load values**: Read `values.yaml` (and any `-f` overrides)
2. **Process templates**: Replace `{{ .Values.* }}` with actual values
3. **Generate manifests**: Create final Kubernetes YAML
4. **Apply to cluster**: Send to Kubernetes API

Example transformation:

**Template** (deployment.yaml):
```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

**Values** (values.yaml):
```yaml
image:
  repository: backend-app
  tag: latest
```

**Final Manifest**:
```yaml
image: "backend-app:latest"
```

## 🏗️ Architecture Deployed

```
┌─────────────────────────────────────────────────────┐
│              Kubernetes Cluster                      │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │  Deployment: my-backend                    │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐ │    │
│  │  │ Pod 1    │  │ Pod 2    │  │ Pod 3    │ │    │
│  │  │ Backend  │  │ Backend  │  │ Backend  │ │    │
│  │  │ :8000    │  │ :8000    │  │ :8000    │ │    │
│  │  └─────▲────┘  └─────▲────┘  └─────▲────┘ │    │
│  └────────┼─────────────┼─────────────┼──────┘    │
│           │             │             │            │
│  ┌────────┼─────────────┼─────────────┼──────┐    │
│  │ Service: my-backend (ClusterIP)          │    │
│  │        Port: 8000                          │    │
│  └───────────────────────────────────────────┘    │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │  StatefulSet: my-backend-postgres          │    │
│  │  ┌──────────────────────────┐              │    │
│  │  │ Pod: postgres-0          │              │    │
│  │  │ PostgreSQL 15            │              │    │
│  │  │ Port: 5432               │              │    │
│  │  └─────────▲────────────────┘              │    │
│  └────────────┼───────────────────────────────┘    │
│               │                                      │
│  ┌────────────┼───────────────────────────────┐    │
│  │ Service: my-backend-postgres (Headless)    │    │
│  │        Port: 5432                          │    │
│  └───────────────────────────────────────────┘    │
│               │                                      │
│  ┌────────────▼───────────────────────────────┐    │
│  │ PVC: postgres-data-my-backend-postgres-0   │    │
│  │ Size: 1Gi                                  │    │
│  └───────────────────────────────────────────┘    │
│               │                                      │
│  ┌────────────▼───────────────────────────────┐    │
│  │ PV: Automatically provisioned              │    │
│  └───────────────────────────────────────────┘    │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │ Secret: my-backend-postgres-secret         │    │
│  │ - username: appuser                        │    │
│  │ - password: ••••••••••                     │    │
│  │ - database: appdb                          │    │
│  └───────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

## 🔧 Template Functions Used

### In _helpers.tpl

1. **`backend.name`**: Returns the chart name
2. **`backend.fullname`**: Returns release-name-chart-name
3. **`backend.labels`**: Standard Kubernetes labels
4. **`backend.selectorLabels`**: Labels for pod selection

### In templates

1. **`include`**: Include helper templates
   ```yaml
   labels:
     {{- include "backend.labels" . | nindent 4 }}
   ```

2. **`tpl`**: Process template strings
   ```yaml
   value: {{ tpl .value $ | quote }}
   ```

3. **`b64enc`**: Base64 encode
   ```yaml
   password: {{ .Values.postgres.auth.password | b64enc | quote }}
   ```

4. **`nindent`**: Indent and add newline
   ```yaml
   {{- toYaml . | nindent 8 }}
   ```

5. **Conditionals**:
   ```yaml
   {{- if .Values.postgres.enabled }}
   # PostgreSQL resources
   {{- end }}
   ```

6. **Loops**:
   ```yaml
   {{- range .Values.env }}
   - name: {{ .name }}
   {{- end }}
   ```

## 🎨 Customization Points

You can customize by modifying `values.yaml` or creating override files:

### Common Customizations

1. **Change image**:
   ```yaml
   image:
     repository: myregistry/backend
     tag: v1.2.3
   ```

2. **Scale up**:
   ```yaml
   replicaCount: 3
   ```

3. **Adjust resources**:
   ```yaml
   resources:
     limits:
       cpu: 1000m
       memory: 1Gi
   ```

4. **Use external database**:
   ```yaml
   postgres:
     enabled: false
   
   env:
     - name: DB_HOST
       value: "external-db.example.com"
   ```

5. **Enable autoscaling**:
   ```yaml
   autoscaling:
     enabled: true
     minReplicas: 2
     maxReplicas: 10
     targetCPUUtilizationPercentage: 80
   ```

## 🔍 Debugging Templates

Render templates without installing:

```bash
# See all manifests
helm template my-backend .

# Save to file
helm template my-backend . > rendered.yaml

# Debug with values
helm template my-backend . --debug

# Specific values file
helm template my-backend . -f values-local.yaml
```

Check what will be installed:

```bash
# Dry run
helm install my-backend . --dry-run --debug

# Show diff on upgrade
helm diff upgrade my-backend .  # Requires helm-diff plugin
```

## 📚 Learn More

- **Helm Go Templates**: https://helm.sh/docs/chart_template_guide/
- **Sprig Functions**: http://masterminds.github.io/sprig/
- **Best Practices**: https://helm.sh/docs/chart_best_practices/
- **[HELM Learning Guide](../../docs/HELM-LEARNING-GUIDE.md)** - Complete learning path
- **[Deployment Guide](../../docs/DEPLOYMENT.md)** - Full deployment instructions

