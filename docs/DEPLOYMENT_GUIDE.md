# 🚀 AWS Deployment Guide with Jenkins CI/CD

This guide will walk you through deploying the Resume Builder application on AWS with a complete CI/CD pipeline using **Jenkins**, **Docker**, **Git**, and **Nginx** as a reverse proxy.

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [AWS Infrastructure Setup](#aws-infrastructure-setup)
4. [Jenkins Setup](#jenkins-setup)
5. [Docker Configuration](#docker-configuration)
6. [CI/CD Pipeline Configuration](#cicd-pipeline-configuration)
7. [Nginx Reverse Proxy Setup](#nginx-reverse-proxy-setup)
8. [SSL Certificate Setup](#ssl-certificate-setup)
9. [Monitoring & Logs](#monitoring--logs)
10. [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                   │
│                                                                          │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────────┐ │
│  │   GitHub     │────▶│   Jenkins    │────▶│       AWS ECR            │ │
│  │  Repository  │     │   Server     │     │   (Container Registry)   │ │
│  └──────────────┘     └──────────────┘     └──────────────────────────┘ │
│                              │                          │                │
│                              │                          │                │
│                              ▼                          ▼                │
│                       ┌──────────────────────────────────────┐          │
│                       │           EC2 Instance               │          │
│                       │  ┌─────────────────────────────────┐ │          │
│                       │  │         Nginx Proxy             │ │          │
│                       │  │     (SSL Termination)           │ │          │
│                       │  │      Port 80/443                │ │          │
│                       │  └──────────────┬──────────────────┘ │          │
│                       │                 │                    │          │
│                       │                 ▼                    │          │
│                       │  ┌─────────────────────────────────┐ │          │
│                       │  │    Resume Builder App           │ │          │
│                       │  │    (Docker Container)           │ │          │
│                       │  │      Port 3000                  │ │          │
│                       │  └─────────────────────────────────┘ │          │
│                       └──────────────────────────────────────┘          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## ✅ Prerequisites

Before starting, ensure you have:

- [ ] **AWS Account** with appropriate permissions
- [ ] **GitHub Account** with your Resume Builder repository
- [ ] **Domain Name** (optional, but recommended for production)
- [ ] **Local Machine Setup**:
  - Git installed
  - Docker Desktop installed (for local testing)
  - AWS CLI installed and configured

---

## 1️⃣ AWS Infrastructure Setup

### Step 1.1: Create an EC2 Instance for the Application

1. **Login to AWS Console** → Navigate to **EC2**

2. **Launch a new instance:**
   - **Name**: `resume-builder-app`
   - **AMI**: Ubuntu Server 22.04 LTS
   - **Instance Type**: `t3.small` (minimum) or `t3.medium` (recommended)
   - **Key Pair**: Create or select an existing key pair (you'll need this for SSH)
   - **Security Group**: Create new with these rules:

   | Type  | Port | Source    | Description           |
   |-------|------|-----------|----------------------|
   | SSH   | 22   | Your IP   | SSH access           |
   | HTTP  | 80   | 0.0.0.0/0 | HTTP traffic         |
   | HTTPS | 443  | 0.0.0.0/0 | HTTPS traffic        |
   | Custom| 3000 | Your IP   | Direct app access    |

3. **Storage**: 20 GB gp3 (minimum)

4. **Launch the instance** and note down the Public IP

### Step 1.2: Create an EC2 Instance for Jenkins

1. **Launch another instance:**
   - **Name**: `jenkins-server`
   - **AMI**: Ubuntu Server 22.04 LTS
   - **Instance Type**: `t3.medium` (minimum for Jenkins)
   - **Key Pair**: Use the same key pair
   - **Security Group**: Create new with these rules:

   | Type  | Port | Source    | Description           |
   |-------|------|-----------|----------------------|
   | SSH   | 22   | Your IP   | SSH access           |
   | HTTP  | 8080 | Your IP   | Jenkins Web UI       |
   | HTTPS | 443  | 0.0.0.0/0 | (Optional) SSL       |

3. **Storage**: 30 GB gp3

### Step 1.3: Create ECR Repository

1. Navigate to **Amazon ECR** → **Create repository**
2. **Repository name**: `resume-builder`
3. **Image scan settings**: Enable on push (recommended)
4. **Create repository**
5. Note down the **Repository URI**:
   ```
   <aws-account-id>.dkr.ecr.<region>.amazonaws.com/resume-builder
   ```

### Step 1.4: Create IAM Roles and Policies

#### For EC2 Instances (ECR Access):

1. Navigate to **IAM** → **Roles** → **Create role**
2. Select **AWS service** → **EC2**
3. Attach these policies:
   - `AmazonEC2ContainerRegistryFullAccess`
   - `AmazonSSMManagedInstanceCore` (for Systems Manager)
4. **Role name**: `EC2-ECR-Role`
5. Attach this role to both EC2 instances

---

## 2️⃣ Jenkins Setup

### Step 2.1: Install Jenkins on EC2

SSH into your Jenkins EC2 instance:

```bash
ssh -i your-key.pem ubuntu@<jenkins-public-ip>
```

Run the installation script:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java 17 (required for Jenkins)
sudo apt install -y openjdk-17-jdk

# Add Jenkins repository
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start and enable Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Step 2.2: Install Docker on Jenkins Server

```bash
# Install Docker
sudo apt install -y docker.io

# Add Jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins
sudo systemctl restart jenkins
```

### Step 2.3: Install AWS CLI on Jenkins Server

```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install -y unzip
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

### Step 2.4: Access Jenkins Web UI

1. Open browser: `http://<jenkins-public-ip>:8080`
2. Enter the initial admin password from step 2.1
3. Install suggested plugins
4. Create admin user
5. Configure Jenkins URL

### Step 2.5: Install Required Jenkins Plugins

Go to **Manage Jenkins** → **Plugins** → **Available plugins**

Install these plugins:
- ✅ Docker Pipeline
- ✅ Amazon ECR
- ✅ Pipeline: AWS Steps
- ✅ Git
- ✅ GitHub Integration
- ✅ SSH Agent
- ✅ Credentials Binding
- ✅ Blue Ocean (optional, for better UI)

### Step 2.6: Configure Jenkins Credentials

Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**

Add these credentials:

| ID | Type | Description |
|----|------|-------------|
| `aws-ecr-registry` | Secret text | Your ECR registry URL |
| `vite-openrouter-api-key` | Secret text | OpenRouter API key |
| `vite-supabase-url` | Secret text | Supabase URL |
| `vite-supabase-anon-key` | Secret text | Supabase anon key |
| `ec2-host-ip` | Secret text | Application EC2 public IP |
| `ec2-ssh-key` | SSH Username with private key | Your EC2 key pair |

---

## 3️⃣ Application EC2 Setup

SSH into application EC2:

```bash
ssh -i your-key.pem ubuntu@<app-public-ip>
```

### Step 3.1: Install Docker

```bash
# Update and install Docker
sudo apt update
sudo apt install -y docker.io docker-compose

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Log out and back in to apply group changes
exit
```

### Step 3.2: Install AWS CLI

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install -y unzip
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
```

### Step 3.3: Install Nginx (Reverse Proxy)

```bash
# Install Nginx
sudo apt install -y nginx

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

---

## 4️⃣ Docker Configuration

### Local Testing

Before pushing to CI/CD, test locally:

```bash
# Clone your repository
git clone https://github.com/Smilin01/Resume-builder.git
cd Resume-builder

# Create .env file with your secrets
cp .env.example .env
# Edit .env with your values

# Build and run with Docker Compose
docker-compose up --build

# Access at http://localhost:3000
```

### Files Created

The following Docker-related files have been created:

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build for production |
| `.dockerignore` | Excludes unnecessary files from build |
| `docker-compose.yml` | Local development setup |
| `nginx/nginx.conf` | Main Nginx configuration |
| `nginx/default.conf` | Server block for the app |
| `nginx/proxy.conf` | Reverse proxy with SSL |

---

## 5️⃣ CI/CD Pipeline Configuration

### Step 5.1: Create Jenkins Pipeline Job

1. Go to Jenkins Dashboard → **New Item**
2. Enter name: `resume-builder-pipeline`
3. Select **Pipeline** → OK
4. Configure:
   - **GitHub project**: `https://github.com/Smilin01/Resume-builder`
   - **Build Triggers**: 
     - ✅ GitHub hook trigger for GITScm polling
   - **Pipeline**:
     - Definition: **Pipeline script from SCM**
     - SCM: **Git**
     - Repository URL: `https://github.com/Smilin01/Resume-builder.git`
     - Branch: `*/main`
     - Script Path: `Jenkinsfile`
5. **Save**

### Step 5.2: Configure GitHub Webhook

1. Go to your GitHub repository → **Settings** → **Webhooks**
2. **Add webhook**:
   - Payload URL: `http://<jenkins-public-ip>:8080/github-webhook/`
   - Content type: `application/json`
   - Which events: **Just the push event**
3. **Add webhook**

### Step 5.3: Test the Pipeline

1. Make a small change to your code
2. Commit and push to `main` branch
3. Watch Jenkins automatically trigger the pipeline

---

## 6️⃣ Nginx Reverse Proxy Setup

### Step 6.1: Configure Nginx on Application EC2

SSH into application EC2 and create the Nginx configuration:

```bash
sudo nano /etc/nginx/sites-available/resume-builder
```

Add this configuration (for HTTP only, we'll add SSL later):

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    # Or use: server_name _;  for IP-based access

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /health {
        proxy_pass http://127.0.0.1:3000/health;
        access_log off;
    }
}
```

Enable the site:

```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/resume-builder /etc/nginx/sites-enabled/

# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

---

## 7️⃣ SSL Certificate Setup (Let's Encrypt)

### Step 7.1: Install Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### Step 7.2: Obtain SSL Certificate

```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com
```

Follow the prompts:
1. Enter email address
2. Agree to terms
3. Choose whether to redirect HTTP to HTTPS (recommended: yes)

### Step 7.3: Auto-Renewal

Certbot automatically sets up a cron job. Verify:

```bash
sudo certbot renew --dry-run
```

---

## 8️⃣ Monitoring & Logs

### View Application Logs

```bash
# Docker container logs
docker logs resume-builder-app

# Follow logs in real-time
docker logs -f resume-builder-app

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Docker Container Status

```bash
# Check running containers
docker ps

# Check container health
docker inspect resume-builder-app --format='{{.State.Health.Status}}'

# View resource usage
docker stats resume-builder-app
```

### Jenkins Logs

```bash
# On Jenkins server
sudo tail -f /var/log/jenkins/jenkins.log
```

---

## 9️⃣ Quick Command Reference

### Docker Commands

```bash
# Build image
docker build -t resume-builder .

# Run container
docker run -d -p 3000:80 --name resume-builder-app resume-builder

# Stop container
docker stop resume-builder-app

# Remove container
docker rm resume-builder-app

# View logs
docker logs resume-builder-app

# Shell into container
docker exec -it resume-builder-app sh
```

### AWS CLI Commands

```bash
# ECR login
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <ecr-registry>

# Push to ECR
docker tag resume-builder:latest <ecr-registry>/resume-builder:latest
docker push <ecr-registry>/resume-builder:latest

# Pull from ECR
docker pull <ecr-registry>/resume-builder:latest
```

---

## 🔧 Troubleshooting

### Issue: Container fails to start

```bash
# Check container logs
docker logs resume-builder-app

# Check if port is in use
sudo lsof -i :3000
```

### Issue: Nginx 502 Bad Gateway

```bash
# Check if container is running
docker ps

# Check Nginx error logs
sudo tail -20 /var/log/nginx/error.log

# Verify container is accessible
curl http://localhost:3000/health
```

### Issue: Jenkins cannot connect to EC2

1. Verify SSH key is correctly added to Jenkins credentials
2. Check security group allows SSH from Jenkins IP
3. Test SSH manually:
   ```bash
   ssh -i /path/to/key ubuntu@<ec2-ip>
   ```

### Issue: ECR push fails

```bash
# Ensure IAM role is attached to EC2
# Re-login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <ecr-registry>
```

---

## 📞 Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Jenkins build console output
3. Check AWS CloudWatch logs
4. Open an issue on GitHub

---

## 📝 Environment Variables Reference

| Variable | Description | Where to Set |
|----------|-------------|--------------|
| `VITE_OPENROUTER_API_KEY` | OpenRouter API key | Jenkins Credentials |
| `VITE_SUPABASE_URL` | Supabase project URL | Jenkins Credentials |
| `VITE_SUPABASE_ANON_KEY` | Supabase anonymous key | Jenkins Credentials |

---

## 🎉 Success!

Once everything is set up:

1. ✅ Push code to GitHub `main` branch
2. ✅ Jenkins automatically builds Docker image
3. ✅ Image is pushed to AWS ECR
4. ✅ New container is deployed to EC2
5. ✅ Nginx serves the application with SSL

Your Resume Builder is now live at `https://your-domain.com`! 🚀
