#!/bin/bash
# ============================================
# Jenkins Server Setup Script
# Run this on a fresh Ubuntu 22.04 EC2 instance
# ============================================

set -e  # Exit on any error

echo "=========================================="
echo "🚀 Jenkins Server Setup Script"
echo "=========================================="

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Java 17 (required for Jenkins)
echo "☕ Installing Java 17..."
sudo apt install -y fontconfig openjdk-17-jdk
java -version

# Install Docker
echo "🐳 Installing Docker..."
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
docker --version

# Install Jenkins
echo "🔧 Installing Jenkins..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins

# Add jenkins user to docker group
echo "🔐 Configuring permissions..."
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
sudo systemctl enable jenkins

# Install AWS CLI v2
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install -y unzip
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
aws --version

# Install Node.js 20 (optional, for local builds)
echo "📗 Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node --version
npm --version

# Disable UFW firewall (use AWS Security Groups instead)
echo "🔥 Disabling local firewall..."
sudo ufw disable || true

# Clean up
echo "🧹 Cleaning up..."
sudo apt autoremove -y
sudo apt clean

echo ""
echo "=========================================="
echo "✅ Jenkins Server Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Next Steps:"
echo "1. Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "2. Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "3. Configure AWS CLI:"
echo "   aws configure"
echo ""
echo "4. Install recommended Jenkins plugins:"
echo "   - Git"
echo "   - Docker Pipeline"
echo "   - SSH Agent"
echo "   - Credentials Binding"
echo ""
echo "=========================================="
