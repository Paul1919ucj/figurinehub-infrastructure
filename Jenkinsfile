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
                        -t "$FRONTEND_IMAGE:latest" \
                        ./frontend

                    docker build \
                        -t "$BACKEND_IMAGE:$BUILD_NUMBER" \
                        -t "$BACKEND_IMAGE:latest" \
                        ./backend
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
                        ssh -o StrictHostKeyChecking=accept-new \
                            ubuntu@$STAGE_IP '
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
                            "BUILD_TAG_NUMBER=$BUILD_NUMBER bash -s" <<'REMOTE'
set -eu

cd ~/figurinehub

COMPOSE="blue-green/docker-compose.blue-green.yml"
PROXY_CONF="blue-green/nginx-proxy.conf"
PROXY_CONTAINER="figurinehub-bg-proxy-1"

# Identificăm versiunea activă.
if grep -q 'proxy_pass http://frontend-blue:80;' "$PROXY_CONF"; then
    ACTIVE=blue
    TARGET=green
elif grep -q 'proxy_pass http://frontend-green:80;' "$PROXY_CONF"; then
    ACTIVE=green
    TARGET=blue
else
    echo "ERROR: Configuratie proxy necunoscuta."
    exit 1
fi

echo "ACTIVE: $ACTIVE"
echo "DEPLOY TARGET: $TARGET"

# Păstrăm configurația curentă pentru rollback.
cp "$PROXY_CONF" "$PROXY_CONF.rollback"

# Setăm versiunea nouă doar pentru mediul inactiv.
if [ "$TARGET" = "green" ]; then
    printf 'GREEN_TAG=%s\\n' "$BUILD_TAG_NUMBER" \
        > blue-green/green.env
    cp blue-green/green.env blue-green/green.env.backup
else
    printf 'BLUE_TAG=%s\\n' "$BUILD_TAG_NUMBER" \
        > blue-green/blue.env
    cp blue-green/blue.env blue-green/blue.env.backup
fi

# Citim tagurile celor două medii.
BLUE_TAG=latest
GREEN_TAG=latest

if [ -f blue-green/blue.env ]; then
    . ./blue-green/blue.env
fi

if [ -f blue-green/green.env ]; then
    . ./blue-green/green.env
fi

export BLUE_TAG GREEN_TAG

# Actualizăm numai mediul inactiv.
sudo -E docker compose \
    --env-file .env \
    -f "$COMPOSE" \
    -p figurinehub-bg \
    pull "backend-$TARGET" "frontend-$TARGET"

sudo -E docker compose \
    --env-file .env \
    -f "$COMPOSE" \
    -p figurinehub-bg \
    up -d --no-deps \
    "backend-$TARGET" "frontend-$TARGET"

# Verificăm noua versiune înainte de comutare.
FRONTEND_CONTAINER="figurinehub-bg-frontend-$TARGET-1"

HEALTHY=0

for i in $(seq 1 12); do
    if sudo docker exec "$FRONTEND_CONTAINER" \
        wget -qO- http://127.0.0.1/health >/dev/null 2>&1; then
        HEALTHY=1
        break
    fi

    sleep 5
done

if [ "$HEALTHY" -ne 1 ]; then
    echo "DEPLOY FAILED: $TARGET nu raspunde."
    echo "Traficul ramane pe $ACTIVE."
    exit 1
fi

# Comutăm traficul.
sed -i \
    "s/frontend-$ACTIVE:80/frontend-$TARGET:80/" \
    "$PROXY_CONF"

# Verificăm sintaxa înainte de reload.
if ! sudo docker exec "$PROXY_CONTAINER" nginx -t; then
    cp "$PROXY_CONF.rollback" "$PROXY_CONF"
    echo "ROLLBACK: configuratie Nginx invalida."
    exit 1
fi

sudo docker exec "$PROXY_CONTAINER" nginx -s reload

# Verificăm aplicația prin proxy-ul public.
sleep 3

if ! curl -fsS http://127.0.0.1/health; then
    echo "DEPLOY FAILED: revenim la $ACTIVE."

    cp "$PROXY_CONF.rollback" "$PROXY_CONF"

    sudo docker exec "$PROXY_CONTAINER" nginx -s reload

    echo "ROLLBACK EXECUTAT."
    exit 1
fi

echo
echo "BLUE/GREEN DEPLOY SUCCESS!"
echo "ACTIVE VERSION: $TARGET"
echo "DOCKER TAG: $BUILD_TAG_NUMBER"
REMOTE
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'FigurineHub CI/CD: Build, Push, STAGE and Blue/Green PROD SUCCESS!'
        }

        failure {
            echo 'FigurineHub CI/CD FAILED! Check deployment and rollback logs.'
        }
    }
}