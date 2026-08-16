# 🗄️ Queries SQL para Creación de Elementos de Prueba y Validación

Este documento contiene scripts SQL preparados para ejecutarse directamente en el **SQL Editor de Supabase**. Permiten poblar bases de datos de desarrollo/staging con datos sintéticos, probar las funciones RPC de forma aislada, simular estados de ventas y verificar el comportamiento multi-inquilino (*multi-tenant*).

---

## 📑 Índice de Scripts

1. [Creación de Negocios de Prueba (Tenants)](#1-creación-de-negocios-de-prueba-tenants)
2. [Población de Catálogo de Productos](#2-población-de-catálogo-de-productos)
3. [Creación de Clientes de Prueba](#3-creación-de-clientes-de-prueba)
4. [Simulación de Sesiones de Venta en Distintos Estados](#4-simulación-de-sesiones-de-venta-en-distintos-estados)
5. [Creación de Citas de Prueba](#5-creación-de-citas-de-prueba)
6. [Pruebas Directas de Funciones RPC (Store Procedures)](#6-pruebas-directas-de-funciones-rpc)
7. [Queries de Diagnóstico y Sanity Checks](#7-queries-de-diagnóstico-y-sanity-checks)
8. [Script de Limpieza y Reseteo](#8-script-de-limpieza-y-reseteo)

---

## 1. Creación de Negocios de Prueba (Tenants)

Crea dos negocios independientes para comprobar el aislamiento estricto de datos (*multi-tenancy*):

```sql
-- Tenant A: Tienda de Ropa y Calzado
INSERT INTO public.tenants (
    number,
    name,
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
    '521234567890',
    'Moda Urbana Store',
    'admin@modaurbana.com',
    '10023456789',
    'EAAG_TOKEN_MODA_URBANA_TEST',
    'MY_VERIFY_TOKEN_DEMO',
    true, true, true, true, true
) ON CONFLICT (whatsapp_phone_number_id) DO UPDATE SET
    name = EXCLUDED.name,
    number = EXCLUDED.number;

-- Tenant B: Consultorio / Servicios (Ventas desactivadas, citas activadas)
INSERT INTO public.tenants (
    number,
    name,
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
    '573209876543',
    'Consultorio Dental Sonrisas',
    'contacto@dentalsonrisas.com',
    '9876543210987654',
    'EAAG_TOKEN_DENTAL_TEST',
    'DentalVerifyToken.2026',
    false, false, true, true, true
) ON CONFLICT (whatsapp_phone_number_id) DO UPDATE SET
    name = EXCLUDED.name,
    number = EXCLUDED.number;
```

---

## 2. Población de Catálogo de Productos

Inserta productos con diferentes rangos de precio y stock para probar filtros, búsquedas y alertas de stock bajo:

```sql
-- Insertar catálogo para 'Moda Urbana Store'
WITH t AS (
    SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789' LIMIT 1
)
INSERT INTO public.products (tenant_id, name, description, price, stock, is_active)
SELECT 
    t.id, 
    p.name, 
    p.description, 
    p.price, 
    p.stock, 
    p.is_active
FROM t, (
    VALUES
        ('Camisa Azul Manga Larga', 'Camisa formal 100% algodón, corte regular', 120000.00, 25, true),
        ('Camisa Blanca Oxford', 'Camisa elegante para oficina y eventos', 135000.00, 18, true),
        ('Pantalón Jean Slim Fit', 'Jean azul clásico con elastano', 180000.00, 3, true), -- Stock crítico (<5)
        ('Chaqueta de Cuero Negra', 'Chaqueta estilo biker impermeable', 350000.00, 2, true), -- Stock crítico
        ('Zapatos Formales Oxford', 'Zapatos de cuero color café suela cosida', 280000.00, 8, true),
        ('Cinturón de Cuero Negro', 'Cinturón reversible formal/casual', 65000.00, 0, false), -- Agotado / Inactivo
        ('Gorra Deportiva Urbana', 'Gorra con visera curva ajustable', 45000.00, 30, true)
) AS p(name, description, price, stock, is_active);
```

---

## 3. Creación de Clientes de Prueba

```sql
-- Clientes para Moda Urbana Store
WITH t AS (
    SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789' LIMIT 1
)
INSERT INTO public.clients (tenant_id, number, name)
SELECT t.id, c.number, c.name
FROM t, (
    VALUES
        ('573001112233', 'Laura Gómez'),
        ('573004445566', 'Carlos Mendoza'),
        ('573007778899', 'Andrea Rincón')
) AS c(number, name)
ON CONFLICT (tenant_id, number) DO NOTHING;
```

---

## 4. Simulación de Sesiones de Venta en Distintos Estados

Este script crea sesiones de compra en cada una de las 7 etapas de la máquina de estados de ventas:

```sql
-- 1. Sesión 'waiting_product_approval' (Esperando confirmación del producto por el cliente)
WITH ctx AS (
    SELECT t.id AS tenant_id, c.id AS client_id, p.id AS product_id
    FROM public.tenants t
    JOIN public.clients c ON c.tenant_id = t.id AND c.number = '573001112233'
    JOIN public.products p ON p.tenant_id = t.id AND p.name ILIKE '%Camisa Azul%'
    LIMIT 1
)
INSERT INTO public.sessions (tenant_id, client_id, status, search_term, found_product_id, response)
SELECT ctx.tenant_id, ctx.client_id, 'waiting_product_approval', 'camisa azul', ctx.product_id, '¿Deseas comprar Camisa Azul Manga Larga por $120.000?'
FROM ctx;

-- 2. Sesión 'waiting_delivery_address' (Producto aprobado, método seleccionado, solicitando dirección)
WITH ctx AS (
    SELECT t.id AS tenant_id, c.id AS client_id, p.id AS product_id
    FROM public.tenants t
    JOIN public.clients c ON c.tenant_id = t.id AND c.number = '573004445566'
    JOIN public.products p ON p.tenant_id = t.id AND p.name ILIKE '%Pantalón Jean%'
    LIMIT 1
)
INSERT INTO public.sessions (tenant_id, client_id, status, search_term, found_product_id, payment_method, response)
SELECT ctx.tenant_id, ctx.client_id, 'waiting_delivery_address', 'pantalon jean', ctx.product_id, 'Transferencia Bancaria', 'Por favor envía tu dirección de despacho'
FROM ctx;

-- 3. Sesión 'waiting_business_confirmation' (Cliente adjuntó comprobante, esperando que el dueño apruebe)
WITH ctx AS (
    SELECT t.id AS tenant_id, c.id AS client_id, p.id AS product_id
    FROM public.tenants t
    JOIN public.clients c ON c.tenant_id = t.id AND c.number = '573007778899'
    JOIN public.products p ON p.tenant_id = t.id AND p.name ILIKE '%Zapatos Formales%'
    LIMIT 1
)
INSERT INTO public.sessions (tenant_id, client_id, status, search_term, found_product_id, payment_method, delivery_address, response)
SELECT ctx.tenant_id, ctx.client_id, 'waiting_business_confirmation', 'zapatos formales', ctx.product_id, 'Transferencia Bancaria', 'Carrera 7 # 72-41, Bogotá', 'Comprobante recibido. Esperando validación del dueño.'
FROM ctx;
```

---

## 5. Creación de Citas de Prueba

Crea citas para probar el listado de citas del día y la validación de colisiones / prevención de overbooking:

```sql
-- Citas para el día de hoy y mañana
WITH ctx AS (
    SELECT t.id AS tenant_id, c.id AS client_id
    FROM public.tenants t
    JOIN public.clients c ON c.tenant_id = t.id AND c.number = '573001112233'
    LIMIT 1
)
INSERT INTO public.appointments (tenant_id, client_id, title, appointment_date, status, created_by)
SELECT 
    ctx.tenant_id, 
    ctx.client_id, 
    a.title, 
    a.appointment_date, 
    a.status::VARCHAR, 
    a.created_by::VARCHAR
FROM ctx, (
    VALUES
        ('Asesoría de Vestuario Formal', NOW() + INTERVAL '2 hours', 'scheduled', 'client'),
        ('Prueba de Tallas', NOW() + INTERVAL '4 hours', 'confirmed', 'business'),
        ('Cita Mañana Tarde', NOW() + INTERVAL '1 day 3 hours', 'scheduled', 'client')
) AS a(title, appointment_date, status, created_by);
```

---

## 6. Pruebas Directas de Funciones RPC

Ejecuta estas consultas en el SQL Editor para validar la lógica transaccional de los procedimientos almacenados:

### A. Test de Búsqueda de Productos (`search_products`)
```sql
-- Buscar 'camisa' dentro del tenant específico
SELECT * FROM public.search_products(
    'camisa', 
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789')
);
```

---

### B. Test de Ajuste Relativo de Stock (`adjust_product_stock`)
```sql
-- Sumar 10 unidades a 'Camisa Azul'
SELECT * FROM public.adjust_product_stock(
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789'),
    'Camisa Azul',
    10
);

-- Restar 5 unidades
SELECT * FROM public.adjust_product_stock(
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789'),
    'Camisa Azul',
    -5
);
```

---

### C. Test de Prevención de Overbooking (`check_appointment_availability`)
```sql
-- Validar si hay disponibilidad para una fecha con colisión (debe retornar FALSE si está a ±29 min de una cita existente)
SELECT public.check_appointment_availability(
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789'),
    NOW() + INTERVAL '2 hours' -- Misma hora que la cita creada antes
) AS is_available;

-- Validar para un horario libre (debe retornar TRUE)
SELECT public.check_appointment_availability(
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789'),
    NOW() + INTERVAL '10 hours'
) AS is_available;
```

---

### D. Test de Aprobación Atómica de Pago (`confirm_payment_and_deduct_stock`)
```sql
-- Aprobar la sesión pendiente y verificar decremento de stock
WITH session_to_approve AS (
    SELECT s.id, s.tenant_id
    FROM public.sessions s
    WHERE s.status = 'waiting_business_confirmation'
    LIMIT 1
)
SELECT * FROM public.confirm_payment_and_deduct_stock(
    (SELECT id FROM session_to_approve),
    (SELECT tenant_id FROM session_to_approve)
);
```

---

## 7. Queries de Diagnóstico y Sanity Checks

### Dashboard de Pendientes del Negocio
```sql
SELECT 
    'Pagos por Validar' AS concepto,
    COUNT(*)::TEXT AS cantidad
FROM public.sessions s
JOIN public.tenants t ON t.id = s.tenant_id
WHERE s.status = 'waiting_business_confirmation'
  AND t.whatsapp_phone_number_id = '10023456789'

UNION ALL

SELECT 
    'Citas de Hoy',
    COUNT(*)::TEXT
FROM public.appointments a
JOIN public.tenants t ON t.id = a.tenant_id
WHERE a.status = 'scheduled'
  AND DATE(a.appointment_date AT TIME ZONE 'America/Bogota') = CURRENT_DATE
  AND t.whatsapp_phone_number_id = '10023456789'

UNION ALL

SELECT 
    'Productos con Stock Crítico (<5)',
    COUNT(*)::TEXT
FROM public.products p
JOIN public.tenants t ON t.id = p.tenant_id
WHERE p.is_active = TRUE 
  AND p.stock < 5
  AND t.whatsapp_phone_number_id = '10023456789';
```

---

## 8. Script de Limpieza y Reseteo

Utiliza este bloque para reiniciar los datos de prueba sin eliminar la estructura ni las funciones RPC:

```sql
-- Limpiar sesiones, citas, productos y clientes manteniendo la estructura
TRUNCATE TABLE public.sessions, public.appointments, public.products, public.clients CASCADE;

-- Si deseas eliminar también los tenants de prueba:
-- TRUNCATE TABLE public.tenants CASCADE;
```
