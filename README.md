# Splitkaro

A modern expense-splitting and debt-simplification app built with **Flutter** (frontend) and **PocketBase** (backend).

## Features
- **Group & Friend Expenses**: Split bills equally, by exact amounts, or custom percentages.
- **Debt Simplification**: Intelligent debt settlement algorithm to minimize the number of transactions.
- **Insights & Analytics**: Spending breakdowns by category, month, and user share.
- **Real-time Backend**: Powered by PocketBase SQLite database with instant sync.

## Project Structure
- `frontend/`: Flutter cross-platform application (iOS, Android, Web, macOS, Desktop).
- `backend/`: PocketBase backend service, schema definitions, and database migrations (`pb_migrations/`).

## Getting Started

### 1. Backend (PocketBase)
```bash
cd backend
./pocketbase serve --http="127.0.0.1:8090"
```
The PocketBase admin dashboard will be available at `http://127.0.0.1:8090/_/`.

### 2. Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```
