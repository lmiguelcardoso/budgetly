.PHONY: help up down build restart logs clean install dev-frontend dev-backend test

# Colors for terminal output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
NC     := \033[0m

help: ## Show this help message
	@echo '$(GREEN)Budgetly - Makefile Commands$(NC)'
	@echo ''
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

install: ## Install dependencies
	@echo "$(GREEN)Installing frontend dependencies...$(NC)"
	cd frontend && npm install
	@echo "$(GREEN)Installing backend dependencies...$(NC)"
	cd backend && go mod download
	@echo "$(GREEN)Dependencies installed$(NC)"

up: ## Start all services
	@echo "$(GREEN)Starting services...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)Services started$(NC)"
	@echo "$(YELLOW)Frontend: http://localhost:3000$(NC)"
	@echo "$(YELLOW)Backend:  http://localhost:8080$(NC)"

down: ## Stop all services
	@echo "$(GREEN)Stopping services...$(NC)"
	docker-compose down
	@echo "$(GREEN)Services stopped$(NC)"

build: ## Build all containers
	@echo "$(GREEN)Building containers...$(NC)"
	docker-compose build
	@echo "$(GREEN)Containers built$(NC)"

restart: down up ## Restart all services

logs: ## Show logs from all services
	docker-compose logs -f

logs-backend: ## Show backend logs
	docker-compose logs -f backend

logs-frontend: ## Show frontend logs
	docker-compose logs -f frontend

logs-db: ## Show database logs
	docker-compose logs -f postgres

clean: down ## Clean all containers, volumes and images
	@echo "$(YELLOW)Cleaning up...$(NC)"
	docker-compose down -v --remove-orphans
	docker system prune -f
	@echo "$(GREEN)Cleanup complete$(NC)"

dev-frontend: ## Run frontend in development mode (local)
	cd frontend && npm run dev

dev-backend: ## Run backend in development mode (local)
	cd backend && go run main.go

db-shell: ## Access PostgreSQL shell
	docker-compose exec postgres psql -U budgetly -d budgetly

redis-shell: ## Access Redis CLI
	docker-compose exec redis redis-cli

backend-shell: ## Access backend container shell
	docker-compose exec backend sh

frontend-shell: ## Access frontend container shell
	docker-compose exec frontend sh

ps: ## Show running containers
	docker-compose ps

test-backend: ## Run backend tests
	cd backend && go test ./...

test-frontend: ## Run frontend tests
	cd frontend && npm test

migrate-up: ## Run database migrations up
	@echo "$(YELLOW)Migrations not configured yet$(NC)"

migrate-down: ## Run database migrations down
	@echo "$(YELLOW)Migrations not configured yet$(NC)"
