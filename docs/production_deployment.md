# 🌐 Production Deployment Guide — N8N + Docker + SSL + Meta WhatsApp API

This guide covers deploying the **Multi-Tenant Conversational E-Commerce and Booking System** on Linux production servers (Ubuntu/Debian, VPS on AWS EC2, DigitalOcean, Hetzner, etc.) for continuous 24/7 operation with automatic SSL certificates, secure Supabase connectivity, and webhook persistence.

---

## 📋 Prerequisites

1. **VPS / Cloud Server**:
   - Ubuntu 22.04 LTS or Debian 12 (recommended).
   - Minimum 2 GB RAM (4 GB recommended for intensive LangChain agent execution).
   - 1 vCPU or more.
   - Public static IPv4 address.
2. **Domain Name**:
   - A domain or subdomain (e.g., `n8n.yourdomain.com`) with a **DNS Type A record** pointing to the server's public IP.
3. **Firewall / Open Ports**:
   - `80/TCP` (HTTP for Let's Encrypt / ACME validation).
   - `443/TCP` (HTTPS for web traffic and Meta WhatsApp Webhooks).
   - `22/TCP` (SSH for remote administration).

---

## 🛠️ Step 1: Install Docker & Docker Compose

Connect to your server via SSH and run:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl ufw docker.io docker-compose-plugin

# Start and enable Docker
sudo systemctl enable --now docker

# Configure basic firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## 📦 Step 2: Configure Docker Compose for N8N

Create the working directory:

```bash
mkdir -p ~/n8n-commerce && cd ~/n8n-commerce
```

Create `docker-compose.yml`:

```bash
nano docker-compose.yml
```

Paste the following configuration (replace `n8n.yourdomain.com` with your real subdomain):

```yaml
version: '3.8'

services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n_commerce
    restart: always
    ports:
      # Exposed locally only for the reverse proxy
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_HOST=n8n.yourdomain.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://n8n.yourdomain.com/
      - GENERIC_TIMEZONE=America/Bogota
      - TZ=America/Bogota
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168 # 7 days retention
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
    name: n8n_commerce_data
```

### Critical Environment Variables Explained

| Variable | Recommended Value | Purpose |
|---|---|---|
| `WEBHOOK_URL` | `https://n8n.yourdomain.com/` | **Mandatory:** n8n prefixes all webhook endpoints with this public URL so Meta WhatsApp Cloud API can deliver events. |
| `N8N_PROTOCOL` | `https` | Enforces HTTPS operation. |
| `GENERIC_TIMEZONE` | `America/Bogota` (or your local timezone) | Ensures the daily reports cron (Flow 3) and appointment slots (Flow 4) adhere to your local time. |
| `EXECUTIONS_DATA_PRUNE` | `true` | Prevents disk overflow by automatically pruning old workflow executions. |

---

## 🔒 Step 3: Configure Reverse Proxy with SSL (HTTPS)

Meta strictly requires HTTPS with valid TLS certificates (no self-signed certs). Choose one of the following options:

### Option A: Caddy Server (Recommended — Automatic SSL in 3 Lines)

Caddy automatically provisions and renews Let's Encrypt certificates with zero maintenance.

1. **Install Caddy**:
   ```bash
   sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
   curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
   curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
   sudo apt update && sudo apt install -y caddy
   ```

2. **Edit `/etc/caddy/Caddyfile`**:
   ```bash
   sudo nano /etc/caddy/Caddyfile
   ```
   Replace the entire content with:
   ```caddy
   n8n.yourdomain.com {
       reverse_proxy 127.0.0.1:5678
   }
   ```

3. **Restart Caddy**:
   ```bash
   sudo systemctl restart caddy
   sudo systemctl enable caddy
   ```

---

### Option B: Nginx + Certbot

1. **Install Nginx & Certbot**:
   ```bash
   sudo apt install -y nginx certbot python3-certbot-nginx
   ```

2. **Create Site Configuration**:
   ```bash
   sudo nano /etc/nginx/sites-available/n8n
   ```
   Content:
   ```nginx
   server {
       listen 80;
       server_name n8n.yourdomain.com;

       location / {
           proxy_pass http://127.0.0.1:5678;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
           proxy_buffering off;
           proxy_cache off;
       }
   }
   ```

3. **Enable Site & Generate SSL Certificate**:
   ```bash
   sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl restart nginx
   sudo certbot --nginx -d n8n.yourdomain.com
   ```

---

## 🚀 Step 4: Start N8N

From `~/n8n-commerce`:

```bash
docker compose up -d
docker compose logs -f
```

Open `https://n8n.yourdomain.com` in your browser and complete the initial administrator setup.

---

## 🗄️ Step 5: Database Setup & Tenant Creation (Supabase)

### 1. Execute Database Schema
1. Open the **SQL Editor** in your Supabase project dashboard.
2. Execute the entire content of [`supabase_setup.sql`](../supabase_setup.sql).

### 2. Retrieve Credentials from Meta for Developers
Log in to [Meta for Developers](https://developers.facebook.com/) and open your WhatsApp Business App:
* **Phone Number ID**: Go to **WhatsApp > API Setup** and copy the 15-16 digit **Phone number ID** (e.g., `10023456789`).
* **Access Token**: Copy the temporary token or create a permanent **System User Token** in Meta Business Manager with `whatsapp_business_messaging` permissions.
* **Verify Token**: Choose any custom secret string (e.g., `ThisIsMyToken.1` or `MySecretToken2026`).

### 3. Insert Your Business Tenant in Supabase
Run this query in Supabase SQL Editor (replace the values with your actual data):

```sql
INSERT INTO public.tenants (
    name,
    number,
    email,
    whatsapp_phone_number_id,
    whatsapp_access_token,
    whatsapp_verify_token,
    require_delivery_address,
    enable_sales,
    enable_crud,
    enable_reports,
    enable_appointments
) VALUES (
    'My WhatsApp Store',                -- Business Name
    '573001234567',                     -- Admin WhatsApp Number (country code + number)
    'admin@mybusiness.com',             -- Admin Email
    '10023456789',                      -- Meta WhatsApp Phone Number ID
    'EAAG_YOUR_META_ACCESS_TOKEN...',   -- Meta Access Token
    'ThisIsMyToken.1',                  -- Meta Webhook Verify Token
    true,                               -- Require physical delivery address on checkout
    true,                               -- Enable Sales subflow
    true,                               -- Enable Catalog CRUD subflow
    true,                               -- Enable Automated Reports subflow
    true                                -- Enable Appointment Booking subflow
)
ON CONFLICT (whatsapp_phone_number_id) DO UPDATE SET
    name = EXCLUDED.name,
    number = EXCLUDED.number,
    whatsapp_access_token = EXCLUDED.whatsapp_access_token,
    whatsapp_verify_token = EXCLUDED.whatsapp_verify_token;
```

---

## 🔑 Step 6: Configure Global Credentials in N8N

In n8n (`Settings > Credentials`), add the following two global credentials:

### 1. Supabase API (`supabaseApi`)
- **Host / URL**: `https://<YOUR_PROJECT_ID>.supabase.co`
- **Service Role Secret**: Your Supabase `service_role` key (**Project Settings > API > service_role key**).
  > ⚠️ **Important**: Use the `service_role` secret key, not the public `anon` key, as workflows require administrative access to execute atomic RPC functions and bypass RLS constraints securely.

### 2. NVIDIA Nemotron API (`nvidiaApi`) (or your LLM provider)
- **API Key**: Your NVIDIA API Key (`nvapi-...`).
- **Model**: `NVIDIA Nemotron Chat Model` (or any OpenAI-compatible provider).

---

## 📲 Step 7: Meta WhatsApp Webhook Configuration & Verification

> [!IMPORTANT]
> **Production Webhook URL vs Test URL:**
> - Never use the `/webhook-test/...` URL in Meta Developers. Test URLs only listen for a single manual click inside the n8n UI and will cause Meta's verification challenge to fail with `404 Not Found`.
> - The **Flujo 0 - Orquestador WhatsApp** workflow MUST be set to **Active = ON** (top-right toggle in n8n) before verifying in Meta.

1. Go to [Meta for Developers](https://developers.facebook.com/) > **WhatsApp > Configuration**.
2. Under the **Webhook** section, click **Edit**:
   - **Callback URL**:
     ```
     https://n8n.yourdomain.com/webhook/whatsapp
     ```
     *(Or your active ngrok tunnel URL: `https://<your-subdomain>.ngrok-free.app/webhook/whatsapp`)*
   - **Verify Token**:
     ```
     ThisIsMyToken.1
     ```
     *(Must match the `whatsapp_verify_token` entered in the `public.tenants` table).*
3. Click **Verify and Save**. N8N will immediately respond with the `hub.challenge` string and status `200 OK`.
4. Under **Webhook fields**, click **Manage** and subscribe to the `messages` event.

---

## 📥 Step 8: Import and Activate Workflows

Import all 5 JSON workflow files into N8N in order:

1. `flujo0_orquestador_whatsapp.json` (**Activate — Webhook trigger enabled**)
2. `flujo1_ventas_estados.json` (**Activate**)
3. `flujo2_crud_productos.json` (**Activate**)
4. `flujo3_reportes_automatizados.json` (**Activate — Daily 6:00 PM Cron enabled**)
5. `flujo4_agendamiento_citas.json` (**Activate**)

---

## 🔄 Step 9: Maintenance & Operations

### View Real-Time Logs
```bash
docker compose logs -f n8n
```

### Restart Service
```bash
docker compose restart
```

### Update N8N to Latest Release
```bash
cd ~/n8n-commerce
docker compose pull
docker compose up -d
```

### Backup N8N Data Volume
```bash
docker run --rm -v n8n_commerce_data:/data -v $(pwd):/backup ubuntu tar czvf /backup/n8n_backup_$(date +%Y%m%d).tar.gz /data
```
