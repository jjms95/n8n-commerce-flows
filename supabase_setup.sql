-- =========================================================
-- SCRIPT DE SETUP PARA SUPABASE (MULTI-TENANT ESTRICTO & COMERCIO)
-- Sistema de Comercio Conversacional N8N con Orquestación Meta WhatsApp
-- =========================================================

-- ─────────────────────────────────────────────
-- 1. TABLA: tenants (Negocios con credenciales Meta completas e integración WhatsApp)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    number VARCHAR(20) NOT NULL,                          -- Número de WhatsApp del Admin/Dueño
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    whatsapp_phone_number_id VARCHAR(100) UNIQUE,        -- Phone ID asignado por Meta Cloud API
    whatsapp_access_token TEXT,                          -- Access Token (Permanent / System User Token)
    whatsapp_app_id VARCHAR(100),                        -- Meta App ID
    whatsapp_app_secret TEXT,                            -- Meta App Secret (para firma HMAC X-Hub-Signature-256)
    whatsapp_verify_token VARCHAR(255),                  -- Token de verificación para GET /webhook Meta
    require_delivery_address BOOLEAN NOT NULL DEFAULT TRUE,
    enable_sales BOOLEAN NOT NULL DEFAULT TRUE,
    enable_crud BOOLEAN NOT NULL DEFAULT TRUE,
    enable_reports BOOLEAN NOT NULL DEFAULT TRUE,
    enable_appointments BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Asegurar columnas si la tabla ya existía previamente
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS whatsapp_phone_number_id VARCHAR(100);
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS whatsapp_access_token TEXT;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS whatsapp_app_id VARCHAR(100);
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS whatsapp_app_secret TEXT;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS whatsapp_verify_token VARCHAR(255);
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS require_delivery_address BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS enable_sales BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS enable_crud BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS enable_reports BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS enable_appointments BOOLEAN NOT NULL DEFAULT TRUE;

-- ─────────────────────────────────────────────
-- 2. TABLA: clients (Aislada por tenant_id)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.clients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    number VARCHAR(20) NOT NULL,
    name VARCHAR(255) NOT NULL,
    bot_paused BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_tenant_client_number UNIQUE (tenant_id, number)
);

ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS bot_paused BOOLEAN NOT NULL DEFAULT FALSE;

-- ─────────────────────────────────────────────
-- 3. TABLA: products (Aislada por tenant_id)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;

-- ─────────────────────────────────────────────
-- 4. TABLA: sessions (Aislada por tenant_id y client_id + TRIGGER)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'pending'
        CHECK (status IN (
            'pending',
            'waiting_product_approval',
            'selecting_quantity',
            'cart_review',
            'select_payment',
            'waiting_delivery_address',
            'waiting_payment_evidence',
            'waiting_business_confirmation',
            'payment_confirmed',
            'dispatched',
            'delivered',
            'live_chat',
            'cancelled'
        )),
    search_term TEXT,
    found_product_id UUID REFERENCES public.products(id),
    cart_items JSONB DEFAULT '[]'::jsonb,
    total_amount NUMERIC(10, 2) DEFAULT 0,
    payment_method VARCHAR(100),
    delivery_address TEXT,
    tracking_number TEXT,
    delivery_notes TEXT,
    is_live_chat BOOLEAN NOT NULL DEFAULT FALSE,
    response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.sessions ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;
ALTER TABLE public.sessions ADD COLUMN IF NOT EXISTS cart_items JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.sessions ADD COLUMN IF NOT EXISTS total_amount NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE public.sessions ADD COLUMN IF NOT EXISTS tracking_number TEXT;
ALTER TABLE public.sessions ADD COLUMN IF NOT EXISTS delivery_notes TEXT;
ALTER TABLE public.sessions ADD COLUMN IF NOT EXISTS is_live_chat BOOLEAN NOT NULL DEFAULT FALSE;

-- Trigger para auto-actualizar updated_at en sessions (PRESERVADO)
CREATE OR REPLACE FUNCTION update_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sessions_updated_at ON public.sessions;
CREATE TRIGGER sessions_updated_at
    BEFORE UPDATE ON public.sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_sessions_updated_at();

-- ─────────────────────────────────────────────
-- 5. TABLA: appointments (Aislada por tenant_id y client_id)
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE,
    client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    appointment_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'confirmed', 'cancelled', 'completed')),
    created_by VARCHAR(20) NOT NULL DEFAULT 'client'
        CHECK (created_by IN ('client', 'business')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.appointments ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE;

-- ─────────────────────────────────────────────
-- 6. RPC: search_products (Busca catálogo con filtro opcional por tenant_id)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.search_products(p_search_term TEXT, p_tenant_id UUID DEFAULT NULL)
RETURNS TABLE (
    id UUID,
    tenant_id UUID,
    name VARCHAR,
    description TEXT,
    price NUMERIC,
    stock INTEGER,
    is_active BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.tenant_id,
        p.name,
        p.description,
        p.price,
        p.stock,
        p.is_active
    FROM public.products p
    WHERE
        p.is_active = TRUE
        AND p.stock > 0
        AND (p_tenant_id IS NULL OR p.tenant_id = p_tenant_id)
        AND (
            p.name ILIKE '%' || p_search_term || '%'
            OR p.description ILIKE '%' || p_search_term || '%'
        )
    ORDER BY
        CASE WHEN p.name ILIKE p_search_term THEN 0 ELSE 1 END,
        p.name ASC
    LIMIT 5;
END;
$$;

-- ─────────────────────────────────────────────
-- 7. RPC: adjust_product_stock (Incremento/Decremento Relativo de Stock por Chat)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.adjust_product_stock(
    p_tenant_id UUID,
    p_product_name TEXT,
    p_quantity_change INTEGER
)
RETURNS TABLE (
    id UUID,
    name VARCHAR,
    old_stock INTEGER,
    new_stock INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_prod_id UUID;
    v_old_stock INTEGER;
    v_new_stock INTEGER;
    v_prod_name VARCHAR;
BEGIN
    SELECT p.id, p.stock, p.name INTO v_prod_id, v_old_stock, v_prod_name
    FROM public.products p
    WHERE p.tenant_id = p_tenant_id
      AND p.is_active = TRUE
      AND p.name ILIKE '%' || p_product_name || '%'
    LIMIT 1;

    IF v_prod_id IS NULL THEN
        RAISE EXCEPTION 'Producto no encontrado con el término %', p_product_name;
    END IF;

    v_new_stock := GREATEST(0, v_old_stock + p_quantity_change);

    UPDATE public.products
    SET stock = v_new_stock,
        is_active = (v_new_stock > 0)
    WHERE public.products.id = v_prod_id;

    RETURN QUERY SELECT v_prod_id, v_prod_name, v_old_stock, v_new_stock;
END;
$$;

-- ─────────────────────────────────────────────
-- 8. RPC: check_appointment_availability (Previene Overbooking en Citas)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.check_appointment_availability(
    p_tenant_id UUID,
    p_appointment_date TIMESTAMP WITH TIME ZONE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.appointments
    WHERE tenant_id = p_tenant_id
      AND status = 'scheduled'
      AND appointment_date BETWEEN (p_appointment_date - INTERVAL '29 minutes') AND (p_appointment_date + INTERVAL '29 minutes');
    
    RETURN (v_count = 0);
END;
$$;

-- ─────────────────────────────────────────────
-- 9. RPC: confirm_payment_and_deduct_stock (Aprobación Atómica de Pago + Descuento Stock de Carrito)
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.confirm_payment_and_deduct_stock(
    p_session_id UUID,
    p_tenant_id UUID
)
RETURNS TABLE (
    session_id UUID,
    client_id UUID,
    total_deducted_items INTEGER,
    total_amount NUMERIC,
    status VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_client_id UUID;
    v_cart JSONB;
    v_item JSONB;
    v_prod_id UUID;
    v_qty INTEGER;
    v_total_amount NUMERIC;
    v_count INTEGER := 0;
BEGIN
    SELECT s.client_id, s.cart_items, s.total_amount, s.found_product_id 
    INTO v_client_id, v_cart, v_total_amount, v_prod_id
    FROM public.sessions s
    WHERE s.id = p_session_id AND s.tenant_id = p_tenant_id;

    IF v_client_id IS NULL THEN
        RAISE EXCEPTION 'Sesión no encontrada o no pertenece al tenant';
    END IF;

    -- 1. Actualizar estado de la sesión
    UPDATE public.sessions
    SET status = 'payment_confirmed',
        updated_at = NOW()
    WHERE id = p_session_id;

    -- 2. Descuento atómico de stock iterando sobre el carrito
    IF v_cart IS NOT NULL AND jsonb_array_length(v_cart) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_cart)
        LOOP
            v_prod_id := (v_item->>'product_id')::UUID;
            v_qty := COALESCE((v_item->>'quantity')::INTEGER, 1);
            
            IF v_prod_id IS NOT NULL THEN
                UPDATE public.products
                SET stock = GREATEST(0, stock - v_qty),
                    is_active = (stock - v_qty > 0)
                WHERE id = v_prod_id;
                
                v_count := v_count + v_qty;
            END IF;
        END LOOP;
    ELSIF v_prod_id IS NOT NULL THEN
        -- Modo retrocompatible para producto individual
        UPDATE public.products
        SET stock = GREATEST(0, stock - 1),
            is_active = (stock - 1 > 0)
        WHERE id = v_prod_id;
        v_count := 1;
    END IF;

    RETURN QUERY SELECT p_session_id, v_client_id, v_count, COALESCE(v_total_amount, 0), 'payment_confirmed'::VARCHAR;
END;
$$;

-- ─────────────────────────────────────────────
-- 10. DATOS DE EJEMPLO DE TENANT Y PRODUCTOS
-- ─────────────────────────────────────────────
INSERT INTO public.tenants (
    number, name, email, whatsapp_phone_number_id, whatsapp_access_token, whatsapp_verify_token,
    require_delivery_address, enable_sales, enable_crud, enable_reports, enable_appointments
) VALUES (
    '521234567890', 'Mi Negocio Demo', 'admin@minegocio.com', '10023456789', 'EAAG_DEMO_TOKEN_PLACEHOLDER', 'MY_VERIFY_TOKEN_DEMO',
    true, true, true, true, true
) ON CONFLICT (number) DO NOTHING;

-- Asignar tenant_id si había productos existentes
INSERT INTO public.products (tenant_id, name, description, price, stock)
SELECT
    t.id, p.name, p.description, p.price, p.stock
FROM public.tenants t
CROSS JOIN (
    VALUES
        ('Camisa Azul Manga Larga', 'Camisa formal de algodón 100%, talla estándar', 350.00, 25),
        ('Pantalón Negro Formal', 'Pantalón de vestir corte slim, muy elegante', 480.00, 15),
        ('Vestido Rojo Casual', 'Vestido casual para uso diario, tela liviana', 290.00, 10),
        ('Zapatos Negros Oxford', 'Zapatos de cuero genuino, suela resistente', 750.00, 8),
        ('Bolsa de Mano Café', 'Bolsa mediana de cuero, ideal para trabajo', 620.00, 5)
) AS p(name, description, price, stock)
WHERE t.number = '521234567890'
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────
-- 11. RLS (Row Level Security) - Acceso Completo Exclusivo para Service Role
-- ─────────────────────────────────────────────
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role full access - tenants" ON public.tenants;
DROP POLICY IF EXISTS "Service role full access - clients" ON public.clients;
DROP POLICY IF EXISTS "Service role full access - products" ON public.products;
DROP POLICY IF EXISTS "Service role full access - sessions" ON public.sessions;
DROP POLICY IF EXISTS "Service role full access - appointments" ON public.appointments;

CREATE POLICY "Service role full access - tenants" ON public.tenants FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access - clients" ON public.clients FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access - products" ON public.products FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access - sessions" ON public.sessions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access - appointments" ON public.appointments FOR ALL TO service_role USING (true) WITH CHECK (true);
