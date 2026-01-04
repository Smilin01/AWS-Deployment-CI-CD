#!/bin/bash
# ============================================
# Application Server Setup Script
# Run this on a fresh Ubuntu 22.04 EC2 instance
# ============================================

set -e  # Exit on any error

echo "=========================================="
echo "🚀 Application Server Setup Script"
echo "=========================================="

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
docker --version

# Install Docker Compose
echo "🐳 Installing Docker Compose..."
sudo apt install -y docker-compose
docker-compose --version

# Install AWS CLI v2
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install -y unzip
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
aws --version

# Install Nginx (for SSL termination - optional)
echo "🌐 Installing Nginx..."
sudo apt install -y nginx
sudo systemctl enable nginx

# Install Certbot for SSL (optional)
echo "🔐 Installing Certbot for SSL..."
sudo apt install -y certbot python3-certbot-nginx

# Disable UFW firewall (use AWS Security Groups instead)
echo "🔥 Disabling local firewall..."
sudo ufw disable || true

# Create application directory
echo "📁 Creating application directory..."
sudo mkdir -p /opt/resume-builder
sudo chown ubuntu:ubuntu /opt/resume-builder

# Clean up
echo "🧹 Cleaning up..."
sudo apt autoremove -y
sudo apt clean

echo ""
echo "=========================================="
echo "✅ Application Server Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Configure AWS CLI:"
echo "   aws configure"
echo ""
echo "2. Login to ECR:"
echo "   aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin YOUR_ECR_URL"
echo ""
echo "3. Pull and run the application:"
echo "   docker pull YOUR_ECR_URL/resume-builder:latest"
echo "   docker run -d --name resume-builder-app -p 3000:80 YOUR_ECR_URL/resume-builder:latest"
echo ""
echo "4. (Optional) Setup SSL with Certbot:"
echo "   sudo certbot --nginx -d yourdomain.com"
echo ""
echo "=========================================="
