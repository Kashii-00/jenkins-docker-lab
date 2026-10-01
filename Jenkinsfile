pipeline {
    agent {
        label 'local-docker'
    }

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        APP_IMAGE = 'devsecops-app'
        SONAR_PROJECT_KEY = 'devsecops-app'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify build agent') {
            steps {
                sh '''
                    whoami
                    docker --version
                    trivy --version
                '''
            }
        }

        stage('Install dependencies') {
            steps {
                sh '''
                    docker run --rm \
                      -u "$(id -u):$(id -g)" \
                      -v "$PWD:/app" \
                      -w /app \
                      node:22-bookworm \
                      sh -lc 'if [ -f package-lock.json ]; then npm ci; else npm install; fi'
                '''
            }
        }

        stage('Build application') {
            steps {
                sh '''
                    docker run --rm \
                      -u "$(id -u):$(id -g)" \
                      -v "$PWD:/app" \
                      -w /app \
                      node:22-bookworm \
                      npm run build --if-present
                '''
            }
        }

        stage('Run unit and API tests') {
            steps {
                sh '''
                    docker run --rm \
                      -u "$(id -u):$(id -g)" \
                      -v "$PWD:/app" \
                      -w /app \
                      node:22-bookworm \
                      npm test
                '''
            }
        }

        stage('SonarQube analysis') {
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'

                    withSonarQubeEnv('sonarqube-local') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                              -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                              -Dsonar.sources=. \
                              -Dsonar.exclusions=node_modules/**,coverage/**,dist/**
                        """
                    }
                }
            }
        }

        stage('SonarQube quality gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker image') {
            steps {
                sh 'docker build -t ${APP_IMAGE}:${BUILD_NUMBER} .'
            }
        }

        stage('Trivy image security scan') {
            steps {
                sh '''
                    cd /tmp

                    trivy image \
                      --severity HIGH,CRITICAL \
                      --exit-code 1 \
                      "${APP_IMAGE}:${BUILD_NUMBER}"
                '''
            }
        }
    }

    post {
        always {
            sh 'docker image rm "${APP_IMAGE}:${BUILD_NUMBER}" || true'
            cleanWs()
        }
    }
}
