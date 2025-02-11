#!/bin/bash

# SmartOffice360 deployment script
export PLATFORM_NAME="smartoffice360"
export DOMAIN="designx.co.ke"

# Create main directory
sudo mkdir -p /opt/$PLATFORM_NAME
sudo chown -R $USER:$USER /opt/$PLATFORM_NAME
cd /opt/$PLATFORM_NAME

# Create necessary directories
mkdir -p {config,data,logs,ssl,secrets}
mkdir -p services/{auth,storage,office,ai,automation}

# Generate secure passwords and keys
openssl rand -base64 32 > /opt/$PLATFORM_NAME/secrets/admin_password.txt
openssl rand -base64 32 > /opt/$PLATFORM_NAME/secrets/db_password.txt
openssl rand -base64 32 > /opt/$PLATFORM_NAME/secrets/minio_password.txt

# Create docker-compose.yml
cat > /opt/$PLATFORM_NAME/docker-compose.yml << 'EOF'
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: smartoffice360-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./ssl:/etc/nginx/ssl
      - ./config/nginx:/etc/nginx/conf.d
    depends_on:
      - auth
      - api-gateway
    restart: always

  api-gateway:
    image: kong:latest
    container_name: smartoffice360-gateway
    environment:
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-database
    depends_on:
      - kong-database
    ports:
      - "8000:8000"
      - "8443:8443"
    restart: always

  kong-database:
    image: postgres:13
    container_name: smartoffice360-kong-db
    environment:
      - POSTGRES_DB=kong
      - POSTGRES_USER=kong
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    volumes:
      - kong_data:/var/lib/postgresql/data
    restart: always

  auth:
    image: keycloak/keycloak:latest
    container_name: smartoffice360-auth
    environment:
      - KEYCLOAK_ADMIN=admin
      - KEYCLOAK_ADMIN_PASSWORD_FILE=/run/secrets/admin_password
      - KC_DB=postgres
    depends_on:
      - auth-database
    ports:
      - "8080:8080"
    restart: always

  auth-database:
    image: postgres:13
    container_name: smartoffice360-auth-db
    environment:
      - POSTGRES_DB=keycloak
      - POSTGRES_USER=keycloak
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    volumes:
      - auth_data:/var/lib/postgresql/data
    restart: always

  storage:
    image: minio/minio
    container_name: smartoffice360-storage
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=admin
      - MINIO_ROOT_PASSWORD_FILE=/run/secrets/minio_password
    volumes:
      - storage_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    restart: always

  office-backend:
    image: node:16-alpine
    container_name: smartoffice360-office
    working_dir: /app
    volumes:
      - ./services/office:/app
    command: npm start
    depends_on:
      - auth
      - storage
    restart: always

  ai-service:
    image: python:3.9-slim
    container_name: smartoffice360-ai
    working_dir: /app
    volumes:
      - ./services/ai:/app
    command: python app.py
    restart: always

  automation:
    image: python:3.9-slim
    container_name: smartoffice360-automation
    working_dir: /app
    volumes:
      - ./services/automation:/app
    command: python app.py
    restart: always

volumes:
  kong_data:
  auth_data:
  storage_data:

secrets:
  admin_password:
    file: ./secrets/admin_password.txt
  db_password:
    file: ./secrets/db_password.txt
  minio_password:
    file: ./secrets/minio_password.txt
EOF

# Create Nginx configuration for designx.co.ke
cat > /opt/$PLATFORM_NAME/config/nginx/default.conf << EOF
server {
    listen 80;
    server_name designx.co.ke;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name designx.co.ke;

    ssl_certificate /etc/nginx/ssl/certificate.crt;
    ssl_certificate_key /etc/nginx/ssl/private.key;

    # Main dashboard
    location / {
        proxy_pass http://api-gateway:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Auth service
    location /auth/ {
        proxy_pass http://auth:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Storage service
    location /storage/ {
        proxy_pass http://storage:9000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Storage console
    location /storage-console/ {
        proxy_pass http://storage:9001/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "Setup complete! Next steps:"
echo "1. Get SSL certificate for designx.co.ke"
echo "2. Place SSL certificates in /opt/$PLATFORM_NAME/ssl/"
echo "3. Run: docker-compose up -d"
echo "4. Access the platform at https://designx.co.ke"
