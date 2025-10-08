# Hello Helm - Full Stack Application with Kubernetes

A full-stack application (FastAPI backend + Next.js frontend + PostgreSQL) demonstrating how to deploy with **Helm charts** on Kubernetes.

## 🎯 Project Overview

This project showcases:
- **FastAPI Backend** with PostgreSQL database
- **Next.js Frontend** (React)
- **Nginx** reverse proxy
- **Helm Charts** for Kubernetes deployment
- **Docker Compose** for local development

## 📁 Project Structure

```
hello-helm/
├── backend/                    # FastAPI application
│   ├── app/                   # Application code
│   ├── Dockerfile             # Dev dockerfile
│   ├── Dockerfile.prod        # Production dockerfile
│   └── pyproject.toml         # Python dependencies (uv)
│
├── frontend/                   # Next.js application
│   └── (frontend code)
│
├── nginx/                      # Nginx configuration
│   └── (nginx config)
│
├── helm_charts/               # Kubernetes Helm Charts
│   ├── backend/              # Backend + PostgreSQL chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-local.yaml
│   │   ├── templates/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── postgres-statefulset.yaml
│   │   │   ├── postgres-service.yaml
│   │   │   └── postgres-secret.yaml
│   │   ├── QUICK-START.md    # 5-minute deployment guide
│   │   ├── README.md          # Complete chart documentation
│   │   └── STRUCTURE.md       # Chart structure deep-dive
│   │
│   └── frontend/              # Frontend chart
│       └── (similar structure)
│
├── compose.yml                # Docker Compose for local dev
│
├── docs/                       # Documentation
│   ├── HELM-LEARNING-GUIDE.md      # 📚 Complete learning guide
│   ├── DEPLOYMENT.md               # Deployment instructions
│   ├── DOCKER-COMPOSE-VS-HELM.md   # Concept comparison
│   └── MAKEFILE-GUIDE.md           # Makefile commands reference
│
└── README.md                   # This file
```

## 🚀 Quick Start

### Option 1: Local Development with Docker Compose

```bash
docker-compose up
```

Access:
- Frontend: http://localhost:80
- Backend: http://localhost:80/api
- Backend docs: http://localhost:80/api/docs

### Option 2: Kubernetes with Helm

**Prerequisites:**
- Docker
- Kubernetes (minikube/kind/Docker Desktop)
- Helm 3.x
- kubectl

**Deploy in 3 commands:**

```bash
# 1. Build & load image
cd backend
docker build -f Dockerfile.prod -t backend-app:latest .
minikube image load backend-app:latest  # or: kind load docker-image backend-app:latest

# 2. Deploy with Helm
cd ../helm_charts/backend
helm install my-backend .

# 3. Access the application
kubectl port-forward svc/my-backend 8000:8000
```

Visit: http://localhost:8000/docs

## 📚 Documentation

### 🎓 Learning Helm Charts (Start Here!)

1. **[docs/HELM-LEARNING-GUIDE.md](docs/HELM-LEARNING-GUIDE.md)** ⭐
   - Complete learning path (Beginner → Advanced)
   - Understand Helm concepts
   - Key takeaways and best practices

2. **[helm_charts/backend/QUICK-START.md](helm_charts/backend/QUICK-START.md)**
   - Deploy in 5 minutes
   - Perfect for first-time users

3. **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**
   - Comprehensive deployment guide
   - Step-by-step instructions
   - Troubleshooting tips

### 📖 Understanding the Architecture

4. **[docs/DOCKER-COMPOSE-VS-HELM.md](docs/DOCKER-COMPOSE-VS-HELM.md)**
   - Compare Docker Compose to Kubernetes/Helm
   - Concept mapping
   - When to use what

5. **[helm_charts/backend/STRUCTURE.md](helm_charts/backend/STRUCTURE.md)**
   - Deep dive into Helm chart structure
   - Template syntax
   - Values flow

### 📘 Reference

6. **[helm_charts/backend/README.md](helm_charts/backend/README.md)**
   - Complete chart documentation
   - Configuration options
   - Customization examples

## 🏗️ Architecture

### Development (Docker Compose)

```
┌─────────────────────────────────────┐
│           Docker Compose             │
│  ┌─────────┐  ┌─────────┐           │
│  │ Nginx   │  │ Backend │           │
│  │ :80     │→ │ :8000   │           │
│  └─────────┘  └────┬────┘           │
│  ┌─────────┐       │                │
│  │Frontend │       │                │
│  │ :3000   │       ↓                │
│  └─────────┘  ┌──────────┐          │
│               │Postgres  │          │
│               │ :5432    │          │
│               └──────────┘          │
└─────────────────────────────────────┘
```

### Production (Kubernetes + Helm)

```
┌───────────────────────────────────────────────────┐
│              Kubernetes Cluster                   │
│                                                   │
│  ┌──────────────────┐  ┌────────────────────┐   │
│  │ Backend Deploy   │  │ Frontend Deploy    │   │
│  │ ┌──────────────┐ │  │ ┌────────────────┐ │   │
│  │ │ Pod │ Pod │..││ │  │ │ Pod │ Pod │... │ │   │
│  │ └──────────────┘ │  │ └────────────────┘ │   │
│  └────────┬─────────┘  └──────────┬─────────┘   │
│           │                       │              │
│  ┌────────▼─────────┐  ┌─────────▼─────────┐   │
│  │ Backend Service  │  │ Frontend Service  │   │
│  │ ClusterIP :8000  │  │ ClusterIP :3000   │   │
│  └──────────────────┘  └───────────────────┘   │
│           │                                      │
│  ┌────────▼─────────────────┐                   │
│  │ PostgreSQL StatefulSet   │                   │
│  │ ┌──────────────────────┐ │                   │
│  │ │ postgres-0           │ │                   │
│  │ └──────────────────────┘ │                   │
│  └────────┬─────────────────┘                   │
│           │                                      │
│  ┌────────▼─────────┐                           │
│  │ PVC (1Gi)        │                           │
│  └──────────────────┘                           │
└───────────────────────────────────────────────────┘
```

## 🛠️ Technology Stack

### Backend
- **FastAPI** - Modern Python web framework
- **SQLAlchemy** - ORM with async support
- **PostgreSQL 15** - Database
- **Uvicorn** - ASGI server
- **Pydantic** - Data validation
- **uv** - Fast Python package manager

### Frontend
- **Next.js** - React framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling

### Infrastructure
- **Docker** - Containerization
- **Kubernetes** - Orchestration
- **Helm** - Package management
- **Nginx** - Reverse proxy

## 📦 Backend Dependencies

```toml
[project]
dependencies = [
    "asyncpg>=0.30.0",
    "fastapi[standard]>=0.118.0",
    "pydantic>=2.11.10",
    "pydantic-settings>=2.11.0",
    "sqlmodel>=0.0.25",
    "uvicorn>=0.37.0",
]
```

## 🔒 Security Notes

⚠️ **For Production:**

1. **Secrets Management**
   - Don't store passwords in `values.yaml`
   - Use Kubernetes Secrets with encryption at rest
   - Consider external secret managers (Vault, AWS Secrets Manager)

2. **Image Security**
   - Use specific version tags, not `latest`
   - Scan images for vulnerabilities
   - Use minimal base images

3. **Network Security**
   - Implement Network Policies
   - Use TLS/SSL for all connections
   - Restrict service-to-service communication

4. **Access Control**
   - Enable RBAC
   - Use least privilege principle
   - Regular security audits

## 🧪 Testing

### Test Backend Locally

```bash
# With Docker Compose
docker-compose up backend postgres

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/items

# API docs
open http://localhost:8000/docs
```

### Test in Kubernetes

```bash
# Deploy
helm install test-backend helm_charts/backend/

# Port forward
kubectl port-forward svc/test-backend 8000:8000

# Test
curl http://localhost:8000/health

# Cleanup
helm uninstall test-backend
```

## 🐛 Troubleshooting

### Docker Compose Issues

```bash
# View logs
docker-compose logs backend
docker-compose logs postgres

# Restart services
docker-compose restart backend

# Clean up
docker-compose down -v
```

### Kubernetes Issues

```bash
# Check pod status
kubectl get pods

# View logs
kubectl logs -l app.kubernetes.io/name=backend

# Describe pod for events
kubectl describe pod <pod-name>

# Delete and recreate
helm uninstall my-backend
helm install my-backend helm_charts/backend/
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed troubleshooting.

## 📊 Monitoring & Observability

### Logs

```bash
# Docker Compose
docker-compose logs -f backend

# Kubernetes
kubectl logs -l app.kubernetes.io/name=backend -f
```

### Metrics

For production, consider adding:
- **Prometheus** - Metrics collection
- **Grafana** - Visualization
- **Loki** - Log aggregation
- **Jaeger** - Distributed tracing

## 🚢 CI/CD

Suggested pipeline:

```
1. Code Push
   ↓
2. Run Tests
   ↓
3. Build Docker Image
   ↓
4. Push to Registry
   ↓
5. Update Helm Values
   ↓
6. Deploy to Staging
   ↓
7. Run Integration Tests
   ↓
8. Deploy to Production (manual approval)
```

## 📝 Development Workflow

### Making Changes

1. **Edit code** in `backend/app/`
2. **Test locally** with Docker Compose
3. **Build new image** with version tag
4. **Update Helm values** with new tag
5. **Deploy to dev cluster** and test
6. **Deploy to production** when ready

### Example

```bash
# 1. Make changes
vim backend/app/main.py

# 2. Test with compose
docker-compose up backend

# 3. Build with version
docker build -f backend/Dockerfile.prod -t backend-app:v1.2.3 .

# 4. Load into cluster
minikube image load backend-app:v1.2.3

# 5. Deploy
helm upgrade my-backend helm_charts/backend/ \
  --set image.tag=v1.2.3
```

## 🤝 Contributing

This is a learning project following your company's Helm chart pattern:
- Each component gets its own chart
- Charts are independent and versioned separately
- Shared values through parent charts or external configuration

## 📄 License

This is a practice/learning project.

## 🎓 Learning Resources

- [Helm Official Docs](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Next.js Documentation](https://nextjs.org/docs)

## 🆘 Need Help?

1. Check **[HELM-LEARNING-GUIDE.md](HELM-LEARNING-GUIDE.md)** for comprehensive guidance
2. Review **[DEPLOYMENT.md](DEPLOYMENT.md)** for deployment issues
3. Read component-specific READMEs in `helm_charts/`
4. Check troubleshooting sections in each guide

## 🎯 Next Steps

- [ ] Deploy backend with Helm ✅ (follow QUICK-START.md)
- [ ] Create frontend Helm chart (similar pattern)
- [ ] Add Ingress for external access
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Implement CI/CD pipeline
- [ ] Add automated tests
- [ ] Document runbooks for operations

---

**Happy Learning!** 🚀⎈

For a complete learning experience, start with [docs/HELM-LEARNING-GUIDE.md](docs/HELM-LEARNING-GUIDE.md)!

