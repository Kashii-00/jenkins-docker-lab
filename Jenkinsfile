pipeline {
    agent { label 'local-docker' }

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        APP_IMAGE = 'devsecops-app'
        SONAR_PROJECT_KEY = 'devsecops-app'
        AWS_REGION = 'ap-southeast-1'
        ECR_REGISTRY = '941017931809.dkr.ecr.ap-southeast-1.amazonaws.com'
        ECR_REPOSITORY = 'devsecops-app'
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
                    aws --version
                '''
            }
        }

        stage('Run test cases') {
            steps {
                sh 'bash tests/test_site.sh'
            }
        }

        stage('SonarQube analysis') {
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'

                    withSonarQubeEnv('sonarqube-local') {
                        sh """
                            "${scannerHome}/bin/sonar-scanner" \
                              -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                              -Dsonar.sources=. \
                              '-Dsonar.exclusions=.git/**,coverage/**,dist/**'
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
                sh 'docker build -t "${APP_IMAGE}:${BUILD_NUMBER}" .'
            }
        }

        stage('Trivy image security scan') {
            steps {
                sh '''
                    set -eu
                    cd /tmp

                    trivy image \
                      --scanners vuln \
                      --severity HIGH,CRITICAL \
                      --exit-code 1 \
                      "${APP_IMAGE}:${BUILD_NUMBER}"
                '''
            }
        }

        stage('Push image to ECR') {
            steps {
                sh '''#!/bin/bash
                    set -euo pipefail

                    ECR_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}"

                    aws ecr get-login-password --region "${AWS_REGION}" |
                      docker login --username AWS --password-stdin "${ECR_REGISTRY}"

                    docker tag "${APP_IMAGE}:${BUILD_NUMBER}" \
                      "${ECR_URI}:${BUILD_NUMBER}"

                    docker push "${ECR_URI}:${BUILD_NUMBER}"

                    echo "${ECR_URI}:${BUILD_NUMBER}" > image-uri.txt
                '''

                archiveArtifacts artifacts: 'image-uri.txt', fingerprint: true
            }
        }
    }

    post {
        always {
            sh '''
                docker image rm \
                  "${APP_IMAGE}:${BUILD_NUMBER}" \
                  "${ECR_REGISTRY}/${ECR_REPOSITORY}:${BUILD_NUMBER}" || true
            '''
            cleanWs()
        }
    }
}