# PocketBase Backend Deployment (Git Clone Approach)

This guide covers deploying the PocketBase backend using **Git Clone + Docker Compose** on your Linux server.

---

## 1. Initial Setup on Server

SSH into your server and run:

```bash
# 1. Clone the repository
git clone git@github.com:satyamramani/splitkaro.git
cd splitkaro/backend

# 2. (Optional) If you want to copy your existing local data from your Mac:
# Run this from your MAC terminal:
# rsync -avz /Users/satyamramani/Workspace/Split/backend/pb_data/ user@YOUR_SERVER_IP:~/splitkaro/backend/pb_data/

# 3. Start PocketBase with Docker Compose
docker compose up -d --build
```

- **PocketBase Admin Dashboard:** `http://YOUR_SERVER_IP:8090/_/`
- **REST API:** `http://YOUR_SERVER_IP:8090/api/`

---

## 2. (Recommended) Enable Automatic HTTPS / Domain with Caddy

To connect your phone app securely:

1. Point your domain DNS **A record** (e.g. `api.splitkaro.com`) to your server IP.
2. Edit `Caddyfile` on the server:
   ```caddy
   api.splitkaro.com {
       reverse_proxy pocketbase:8090
   }
   ```
3. Edit `docker-compose.yml` to uncomment the `caddy` service and volumes.
4. Restart containers:
   ```bash
   docker compose up -d --build
   ```
Caddy will automatically provision and renew a free Let's Encrypt SSL certificate!

---

## 3. How to Update in the Future

Whenever you make backend or migration changes on your laptop and push to GitHub, update the server with 2 commands:

```bash
cd ~/splitkaro
git pull origin main
cd backend
docker compose up -d --build
```

Docker will rebuild the container, run any new migrations from `pb_migrations/`, and restart the service without losing any database records in `pb_data/`.

---

## Useful Commands

| Task | Command |
|---|---|
| View live logs | `docker compose logs -f pocketbase` |
| Check status | `docker compose ps` |
| Stop service | `docker compose down` |
| Restart | `docker compose restart` |
