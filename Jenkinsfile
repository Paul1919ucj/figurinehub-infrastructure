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