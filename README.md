# 🚀 WhatsApp E-Commerce & Booking Automation System (Multi-Tenant)
### N8N + Supabase (PostgreSQL) + Meta WhatsApp Cloud API + LangChain AI Agents

A complete, production-ready, multi-tenant conversational automation ecosystem for WhatsApp. It enables business owners to manage online sales, dynamic shopping carts, payment proof validation, live chat handovers, inventory CRUD, automated financial reports, and collision-free appointment scheduling.

---

## 📚 Technical Documentation Index

| Guide | Description |
|---|---|
| 📖 [**Production Deployment Guide**](docs/production_deployment.md) | VPS deployment with Docker Compose, Caddy / Nginx SSL, Meta Webhook setup, and tenant creation. |
| 💬 [**Usage Examples & Test Payloads**](docs/usage_examples.md) | Full table of commands for business owners (`ROLE: BUSINESS`), customer dialogues (`ROLE: CLIENT`), and cURL payloads. |
| 🗄️ [**SQL Test Queries & Seed Data**](docs/test_queries.md) | Ready-to-run Supabase scripts: tenant seeding, product catalog, customer records, state machine simulations, and RPC tests. |
| 🏗️ [**Technical Architecture & State Machine**](docs/flow_architecture.md) | System diagrams, 7-state sales machine, LangChain AI classifier logic, multi-tenant data model, and RLS policies. |
| 🔄 [**Git Workflow Sync Manager (CI/CD)**](docs/git_sync_guide.md) | Automated GitHub Push Webhook sync to create and update N8N workflows dynamically. |

---

## 📁 Repository Structure

```
.
├── README.md                           # 📖 Main Project Documentation
├── supabase_setup.sql                  # 🗄️ Database DDL, RLS Policies, Indexes & RPC Functions
├── n8n_git_sync_manager.json           # 🔄 Git Workflow Sync Manager (CI/CD for N8N)
├── flow0_whatsapp_orchestrator.json    # 🔀 Master Orchestrator (Meta Webhook GET/POST + AI Classifier)
├── flow1_sales_state_machine.json      # 🛒 7-State Conversational Sales Machine & Atomic Checkout
├── flow2_product_catalog_crud.json     # 📦 Catalog Management & Relative Stock (+/-)
├── flow3_automated_reports.json        # 📊 Automated Daily Financial Reports (6:00 PM Cron)
├── flow4_appointment_booking.json      # 📅 Commercial Booking with Anti-Collision (±29 min)
└── docs/                               # 📚 Detailed Technical Documentation
    ├── production_deployment.md        # 🌐 Server Deployment, SSL & Meta Webhook Verification
    ├── flow_architecture.md            # 🏗️ Architecture, State Machine & Multi-Tenant Model
    ├── usage_examples.md               # 💬 Interactive Chat Examples & cURL Simulation Payloads
    ├── test_queries.md                 # 🧪 SQL Queries, Seed Scripts & RPC Validation Tests
    └── git_sync_guide.md               # 🔄 GitHub Push Webhook CI/CD Sync Guide
```

---

## ⚡ Quick Start (Local Testing with ngrok)

### 1. Start Tunnel
```bash
ngrok http 5678
```
> Copy the HTTPS URL generated (e.g., `https://your-subdomain.ngrok-free.app`).

### 2. Start N8N with Webhook URL
```bash
export WEBHOOK_URL="https://your-subdomain.ngrok-free.app" && npx n8n start
```

### 3. Setup Supabase Database & Insert Business Tenant
1. Open the **SQL Editor** in your Supabase project.
2. Execute [`supabase_setup.sql`](supabase_setup.sql).
3. Insert your business record following the [Tenant Setup Guide](docs/production_deployment.md#3-insert-your-business-tenant-in-supabase).

### 4. Configure Global Credentials in N8N
Open `http://localhost:5678`, navigate to **Settings > Credentials**, and configure:
* **Supabase API (`supabaseApi`)**: Project URL (`https://<YOUR_PROJECT_ID>.supabase.co`) and `service_role` secret key.
* **NVIDIA Nemotron API (`nvidiaApi`)**: Your API Key (`nvapi-...`).

### 5. Configure Meta WhatsApp Webhook
* Set **Flow 0** in n8n to **Active = ON**.
* In Meta Developers (**WhatsApp > Configuration > Webhook**):
  * **Callback URL**: `https://your-subdomain.ngrok-free.app/webhook/whatsapp` *(use the production URL without `-test`)*.
  * **Verify Token**: Must match the `whatsapp_verify_token` stored in your `public.tenants` row.
* Click **Verify and Save** and subscribe to the `messages` event.

---

## 🔀 Workflow Architecture Overview

```
                                📱 Meta WhatsApp API
                                         │
                                         ▼
                     ┌───────────────────────────────────────┐
                     │       Flow 0: Master Orchestrator     │
                     │    - Meta Webhook GET Challenge       │
                     │    - Meta Webhook POST Inbound Events │
                     │    - Tenant & Role Detection          │
                     │    - LangChain / AI Agent Classifier  │
                     └───────────────────┬───────────────────┘
                                         │
                 ┌───────────────────────┼───────────────────────┐
                 ▼                       ▼                       ▼
      ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
      │   Flow 1: Sales     │ │  Flow 2: Catalog    │ │  Flow 4: Booking    │
      │  - 7 State Machine  │ │  - Product CRUD     │ │  - Online Booking   │
      │  - Cart & Checkout  │ │  - Relative Stock   │ │  - Anti-Collision   │
      │  - Atomic RPC Deduct│ │  - Price Updates    │ │    (±29 min)        │
      └─────────────────────┘ └─────────────────────┘ └─────────────────────┘
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │  Flow 3: Reports    │
                              │  - Daily 6:00 PM    │
                              │  - Financial Summary│
                              └─────────────────────┘
```

---

## 🛠️ Quick Business Commands (Via WhatsApp Chat)

Business owners can manage their operations directly by texting their WhatsApp business number:

- `ayuda` / `help` ➔ Interactive menu displaying active modules.
- `tareas` / `tasks` ➔ Summary of pending payment validations, today's appointments, and low stock alerts.
- `aprobar <number>` ➔ Atomically confirms order payment, updates state, and deducts inventory in database.
- `rechazar <number> <reason>` ➔ Rejects payment receipt and notifies customer with explanation.
- `despachos` ➔ Lists confirmed orders ready for shipping with delivery addresses.
- `ver inventario` ➔ Lists active products, unit prices, and available stock.
- `crear producto <name> precio <price> stock <qty>` ➔ Adds a new product to the catalog.
- `agregar stock <qty> a <product>` ➔ Adds units to current stock.
- `restar stock <qty> a <product>` ➔ Deducts units from current stock.
- `cambiar precio de <product> a <price>` ➔ Updates product sale price.
- `generar reporte` ➔ Returns consolidated financial metrics.
- `ver citas` ➔ Lists appointments scheduled for today.

*(See full command matrix and interactive button dialogues in [docs/usage_examples.md](docs/usage_examples.md)).*

---

## 🤖 Context Guide for AI Coding Agents

If you are an AI assistant working within this codebase:
- **Database Schema**: Always refer to [`supabase_setup.sql`](supabase_setup.sql) and [`docs/test_queries.md`](docs/test_queries.md) before writing Supabase queries.
- **N8N Flows**: Workflows communicate through `Execute Workflow` triggers and Supabase RPCs. Review [`docs/flow_architecture.md`](docs/flow_architecture.md) for state transitions.
- **Production Deployments**: For server setups and container configurations, check [`docs/production_deployment.md`](docs/production_deployment.md).
