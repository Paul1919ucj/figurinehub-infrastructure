pipeline {
    agent any

    environment {
        STAGE_IP = '63.176.106.103'
        PROD_IP = '54.93.96.14'
        FRONTEND_IMAGE = 'ghcr.io/paul1919ucj/figurinehub-frontend'
        BACKEND_IMAGE = 'ghcr.io/paul1919ucj/figurinehub-backend'
    }

    stages {
        stage('Checkout Repositories') {
            steps {
                dir('frontend') {
                    git branch: 'main',
                        url: 'https://github.com/Paul1919ucj/figurinehub-frontend.git'
                }

                dir('backend') {
                    git branch: 'main',
                        url: 'https://github.com/Paul1919ucj/figurinehub-backend.git'
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                sh '''
                    docker build -t figurinehub-frontend:latest ./frontend
                    docker build -t figurinehub-backend:latest ./backend
                '''
            }
        }

        stage('Push Docker Images to GHCR') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-ghcr',
                    usernameVariable: 'GHCR_USER',
                    passwordVariable: 'GHCR_TOKEN'
                )]) {
                    sh '''
                        set +x
                        echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin

                        docker tag figurinehub-frontend:latest "$FRONTEND_IMAGE:latest"
                        docker tag figurinehub-backend:latest "$BACKEND_IMAGE:latest"

                        docker push "$FRONTEND_IMAGE:latest"
                        docker push "$BACKEND_IMAGE:latest"

                        docker logout ghcr.io
                    '''
                }
            }
        }

        stage('Deploy STAGE') {
            steps {
                sshagent(credentials: ['aws-ec2-ssh']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=accept-new ubuntu@$STAGE_IP '
                            cd ~/figurinehub &&
                            sudo docker compose -f docker-compose.aws.yml pull &&
                            sudo docker compose -f docker-compose.aws.yml up -d
                        '
                    '''
                }
            }
        }

        stage('Verify STAGE') {
            steps {
                sh '''
                    for i in 1 2 3 4 5 6 7 8 9 10; do
                        if curl -fsS "http://$STAGE_IP/health"; then
                            exit 0
                        fi
                        sleep 5
                    done
                    exit 1
                '''
            }
        }

        stage('Deploy PROD') {
            steps {
                sshagent(credentials: ['aws-ec2-ssh']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=accept-new ubuntu@$PROD_IP '
                            cd ~/figurinehub &&
                            sudo docker compose -f docker-compose.aws.yml pull &&
                            sudo docker compose -f docker-compose.aws.yml up -d
                        '
                    '''
                }
            }
        }

        stage('Verify PROD') {
            steps {
                sh '''
                    for i in 1 2 3 4 5 6 7 8 9 10; do
                        if curl -fsS "http://$PROD_IP/health"; then
                            exit 0
                        fi
                        sleep 5
                    done
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            echo 'FigurineHub CI/CD: Build, Push and AWS Deployment SUCCESS!'
        }

        failure {
            echo 'FigurineHub CI/CD FAILED!'
        }
    }
}