# 🔧 Troubleshooting Guide

This guide covers common issues and their solutions when working with the Resume Builder CI/CD pipeline.

---

## Table of Contents

1. [Jenkins Issues](#jenkins-issues)
2. [Docker Issues](#docker-issues)
3. [AWS Issues](#aws-issues)
4. [Pipeline Issues](#pipeline-issues)
5. [Application Issues](#application-issues)

---

## Jenkins Issues

### Issue: Jenkins not accessible (Connection refused)

**Symptoms:**
- Cannot access `http://SERVER_IP:8080`
- Connection refused or timeout

**Solutions:**

```bash
# Check if Jenkins is running
sudo systemctl status jenkins

# Start Jenkins if stopped
sudo systemctl start jenkins

# Check logs for errors
sudo journalctl -u jenkins -f

# Check if port 8080 is open
sudo netstat -tlnp | grep 8080
```

**Also check:**
- AWS Security Group has port 8080 open
- Firewall is disabled: `sudo ufw disable`

---

### Issue: Jenkins "Waiting for executable" in pipeline

**Symptoms:**
- Pipeline hangs at execution
- Shows "Waiting for executable"

**Solutions:**

```bash
# Ensure required tools are installed
which docker
which aws
which git

# If any are missing, install them
sudo apt install -y docker.io git
```

---

### Issue: Permission denied for Docker in Jenkins

**Symptoms:**
```
permission denied while trying to connect to the Docker daemon socket
```

**Solutions:**

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins
sudo systemctl restart jenkins

# Verify group membership
groups jenkins
```

---

## Docker Issues

### Issue: Docker daemon not running

**Symptoms:**
```
Cannot connect to the Docker daemon
```

**Solutions:**

```bash
# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Check Docker status
sudo systemctl status docker
```

---

### Issue: Docker build fails - Out of disk space

**Symptoms:**
```
no space left on device
```

**Solutions:**

```bash
# Remove unused images
docker image prune -a

# Remove unused containers
docker container prune

# Remove all unused data
docker system prune -a

# Check disk usage
df -h
```

---

### Issue: Docker image push fails to ECR

**Symptoms:**
```
denied: Your authorization token has expired
```

**Solutions:**

```bash
# Re-authenticate with ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin YOUR_ECR_URL

# Check AWS CLI credentials
aws sts get-caller-identity
```

---

## AWS Issues

### Issue: AWS CLI not configured

**Symptoms:**
```
Unable to locate credentials
```

**Solutions:**

```bash
# Configure AWS CLI
aws configure

# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: ap-south-1
# - Default output format: json

# Verify configuration
aws sts get-caller-identity
```

---

### Issue: ECR repository not found

**Symptoms:**
```
repository does not exist in the registry
```

**Solutions:**

```bash
# List existing repositories
aws ecr describe-repositories --region ap-south-1

# Create repository if missing
aws ecr create-repository --repository-name resume-builder --region ap-south-1
```

---

### Issue: SSH connection to EC2 fails

**Symptoms:**
```
Permission denied (publickey)
Connection timed out
```

**Solutions:**

1. **Check key file permissions:**
```bash
chmod 400 your-key.pem
```

2. **Verify correct username:**
   - Ubuntu AMI: `ubuntu`
   - Amazon Linux: `ec2-user`

3. **Check Security Group:**
   - Port 22 must be open

4. **Test SSH manually:**
```bash
ssh -v -i your-key.pem ubuntu@EC2_IP
```

---

## Pipeline Issues

### Issue: Branch condition skipping stages

**Symptoms:**
```
Stage "Push to ECR" skipped due to when conditional
```

**Solutions:**

Either remove branch conditions from Jenkinsfile or ensure Jenkins detects the correct branch:

```groovy
// Option 1: Remove condition
stage('Push to ECR') {
    steps {
        // ... steps
    }
}

// Option 2: Use different branch detection
stage('Push to ECR') {
    when {
        anyOf {
            branch 'main'
            branch 'master'
            expression { env.GIT_BRANCH == 'origin/main' }
        }
    }
    steps {
        // ... steps
    }
}
```

---

### Issue: Credential not found

**Symptoms:**
```
ERROR: Could not find credentials entry with ID 'xxx'
```

**Solutions:**

1. Go to Jenkins → Manage Jenkins → Credentials
2. Verify the credential ID matches exactly
3. Check credential scope is "Global"

---

### Issue: SSH Agent plugin issues

**Symptoms:**
```
[ssh-agent] Using credentials failed
```

**Solutions:**

1. Verify SSH key is in PEM format
2. Check private key includes headers:
```
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

3. Re-add the credential in Jenkins

---

## Application Issues

### Issue: Application not accessible

**Symptoms:**
- Browser timeout
- Connection refused

**Solutions:**

```bash
# Check if container is running
docker ps

# Check container logs
docker logs resume-builder-app

# Check if port is listening
netstat -tlnp | grep 3000

# Test locally
curl http://localhost:3000/health
```

---

### Issue: Health check fails

**Symptoms:**
```
curl: (7) Failed to connect
```

**Solutions:**

1. **Check container health:**
```bash
docker inspect --format='{{.State.Health.Status}}' resume-builder-app
```

2. **Check Nginx is running inside container:**
```bash
docker exec resume-builder-app nginx -t
```

3. **Restart container:**
```bash
docker restart resume-builder-app
```

---

### Issue: Application shows blank page

**Symptoms:**
- Page loads but shows blank
- JavaScript errors in console

**Solutions:**

1. **Check browser console for errors**
2. **Verify environment variables were set during build:**
```bash
docker exec resume-builder-app printenv | grep VITE
```

3. **Rebuild with correct build args**

---

## Quick Diagnostic Commands

```bash
# System status
sudo systemctl status jenkins docker nginx

# Docker containers
docker ps -a

# Docker logs
docker logs -f resume-builder-app

# Jenkins logs
sudo journalctl -u jenkins -n 100

# Disk usage
df -h

# Memory usage
free -m

# Network ports
sudo netstat -tlnp

# AWS identity
aws sts get-caller-identity
```

---

## Getting Help

If you're still stuck:

1. Check Jenkins build console output for detailed error messages
2. Review Docker container logs: `docker logs resume-builder-app`
3. Open an issue on GitHub with:
   - Error message
   - Steps to reproduce
   - Jenkins version
   - Docker version
   - AWS region

---

<p align="center">
  <b>Need more help? Open an issue on GitHub!</b>
</p>
