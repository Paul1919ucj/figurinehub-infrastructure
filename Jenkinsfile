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
                    docker build \
                      -t "$FRONTEND_IMAGE:$BUILD_NUMBER" \
                      -t "$FRONTEND_IMAGE:latest" ./frontend

                    docker build \
                      -t "$BACKEND_IMAGE:$BUILD_NUMBER" \
                      -t "$BACKEND_IMAGE:latest" ./backend
                '''
            }
        }

        stage('Push Docker Images') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'github-ghcr',
                    usernameVariable: 'GHCR_USER',
                    passwordVariable: 'GHCR_TOKEN'
                )]) {
                    sh '''
                        set +x
                        echo "$GHCR_TOKEN" | docker login ghcr.io \
                          -u "$GHCR_USER" --password-stdin

                        docker push "$FRONTEND_IMAGE:$BUILD_NUMBER"
                        docker push "$BACKEND_IMAGE:$BUILD_NUMBER"
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
                    for i in $(seq 1 10); do
                        if curl -fsS "http://$STAGE_IP/health"; then
                            exit 0
                        fi
                        sleep 5
                    done
                    exit 1
                '''
            }
        }

        stage('Deploy PROD Blue-Green') {
            steps {
                sshagent(credentials: ['aws-ec2-ssh']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=accept-new \
                          ubuntu@$PROD_IP \
                          "NEW_TAG=$BUILD_NUMBER bash -s" <<'REMOTE'
set -eu

cd ~/figurinehub

CONF="blue-green/nginx-proxy.conf"
COMPOSE="blue-green/docker-compose.blue-green.yml"
PROXY="figurinehub-bg-proxy-1"

if grep -q 'proxy_pass http://frontend-blue:80;' "$CONF"; then
    ACTIVE=blue
    TARGET=green
elif grep -q 'proxy_pass http://frontend-green:80;' "$CONF"; then
    ACTIVE=green
    TARGET=blue
else
    echo "ERROR: Nu pot identifica mediul activ."
    exit 1
fi

echo "ACTIVE=$ACTIVE TARGET=$TARGET TAG=$NEW_TAG"

# Păstrăm configurația pentru rollback.
cp "$CONF" "$CONF.rollback"

# Păstrăm tagurile existente.
BLUE_TAG=latest
GREEN_TAG=latest

if [ -f blue-green/blue.env ]; then
    . ./blue-green/blue.env
fi

if [ -f blue-green/green.env ]; then
    . ./blue-green/green.env
fi

# Schimbăm doar versiunea mediului inactiv.
if [ "$TARGET" = "blue" ]; then
    BLUE_TAG="$NEW_TAG"
else
    GREEN_TAG="$NEW_TAG"
fi

export BLUE_TAG GREEN_TAG

DC="sudo docker compose --env-file .env -f $COMPOSE -p figurinehub-bg"

# Actualizăm numai mediul inactiv.
$DC pull "backend-$TARGET" "frontend-$TARGET"

$DC up -d --no-deps --force-recreate \
    "backend-$TARGET" "frontend-$TARGET"

FRONTEND="figurinehub-bg-frontend-$TARGET-1"

# Verificăm noua versiune.
HEALTHY=0

for i in $(seq 1 12); do
    if sudo docker exec "$FRONTEND" \
        wget -qO- http://127.0.0.1/health >/dev/null 2>&1; then
        HEALTHY=1
        break
    fi
    sleep 5
done

if [ "$HEALTHY" -ne 1 ]; then
    echo "FAILED: Mediul $TARGET nu este sănătos."
    echo "Traficul rămâne pe $ACTIVE."
    exit 1
fi

# Comutăm traficul.
sed -i \
    "s/frontend-$ACTIVE:80/frontend-$TARGET:80/" \
    "$CONF"

# Reîncărcăm Nginx.
if ! sudo docker exec "$PROXY" nginx -s reload; then
    cp "$CONF.rollback" "$CONF"
    sudo docker exec "$PROXY" nginx -s reload || true
    echo "ROLLBACK EXECUTAT."
    exit 1
fi

sleep 3

# Verificăm noua rutare prin proxy.
if ! curl -fsS http://127.0.0.1/health; then
    cp "$CONF.rollback" "$CONF"
    sudo docker exec "$PROXY" nginx -s reload || true
    echo "ROLLBACK EXECUTAT."
    exit 1
fi

# Salvăm tagul numai după deployment reușit.
if [ "$TARGET" = "blue" ]; then
    printf 'BLUE_TAG=%s\\n' "$NEW_TAG" > blue-green/blue.env
else
    printf 'GREEN_TAG=%s\\n' "$NEW_TAG" > blue-green/green.env
fi

echo
echo "BLUE/GREEN DEPLOYMENT SUCCESS"
echo "ACTIVE=$TARGET"
echo "VERSION=$NEW_TAG"
REMOTE
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'FigurineHub CI/CD SUCCESS!'
        }
        failure {
            echo 'FigurineHub CI/CD FAILED!'
        }
    }
}