# ================================
# Stage 1: Build Flutter Web App
# ================================
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Pre-cache dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy full frontend source code
COPY . .

# Build web release bundle
ARG PB_URL=https://pocket.chai-tea.duckdns.org
RUN flutter build web --release --dart-define=PB_URL=$PB_URL

# ================================
# Stage 2: Serve with Nginx
# ================================
FROM nginx:alpine

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy compiled Flutter web assets
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
