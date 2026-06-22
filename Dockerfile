# ============================================
# Piped Frontend - Nginx + Docker (Railway)
# ============================================
# Features:
# - Lite: nginx:alpine final stage (~22MB)
# - Stable: Multi-stage build, health checks
# - Railway: PORT env, auto-detection
# ============================================

# ---- Stage 1: Build ----
FROM node:20-alpine AS builder

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Cache dependencies
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm \
    --mount=type=cache,target=/app/node_modules \
    pnpm install --frozen-lockfile --prefer-offline

# Copy source & build
COPY . .
RUN pnpm build

# ---- Stage 2: Production ----
FROM nginx:1.27-alpine AS production

# Remove default config
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy nginx config
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Create non-root user
RUN addgroup -g 1001 piped && \
    adduser -D -u 1001 -G piped piped && \
    chown -R piped:piped /usr/share/nginx/html && \
    chown -R piped:piped /var/cache/nginx && \
    chown -R piped:piped /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R piped:piped /var/run/nginx.pid

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
