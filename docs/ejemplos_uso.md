# 💬 Ejemplos de Uso y Payloads de Prueba — Guía de Interacción

Este documento reúne todos los ejemplos de interacción conversacional del sistema tanto para **Clientes** (`ROLE: CLIENT`) como para los **Dueños/Administradores de Negocio** (`ROLE: BUSINESS/TENANT`), así como payloads para pruebas en Postman, cURL o triggers de n8n.

---

## 👥 Roles del Sistema

El orquestador (`flujo0_orquestador_whatsapp.json`) clasifica automáticamente al usuario entrante comparando el número emisor con el campo `number` en la tabla `public.tenants`:

1. **`ROLE: BUSINESS` (Dueño/Admin)**: Acceso a comandos administrativos, dashboard de tareas, CRUD de catálogo, aprobación de pagos, generación de reportes y gestión de agenda.
2. **`ROLE: CLIENT` (Cliente)**: Acceso al flujo de compras conversacional, catálogo público, cotizaciones y agendamiento de citas.

---

## 🛠️ 1. Comandos Disponibles para el Negocio (Admin Chat)

Cuando el dueño del negocio escribe desde su WhatsApp registrado en `tenants.number`:

| Categoría | Comando de Ejemplo | Variaciones Aceptadas | Acción Ejecutada |
|---|---|---|---|
| **Menú y Ayuda** | `ayuda` | `menu`, `comandos`, `opciones` | Despliega dinámicamente las funciones activadas en los flags del tenant. |
| **Dashboard de Tareas** | `tareas` | `pendientes`, `dashboard`, `resumen` | Consulta pagos por verificar, citas del día y alertas de stock crítico (< 5 unidades). |
| **Aprobación de Pago** | `aprobar 573001234567` | `aprobar pago 573001234567` | Ejecuta la RPC `confirm_payment_and_deduct_stock`, descuenta stock atómicamente y notifica al cliente. |
| **Rechazo de Pago** | `rechazar 573001234567 foto borrosa` | `rechazar 573001234567 comprobante ilegible` | Notifica al cliente el motivo del rechazo para que vuelva a adjuntar comprobante. |
| **Despachos y Envíos** | `despachos` | `entregas`, `pedidos`, `envios` | Lista pedidos pagados (`payment_confirmed`) con sus productos, cantidades y dirección de entrega. |
| **Marcar Despachado** | `despachar a1b2c3d4` | `enviar pedido a1b2c3d4` | Actualiza estado a `dispatched` y notifica al cliente que su pedido va en camino. |
| **Live Chat Handover** | `pausar bot 573001234567` | `atender 573001234567` | Pausa el bot para ese cliente permitiendo atención humana directa sin interferencias. |
| **Reactivar Bot** | `activar bot 573001234567` | `reanudar 573001234567` | Reactiva las respuestas automáticas del bot para el cliente. |
| **Ver Inventario** | `ver inventario` | `catalogo`, `productos`, `stock` | Lista los productos activos, stock y precios del negocio. |
| **Crear Producto** | `crear producto Camisa Blanca precio 420 stock 15` | `agregar producto Zapato Negro precio 800 stock 10` | Inserta un nuevo producto en `public.products` vinculado al `tenant_id`. |
| **Sumar Stock** | `agregar stock 10 a Camisa` | `sumar 5 stock a Camisa Azul`, `+10 stock Camisa` | Ejecuta `adjust_product_stock(tenant_id, 'Camisa', 10)`. |
| **Restar Stock** | `restar stock 3 a Zapatos` | `quitar stock 2 a Zapatos`, `-3 stock Zapatos` | Ejecuta `adjust_product_stock(tenant_id, 'Zapatos', -3)`. |
| **Cambiar Precio** | `cambiar precio de Pantalón a 450` | `actualizar precio Pantalón 450` | Modifica el precio unitario del producto en base de datos. |
| **Reporte Financiero** | `generar reporte` | `reporte`, `informe diario`, `metricas` | Genera balance de ventas confirmadas, ingresos totales y productos más vendidos. |
| **Agenda de Citas** | `ver citas` | `mis citas`, `agenda hoy`, `citas de hoy` | Consulta y lista las citas agendadas para el día actual. |

---

## 🛒 2. Flujo Conversacional de Compra con Carrito y Botones (Cliente)

A continuación se muestra una interacción moderna utilizando **botones interactivos de WhatsApp**:

```
[Cliente]  Hola, buenas tardes. ¿Tienen camisas azules?
[Bot]      ¡Hola Juan! 👋 Sí, tenemos disponible:
           📦 *Camisa Azul Manga Larga*
           📝 Camisa formal de algodón 100%, talla estándar.
           💰 Precio: $350.00 COP
           📊 Stock disponible: 25 unidades

           ¿Deseas agregarlo a tu carrito?
           🔘 [🛒 Agregar al Carrito]  🔘 [🔄 Ver Otros]  🔘 [❌ Cancelar]

[Cliente]  [Toca '🛒 Agregar al Carrito']
[Bot]      ✅ *¡Camisa Azul Manga Larga añadida a tu carrito!* 🛒
           💰 Subtotal actual: $350.00 COP

           💳 ¿Cómo deseas pagar o prefieres explorar más productos?
           🔘 [📱 Transferencia/Nequi]  🔘 [💵 Contra Entrega]  🔘 [🛍️ Comprar Algo Más]

[Cliente]  [Toca '📱 Transferencia/Nequi']
[Bot]      📍 Por favor ingresa tu *dirección de entrega completa* o comparte tu ubicación 📌 por este chat para coordinar el envío.

[Cliente]  Calle 100 # 15-20, Apto 402, Bogotá
[Bot]      ¡Perfecto! Para proceder con tu pedido, realiza la transferencia por *$350.00 COP* a la siguiente cuenta:
           🏦 *Bancolombia Ahorros:* 123-456789-01
           📱 *Nequi / Daviplata:* 3001234567
           📸 Por favor adjunta una foto o captura de tu comprobante de pago por este chat.

[Cliente]  [Envía imagen de comprobante]
[Bot]      ¡Comprobante recibido con éxito! 📨 Nuestro equipo está verificando el pago. En cuanto sea confirmado, te enviaremos la guía de despacho. ¡Gracias por tu compra!

--- NOTIFICACIÓN AL NEGOCIO (ADMIN) ---
[Bot -> Dueño]  📲 *NUEVA EVIDENCIA DE PAGO RECIBIDA*
                👤 *Cliente:* Juan (573001234567)
                📦 *Producto:* Camisa Azul Manga Larga - $350.00
                💳 *Método de Pago:* Transferencia/Nequi
                🏠 *Dirección:* Calle 100 # 15-20, Apto 402, Bogotá
                📸 *Evidencia:* https://example.com/comprobante.jpg
                🆔 *ID de Sesión:* `a1b2c3d4-0000-0000-0000-000000000000`

                👇 *Toca un botón para autorizar o rechazar:*
                🔘 [✅ Aprobar Pago]  🔘 [❌ Rechazar Pago]

[Dueño]        [Toca '✅ Aprobar Pago']
[Bot -> Cliente] ✅ *¡Tu pago ha sido confirmado con éxito!* 🎉
                 Estamos preparando tu pedido para despacho. Te enviaremos la guía en cuanto sea entregado a la transportadora. ¡Gracias por tu compra!
                 🔘 [🛍️ Comprar Más]  🔘 [🏠 Menú Principal]
```

---

### 2.1. Escenario de Incidencia: Falta de Stock, Ajuste de Productos y Handover Humano

Si el negocio identifica que no tiene stock suficiente para completar las cantidades solicitadas o necesita acordar una sustitución con el cliente:

```text
[Bot -> Dueño]  📲 *NUEVA EVIDENCIA DE PAGO RECIBIDA*
                👤 *Cliente:* Juan (573001234567)
                📦 *PRODUCTOS COMPRADOS:*
                 • 3x Camisa Azul Manga Larga ($350.00 c/u) = $1,050.00
                💰 *TOTAL A VALIDAR:* $1,050.00 COP
                🆔 *ID de Sesión:* `a1b2c3d4-0000-0000-0000-000000000000`

                👇 *Toca un botón para autorizar, rechazar o chatear:*
                🔘 [✅ Aprobar Pago]  🔘 [❌ Rechazar Pago]  🔘 [💬 Chatear Cliente]

[Dueño]        [Toca '💬 Chatear Cliente' (o escribe 'pausar bot 573001234567')]

[Bot -> Dueño]  ⏸️ *MODO ATENCIÓN HUMANA ACTIVADO (BOT PAUSADO)*
                👤 *Cliente:* Juan (573001234567)
                💬 *Enlace directo al chat con 1 clic:*
                👉 https://wa.me/573001234567?text=Hola%20Juan,%20te%20escribo%20respecto%20a%20tu%20pedido
                
                ℹ️ El bot permanecerá en silencio para este cliente mientras acuerdan el cambio de producto o la cantidad.
                
                👇 *Una vez resuelto el acuerdo:*
                🔘 [✅ Aprobar Pago]  🔘 [▶️ Reactivar Bot]

[Bot -> Cliente] 🧑‍💼 *Un asesor de nuestro equipo se pondrá en contacto contigo en este momento por este chat para coordinar los detalles de tu pedido.*

--- EL DUEÑO Y EL CLIENTE CONVERSAN DIRECTAMENTE POR WHATSAPP ---
[Dueño a Juan]: "Hola Juan, de la camisa azul solo nos quedan 2 unidades, ¿te enviamos 2 azules y 1 blanca o prefieres el ajuste?"
[Juan a Dueño]: "Perfecto, envíame 2 azules y 1 blanca por favor."

--- CIERRE DE LA INCIDENCIA POR EL DUEÑO ---
[Dueño al Bot]  [Toca '✅ Aprobar Pago' o escribe 'activar bot 573001234567']

[Bot -> Cliente] ✅ *¡Tu pedido ha sido confirmado y procesado con éxito!* 🎉
                 Estamos preparando tus productos para despacho. Te enviaremos la guía de envío en breve.
```

---

## 📅 3. Flujo Conversacional de Agendamiento de Citas con Google Calendar (Cliente)

```
[Cliente]  Hola, quiero agendar una cita para mañana a las 3pm
[Bot]      📅 *CITA CONFIRMADA EXITOSAMENTE*

           👤 *Asesoría comercial personalizada*

           🗓️ lunes, 17 de agosto de 2026
           ⏰ 03:00 PM

           📲 *Añadir a Google Calendar:*
           https://calendar.google.com/calendar/render?action=TEMPLATE&text=Asesoria+comercial...

           _ID de Cita: c7f1e92a-1111-2222-3333-444455556666_

           🔘 [📅 Mis Citas]  🔘 [🛍️ Ver Catálogo]  🔘 [🏠 Menú Principal]
```

---

## 🧪 4. Payloads de Prueba Manual (Simulación de Webhook)

Puedes enviar estos payloads mediante **Postman**, **Insomnia**, **cURL** o el botón **Test step** en n8n hacia tu URL de webhook (`POST http://localhost:5678/webhook/whatsapp` o `https://n8n.tudominio.com/webhook/whatsapp`).

### 1. Verificación GET de Webhook Meta (Handshake Inicial)

```bash
curl -X GET "https://n8n.tudominio.com/webhook/whatsapp?hub.mode=subscribe&hub.verify_token=MY_VERIFY_TOKEN&hub.challenge=89327498"
```
- **Respuesta HTTP esperada:** Status `200 OK` con cuerpo plano `89327498`.

---

### 2. Mensaje de Cliente buscando un producto (POST)

```bash
curl -X POST "https://n8n.tudominio.com/webhook/whatsapp" \
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
            "text": { "body": "hola, busco camisa azul" },
            "type": "text"
          }]
        }
      }]
    }]
  }'
```

---

### 3. Cliente enviando Comprobante de Pago (Imagen) (POST)

```bash
curl -X POST "https://n8n.tudominio.com/webhook/whatsapp" \
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
            "type": "image",
            "image": {
              "id": "media_img_12345678",
              "mime_type": "image/jpeg",
              "sha256": "abcdef1234567890",
              "link": "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c"
            }
          }]
        }
      }]
    }]
  }'
```

---

### 4. Dueño solicitando el Dashboard de Tareas (POST)

```bash
curl -X POST "https://n8n.tudominio.com/webhook/whatsapp" \
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

### 5. Dueño aprobando el pago de una venta (POST)

```bash
curl -X POST "https://n8n.tudominio.com/webhook/whatsapp" \
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

---

### 6. Dueño sumando stock a un producto (POST)

```bash
curl -X POST "https://n8n.tudominio.com/webhook/whatsapp" \
  -H "Content-Type: application/json" \
  -d '{
    "object": "whatsapp_business_account",
    "entry": [{
      "changes": [{
        "value": {
          "metadata": { "phone_number_id": "10023456789" },
          "messages": [{
            "from": "521234567890",
            "text": { "body": "agregar stock 15 a camisa" },
            "type": "text"
          }]
        }
      }]
    }]
  }'
```
