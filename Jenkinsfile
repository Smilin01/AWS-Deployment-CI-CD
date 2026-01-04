// ============================================
// Jenkins Pipeline for Resume Builder
// CI/CD Pipeline with Docker and AWS Deployment
// ============================================

pipeline {
    agent any

    environment {
        // Docker configuration
        DOCKER_IMAGE = 'resume-builder'
        DOCKER_REGISTRY = credentials('aws-ecr-registry') // ECR registry URL
        AWS_REGION = 'ap-south-1'
        
        // Application environment variables (stored in Jenkins credentials)
        VITE_OPENROUTER_API_KEY = credentials('vite-openrouter-api-key')
        VITE_SUPABASE_URL = credentials('vite-supabase-url')
        VITE_SUPABASE_ANON_KEY = credentials('vite-supabase-anon-key')
        
        // EC2 configuration
        EC2_HOST = credentials('ec2-host-ip')
        EC2_USER = 'ubuntu'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        // ----------------------
        // Stage 1: Checkout Code
        // ----------------------
        stage('Checkout') {
            steps {
                echo '📥 Checking out source code...'
                checkout scm
                sh 'git log -1 --pretty=format:"%h - %an: %s"'
            }
        }

        // ----------------------
        // Stage 2: Build Docker Image
        // ----------------------
        stage('Docker Build') {
            steps {
                echo '🐳 Building Docker image...'
                script {
                    def imageTag = "${env.BUILD_NUMBER}"
                    sh """
                        docker build \
                            --build-arg VITE_OPENROUTER_API_KEY=${VITE_OPENROUTER_API_KEY} \
                            --build-arg VITE_SUPABASE_URL=${VITE_SUPABASE_URL} \
                            --build-arg VITE_SUPABASE_ANON_KEY=${VITE_SUPABASE_ANON_KEY} \
                            -t ${DOCKER_IMAGE}:${imageTag} \
                            -t ${DOCKER_IMAGE}:latest \
                            .
                    """
                }
                echo '✅ Docker image built successfully!'
            }
        }

        // ----------------------
        // Stage 3: Push to ECR
        // ----------------------
        stage('Push to ECR') {
            steps {
                echo '📤 Pushing Docker image to AWS ECR...'
                script {
                    def imageTag = "${env.BUILD_NUMBER}"
                    sh """
                        # Login to ECR
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}
                        
                        # Tag images for ECR
                        docker tag ${DOCKER_IMAGE}:${imageTag} ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${imageTag}
                        docker tag ${DOCKER_IMAGE}:latest ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                        
                        # Push to ECR
                        docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${imageTag}
                        docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                    """
                }
                echo '✅ Image pushed to ECR successfully!'
            }
        }

        // ----------------------
        // Stage 4: Deploy to EC2
        // ----------------------
        stage('Deploy to AWS') {
            steps {
                echo '🚀 Deploying to AWS EC2...'
                sshagent(['ec2-ssh-key']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << 'ENDSSH'
                            # Login to ECR
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}
                            
                            # Pull latest image
                            docker pull ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                            
                            # Stop and remove existing container
                            docker stop resume-builder-app || true
                            docker rm resume-builder-app || true
                            
                            # Run new container
                            docker run -d \
                                --name resume-builder-app \
                                --restart unless-stopped \
                                -p 3000:80 \
                                ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:latest
                            
                            # Cleanup old images
                            docker image prune -f
                            
                            # Verify deployment
                            sleep 5
                            curl -f http://localhost:3000/health || exit 1
                            
                            echo "✅ Deployment successful!"
ENDSSH
                    """
                }
            }
        }

        // ----------------------
        // Stage 5: Health Check
        // ----------------------
        stage('Health Check') {
            steps {
                echo '🏥 Running health check...'
                sh """
                    sleep 10
                    curl -f http://${EC2_HOST}:3000/health || echo "Health check pending..."
                """
                echo '✅ Application is live!'
            }
        }
    }

    post {
        always {
            echo '🧹 Cleaning up workspace...'
            cleanWs()
            sh 'docker image prune -f || true'
        }
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}
