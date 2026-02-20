# Credit Card Invoice Reader (OCR) - Implementation Plan

## Context

The user wants to implement the core feature of Budgetly: a Credit Card Invoice Reader using OCR technology. This feature will allow users to upload PDF or image files of their credit card invoices, automatically extract transaction data using OCR, review and correct the extracted data, and save it to the database for financial tracking.

**Current State:**
- Backend: Basic Go + Gin API with health check, CORS configured, PostgreSQL and Redis in docker-compose but not connected
- Frontend: React 18 + TypeScript with Vite, minimal structure (only health check component), no routing or state management
- No database models, file upload handling, or OCR integration exist

**Goal:** Build a complete end-to-end OCR invoice processing system with backend APIs and frontend UI for upload, processing, review, and confirmation of transactions.

---

## Implementation Approach

### High-Level Architecture

```
User uploads file → Backend stores & creates invoice record →
OCR processes file (Tesseract) → Parser extracts transactions →
Frontend displays editable table → User reviews/edits →
Confirms and saves to database
```

### Technology Choices

**OCR Service:** OpenAI GPT-4 Vision API
- Sends image/PDF directly to GPT-4V with structured prompts
- Extremely high accuracy (95%+) with intelligent parsing
- Returns structured JSON with transactions
- Handles Brazilian Portuguese natively
- Understands context and can correct obvious errors
- Cost: ~$0.01-0.05 per invoice (vision tokens)
- No local processing needed - API handles everything

**Database:** PostgreSQL with standard database/sql package
- Using `pgx` driver (best PostgreSQL driver for Go)
- Direct SQL queries with prepared statements
- No ORM overhead
- **Single-user app** - no users table needed
- 3 main tables: invoices, transactions, categories
- UUID primary keys
- Proper indexes for performance

**OpenAI API Key Handling:**
- User provides their own OpenAI API key
- Passed as parameter from frontend (stored in localStorage or env)
- Backend receives key per request (header or body)
- No server-side API key storage
- User controls their own costs

**File Storage:** Local filesystem with Docker volumes
- Upload limit: 10MB
- Supported formats: PDF, PNG, JPG, JPEG
- Path: `/app/uploads/invoices/{invoice_id}_{filename}`

---

## Database Schema

**Note:** Single-user application - no users table needed

### Invoices Table
```sql
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size INTEGER NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_status VARCHAR(50) DEFAULT 'pending',
    ocr_confidence DECIMAL(5,2),
    invoice_date DATE,
    due_date DATE,
    total_amount DECIMAL(12,2),
    card_last_four VARCHAR(4),
    card_issuer VARCHAR(100),
    confirmed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_invoices_status ON invoices(processing_status);
CREATE INDEX idx_invoices_date ON invoices(invoice_date);
```

### Transactions Table
```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    transaction_date DATE NOT NULL,
    description TEXT NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    category VARCHAR(100),
    merchant VARCHAR(255),
    ocr_confidence DECIMAL(5,2),
    is_edited BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transactions_invoice_id ON transactions(invoice_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_category ON transactions(category);
```

### Categories Table
```sql
CREATE TABLE categories (
    id UUID PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(7),
    created_at TIMESTAMP
);
```

---

## Backend Implementation

### Dependencies to Add (go.mod)
```
github.com/jackc/pgx/v5 v5.5.3
github.com/google/uuid v1.6.0
github.com/sashabaranov/go-openai v1.20.2
```

### Critical Backend Files

**1. Database & Models**
- `backend/config/database.go` - pgx connection pool setup
- `backend/migrations/001_create_tables.sql` - SQL migration file for schema
- `backend/models/invoice.go` - Invoice struct (plain Go struct)
- `backend/models/transaction.go` - Transaction struct
- `backend/models/category.go` - Category struct

**2. Handlers**
- `backend/handlers/invoice_handler.go` - Upload, process, confirm endpoints
- `backend/handlers/transaction_handler.go` - CRUD operations for transactions

**3. Services**
- `backend/services/openai_service.go` - OpenAI API client factory (creates client with user's API key)
- `backend/services/ocr_service.go` - Processes invoice with GPT-4V, extracts structured data
- `backend/services/invoice_processor.go` - Orchestrates: Upload → GPT-4V → Parse JSON → Save workflow

**4. Utilities**
- `backend/utils/file.go` - File validation, saving utilities
- `backend/utils/response.go` - Standard JSON response format
- `backend/middleware/file_upload.go` - Max size, type validation
- `backend/middleware/error_handler.go` - Global error handling

**5. Repositories**
- `backend/repositories/transaction_repository.go` - Database operations abstraction

### API Endpoints

**All endpoints require `X-OpenAI-API-Key` header with user's OpenAI API key**

```
POST   /api/v1/invoices/upload
       Headers: X-OpenAI-API-Key
       Body: multipart/form-data with file

POST   /api/v1/invoices/{id}/process
       Headers: X-OpenAI-API-Key

GET    /api/v1/invoices
       Returns: List of all invoices

GET    /api/v1/invoices/{id}
       Returns: Invoice details

GET    /api/v1/invoices/{id}/transactions
       Returns: Extracted transactions

POST   /api/v1/invoices/{id}/confirm
       Body: { transactions: [...] }

PUT    /api/v1/transactions/{id}
       Body: { date, description, amount, category }

DELETE /api/v1/transactions/{id}

PATCH  /api/v1/invoices/{id}/transactions
       Body: { transactions: [...] }
```

### OCR Processing Logic

**GPT-4 Vision Processing:**
- Convert PDF to image (using pdf-to-image library if needed)
- Encode image to base64
- Send to OpenAI API with structured prompt:

```json
{
  "model": "gpt-4-vision-preview",
  "messages": [{
    "role": "user",
    "content": [
      {"type": "text", "text": "Extract all transactions from this credit card invoice. Return JSON with: invoice_date, due_date, total_amount, card_last_four, transactions array with (date, description, amount, merchant). Amounts in Brazilian format (R$ 1.234,56)."},
      {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
    ]
  }],
  "response_format": { "type": "json_object" }
}
```

**Response Parsing:**
- GPT-4V returns structured JSON directly
- No regex needed - AI understands context
- Can handle variations in invoice format
- Returns confidence implicitly (accuracy ~95%+)
- Handles OCR errors intelligently (e.g., "0" vs "O")

### Dockerfile Update

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
RUN mkdir -p /root/uploads/invoices /root/uploads/temp
EXPOSE 8080
CMD ["./main"]
```

**Note:** No Tesseract needed since OCR is handled by OpenAI API

---

## Frontend Implementation

### Dependencies (Already Installed)
- React 18, TypeScript, Vite
- react-router-dom (not yet used)
- axios (not yet used)

### Project Structure

```
frontend/src/
├── components/
│   ├── FileUpload/
│   │   ├── FileUpload.tsx
│   │   └── FileUpload.module.css
│   ├── TransactionTable/
│   │   ├── TransactionTable.tsx
│   │   ├── TransactionRow.tsx
│   │   └── TransactionTable.module.css
│   ├── Loading/
│   │   ├── Spinner.tsx
│   │   ├── ProgressBar.tsx
│   │   └── ProcessingModal.tsx
│   └── Error/
│       ├── ErrorMessage.tsx
│       └── ErrorBoundary.tsx
├── pages/
│   ├── HomePage.tsx
│   ├── UploadPage.tsx
│   └── InvoiceReviewPage.tsx
├── services/
│   ├── api.ts
│   └── invoiceService.ts
├── types/
│   └── invoice.ts
├── hooks/
│   └── useFileUpload.ts
├── contexts/
│   └── InvoiceContext.tsx
└── utils/
    └── errorHandler.ts
```

### Critical Frontend Files

**1. API Integration**
- `services/api.ts` - Axios instance with base URL, interceptors
- `services/invoiceService.ts` - API methods: uploadInvoice, processInvoice, confirmInvoice
- `types/invoice.ts` - TypeScript interfaces for Invoice, Transaction, HealthResponse

**2. Routing**
- Update `main.tsx` - Add BrowserRouter
- Update `App.tsx` - Setup Routes for /, /upload, /invoices/:id/review, /transactions

**3. Components**
- `FileUpload.tsx` - Drag-and-drop upload, file validation, progress bar
- `TransactionTable.tsx` - Editable table with inline editing, delete, add row
- `TransactionRow.tsx` - Individual editable row with validation
- `ProcessingModal.tsx` - Shows OCR processing stages
- `Spinner.tsx`, `ErrorMessage.tsx` - Loading and error states

**4. Pages**
- `HomePage.tsx` - Dashboard with quick upload, recent invoices
- `UploadPage.tsx` - Upload workflow, redirects to review
- `InvoiceReviewPage.tsx` - Display invoice metadata, editable transaction table, confirm/cancel

**5. State Management**
- `InvoiceContext.tsx` - React Context for invoice/transaction state
- `useFileUpload.ts` - Custom hook for upload logic with progress

### Key Features

**File Upload:**
- Drag-and-drop area
- File type validation (PDF, PNG, JPG, JPEG)
- Max size validation (10MB client-side)
- Upload progress bar
- File preview for images

**Transaction Table:**
- Inline editing for date, description, amount, category
- Delete row functionality
- Add manual transaction
- Visual indicators for low confidence (<0.8)
- Highlight edited rows
- Validation on save

---

## Implementation Phases (6 Sprints)

### Sprint 1: Database & File Upload Backend (Week 1)
**Tasks:**
1. Add pgx and OpenAI SDK dependencies to go.mod
2. Create SQL migration file `migrations/001_create_tables.sql`
3. Implement `config/database.go` with pgx connection pool
4. Create database models (plain structs with sql.Scanner)
5. Create file upload handler in `handlers/invoice_handler.go`
6. Add file validation middleware
7. Update docker-compose.yml with upload volumes and OPENAI_API_KEY env
8. Test file upload endpoint

**Deliverable:** Backend can receive and store invoice files

### Sprint 2: OpenAI GPT-4 Vision Integration (Week 2)
**Tasks:**
1. Setup OpenAI API key in environment
2. Implement `services/openai_service.go` with client initialization
3. Build `services/ocr_service.go`:
   - Convert PDF to image (if needed)
   - Encode image to base64
   - Call GPT-4V with structured prompt
   - Parse JSON response
4. Create `services/invoice_processor.go` workflow
5. Add process endpoint
6. Test with sample Brazilian credit card invoices
7. Handle API errors and rate limits

**Deliverable:** Backend extracts and parses transactions using GPT-4 Vision

### Sprint 3: Backend APIs (Week 3)
**Tasks:**
1. Implement transaction CRUD in `handlers/transaction_handler.go`
2. Add confirm endpoint for invoice
3. Create `repositories/transaction_repository.go` with prepared SQL statements
4. Add error handling middleware
5. Implement response utilities
6. Write unit tests for OpenAI service (with mocked responses)
7. API documentation

**Deliverable:** Complete backend API ready for frontend integration

### Sprint 4: Frontend Foundation (Week 4)
**Tasks:**
1. Create project folder structure
2. Setup React Router in main.tsx and App.tsx
3. Build `services/api.ts` axios client
4. Implement `services/invoiceService.ts`
5. Create TypeScript types in `types/invoice.ts`
6. Build `FileUpload.tsx` component
7. Create `UploadPage.tsx`
8. Implement `useFileUpload.ts` hook

**Deliverable:** Users can upload invoice files from frontend

### Sprint 5: Review Interface (Week 5)
**Tasks:**
1. Build `TransactionTable.tsx` with editing
2. Create `TransactionRow.tsx` editable component
3. Implement `InvoiceReviewPage.tsx`
4. Add `InvoiceContext.tsx` for state
5. Create loading components (Spinner, ProcessingModal)
6. Add error handling (ErrorMessage, ErrorBoundary)
7. Style all components

**Deliverable:** Users can review, edit, and confirm transactions

### Sprint 6: Polish & Testing (Week 6)
**Tasks:**
1. End-to-end integration testing
2. Add loading states throughout
3. Improve error messages
4. UI/UX polish
5. Performance optimization
6. Bug fixes
7. User documentation

**Deliverable:** MVP ready for production use

---

## Testing & Verification

### Backend Tests
**Unit Tests:**
- `handlers/invoice_handler_test.go` - Test upload validation, processing
- `services/ocr_service_test.go` - Test with mocked OpenAI responses
- `repositories/transaction_repository_test.go` - Test SQL queries with test database

**Integration Tests:**
- Upload → Process → Confirm flow
- Database operations
- File storage and retrieval

### Frontend Tests
**Component Tests:**
- `FileUpload.test.tsx` - Test file validation, upload
- `TransactionTable.test.tsx` - Test editing, validation

### Manual Test Scenarios
1. Upload valid PDF credit card invoice
2. Upload invalid file type (should reject)
3. Upload oversized file (should reject)
4. Process invoice and verify OCR extraction
5. Edit transaction data and confirm
6. Handle network errors gracefully
7. Test with multiple invoice formats

### Success Metrics
- OCR accuracy: >95% (GPT-4 Vision is extremely accurate)
- Processing time: 5-15 seconds per invoice (API latency)
- Upload success rate: >98%
- User completion rate (upload to confirm): >80%
- API cost per invoice: <$0.05

---

## Docker Configuration

### docker-compose.yml Updates

```yaml
backend:
  build:
    context: ./backend
    dockerfile: Dockerfile
  environment:
    PORT: 8080
    GIN_MODE: debug
    DATABASE_URL: postgres://budgetly:budgetly123@postgres:5432/budgetly?sslmode=disable
    REDIS_URL: redis:6379
    UPLOAD_DIR: /app/uploads
    MAX_UPLOAD_SIZE: 10485760  # 10MB
  volumes:
    - ./backend:/app
    - ./backend/uploads:/app/uploads  # Persist uploaded files
```

---

## Risk Mitigation

**Risk 1: API Costs**
- Monitor OpenAI API usage and costs
- Implement cost tracking per invoice
- Set usage limits/budgets in OpenAI dashboard
- Consider caching results to avoid reprocessing
- Estimated cost: $0.01-0.05 per invoice (very affordable for MVP)

**Risk 2: Diverse Invoice Formats**
- Start with 2-3 major Brazilian card issuers
- Build regex pattern library incrementally
- Allow manual transaction entry as fallback

**Risk 3: File Storage Growth**
- Implement cleanup after processing confirmation
- Add retention policy (delete after 90 days)
- Compress files before storage

**Risk 4: Processing Latency & API Rate Limits**
- GPT-4V API calls take 5-15 seconds per invoice
- Show clear progress indicators during processing
- Handle rate limits gracefully (retry with exponential backoff)
- Consider async processing with job queue (Redis) for production
- Allow users to leave and return to review

**Risk 5: Security**
- Strict file type validation
- Rate limiting on upload endpoint
- Sanitize file names
- Store files outside web-accessible directories

---

## Future Enhancements (Post-MVP)

1. Automatic transaction categorization with ML
2. Email integration (process invoices from inbox)
3. Batch upload (multiple invoices at once)
4. Export to CSV/Excel
5. Mobile app for photo capture
6. Notification system for completed processing
7. Multi-currency support
8. Recurring transaction detection
9. Budget tracking integration
10. Analytics dashboard with spending insights

---

## Critical Files for Implementation

1. **`backend/config/database.go`** - pgx connection pool initialization; foundational for all DB operations
2. **`backend/migrations/001_create_tables.sql`** - Database schema creation
3. **`backend/models/invoice.go`** - Core data structures for invoices and transactions
4. **`backend/services/openai_service.go`** - OpenAI API client setup and configuration
5. **`backend/services/ocr_service.go`** - GPT-4 Vision integration; processes invoices and returns structured JSON
6. **`backend/handlers/invoice_handler.go`** - Main API handlers; orchestrates upload/process/confirm workflow
7. **`backend/repositories/transaction_repository.go`** - SQL queries for transaction CRUD operations
8. **`frontend/src/services/api.ts`** - Axios client; foundation for all API communication
9. **`frontend/src/components/TransactionTable/TransactionTable.tsx`** - Editable table; critical for UX
10. **`frontend/src/pages/InvoiceReviewPage.tsx`** - Main review page; orchestrates user workflow

---

## Dependencies Summary

### Backend (add to go.mod)
```
github.com/jackc/pgx/v5 v5.5.3
github.com/google/uuid v1.6.0
github.com/sashabaranov/go-openai v1.20.2
```

**Environment Variables Required:**
```
DATABASE_URL=postgres://budgetly:budgetly123@postgres:5432/budgetly?sslmode=disable
```

**Note:** No server-side OPENAI_API_KEY needed - user provides their own key via frontend

### Frontend
All required dependencies already installed (react, typescript, axios, react-router-dom)

---

## Verification Steps

1. **Backend Database:**
   - Run migrations: `psql $DATABASE_URL -f backend/migrations/001_create_tables.sql`
   - Verify tables created: `make db-shell` then `\dt`

2. **Backend API:**
   - Set OPENAI_API_KEY in docker-compose.yml or .env
   - Start services: `make up`
   - Upload file: `curl -F "file=@invoice.pdf" http://localhost:8080/api/v1/invoices/upload`
   - Process with GPT-4V: `curl -X POST http://localhost:8080/api/v1/invoices/{id}/process`
   - Check results: `curl http://localhost:8080/api/v1/invoices/{id}`

3. **Frontend:**
   - Access: http://localhost:3000
   - Navigate to /upload
   - Drag and drop invoice file
   - Verify upload progress
   - Check review page displays transactions
   - Edit a transaction
   - Confirm and verify saved to database

4. **End-to-End:**
   - Complete flow: Upload → Process → Review → Edit → Confirm
   - Check database: `SELECT * FROM transactions WHERE invoice_id = '{id}'`
   - Verify files stored: `ls backend/uploads/invoices/`

---

**Estimated Timeline:** 6 weeks (6 sprints)
**Team Size:** 1-2 developers
**Complexity:** Medium-High
