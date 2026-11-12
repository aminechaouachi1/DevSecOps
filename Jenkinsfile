// Pipeline DevSecOps minimal : 1 outil par phase
//   Phase 1 Development : Semgrep  (SAST  - analyse du code)
//   Phase 2 Acceptance  : OWASP ZAP (DAST  - scan de l'app qui tourne)
//   Phase 3 Production  : Trivy     (scan de l'image avant deploiement)
//   Phase 4 Operations  : Falco     (detection runtime sur la prod)
pipeline {
    agent any

    parameters {
        booleanParam(name: 'ENFORCE', defaultValue: false,
            description: 'true = le pipeline echoue si Semgrep/Trivy trouvent des failles (quality gate)')
    }

    environment {
        IMAGE   = "devsecops-demo:${BUILD_NUMBER}"
        ENFORCE = "${params.ENFORCE}"
    }

    stages {
        stage('Phase 1 - Development (Semgrep SAST)') {
            steps {
                sh '''
                    rm -rf reports; mkdir -p reports
                    ARGS=""
                    if [ "$ENFORCE" = "true" ]; then ARGS="--error"; fi
                    docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
                        -v "$WORKSPACE":/src -w /src semgrep/semgrep:latest \
                        semgrep scan --config p/python --config p/security-audit --metrics=off $ARGS \
                        --json-output=reports/semgrep.json app
                '''
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build -t "$IMAGE" app'
            }
        }

        stage('Phase 2 - Acceptance (OWASP ZAP DAST)') {
            steps {
                sh '''
                    NET=dso-net-$BUILD_NUMBER; APP=staging-$BUILD_NUMBER
                    chmod 777 reports
                    docker network create $NET
                    docker run -d --name $APP --network $NET "$IMAGE"
                    for i in $(seq 1 30); do
                        docker exec $APP python -c "import urllib.request;urllib.request.urlopen('http://localhost:5000/health')" && break
                        sleep 1
                    done
                    docker run --rm --network $NET -v "$WORKSPACE/reports":/zap/wrk:rw \
                        ghcr.io/zaproxy/zaproxy:stable \
                        zap-baseline.py -t http://$APP:5000 -r zap.html -J zap.json || true
                '''
            }
        }

        stage('Phase 3 - Production (Trivy + deploy)') {
            steps {
                sh '''
                    docker save "$IMAGE" -o image.tar
                    TRIVY="docker run --rm --user $(id -u):$(id -g) -e TRIVY_CACHE_DIR=/w/.trivycache -v $WORKSPACE:/w aquasec/trivy:latest"
                    # 1) rapport complet (HIGH + CRITICAL)
                    $TRIVY image --input /w/image.tar --severity HIGH,CRITICAL --ignore-unfixed \
                        --format json --output /w/reports/trivy.json
                    # 2) quality gate sur les CRITICAL (bloque seulement si ENFORCE=true)
                    EXIT=0; if [ "$ENFORCE" = "true" ]; then EXIT=1; fi
                    $TRIVY image --input /w/image.tar --severity CRITICAL --ignore-unfixed --exit-code $EXIT
                    rm -f image.tar

                    # Deploiement (uniquement si le gate est passe)
                    docker rm -f devsecops-prod 2>/dev/null || true
                    docker run -d --name devsecops-prod -p 8081:5000 --restart unless-stopped "$IMAGE"
                    for i in $(seq 1 30); do curl -fsS http://localhost:8081/health && break; sleep 1; done
                '''
            }
        }

        stage('Phase 4 - Operations (Falco runtime)') {
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh '''
                        docker rm -f falco 2>/dev/null || true
                        docker run -d --name falco \
                            --cap-drop all --cap-add sys_admin --cap-add sys_resource --cap-add sys_ptrace \
                            -v /sys/kernel/tracing:/sys/kernel/tracing:ro \
                            -v /var/run/docker.sock:/host/var/run/docker.sock \
                            -v /proc:/host/proc:ro -v /etc:/host/etc:ro \
                            falcosecurity/falco:0.45.2
                        sleep 15
                        # Simulation d'une intrusion dans le conteneur de prod
                        docker exec devsecops-prod cat /etc/shadow > /dev/null
                        docker exec -u root devsecops-prod touch /etc/pwned
                        sleep 5
                        docker logs falco > reports/falco.log 2>&1
                        grep -E "Warning|Notice|Error|Critical" reports/falco.log
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                docker rm -f staging-$BUILD_NUMBER falco 2>/dev/null || true
                docker network rm dso-net-$BUILD_NUMBER 2>/dev/null || true
            '''
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }
    }
}
