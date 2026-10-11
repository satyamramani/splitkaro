# PocketBase Backend Deployment

This directory contains the containerized setup for the PocketBase backend.

## Prerequisites
- Docker & Docker Compose installed on your server (or local machine).

---

## 1. Local Development with Docker

Run PocketBase in the background:
```bash
docker compose up -d --build
```

- **API Endpoint:** `http://localhost:8090/api/`
- **Admin Dashboard:** `http://localhost:8090/_/`
- **View Logs:** `docker compose logs -f`
- **Stop:** `docker compose down`

Database data is automatically persisted in `./pb_data/`.

---

## 2. Deploying on a Cloud Server (VPS) with Automatic HTTPS

PocketBase is configured to easily work with **Caddy** for free, automatic SSL certificates.

### Step 1: Copy `backend` to your server
```bash
rsync -avz backend/ user@YOUR_SERVER_IP:/var/www/splitkaro-backend/
```

### Step 2: Configure your domain
1. Point your domain DNS (e.g. `api.splitkaro.com`) to your server IP via an **A record**.
2. Open `Caddyfile` and replace `:80` with your domain:
```caddy
api.splitkaro.com {
    reverse_proxy pocketbase:8090
}
```
3. Open `docker-compose.yml` and uncomment the `caddy` service and volumes.

### Step 3: Start on the server
```bash
docker compose up -d --build
```

Caddy will automatically generate a Let's Encrypt SSL certificate and proxy all HTTPS traffic to PocketBase.
