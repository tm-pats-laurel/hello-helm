#!/bin/bash
# Quick deployment script for local Kubernetes (minikube/kind)

set -e

RELEASE_NAME="${1:-my-frontend}"
NAMESPACE="${2:-default}"
BACKEND_RELEASE="${3:-my-backend}"

echo "🚀 Deploying Frontend Helm Chart"
echo "================================"
echo "Release Name: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Backend Release: $BACKEND_RELEASE"
echo ""

# Check if we're using minikube or kind
if kubectl config current-context | grep -q "minikube"; then
    echo "📦 Detected minikube - checking if image exists locally..."
    if ! minikube image ls | grep -q "frontend-app:latest"; then
        echo "⚠️  Image 'frontend-app:latest' not found in minikube"
        echo "Building and loading image..."
        cd ../../frontend
        docker build -f Dockerfile.prod -t frontend-app:latest .
        minikube image load frontend-app:latest
        cd ../helm_charts/frontend
        echo "✅ Image loaded into minikube"
    else
        echo "✅ Image already exists in minikube"
    fi
elif kubectl config current-context | grep -q "kind"; then
    echo "📦 Detected kind - checking if image exists..."
    echo "Building image..."
    cd ../../frontend
    docker build -f Dockerfile.prod -t frontend-app:latest .
    echo "Loading into kind..."
    kind load docker-image frontend-app:latest
    cd ../helm_charts/frontend
    echo "✅ Image loaded into kind"
fi

echo ""
echo "📝 Installing Helm chart..."

# Check if release already exists
if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    echo "⚠️  Release '$RELEASE_NAME' already exists. Upgrading..."
    helm upgrade $RELEASE_NAME . -n $NAMESPACE \
      --set backend.releaseName=$BACKEND_RELEASE
else
    echo "🆕 Installing new release..."
    helm install $RELEASE_NAME . -n $NAMESPACE \
      --set backend.releaseName=$BACKEND_RELEASE
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Status:"
kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE
echo ""
echo "🔍 Useful commands:"
echo "  Watch pods:    kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -w"
echo "  Frontend logs: kubectl logs -l app.kubernetes.io/name=frontend -n $NAMESPACE -f"
echo "  Port forward:  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME 3000:3000"
echo "  Uninstall:     helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
echo "🌐 After port-forwarding, access at:"
echo "  http://localhost:3000"
echo ""
echo "Backend URL configured as: http://$BACKEND_RELEASE:8000"

