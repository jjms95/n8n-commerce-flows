# 🗄️ SQL Test Queries & Seed Data Scripts

This document contains ready-to-run SQL scripts for the **Supabase SQL Editor**. They allow populating development/staging databases with synthetic test data, testing stored procedures (RPCs) in isolation, simulating sales lifecycle states, and verifying multi-tenant data isolation.

---

## 📑 Table of Contents

1. [Create Test Business Tenants](#1-create-test-business-tenants)
2. [Seed Product Catalog](#2-seed-product-catalog)
3. [Create Test Clients](#3-create-test-clients)
4. [Simulate Sales Sessions Across All 7 States](#4-simulate-sales-sessions-across-all-7-states)
5. [Seed Test Appointments](#5-seed-test-appointments)
6. [Direct RPC Function Tests (Stored Procedures)](#6-direct-rpc-function-tests)
7. [Diagnostic & Sanity Check Queries](#7-diagnostic--sanity-check-queries)
8. [Database Cleanup & Reset Script](#8-database-cleanup--reset-script)

---

## 1. Create Test Business Tenants

Creates two isolated businesses to test multi-tenant Row Level Security (RLS) enforcement:

```sql
-- Tenant A: Apparel & Footwear Store
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
    'Urban Fashion Store',
    'admin@urbanfashion.com',
    '10023456789',
    'EAAG_TOKEN_URBAN_TEST',
    'MY_VERIFY_TOKEN_DEMO',
    true, true, true, true, true
) ON CONFLICT (whatsapp_phone_number_id) DO UPDATE SET
    name = EXCLUDED.name,
    number = EXCLUDED.number;

-- Tenant B: Medical / Dental Clinic (Sales disabled, Appointments enabled)
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
    'Dental Care Clinic',
    'contact@dentalcare.com',
    '9876543210987654',
    'EAAG_TOKEN_DENTAL_TEST',
    'DentalVerifyToken.2026',
    false, false, true, true, true
) ON CONFLICT (whatsapp_phone_number_id) DO UPDATE SET
    name = EXCLUDED.name,
    number = EXCLUDED.number;
```

---

## 2. Seed Product Catalog

```sql
-- Insert catalog for 'Urban Fashion Store'
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
        ('Blue Long Sleeve Shirt', '100% cotton formal shirt, regular fit', 120000.00, 25, true),
        ('White Oxford Shirt', 'Classic elegant dress shirt', 135000.00, 18, true),
        ('Slim Fit Jeans', 'Classic blue denim with stretch', 180000.00, 3, true), -- Critical stock (<5)
        ('Black Leather Jacket', 'Waterproof biker jacket', 350000.00, 2, true), -- Critical stock (<5)
        ('Oxford Brown Shoes', 'Stitched sole genuine leather dress shoes', 280000.00, 8, true),
        ('Black Leather Belt', 'Reversible formal/casual leather belt', 65000.00, 0, false), -- Out of stock
        ('Urban Sports Cap', 'Adjustable curved visor sports cap', 45000.00, 30, true)
) AS p(name, description, price, stock, is_active);
```

---

## 3. Create Test Clients

```sql
-- Clients for Urban Fashion Store
WITH t AS (
    SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789' LIMIT 1
)
INSERT INTO public.clients (tenant_id, number, name)
SELECT t.id, c.number, c.name
FROM t, (
    VALUES
        ('573001112233', 'Laura Gomez'),
        ('573004445566', 'Carlos Mendoza'),
        ('573007778899', 'Andrea Rincon')
) AS c(number, name)
ON CONFLICT (tenant_id, number) DO NOTHING;
```

---

## 4. Simulate Sales Sessions Across All 7 States

```sql
-- 1. Session 'waiting_product_approval' (Awaiting product confirmation from client)
WITH ctx AS (
    SELECT t.id AS tenant_id, c.id AS client_id, p.id AS product_id
    FROM public.tenants t
    JOIN public.clients c ON c.tenant_id = t.id AND c.number = '573001112233'
    JOIN public.products p ON p.tenant_id = t.id AND p.name ILIKE '%Blue Long Sleeve%'
    LIMIT 1
)
INSERT INTO public.sessions (tenant_id, client_id, status, search_term, found_product_id, response)
SELECT ctx.tenant_id, ctx.client_id, 'waiting_product_approval', 'blue shirt', ctx.product_id, 'Would you like to purchase Blue Long Sleeve Shirt for $120,000 COP?'
FROM ctx;

-- 2. Session 'waiting_delivery_address' (Product approved, payment selected, awaiting address)
WITH ctx AS (
    SELECT t.id AS tenant_id, c.id AS client_id, p.id AS product_id
    FROM public.tenants t
    JOIN public.clients c ON c.tenant_id = t.id AND c.number = '573004445566'
    JOIN public.products p ON p.tenant_id = t.id AND p.name ILIKE '%Slim Fit Jeans%'
    LIMIT 1
)
INSERT INTO public.sessions (tenant_id, client_id, status, search_term, found_product_id, payment_method, response)
SELECT ctx.tenant_id, ctx.client_id, 'waiting_delivery_address', 'jeans', ctx.product_id, 'Bank Transfer', 'Please provide your shipping address.'
FROM ctx;

-- 3. Session 'waiting_business_confirmation' (Receipt uploaded, awaiting owner approval)
WITH ctx AS (
    SELECT t.id AS tenant_id, c.id AS client_id, p.id AS product_id
    FROM public.tenants t
    JOIN public.clients c ON c.tenant_id = t.id AND c.number = '573007778899'
    JOIN public.products p ON p.tenant_id = t.id AND p.name ILIKE '%Oxford Brown Shoes%'
    LIMIT 1
)
INSERT INTO public.sessions (tenant_id, client_id, status, search_term, found_product_id, payment_method, delivery_address, response)
SELECT ctx.tenant_id, ctx.client_id, 'waiting_business_confirmation', 'brown shoes', ctx.product_id, 'Bank Transfer', '123 Main St, Apt 402, Bogota', 'Receipt received. Awaiting validation from store owner.'
FROM ctx;
```

---

## 5. Seed Test Appointments

```sql
-- Seed appointments for today and tomorrow
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
        ('Formal Wear Consultation', NOW() + INTERVAL '2 hours', 'scheduled', 'client'),
        ('Size Fitting Session', NOW() + INTERVAL '4 hours', 'confirmed', 'business'),
        ('Follow-up Appointment', NOW() + INTERVAL '1 day 3 hours', 'scheduled', 'client')
) AS a(title, appointment_date, status, created_by);
```

---

## 6. Direct RPC Function Tests

### A. Fuzzy Search Function (`search_products`)
```sql
SELECT * FROM public.search_products(
    'shirt', 
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789')
);
```

---

### B. Relative Stock Adjustment Function (`adjust_product_stock`)
```sql
-- Add 10 units to 'Blue Long Sleeve Shirt'
SELECT * FROM public.adjust_product_stock(
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789'),
    'Blue Long Sleeve Shirt',
    10
);

-- Deduct 5 units
SELECT * FROM public.adjust_product_stock(
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789'),
    'Blue Long Sleeve Shirt',
    -5
);
```

---

### C. Overbooking Prevention Function (`check_appointment_availability`)
```sql
-- Check collision for conflicting time slot (returns FALSE if within +-29 min of existing appointment)
SELECT public.check_appointment_availability(
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789'),
    NOW() + INTERVAL '2 hours'
) AS is_available;

-- Check open slot (returns TRUE)
SELECT public.check_appointment_availability(
    (SELECT id FROM public.tenants WHERE whatsapp_phone_number_id = '10023456789'),
    NOW() + INTERVAL '10 hours'
) AS is_available;
```

---

### D. Atomic Payment Confirmation & Stock Deduction (`confirm_payment_and_deduct_stock`)
```sql
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

## 7. Diagnostic & Sanity Check Queries

```sql
SELECT 
    'Payments Awaiting Validation' AS concept,
    COUNT(*)::TEXT AS count
FROM public.sessions s
JOIN public.tenants t ON t.id = s.tenant_id
WHERE s.status = 'waiting_business_confirmation'
  AND t.whatsapp_phone_number_id = '10023456789'

UNION ALL

SELECT 
    'Appointments Scheduled Today',
    COUNT(*)::TEXT
FROM public.appointments a
JOIN public.tenants t ON t.id = a.tenant_id
WHERE a.status = 'scheduled'
  AND DATE(a.appointment_date AT TIME ZONE 'America/Bogota') = CURRENT_DATE
  AND t.whatsapp_phone_number_id = '10023456789'

UNION ALL

SELECT 
    'Critical Low Stock Products (<5)',
    COUNT(*)::TEXT
FROM public.products p
JOIN public.tenants t ON t.id = p.tenant_id
WHERE p.is_active = TRUE 
  AND p.stock < 5
  AND t.whatsapp_phone_number_id = '10023456789';
```

---

## 8. Database Cleanup & Reset Script

```sql
-- Truncate sessions, appointments, products, and clients while keeping schema intact
TRUNCATE TABLE public.sessions, public.appointments, public.products, public.clients CASCADE;

-- Optional: truncate tenants if completely resetting
-- TRUNCATE TABLE public.tenants CASCADE;
```
