# 💰 Budgetly

Smart financial control with AI insights

## 📋 About

Budgetly is a financial management application that uses artificial intelligence to provide personalized insights about your expenses, investments, and assets.

### Planned Features

- 📄 Credit card invoice reading (OCR)
- 📊 Monthly expense tracking and charts
- 🤖 AI insights on spending/income
- 💼 Asset and investment tracking
- 🔔 Smart notifications
- 🏷️ Automatic transaction categorization
- 🎯 Goals and budgets
- 📈 Cash flow forecasting

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Make (optional, but recommended)

### Installation

1. **Clone the repository**
   ```bash
   git clone git@github.com-lmiguelcardoso:lmiguelcardoso/budgetly.git
   cd budgetly
   ```

2. **Start services**
   ```bash
   make up
   ```

3. **Access the application**
   - Frontend: http://localhost:3000
   - Backend: http://localhost:8080
   - API Health: http://localhost:8080/health

## 📝 Available Commands

```bash
make help          # Show all available commands
make up            # Start all services
make down          # Stop all services
make build         # Rebuild containers
make restart       # Restart all services
make logs          # Show logs from all services
make logs-backend  # Show backend logs
make logs-frontend # Show frontend logs
make clean         # Remove containers, volumes and images
make db-shell      # Access PostgreSQL shell
make redis-shell   # Access Redis CLI
make ps            # List running containers
```

## 🛠️ Development

### Project Structure

```
budgetly/
├── frontend/          # React + Vite
│   ├── src/
│   ├── Dockerfile
│   └── package.json
├── backend/           # Go + Gin
│   ├── main.go
│   ├── Dockerfile
│   └── go.mod
├── docker-compose.yml
├── Makefile
└── README.md
```

### Local Development (without Docker)

**Frontend:**
```bash
cd frontend
npm install
npm run dev
```

**Backend:**
```bash
cd backend
go mod download
go run main.go
```

## 🧪 Testing

```bash
make test-frontend  # Frontend tests
make test-backend   # Backend tests
```

## 📦 Tech Stack

- **Frontend:** React, TypeScript, Vite, Axios
- **Backend:** Go, Gin
- **Database:** PostgreSQL 16
- **Cache:** Redis 7
- **DevOps:** Docker, Docker Compose

## 👥 Author

Miguel Cardoso - [@lmiguelcardoso](https://github.com/lmiguelcardoso)
