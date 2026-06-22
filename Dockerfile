# ============================================
# Piped Frontend - Nginx + Docker (Railway)
# ============================================
# Features:
# - Lite: nginx:alpine final stage (~22MB)
# - Stable: Multi-stage build, health checks
# - Railway: PORT env, auto-detection
# - Fixed: Node.js 22 for pnpm compatibility
# ============================================

# ---- Stage 1: Build ----
FROM node:22-alpine AS builder

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy dependency files first (for better caching)
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile --prefer-offline

# Copy source code
COPY . .

# Build the app
RUN pnpm build

# ---- Stage 2: Production ----
FROM nginx:1.27-alpine AS production

# Remove default config
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy nginx main config
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Create non-root user (with error handling)
RUN addgroup -g 1001 piped 2>/dev/null || true && \
    adduser -D -u 1001 -G piped piped 2>/dev/null || true && \
    chown -R piped:piped /usr/share/nginx/html && \
    chown -R piped:piped /var/cache/nginx && \
    chown -R piped:piped /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R piped:piped /var/run/nginx.pid

# Expose port
EXPOSE 3000

# Healthcheck using wget (available in alpine)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT:-3000}/healthz || exit 1

# Use entrypoint script
ENTRYPOINT ["/docker-entrypoint.sh"]

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
