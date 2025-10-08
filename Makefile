DOCKER ?= docker compose
BACKEND_IMAGE ?= backend-app
BACKEND_TAG ?= latest
RELEASE_NAME ?= my-backend
NAMESPACE ?= default

# ============================================
# Docker Compose Commands
# ============================================

local-frontend:
	$(DOCKER) up frontend

local-backend:
	$(DOCKER) up backend

local-env:
	$(DOCKER) up

# ============================================
# Backend Helm Commands
# ============================================

# Build the production backend image
build-backend:
	@echo "🔨 Building backend production image..."
	cd backend && docker build -f Dockerfile.prod -t $(BACKEND_IMAGE):$(BACKEND_TAG) .
	@echo "✅ Backend image built: $(BACKEND_IMAGE):$(BACKEND_TAG)"

# Load backend image into minikube
load-backend:
	@echo "📦 Loading backend image into minikube..."
	minikube image load $(BACKEND_IMAGE):$(BACKEND_TAG)
	@echo "✅ Backend image loaded into minikube"

# Deploy backend using the automated script
helm-local-backend:
	@echo "🚀 Deploying backend with Helm..."
	cd helm_charts/backend && ./deploy-local.sh $(RELEASE_NAME)

# Build, load, and deploy backend (complete workflow)
helm-backend: build-backend load-backend helm-local-backend
	@echo "✅ Backend deployment complete!"

# Port-forward backend service
pf-backend:
	@echo "🌐 Port-forwarding backend service..."
	@echo "Access at: http://localhost:8000/docs"
	kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME) 8000:8000

# View backend logs
backend-logs:
	@echo "📋 Viewing backend logs..."
	kubectl logs -l app.kubernetes.io/name=backend -n $(NAMESPACE) -f

# Destroy backend deployment and clean up resources
helm-destroy-backend:
	@echo "🗑️  Destroying backend deployment..."
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE) || true
	@echo "Deleting PVC..."
	kubectl delete pvc postgres-data-$(RELEASE_NAME)-postgres-0 -n $(NAMESPACE) || true
	@echo "✅ Backend resources cleaned up"

# ============================================
# Utility Commands
# ============================================

# Show all backend resources
backend-status:
	@echo "📊 Backend deployment status:"
	@kubectl get all -l app.kubernetes.io/instance=$(RELEASE_NAME) -n $(NAMESPACE)

# Show backend pods
backend-pods:
	@kubectl get pods -l app.kubernetes.io/instance=$(RELEASE_NAME) -n $(NAMESPACE)

# View PostgreSQL logs
postgres-logs:
	@echo "📋 Viewing PostgreSQL logs..."
	kubectl logs -l app.kubernetes.io/component=database -n $(NAMESPACE) -f

# Port-forward PostgreSQL
pf-postgres:
	@echo "🗄️  Port-forwarding PostgreSQL..."
	@echo "Connect with: psql -h localhost -U appuser -d appdb"
	kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-postgres 5432:5432

# Help command
help:
	@echo "Available commands:"
	@echo ""
	@echo "Docker Compose:"
	@echo "  make local-backend        - Run backend with Docker Compose"
	@echo "  make local-frontend       - Run frontend with Docker Compose"
	@echo "  make local-env            - Run full stack with Docker Compose"
	@echo ""
	@echo "Backend Helm Deployment:"
	@echo "  make build-backend        - Build production backend image"
	@echo "  make load-backend         - Load backend image into minikube"
	@echo "  make helm-local-backend   - Deploy backend with Helm"
	@echo "  make helm-backend         - Build + Load + Deploy (complete workflow)"
	@echo "  make helm-destroy-backend - Destroy backend deployment & clean up"
	@echo ""
	@echo "Backend Operations:"
	@echo "  make pf-backend           - Port-forward backend (http://localhost:8000)"
	@echo "  make backend-logs         - View backend application logs"
	@echo "  make backend-status       - Show all backend resources"
	@echo "  make backend-pods         - Show backend pods"
	@echo ""
	@echo "PostgreSQL Operations:"
	@echo "  make postgres-logs        - View PostgreSQL logs"
	@echo "  make pf-postgres          - Port-forward PostgreSQL (localhost:5432)"
	@echo ""
	@echo "Variables (override with make VAR=value):"
	@echo "  BACKEND_IMAGE=$(BACKEND_IMAGE)"
	@echo "  BACKEND_TAG=$(BACKEND_TAG)"
	@echo "  RELEASE_NAME=$(RELEASE_NAME)"
	@echo "  NAMESPACE=$(NAMESPACE)"

.PHONY: local-frontend local-backend local-env build-backend load-backend \
	helm-local-backend helm-backend pf-backend backend-logs helm-destroy-backend \
	backend-status backend-pods postgres-logs pf-postgres help

