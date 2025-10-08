#!/bin/bash
# Quick deployment script for local Kubernetes (minikube/kind)

set -e

RELEASE_NAME="${1:-my-backend}"
NAMESPACE="${2:-default}"

echo "🚀 Deploying Backend Helm Chart"
echo "================================"
echo "Release Name: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo ""

# Check if we're using minikube or kind
if kubectl config current-context | grep -q "minikube"; then
    echo "📦 Detected minikube - checking if image exists locally..."
    if ! minikube image ls | grep -q "backend-app:latest"; then
        echo "⚠️  Image 'backend-app:latest' not found in minikube"
        echo "Building and loading image..."
        cd ../../backend
        docker build -f Dockerfile.prod -t backend-app:latest .
        minikube image load backend-app:latest
        cd ../helm_charts/backend
        echo "✅ Image loaded into minikube"
    else
        echo "✅ Image already exists in minikube"
    fi
elif kubectl config current-context | grep -q "kind"; then
    echo "📦 Detected kind - checking if image exists..."
    echo "⚠️  Make sure to run: kind load docker-image backend-app:latest"
    echo "Building image..."
    cd ../../backend
    docker build -f Dockerfile.prod -t backend-app:latest .
    echo "Loading into kind..."
    kind load docker-image backend-app:latest
    cd ../helm_charts/backend
    echo "✅ Image loaded into kind"
fi

echo ""
echo "📝 Installing Helm chart..."

# Check if release already exists
if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    echo "⚠️  Release '$RELEASE_NAME' already exists. Upgrading..."
    helm upgrade $RELEASE_NAME . -n $NAMESPACE
else
    echo "🆕 Installing new release..."
    helm install $RELEASE_NAME . -n $NAMESPACE
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Status:"
kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE
echo ""
echo "🔍 Useful commands:"
echo "  Watch pods:    kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -w"
echo "  Backend logs:  kubectl logs -l app.kubernetes.io/name=backend -n $NAMESPACE -f"
echo "  Postgres logs: kubectl logs -l app.kubernetes.io/component=database -n $NAMESPACE -f"
echo "  Port forward:  kubectl port-forward -n $NAMESPACE svc/$RELEASE_NAME 8000:8000"
echo "  Uninstall:     helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
echo "🌐 After port-forwarding, access at:"
echo "  http://localhost:8000/health"
echo "  http://localhost:8000/docs"

