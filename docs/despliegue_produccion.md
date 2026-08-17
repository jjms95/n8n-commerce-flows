# 🌐 Guía de Despliegue en Producción — N8N + Docker + SSL

Esta guía detalla el despliegue del **Sistema de Comercio Conversacional Multi-Tenant** en servidores Linux (Ubuntu/Debian, VPS en AWS EC2, DigitalOcean, Hetzner, etc.) para operación continua 24/7 con certificados SSL automáticos y persistencia de datos.

---

## 📋 Requisitos Previos

1. **Servidor VPS / Cloud**:
   - Ubuntu 22.04 LTS o Debian 12 (recomendado).
   - Mínimo 2 GB RAM (4 GB recomendado para flujos intensivos de LangChain).
   - 1 vCPU o más.
   - IP pública estática.
2. **Nombre de Dominio**:
   - Un dominio o subdominio (ej: `n8n.tudominio.com`) con registro **DNS tipo A** apuntando a la IP pública del servidor.
3. **Puertos Abiertos en Firewall**:
   - `80/TCP` (HTTP para validación Let's Encrypt / ACME).
   - `443/TCP` (HTTPS para tráfico web y webhooks de Meta).
   - `22/TCP` (SSH para administración).

---

## 🛠️ Paso 1: Instalación de Docker y Docker Compose

Conéctate por SSH a tu servidor y ejecuta:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl ufw docker.io docker-compose-plugin

# Iniciar y habilitar el servicio Docker
sudo systemctl enable --now docker

# Configurar firewall básico
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## 📦 Paso 2: Configuración de Docker Compose para N8N

Crea el directorio de trabajo para n8n:

```bash
mkdir -p ~/n8n-commerce && cd ~/n8n-commerce
```

Crea el archivo `docker-compose.yml`:

```bash
nano docker-compose.yml
```

Pega el siguiente contenido (reemplaza `n8n.tudominio.com` por tu subdominio real):

```yaml
version: '3.8'

services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: n8n_commerce
    restart: always
    ports:
      # Expone el puerto solo localmente para el reverse proxy
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_HOST=n8n.tudominio.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://n8n.tudominio.com/
      - GENERIC_TIMEZONE=America/Bogota
      - TZ=America/Bogota
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168 # 7 días de retención de historial
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
    name: n8n_commerce_data
```

### Explicación de Variables Críticas de Entorno

| Variable | Valor Recomendado | Motivo |
|---|---|---|
| `WEBHOOK_URL` | `https://n8n.tudominio.com/` | **Imprescindible:** n8n genera los endpoints de webhook con este prefijo público para que Meta WhatsApp API pueda alcanzarlos. |
| `N8N_PROTOCOL` | `https` | Obliga a n8n a operar bajo HTTPS. |
| `GENERIC_TIMEZONE` | `America/Bogota` (o tu zona horaria) | Asegura que el cron de reportes diarios (Flujo 3) y las citas (Flujo 4) respeten la hora local. |
| `EXECUTIONS_DATA_PRUNE` | `true` | Evita que la base interna de n8n crezca indefinidamente podando ejecuciones antiguas. |

---

## 🔒 Paso 3: Configuración del Reverse Proxy con SSL (HTTPS)

Meta exige conexiones HTTPS con certificados TLS válidos (no autofirmados). Elige una de las siguientes dos opciones:

### Opción A: Caddy Server (Recomendado — SSL Automático en 3 líneas)

Caddy gestiona automáticamente la obtención, instalación y renovación de certificados Let's Encrypt sin configuración adicional de cron ni certbot.

1. **Instalar Caddy**:
   ```bash
   sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
   curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
   curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
   sudo apt update && sudo apt install -y caddy
   ```

2. **Editar `/etc/caddy/Caddyfile`**:
   ```bash
   sudo nano /etc/caddy/Caddyfile
   ```
   Remplaza todo el contenido por:
   ```caddy
   n8n.tudominio.com {
       reverse_proxy 127.0.0.1:5678
   }
   ```

3. **Reiniciar Caddy**:
   ```bash
   sudo systemctl restart caddy
   sudo systemctl enable caddy
   ```

---

### Opción B: Nginx + Certbot

Si prefieres Nginx o ya tienes Nginx instalado en tu servidor:

1. **Instalar Nginx y Certbot**:
   ```bash
   sudo apt install -y nginx certbot python3-certbot-nginx
   ```

2. **Crear archivo de configuración del sitio**:
   ```bash
   sudo nano /etc/nginx/sites-available/n8n
   ```
   Contenido:
   ```nginx
   server {
       listen 80;
       server_name n8n.tudominio.com;

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

3. **Activar y generar certificado SSL**:
   ```bash
   sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl restart nginx
   sudo certbot --nginx -d n8n.tudominio.com
   ```

---

## 🚀 Paso 4: Iniciar el Servicio N8N

Desde el directorio `~/n8n-commerce`:

```bash
# Iniciar n8n en segundo plano
docker compose up -d

# Verificar estado del contenedor
docker compose ps

# Ver logs en tiempo real para verificar inicio correcto
docker compose logs -f
```

Una vez iniciado, abre `https://n8n.tudominio.com` en tu navegador y completa la creación del usuario administrador inicial de n8n.

---

## 🔑 Paso 5: Configuración de Credenciales en N8N

En el panel de N8N (`Settings > Credentials`), añade las siguientes dos credenciales globales:

### 1. Supabase API (`supabaseApi`)
- **Host / URL**: `https://<tu-proyecto>.supabase.co`
- **Service Role Secret**: Tu clave `service_role` de Supabase (**Project Settings > API > service_role key**).
  > ⚠️ **Importante**: Usa la clave `service_role`, no la clave `anon`, ya que los flujos requieren permisos administrativos y acceso a las RPCs protegidas por RLS.

### 2. NVIDIA Nemotron API (`nvidiaApi`)
- **API Key**: Tu clave de API de NVIDIA (`nvapi-...`).
- **Modelo**: NVIDIA Nemotron Chat Model configurado en el agente LangChain (o cualquier proveedor de LLM compatible en n8n).

---

## 📲 Paso 6: Configurar Webhook en Meta for Developers

1. Ingresa a [Meta for Developers](https://developers.facebook.com/) y selecciona tu aplicación de WhatsApp.
2. Ve a **WhatsApp > Configuración**.
3. En la sección **Webhook**:
   - **URL de devolución de llamada (Callback URL)**:
     ```
     https://n8n.tudominio.com/webhook/whatsapp
     ```
    - **Identificador de verificación (Verify Token)**:
      Debe coincidir exactamente con el campo `whatsapp_verify_token` configurado en la tabla `public.tenants` (ej: `MY_VERIFY_TOKEN`).
4. Haz clic en **Verificar y Guardar**. N8N responderá automáticamente al desafío `hub.challenge`.
5. En **Campos de webhook**, haz clic en **Administrar** y suscríbete al campo `messages`.

---

## 📥 Paso 7: Importación y Activación de Flujos

Importa los siguientes archivos JSON en N8N en orden:

1. `flujo0_orquestador_whatsapp.json` (**Activar** — Webhook Trigger activo)
2. `flujo1_ventas_estados.json` (**Activar**)
3. `flujo2_crud_productos.json` (**Activar**)
4. `flujo3_reportes_automatizados.json` (**Activar** — Cron Trigger activo a las 6:00 PM)
5. `flujo4_agendamiento_citas.json` (**Activar**)

> 💡 **Nota**: Verifica que en cada flujo los nodos que conectan con Supabase y OpenRouter tengan seleccionadas las credenciales creadas en el Paso 5.

---

## 📋 Checklist de Parámetros Reales Antes de Probar

Para poner a funcionar los flujos con tus cuentas reales, actualiza los siguientes 4 puntos:

### 1. En la Base de Datos (`public.tenants` en Supabase)
Inserta o actualiza tu registro de negocio con tus credenciales reales de Meta:
* `whatsapp_phone_number_id`: ID numérico de 15-16 dígitos de tu número en Meta WhatsApp Cloud API (**Meta Developer Portal > WhatsApp > API Setup**).
* `whatsapp_access_token`: Access Token permanente generado desde **Meta Business Manager > System Users** con permiso `whatsapp_business_messaging`.
* `whatsapp_verify_token`: Cadena secreta personalizada (ej. `MiClaveSecretaMeta2026`) que colocarás en la configuración del Webhook de Meta.
* `number`: Tu número personal o del administrador con código de país (ej. `573001234567`) para recibir alertas de ventas, citas y reportes.

### 2. En N8N (Credenciales Globales)
* **Supabase API (`supabaseApi`)**: URL de tu proyecto (`https://<TU_PROJECT_ID>.supabase.co`) y tu clave `service_role` (**Project Settings > API**).
* **OpenAI API (`openAiApi`)**: API Key de OpenRouter (`sk-or-v1-...`) y Base URL `https://openrouter.ai/api/v1`.

### 3. En los Nodos de Flujo 1 (Ventas)
* En [flujo1_ventas_estados.json](flujo1_ventas_estados.json), en los nodos HTTP que consultan Supabase (nodos *HTTP - Buscar Palabra Clave*, *HTTP - Obtener Producto*, *HTTP - Buscar Sesión* y *HTTP - Buscar Productos RPC*), reemplaza el placeholder `YOUR_PROJECT_ID` por tu subdominio real de Supabase.

### 4. En Meta for Developers (Configuración del Webhook)
* **Callback URL**: `https://<tu-dominio-n8n>/webhook/whatsapp`
* **Verify Token**: El mismo valor asignado a `whatsapp_verify_token` en el punto 1.
* **Subscripción a eventos**: Marcar casilla `messages`.

---

## 🔄 Paso 8: Operaciones de Mantenimiento y Actualizaciones

### Ver Logs del Sistema
```bash
docker compose logs -f n8n
```

### Reiniciar el Servicio
```bash
docker compose restart
```

### Actualizar N8N a la Última Versión
```bash
cd ~/n8n-commerce
docker compose pull
docker compose up -d
```

### Backup del Volumen de Datos de N8N
```bash
# Crear copia comprimida del volumen n8n_data
docker run --rm -v n8n_commerce_data:/data -v $(pwd):/backup ubuntu tar czvf /backup/n8n_backup_$(date +%Y%m%d).tar.gz /data
```
