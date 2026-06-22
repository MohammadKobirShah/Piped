#!/bin/sh
set -e

# Use PORT from Railway, default to 3000
PORT=${PORT:-3000}

echo "🚀 Starting nginx on port $PORT"

# Create nginx config with correct port
cat > /etc/nginx/conf.d/default.conf << NGINX
server {
    listen $PORT;
    listen [::]:$PORT;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Healthcheck endpoint
    location = /healthz {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # SPA routing
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|otf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # No cache for HTML
    location ~* \.html$ {
        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
        add_header Pragma "no-cache";
    }

    # API proxy
    location /api/ {
        proxy_pass https://api.piped.private.coffee/;
        proxy_set_header Host api.piped.private.coffee;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_server_name on;
    }

    # Error pages
    error_page 404 =200 /index.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
NGINX

echo "✅ Nginx configured for port $PORT"

# Execute the main command
exec "$@"
