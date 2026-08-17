# 💬 Usage Examples & Test Payloads — Interaction Guide

This document gathers comprehensive conversational interaction examples for both **Clients** (`ROLE: CLIENT`) and **Business Owners / Admins** (`ROLE: BUSINESS/TENANT`), as well as test payloads for Postman, Insomnia, cURL, or n8n manual triggers.

---

## 👥 System Roles

The Master Orchestrator (`flow0_whatsapp_orchestrator.json`) automatically classifies incoming users by comparing the sender number with the `number` column in the `public.tenants` table:

1. **`ROLE: BUSINESS` (Owner / Admin)**: Access to administrative commands, tasks dashboard, catalog CRUD, payment approvals/rejections, financial reports, and appointment management.
2. **`ROLE: CLIENT` (Customer)**: Access to conversational e-commerce purchasing, dynamic product catalogs, checkout, and appointment booking.

---

## 🛠️ 1. Available Business Owner Commands (Admin Chat)

When the business owner messages the bot from their registered WhatsApp number (`tenants.number`):

| Category | Example Command | Accepted Variations | Executed Action |
|---|---|---|---|
| **Menu & Help** | `ayuda` / `help` | `menu`, `commands`, `options` | Dynamically displays active modules based on tenant configuration flags. |
| **Tasks Dashboard** | `tareas` / `tasks` | `pendientes`, `dashboard`, `summary` | Retrieves payments pending validation, appointments scheduled today, and critical stock alerts (< 5 units). |
| **Payment Approval** | `aprobar 573001234567` | `aprobar pago 573001234567`, `approve` | Executes the atomic RPC `confirm_payment_and_deduct_stock`, deducts inventory atomically, and notifies the client. |
| **Payment Rejection** | `rechazar 573001234567 foto borrosa` | `rechazar 573001234567 comprobante ilegible` | Notifies the client with the rejection reason and prompts them to re-upload evidence. |
| **Shipments / Dispatch** | `despachos` / `orders` | `entregas`, `pedidos`, `envios` | Lists confirmed paid orders (`payment_confirmed`) with items, quantities, and delivery addresses. |
| **Mark Dispatched** | `despachar a1b2c3d4` | `enviar pedido a1b2c3d4` | Updates session status to `dispatched` and sends dispatch notification to customer. |
| **Live Chat Handover** | `pausar bot 573001234567` | `atender 573001234567`, `pause bot` | Pauses bot responses for that specific client to allow human staff intervention. |
| **Resume Bot** | `activar bot 573001234567` | `reanudar 573001234567`, `resume bot` | Resumes automated bot handling for the client. |
| **View Catalog** | `ver inventario` / `inventory` | `catalogo`, `productos`, `stock` | Lists active products, current stock, and unit prices. |
| **Create Product** | `crear producto Camisa Blanca precio 420 stock 15` | `agregar producto Zapato Negro precio 800 stock 10` | Inserts a new product in `public.products` associated with `tenant_id`. |
| **Add Stock** | `agregar stock 10 a Camisa` | `sumar 5 stock a Camisa Azul`, `+10 stock Camisa` | Calls RPC `adjust_product_stock(tenant_id, 'Camisa', 10)`. |
| **Deduct Stock** | `restar stock 3 a Zapatos` | `quitar stock 2 a Zapatos`, `-3 stock Zapatos` | Calls RPC `adjust_product_stock(tenant_id, 'Zapatos', -3)`. |
| **Update Price** | `cambiar precio de Pantalon a 450` | `actualizar precio Pantalon 450` | Modifies the unit price in the database. |
| **Financial Report** | `generar reporte` / `report` | `reporte`, `daily report`, `metrics` | Compiles revenue metrics, confirmed sales count, and active orders. |
| **View Appointments** | `ver citas` / `appointments` | `mis citas`, `agenda hoy`, `today's appointments` | Lists scheduled appointments for today. |

---

## 🛒 2. Customer Conversational Purchase Flow with Cart & Interactive Buttons

```text
[Client]       Hello, do you have blue shirts available?
[Bot]          Hello Juan! 👋 Yes, we have:
               📦 *Blue Long Sleeve Shirt*
               📝 100% cotton formal shirt, standard fit.
               💰 Price: $350.00 COP
               📊 In stock: 25 units

               Would you like to add it to your cart?
               🔘 [🛒 Add to Cart]  🔘 [🔄 View Others]  🔘 [❌ Cancel]

[Client]       [Taps '🛒 Add to Cart']
[Bot]          ✅ *Blue Long Sleeve Shirt added to your cart!* 🛒
               💰 Current subtotal: $350.00 COP

               💳 How would you like to pay or do you want to explore more?
               🔘 [📱 Transfer/Nequi]  🔘 [💵 Cash on Delivery]  🔘 [🛍️ Buy More]

[Client]       [Taps '📱 Transfer/Nequi']
[Bot]          📍 Please enter your *full delivery address* or share your location 📌 in this chat.

[Client]       123 Main St, Apt 402, Bogota
[Bot]          Awesome! To complete your order, please transfer *$350.00 COP* to:
               🏦 *Bancolombia Savings:* 123-456789-01
               📱 *Nequi / Daviplata:* 3001234567
               📸 Please send a photo or screenshot of your payment receipt in this chat.

[Client]       [Uploads image receipt]
[Bot]          Receipt received successfully! 📨 Our team is verifying the payment. You will receive shipping details upon confirmation. Thank you!

--- NOTIFICATION TO BUSINESS OWNER (ADMIN) ---
[Bot -> Owner] 📲 *NEW PAYMENT EVIDENCE RECEIVED*
               👤 *Customer:* Juan (573001234567)
               📦 *Product:* Blue Long Sleeve Shirt - $350.00
               💳 *Payment Method:* Transfer/Nequi
               🏠 *Address:* 123 Main St, Apt 402, Bogota
               📸 *Evidence:* https://example.com/comprobante.jpg
               🆔 *Session ID:* `a1b2c3d4-0000-0000-0000-000000000000`

               👇 *Tap a button to approve or reject:*
               🔘 [✅ Approve Payment]  🔘 [❌ Reject Payment]

[Owner]        [Taps '✅ Approve Payment']
[Bot -> Client] ✅ *Your payment has been confirmed!* 🎉
                We are preparing your order for shipping. You will receive your tracking number shortly!
                🔘 [🛍️ Buy More]  🔘 [🏠 Main Menu]
```

---

### 2.1. Stock Issue & Live Agent Handover Scenario

```text
[Bot -> Owner]  📲 *NEW PAYMENT EVIDENCE RECEIVED*
                👤 *Customer:* Juan (573001234567)
                📦 *ORDERED ITEMS:*
                 • 3x Blue Long Sleeve Shirt ($350.00 each) = $1,050.00
                💰 *TOTAL TO VALIDATE:* $1,050.00 COP
                🆔 *Session ID:* `a1b2c3d4-0000-0000-0000-000000000000`

                👇 *Tap a button to authorize, reject, or chat with customer:*
                🔘 [✅ Approve Payment]  🔘 [❌ Reject Payment]  🔘 [💬 Chat Customer]

[Owner]         [Taps '💬 Chat Customer' (or types 'pausar bot 573001234567')]

[Bot -> Owner]  ⏸️ *LIVE HUMAN HANDOVER ACTIVATED (BOT PAUSED)*
                👤 *Customer:* Juan (573001234567)
                💬 *1-Click Direct WhatsApp link:*
                👉 https://wa.me/573001234567?text=Hello%20Juan,%20reaching%20out%20about%20your%20order
                
                ℹ️ The bot will stay silent for this customer while you coordinate the substitution.
                
                👇 *Once resolved:*
                🔘 [✅ Approve Payment]  🔘 [▶️ Resume Bot]

[Bot -> Client] 🧑‍💼 *A customer support representative will assist you in this chat shortly.*
```

---

## 📅 3. Appointment Booking Flow with Google Calendar (Client)

```text
[Client]       Hello, I want to book an appointment for tomorrow at 3pm
[Bot]          📅 *APPOINTMENT CONFIRMED*

               👤 *Commercial Consultation*

               🗓️ Monday, August 17, 2026
               ⏰ 03:00 PM

               📲 *Add to Google Calendar:*
               https://calendar.google.com/calendar/render?action=TEMPLATE&text=Commercial+Consultation...

               _Appointment ID: c7f1e92a-1111-2222-3333-444455556666_

               🔘 [📅 My Appointments]  🔘 [🛍️ View Catalog]  🔘 [🏠 Main Menu]
```

---

## 🧪 4. Manual Webhook Simulation Payloads

You can send these payloads using **cURL**, **Postman**, or **Insomnia** to test your n8n webhook endpoint:

### 1. Meta Webhook GET Verification (Challenge Handshake)

```bash
curl -X GET "https://n8n.yourdomain.com/webhook/whatsapp?hub.mode=subscribe&hub.verify_token=MY_VERIFY_TOKEN&hub.challenge=89327498"
```
* **Expected Response:** HTTP Status `200 OK` with raw text body `89327498`.

---

### 2. Client Inbound Message Searching for a Product (POST)

```bash
curl -X POST "https://n8n.yourdomain.com/webhook/whatsapp" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "whatsapp_business_account",
    "entry": [{
      "changes": [{
        "value": {
          "metadata": { "phone_number_id": "10023456789" },
          "contacts": [{ "profile": { "name": "Carlos Mendoza" }, "wa_id": "573001234567" }],
          "messages": [{
            "from": "573001234567",
            "text": { "body": "hello, looking for a blue shirt" },
            "type": "text"
          }]
        }
      }]
    }]
  }'
```

---

### 3. Business Owner Requesting Tasks Dashboard (POST)

```bash
curl -X POST "https://n8n.yourdomain.com/webhook/whatsapp" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "whatsapp_business_account",
    "entry": [{
      "changes": [{
        "value": {
          "metadata": { "phone_number_id": "10023456789" },
          "messages": [{
            "from": "521234567890",
            "text": { "body": "tareas" },
            "type": "text"
          }]
        }
      }]
    }]
  }'
```

---

### 4. Business Owner Approving a Payment (POST)

```bash
curl -X POST "https://n8n.yourdomain.com/webhook/whatsapp" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "whatsapp_business_account",
    "entry": [{
      "changes": [{
        "value": {
          "metadata": { "phone_number_id": "10023456789" },
          "messages": [{
            "from": "521234567890",
            "text": { "body": "aprobar 573001234567" },
            "type": "text"
          }]
        }
      }]
    }]
  }'
```
