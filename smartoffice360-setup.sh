#!/bin/bash

# SmartOffice360 Enhanced Deployment Script with Dashboard
export PLATFORM_NAME="smartoffice360"
export DOMAIN="designx.co.ke"

# Create main directory
sudo mkdir -p /opt/$PLATFORM_NAME
sudo chown -R $USER:$USER /opt/$PLATFORM_NAME
cd /opt/$PLATFORM_NAME

# Create necessary directories
mkdir -p {config,data,logs,ssl,secrets,duda,nextcloud,rclone,n8n,dashboard}
mkdir -p services/{auth,storage,office,ai,automation,website,workflow,dashboard}

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
      - "8081:80"
      - "8443:443"
    volumes:
      - ./ssl:/etc/nginx/ssl
      - ./config/nginx:/etc/nginx/conf.d
    depends_on:
      - auth
      - api-gateway
      - nextcloud
      - duda-proxy
      - dashboard
    restart: always

  duda-proxy:
    image: nginx:alpine
    container_name: smartoffice360-duda
    volumes:
      - ./config/duda:/etc/nginx/conf.d
    restart: always

  nextcloud:
    image: nextcloud:latest
    container_name: smartoffice360-nextcloud
    volumes:
      - nextcloud_data:/var/www/html
    environment:
      - NEXTCLOUD_ADMIN_USER=admin
      - NEXTCLOUD_ADMIN_PASSWORD_FILE=/run/secrets/admin_password
    restart: always

  n8n:
    image: n8nio/n8n
    container_name: smartoffice360-n8n
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    restart: always

  rclone:
    image: rclone/rclone
    container_name: smartoffice360-rclone
    command: rclone serve webdav --addr :8082
    volumes:
      - ./rclone:/config
    restart: always

  dashboard:
    image: ghcr.io/linuxserver/heimdall
    container_name: smartoffice360-dashboard
    ports:
      - "8083:80"
    volumes:
      - dashboard_data:/config
    restart: always

volumes:
  nextcloud_data:
  n8n_data:
  dashboard_data:
EOF

# Configure Duda API integration (placeholder script)
cat > /opt/$PLATFORM_NAME/services/website/duda_setup.sh << EOF
#!/bin/bash
# This script will interact with Duda API to automate website setup
API_KEY="your_duda_api_key"
curl -X POST "https://api.duda.co/api/sites/multiscreen/create" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer \$API_KEY" \
  -d '{"site_name": "new-business-site"}'
EOF
chmod +x /opt/$PLATFORM_NAME/services/website/duda_setup.sh

# Final instructions
echo "Setup complete! Next steps:"
echo "1. Configure Duda API key in /opt/$PLATFORM_NAME/services/website/duda_setup.sh"
echo "2. Run: docker-compose up -d"
echo "3. Access the platform at https://designx.co.ke"
echo "4. Use Nextcloud at /nextcloud and n8n at :5678"
echo "5. Automate workflows with n8n and sync files with Rclone"
echo "6. Manage everything from the dashboard at http://your-server-ip:8083"
