# Splitkaro Fullstack Deployment Guide

Deploy both the **Flutter Web Frontend** and **PocketBase Backend** on your Linux server using Docker Compose.

---

## Architecture Overview

| Service | Port on Host | Description |
|---|---|---|
| **PocketBase** | `18090` | Go backend REST API & Admin UI |
| **Frontend** | `3000` | Nginx serving compiled Flutter Web SPA |

---

## 1. Quick Start on Your Server

SSH into your server and run:

```bash
# 1. Clone repository (or pull if already cloned)
git clone git@github.com:satyamramani/splitkaro.git
cd splitkaro

# 2. Run both frontend & backend with Docker Compose
docker compose up -d --build
```

- **Frontend Web App:** `http://YOUR_SERVER_IP:3000/`
- **PocketBase Admin:** `http://YOUR_SERVER_IP:18090/_/`
- **PocketBase REST API:** `http://YOUR_SERVER_IP:18090/api/`

---

## 2. Running Only Frontend in Docker

If PocketBase is already running and you only want to start the frontend container:

```bash
cd ~/splitkaro/frontend
docker compose up -d --build
```

This starts `splitkaro_frontend` on port `3000`.

---

## 3. Updating the Server with Latest Changes

Whenever changes are pushed to GitHub, update the server with:

```bash
cd ~/splitkaro
git pull origin main
docker compose up -d --build
```

Docker will:
1. Rebuild the frontend with the latest Flutter code.
2. Restart PocketBase without losing any records in `pb_data/`.
3. Apply any new database migrations automatically.

---

## Useful Commands

| Task | Command |
|---|---|
| Check status of containers | `docker compose ps` |
| View live frontend logs | `docker compose logs -f frontend` |
| View live PocketBase logs | `docker compose logs -f pocketbase` |
| Restart all services | `docker compose restart` |
| Stop all services | `docker compose down` |
