# 🛍️ Sistema de Comercio Conversacional Multi-Tenant
### N8N + Supabase (PostgreSQL) + Meta WhatsApp Cloud API + LangChain

> Sistema completo de comercio conversacional, ventas con máquina de estados, control de inventario con descuento atómico de stock, agendamiento de citas sin overbooking y reportes financieros automatizados a través de WhatsApp.

---

## 🗺️ Mapa de la Documentación

Toda la documentación técnica del proyecto ha sido modularizada para facilitar su lectura y mantenimiento:

| Documento | Descripción y Contenido |
|---|---|
| 📖 [**Guía de Despliegue en Producción**](docs/despliegue_produccion.md) | Despliegue en Linux/VPS con Docker Compose, Reverse Proxy Caddy / Nginx con SSL Let's Encrypt automático, configuración de Webhook en Meta for Developers y variables de entorno. |
| 💬 [**Ejemplos de Uso y Payloads de Prueba**](docs/ejemplos_uso.md) | Tabla completa de comandos para el negocio (`ROLE: BUSINESS`), ejemplos de diálogo con clientes (`ROLE: CLIENT`), y payloads JSON/cURL para simular Webhooks en Postman o n8n. |
| 🗄️ [**Queries SQL para Pruebas y Seed Data**](docs/queries_pruebas.md) | Scripts SQL listos para Supabase: inserción de tenants de prueba, catálogo, clientes, sesiones en los 7 estados, pruebas directas de funciones RPC y queries de diagnóstico. |
| 🏗️ [**Arquitectura Técnica y Flujos**](docs/arquitectura_flujos.md) | Diagramas de flujo, máquina de estados de ventas, lógica del clasificador IA LangChain, modelo de datos multi-tenant y políticas de seguridad RLS. |
| ⚡ [**Script SQL de Setup Supabase**](supabase_setup.sql) | DDL completo de base de datos: tablas `tenants`, `clients`, `products`, `sessions`, `appointments`, triggers y funciones RPC transaccionales. |

---

## 📁 Estructura del Repositorio

```
n8n-commerce-flows/
├── flujo0_orquestador_whatsapp.json    # 🔀 Orquestador Principal (Multi-Tenant, Roles, Meta Webhook)
├── flujo1_ventas_estados.json          # 💰 Máquina de Estados de Ventas + Descuento Atómico de Stock
├── flujo2_crud_productos.json          # 📦 CRUD de Catálogo + Stock Relativo (+/-) + Precios
├── flujo3_reportes_automatizados.json  # 📊 Reportes Automatizados (Cron Diario 6PM + On-Demand)
├── flujo4_agendamiento_citas.json      # 📅 Agendamiento de Citas + Prevención Overbooking (±29 min)
├── supabase_setup.sql                  # 🗄️ Script SQL DDL de Setup Supabase (RLS, Triggers, RPCs)
├── README.md                           # 📖 Hub Central del Proyecto
└── docs/                               # 📚 Documentación Técnica Detallada
    ├── despliegue_produccion.md        # 🌐 Despliegue en Servidor VPS / Docker / SSL
    ├── ejemplos_uso.md                 # 💬 Comandos de WhatsApp y Payloads de Prueba
    ├── queries_pruebas.md              # 🗄️ Scripts SQL para Testing y Seed Data
    └── arquitectura_flujos.md          # 🏗️ Diagramas y Arquitectura de Software
```

---

## ⚡ Inicio Rápido en Entorno Local (Desarrollo)

Para probar los flujos localmente con la API de WhatsApp de Meta, requieres un túnel público seguro HTTPS:

### 1. Iniciar Túnel Ngrok
```bash
ngrok http 5678
```
> Copia la URL HTTPS generada (ejemplo: `https://tu-subdominio.ngrok-free.dev`).

### 2. Iniciar N8N con la URL del Webhook
En una segunda terminal:
```bash
export WEBHOOK_URL="https://tu-subdominio.ngrok-free.dev" && npx n8n start
```

### 3. Configurar Base de Datos Supabase
1. Abre el **SQL Editor** en tu proyecto de Supabase.
2. Ejecuta el archivo [`supabase_setup.sql`](supabase_setup.sql).
3. Inserta tu negocio y credenciales de Meta siguiendo la [Guía de Queries de Prueba](docs/queries_pruebas.md#1-creación-de-negocios-de-prueba-tenants).

### 4. Importar y Conectar Credenciales en N8N
Abre `http://localhost:5678`, crea tus credenciales globales de **Supabase API** (`service_role`) y **OpenAI API** (OpenRouter) e importa los 5 flujos JSON.

> ⚠️ **Checklist de Datos Reales Antes de Probar:**  
> Consulta la [Guía de Checklist de Parámetros Reales](docs/despliegue_produccion.md#-checklist-de-parámetros-reales-antes-de-probar) para verificar los 4 puntos clave antes de tus pruebas:
> 1. Configurar tus tokens de Meta (`whatsapp_phone_number_id`, `whatsapp_access_token`, `whatsapp_verify_token`) y tu número en la tabla `public.tenants`.
> 2. Crear las credenciales de Supabase (`service_role`) y OpenRouter (`openAiApi`) en n8n.
> 3. Reemplazar el placeholder `YOUR_PROJECT_ID` en `flujo1_ventas_estados.json` por tu ID de Supabase.
> 4. Configurar el Webhook de Meta apuntando a tu URL de n8n.

---

## 🔀 Resumen de Módulos y Flujos

```
                                📱 Meta WhatsApp API
                                         │
                                         ▼
                     ┌───────────────────────────────────────┐
                     │     Flujo 0: Orquestador Principal    │
                     │    - Validación Webhook GET Challenge │
                     │    - Detección de Tenant y Roles      │
                     │    - Clasificador LangChain / IA      │
                     └───────────────────┬───────────────────┘
                                         │
                 ┌───────────────────────┼───────────────────────┐
                 ▼                       ▼                       ▼
      ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
      │  Flujo 1: Ventas    │ │  Flujo 2: Catálogo  │ │  Flujo 4: Citas     │
      │  - 7 Estados        │ │  - CRUD Productos   │ │  - Agenda Online    │
      │  - Pago + Dirección │ │  - Stock Relativo   │ │  - Anticolisión     │
      │  - RPC Descuento    │ │  - Actualizar Precio│ │    (±29 min)        │
      └─────────────────────┘ └─────────────────────┘ └─────────────────────┘
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │  Flujo 3: Reportes  │
                              │  - Cron Diario 6 PM │
                              │  - Reporte Financero│
                              └─────────────────────┘
```

---

## 🛠️ Comandos Rápidos del Negocio (Vía Chat de WhatsApp)

Los dueños de negocio pueden gestionar su tienda enviando estos mensajes desde su número registrado:

- `ayuda` / `menu` ➔ Menú interactivo con funciones habilitadas.
- `tareas` / `pendientes` ➔ Resumen de pagos por validar, citas del día y stock crítico.
- `aprobar <numero>` ➔ Confirma el pago y descuenta el stock de forma atómica en BD.
- `rechazar <numero> <motivo>` ➔ Notifica al cliente para que reenvíe el comprobante.
- `ver inventario` ➔ Lista el catálogo activo de productos.
- `crear producto <nombre> precio <X> stock <Y>` ➔ Añade un producto al catálogo.
- `agregar stock <N> a <producto>` ➔ Incrementa el stock disponible.
- `restar stock <N> a <producto>` ➔ Reduce el stock disponible.
- `cambiar precio de <producto> a <X>` ➔ Modifica el precio de venta.
- `generar reporte` ➔ Reporte financiero consolidado.
- `ver citas` ➔ Lista las citas programadas para el día de hoy.

*(Para ver la guía completa con ejemplos y respuestas del bot, consulta [docs/ejemplos_uso.md](docs/ejemplos_uso.md)).*

---

## 🤖 Guía de Contexto para Agentes de IA

Si eres un agente de IA interactuando con este repositorio:
- **Base de Datos**: Siempre consulta [`docs/queries_pruebas.md`](docs/queries_pruebas.md) y [`supabase_setup.sql`](supabase_setup.sql) antes de modificar o crear consultas a Supabase.
- **Flujos N8N**: Los flujos se comunican a través de nodos de ejecución de sub-workflow y llamadas RPC. Revisa [`docs/arquitectura_flujos.md`](docs/arquitectura_flujos.md) para conocer la máquina de estados.
- **Despliegue**: Para cambios en contenedores o infraestructura, revisa [`docs/despliegue_produccion.md`](docs/despliegue_produccion.md).
