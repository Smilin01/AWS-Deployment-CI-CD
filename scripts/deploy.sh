#!/bin/bash
# ============================================
# Manual Deployment Script
# Run this to manually deploy the application
# ============================================

set -e

# Configuration
ECR_REGISTRY="${ECR_REGISTRY:-YOUR_ECR_REGISTRY_URL}"
IMAGE_NAME="${IMAGE_NAME:-resume-builder}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-resume-builder-app}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

echo "=========================================="
echo "🚀 Manual Deployment Script"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  ECR Registry: ${ECR_REGISTRY}"
echo "  Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Container: ${CONTAINER_NAME}"
echo ""

# Login to ECR
echo "🔐 Logging in to AWS ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Pull latest image
echo "📥 Pulling latest image..."
docker pull ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}

# Stop and remove existing container
echo "🛑 Stopping existing container..."
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm ${CONTAINER_NAME} 2>/dev/null || true

# Run new container
echo "🚀 Starting new container..."
docker run -d \
  --name ${CONTAINER_NAME} \
  --restart unless-stopped \
  -p 3000:80 \
  ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}

# Cleanup old images
echo "🧹 Cleaning up old images..."
docker image prune -f

# Health check
echo "🏥 Running health check..."
sleep 5
if curl -sf http://localhost:3000/health > /dev/null; then
  echo "✅ Health check passed!"
else
  echo "⚠️ Health check pending - application may still be starting"
fi

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "📊 Container Status:"
docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "🔗 Access your application at: http://localhost:3000"
echo ""
