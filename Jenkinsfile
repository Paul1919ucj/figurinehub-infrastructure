pipeline {
    agent any

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
                sh 'docker build -t figurinehub-frontend:latest ./frontend'
                sh 'docker build -t figurinehub-backend:latest ./backend'
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

                        docker tag figurinehub-frontend:latest ghcr.io/paul1919ucj/figurinehub-frontend:latest
                        docker tag figurinehub-backend:latest ghcr.io/paul1919ucj/figurinehub-backend:latest

                        docker push ghcr.io/paul1919ucj/figurinehub-frontend:latest
                        docker push ghcr.io/paul1919ucj/figurinehub-backend:latest

                        docker logout ghcr.io
                    '''
                }
            }
        }

        stage('Verify Images') {
            steps {
                sh 'docker image inspect figurinehub-frontend:latest'
                sh 'docker image inspect figurinehub-backend:latest'
            }
        }
    }

    post {
        success {
            echo 'FigurineHub Docker images built successfully!'
        }

        failure {
            echo 'FigurineHub pipeline failed!'
        }
    }
}
