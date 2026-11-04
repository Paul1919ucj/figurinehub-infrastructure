pipeline {
    agent any

    stages {
        stage('Verify Jenkins') {
            steps {
                echo 'Jenkins pipeline started successfully!'
                echo 'Project: FigurineHub'
            }
        }

        stage('Verify Git') {
            steps {
                sh 'git --version'
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }

        failure {
            echo 'Pipeline failed!'
        }
    }
}