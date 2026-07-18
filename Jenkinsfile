pipeline {
    agent any

    environment {
        APP_URL = 'http://3.93.25.12/NexusFrontEnd/'
        GATEWAY_HEALTH_URL = 'http://3.93.25.12:9080/NexusGateway/actuator/health'
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_PROJECT_KEY = 'NexusMicroservicios'
        WAZUH_URL = 'https://54.157.208.255'
        PROMETHEUS_URL = 'http://54.157.208.255:9090'
        GRAFANA_URL = 'http://54.157.208.255:3000'
        AWS_REGION = 'us-east-1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Paso 1 - GitLeaks') {
            steps {
                sh '''
                    mkdir -p reports
                    gitleaks detect --source . --no-git --redact \
                      --report-format json \
                      --report-path reports/gitleaks-report.json || true
                '''
            }
        }

        stage('Paso 2 - Trivy SCA') {
            steps {
                sh '''
                    mkdir -p reports
                    trivy fs --scanners vuln,misconfig \
                      --severity HIGH,CRITICAL \
                      --format json \
                      --output reports/trivy-sca-report.json . || true
                '''
            }
        }

        stage('Paso 3 - SonarQube SAST') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=$SONAR_PROJECT_KEY \
                          -Dsonar.projectName=NexusMicroservicios \
                          -Dsonar.sources=2_BackEnd,3_FrontEnd/NexusFrontEnd/src \
                          -Dsonar.exclusions=**/*.png,**/*.ico,**/target/**,**/node_modules/** \
                          -Dsonar.java.binaries=2_BackEnd/NexusSeguridadMs/target/classes,2_BackEnd/NexusCatalogoMs/target/classes,2_BackEnd/NexusIngresoMs/target/classes,2_BackEnd/NexusGatewayMs/target/classes \
                          -Dsonar.host.url=$SONAR_HOST_URL \
                          -Dsonar.token=$SONAR_TOKEN || true
                    '''
                }
            }
        }

        stage('Paso 4 - Build Backend') {
            steps {
                sh '''
                    chmod +x 2_BackEnd/NexusSeguridadMs/mvnw
                    chmod +x 2_BackEnd/NexusCatalogoMs/mvnw
                    chmod +x 2_BackEnd/NexusIngresoMs/mvnw
                    chmod +x 2_BackEnd/NexusGatewayMs/mvnw

                    cd 2_BackEnd/NexusSeguridadMs && ./mvnw clean package -DskipTests
                    cd ../NexusCatalogoMs && ./mvnw clean package -DskipTests
                    cd ../NexusIngresoMs && ./mvnw clean package -DskipTests
                    cd ../NexusGatewayMs && ./mvnw clean package -DskipTests
                '''
            }
        }

        stage('Paso 4 - Build Frontend') {
            steps {
                sh '''
                    cd 3_FrontEnd/NexusFrontEnd
                    npm install
                    npm run build -- --configuration production --base-href /NexusFrontEnd/
                '''
            }
        }

        stage('Paso 5 - Docker Build') {
            steps {
                sh '''
                    docker build -t nexus-seguridad-ms:${BUILD_NUMBER} 2_BackEnd/NexusSeguridadMs
                    docker build -t nexus-catalogo-ms:${BUILD_NUMBER} 2_BackEnd/NexusCatalogoMs
                    docker build -t nexus-ingreso-ms:${BUILD_NUMBER} 2_BackEnd/NexusIngresoMs
                    docker build -t nexus-gateway-ms:${BUILD_NUMBER} 2_BackEnd/NexusGatewayMs
                    docker build -t nexus-frontend-nginx:${BUILD_NUMBER} 3_FrontEnd/NexusFrontEnd
                '''
            }
        }

        stage('Paso 6 - Trivy Image Scan') {
            steps {
                sh '''
                    mkdir -p reports
                    trivy image --severity HIGH,CRITICAL --format json --output reports/trivy-image-seguridad.json nexus-seguridad-ms:${BUILD_NUMBER} || true
                    trivy image --severity HIGH,CRITICAL --format json --output reports/trivy-image-catalogo.json nexus-catalogo-ms:${BUILD_NUMBER} || true
                    trivy image --severity HIGH,CRITICAL --format json --output reports/trivy-image-ingreso.json nexus-ingreso-ms:${BUILD_NUMBER} || true
                    trivy image --severity HIGH,CRITICAL --format json --output reports/trivy-image-gateway.json nexus-gateway-ms:${BUILD_NUMBER} || true
                    trivy image --severity HIGH,CRITICAL --format json --output reports/trivy-image-frontend.json nexus-frontend-nginx:${BUILD_NUMBER} || true
                '''
            }
        }

        stage('Paso 7 - AWS Secrets Manager') {
            steps {
                sh '''
                    aws configure set region $AWS_REGION
                    aws secretsmanager list-secrets --query "SecretList[*].Name" --output table
                    aws secretsmanager get-secret-value \
                      --secret-id nexus/db/seguridad \
                      --query SecretString \
                      --output text | jq 'del(.password)'
                '''
            }
        }

        stage('Paso 8 - Trivy IaC') {
            steps {
                sh '''
                    mkdir -p reports
                    trivy config --severity HIGH,CRITICAL \
                      --format json \
                      --output reports/trivy-iac-report.json \
                      4_Infraestructure/NexusInfraestructura || true
                '''
            }
        }

        stage('Paso 9 - OPA Policy Check') {
            steps {
                sh '''
                    mkdir -p reports

                    conftest test 4_Infraestructure/NexusInfraestructura/docker-compose.yml \
                      --policy security/opa \
                      --namespace main || true

                    conftest test 4_Infraestructure/NexusInfraestructura/docker-compose.yml \
                      --policy security/opa \
                      --namespace main \
                      --output json > reports/opa-docker-compose-report.json || true
                '''
            }
        }

        stage('Paso 10 - Terraform Validate and Plan') {
            steps {
                sh '''
                    cd infra/terraform


		    cat > terraform.tfvars << 'EOF'
aws_region = "us-east-1"
key_name   = "nexus-secops-key"
my_ip_cidr = "0.0.0.0/0"
ami_id     = "ami-0f8a61b66d1accaee"
EOF

                    terraform init
                    terraform validate
                    terraform plan -out=tfplan
                    terraform show -no-color tfplan > ../../reports/terraform-plan.txt
                '''
            }
        }

        stage('Paso 11 - Deploy Evidence') {
            steps {
                sh '''
                    echo "Frontend Nexus:"
                    curl -I $APP_URL || true
                    echo "Gateway Health:"
                    curl $GATEWAY_HEALTH_URL || true
                '''
            }
        }

        stage('Paso 12 - OWASP ZAP DAST') {
            steps {
                sh '''
                    mkdir -p reports/zap

                    docker run --rm \
                      -v $(pwd)/reports/zap:/zap/wrk \
                      ghcr.io/zaproxy/zaproxy:stable \
                      zap-baseline.py \
                      -t $APP_URL \
                      -r zap-nexus-report.html \
                      -J zap-nexus-report.json || true
                '''
            }
        }

        stage('Paso 13 - Wazuh SIEM Evidence') {
            steps {
                sh '''
                    echo "Wazuh Dashboard: $WAZUH_URL"
                    echo "Agente esperado: nexus-app active"
                '''
            }
        }

        stage('Paso 14 - Prometheus and Grafana Evidence') {
            steps {
                sh '''
                    echo "Prometheus: $PROMETHEUS_URL"
                    echo "Grafana: $GRAFANA_URL"
                '''
            }
        }

        stage('Paso 15 - Playbooks') {
            steps {
                sh '''
                    mkdir -p reports/playbooks

                    cat > reports/playbooks/playbooks-secops.txt << 'EOF'
Playbook 1: Secreto detectado por GitLeaks
Accion: detener pipeline, revocar secreto, mover credencial a Secrets Manager y reejecutar escaneo.

Playbook 2: CVE critica detectada por Trivy
Accion: bloquear promocion, actualizar dependencia o imagen base, reconstruir y reescanear.

Playbook 3: Fuerza bruta SSH detectada por Wazuh
Accion: identificar IP origen, bloquear en firewall o Security Group y verificar MITRE ATT&CK.

Playbook 4: Politica OPA incumplida
Accion: detener despliegue, corregir imagen latest o secretos hardcodeados y revalidar con Conftest.
EOF
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**/*', allowEmptyArchive: true
        }
    }
}
