#!/bin/bash
# ============================================
# Piped Nginx Docker - Deploy Script
# ============================================

set -e

echo "🚀 Piped Nginx Docker Deployer"
echo "=============================="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Install Docker first."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Install it first."
    exit 1
fi

# Build image
echo "📦 Building Docker image..."
docker build -t piped-nginx .

# Stop existing container
echo "🛑 Stopping existing container..."
docker stop piped-frontend 2>/dev/null || true
docker rm piped-frontend 2>/dev/null || true

# Run container
echo "▶️  Starting container..."
docker run -d \
    --name piped-frontend \
    --restart unless-stopped \
    -p ${PORT:-3000}:3000 \
    piped-nginx

# Wait for health
echo "⏳ Waiting for health check..."
sleep 5

# Check status
if docker inspect --format='{{.State.Health.Status}}' piped-frontend 2>/dev/null | grep -q "healthy"; then
    echo "✅ Container is healthy!"
else
    echo "⚠️  Container starting up..."
fi

echo ""
echo "🎉 Deployed successfully!"
echo "========================"
echo "🌐 URL: http://localhost:${PORT:-3000}"
echo "📊 Status: docker inspect piped-frontend"
echo "📝 Logs: docker logs -f piped-frontend"
echo "🛑 Stop: docker stop piped-frontend"
