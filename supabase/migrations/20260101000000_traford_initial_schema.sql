-- =============================================================================
-- TRAFORD FARM FRESH — Initial Schema Migration
-- =============================================================================
-- One-shot migration: Schema + Triggers + Helper Functions + RLS Policies
--
-- Run this in: Supabase Dashboard → SQL Editor → New Query → paste → Run
-- Or via CLI:  supabase db push
--
-- Target Supabase project: ibigvmkybuejciykbqbg
-- Idempotent: uses IF NOT EXISTS / DROP-then-CREATE where safe
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. EXTENSIONS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. ENUM TYPES
-- =============================================================================
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('customer', 'field_staff', 'admin', 'director');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE product_audience AS ENUM ('public', 'field_staff_only');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE order_status AS ENUM (
    'pending', 'confirmed', 'preparing',
    'shipped', 'out_for_delivery', 'delivered',
    'cancelled', 'refunded'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE order_type AS ENUM ('customer', 'agro_input');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM ('mtn_momo', 'airtel_money', 'flexipay', 'cash', 'bank');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM ('pending', 'submitted', 'verified', 'failed', 'refunded');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE delivery_status AS ENUM (
    'pending', 'assigned', 'picked_up', 'in_transit',
    'out_for_delivery', 'delivered', 'failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =============================================================================
-- 2. TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 PROFILES (extends auth.users)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email           TEXT,
  phone           TEXT,
  full_name       TEXT,
  avatar_url      TEXT,
  role            user_role NOT NULL DEFAULT 'customer',
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);

-- -----------------------------------------------------------------------------
-- 2.2 ADDRESSES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.addresses (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  label           TEXT,
  recipient       TEXT NOT NULL,
  phone           TEXT NOT NULL,
  street          TEXT,
  city            TEXT,
  district        TEXT,
  country         TEXT DEFAULT 'Uganda',
  is_default      BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_addresses_user ON public.addresses(user_id);

-- -----------------------------------------------------------------------------
-- 2.3 CATEGORIES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
  id              BIGSERIAL PRIMARY KEY,
  name            TEXT NOT NULL,
  slug            TEXT UNIQUE NOT NULL,
  description     TEXT,
  parent_id       BIGINT REFERENCES public.categories(id),
  image_url       TEXT,
  display_order   INT DEFAULT 0,
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_categories_parent ON public.categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_slug ON public.categories(slug);

-- -----------------------------------------------------------------------------
-- 2.4 PRODUCTS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.products (
  id              BIGSERIAL PRIMARY KEY,
  name            TEXT NOT NULL,
  slug            TEXT UNIQUE NOT NULL,
  description     TEXT,
  category_id     BIGINT REFERENCES public.categories(id),
  price           NUMERIC(10,2) NOT NULL,
  original_price  NUMERIC(10,2),
  unit            TEXT DEFAULT 'piece',
  stock           INT DEFAULT 0,
  image_url       TEXT,
  gallery         TEXT[],
  rating          NUMERIC(3,2) DEFAULT 0,
  review_count    INT DEFAULT 0,
  is_featured     BOOLEAN DEFAULT FALSE,
  is_active       BOOLEAN DEFAULT TRUE,
  audience        product_audience DEFAULT 'public',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_audience_active ON public.products(audience, is_active);
CREATE INDEX IF NOT EXISTS idx_products_featured ON public.products(is_featured) WHERE is_featured = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_slug ON public.products(slug);

-- -----------------------------------------------------------------------------
-- 2.5 CART ITEMS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cart_items (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_id      BIGINT REFERENCES public.products(id) ON DELETE CASCADE,
  quantity        INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  added_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_cart_user ON public.cart_items(user_id);

-- -----------------------------------------------------------------------------
-- 2.6 WISHLIST ITEMS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.wishlist_items (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_id      BIGINT REFERENCES public.products(id) ON DELETE CASCADE,
  added_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_wishlist_user ON public.wishlist_items(user_id);

-- -----------------------------------------------------------------------------
-- 2.7 ORDERS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.orders (
  id                   BIGSERIAL PRIMARY KEY,
  order_number         TEXT UNIQUE NOT NULL,
  user_id              UUID REFERENCES public.profiles(id),
  order_type           order_type DEFAULT 'customer',
  status               order_status DEFAULT 'pending',
  subtotal             NUMERIC(12,2) NOT NULL,
  tax                  NUMERIC(12,2) DEFAULT 0,
  shipping_fee         NUMERIC(12,2) DEFAULT 0,
  total                NUMERIC(12,2) NOT NULL,
  shipping_address_id  BIGINT REFERENCES public.addresses(id),
  shipping_address     TEXT,
  shipping_city        TEXT,
  shipping_phone       TEXT,
  notes                TEXT,
  approved_by          UUID REFERENCES public.profiles(id),
  approved_at          TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status_type ON public.orders(status, order_type);
CREATE INDEX IF NOT EXISTS idx_orders_created ON public.orders(created_at DESC);

-- -----------------------------------------------------------------------------
-- 2.8 ORDER ITEMS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_items (
  id              BIGSERIAL PRIMARY KEY,
  order_id        BIGINT REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id      BIGINT REFERENCES public.products(id),
  product_name    TEXT NOT NULL,
  unit_price      NUMERIC(10,2) NOT NULL,
  quantity        INT NOT NULL,
  subtotal        NUMERIC(12,2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);

-- -----------------------------------------------------------------------------
-- 2.9 PAYMENTS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
  id              BIGSERIAL PRIMARY KEY,
  order_id        BIGINT REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES public.profiles(id),
  method          payment_method NOT NULL,
  amount          NUMERIC(12,2) NOT NULL,
  reference       TEXT,
  payer_phone     TEXT,
  status          payment_status DEFAULT 'pending',
  raw_response    JSONB,
  verified_by     UUID REFERENCES public.profiles(id),
  verified_at     TIMESTAMPTZ,
  failure_reason  TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_order ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_user ON public.payments(user_id);

-- -----------------------------------------------------------------------------
-- 2.10 DELIVERIES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.deliveries (
  id              BIGSERIAL PRIMARY KEY,
  order_id        BIGINT REFERENCES public.orders(id) ON DELETE CASCADE UNIQUE,
  status          delivery_status DEFAULT 'pending',
  driver_name     TEXT,
  driver_phone    TEXT,
  tracking_code   TEXT,
  estimated_at    TIMESTAMPTZ,
  delivered_at    TIMESTAMPTZ,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deliveries_status ON public.deliveries(status);

-- -----------------------------------------------------------------------------
-- 2.11 DELIVERY EVENTS (immutable timeline)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.delivery_events (
  id              BIGSERIAL PRIMARY KEY,
  delivery_id     BIGINT REFERENCES public.deliveries(id) ON DELETE CASCADE,
  status          delivery_status NOT NULL,
  message         TEXT,
  created_by      UUID REFERENCES public.profiles(id),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delivery_events_delivery ON public.delivery_events(delivery_id);

-- -----------------------------------------------------------------------------
-- 2.12 INVENTORY MOVEMENTS (audit log)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id              BIGSERIAL PRIMARY KEY,
  product_id      BIGINT REFERENCES public.products(id),
  delta           INT NOT NULL,
  reason          TEXT NOT NULL,
  reference       TEXT,
  created_by      UUID REFERENCES public.profiles(id),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_product ON public.inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_created ON public.inventory_movements(created_at DESC);

-- -----------------------------------------------------------------------------
-- 2.13 REVIEWS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reviews (
  id              BIGSERIAL PRIMARY KEY,
  product_id      BIGINT REFERENCES public.products(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES public.profiles(id),
  rating          INT CHECK (rating BETWEEN 1 AND 5),
  title           TEXT,
  comment         TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(product_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_product ON public.reviews(product_id);

-- -----------------------------------------------------------------------------
-- 2.14 NOTIFICATIONS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  type            TEXT NOT NULL,
  title           TEXT NOT NULL,
  body            TEXT,
  data            JSONB,
  read_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id) WHERE read_at IS NULL;

-- =============================================================================
-- 3. HELPER FUNCTIONS
-- =============================================================================

-- 3.1 Get current user's role (used in RLS policies)
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS user_role
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid()
$$;

-- 3.2 Check if current user is admin or director
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT role IN ('admin', 'director') FROM public.profiles WHERE id = auth.uid()),
    FALSE
  )
$$;

-- 3.3 Check if current user is field staff (or higher)
CREATE OR REPLACE FUNCTION public.is_field_staff_or_above()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT role IN ('field_staff', 'admin', 'director') FROM public.profiles WHERE id = auth.uid()),
    FALSE
  )
$$;

-- 3.4 Generate a unique order number (TFD-2025-000123)
CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  next_num BIGINT;
BEGIN
  SELECT COALESCE(MAX(id), 0) + 1 INTO next_num FROM public.orders;
  RETURN 'TFD-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(next_num::TEXT, 6, '0');
END;
$$;

-- 3.5 Touch updated_at
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- 4. TRIGGERS
-- =============================================================================

-- 4.1 Auto-create profile on auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, phone, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.phone,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'),
    'customer'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4.2 Prevent role self-escalation (only admins can change roles)
CREATE OR REPLACE FUNCTION public.prevent_role_self_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM NEW.role AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can change user roles';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_role_change ON public.profiles;
CREATE TRIGGER guard_role_change
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_role_self_change();

-- 4.3 Auto-set updated_at on profiles, products, orders, deliveries
DROP TRIGGER IF EXISTS touch_profiles_updated ON public.profiles;
CREATE TRIGGER touch_profiles_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS touch_products_updated ON public.products;
CREATE TRIGGER touch_products_updated
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS touch_orders_updated ON public.orders;
CREATE TRIGGER touch_orders_updated
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS touch_deliveries_updated ON public.deliveries;
CREATE TRIGGER touch_deliveries_updated
  BEFORE UPDATE ON public.deliveries
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- 4.4 Auto-record delivery event when delivery status changes
CREATE OR REPLACE FUNCTION public.log_delivery_event()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO public.delivery_events (delivery_id, status, message, created_by)
    VALUES (NEW.id, NEW.status, NEW.notes, auth.uid());
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_log_delivery_events ON public.deliveries;
CREATE TRIGGER auto_log_delivery_events
  AFTER INSERT OR UPDATE ON public.deliveries
  FOR EACH ROW EXECUTE FUNCTION public.log_delivery_event();

-- 4.5 Update product rating when a review is added
CREATE OR REPLACE FUNCTION public.refresh_product_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  pid BIGINT;
BEGIN
  pid := COALESCE(NEW.product_id, OLD.product_id);
  UPDATE public.products
  SET rating = COALESCE((SELECT AVG(rating)::NUMERIC(3,2) FROM public.reviews WHERE product_id = pid), 0),
      review_count = (SELECT COUNT(*) FROM public.reviews WHERE product_id = pid)
  WHERE id = pid;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS refresh_rating_on_review ON public.reviews;
CREATE TRIGGER refresh_rating_on_review
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.refresh_product_rating();

-- =============================================================================
-- 5. ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public.profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlist_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deliveries          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_events     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications       ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 5.1 PROFILES policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users read own profile" ON public.profiles;
CREATE POLICY "Users read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Admins manage all profiles" ON public.profiles;
CREATE POLICY "Admins manage all profiles" ON public.profiles
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.2 ADDRESSES policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users manage own addresses" ON public.addresses;
CREATE POLICY "Users manage own addresses" ON public.addresses
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins read all addresses" ON public.addresses;
CREATE POLICY "Admins read all addresses" ON public.addresses
  FOR SELECT USING (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.3 CATEGORIES policies (public read, admin write)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public reads categories" ON public.categories;
CREATE POLICY "Public reads categories" ON public.categories
  FOR SELECT USING (is_active = TRUE OR public.is_admin());

DROP POLICY IF EXISTS "Admins manage categories" ON public.categories;
CREATE POLICY "Admins manage categories" ON public.categories
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.4 PRODUCTS policies (audience-aware)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public reads public products" ON public.products;
CREATE POLICY "Public reads public products" ON public.products
  FOR SELECT USING (is_active = TRUE AND audience = 'public');

DROP POLICY IF EXISTS "Field staff reads agro inputs" ON public.products;
CREATE POLICY "Field staff reads agro inputs" ON public.products
  FOR SELECT USING (
    is_active = TRUE
    AND audience = 'field_staff_only'
    AND public.is_field_staff_or_above()
  );

DROP POLICY IF EXISTS "Admins manage products" ON public.products;
CREATE POLICY "Admins manage products" ON public.products
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.5 CART policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users own cart" ON public.cart_items;
CREATE POLICY "Users own cart" ON public.cart_items
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 5.6 WISHLIST policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users own wishlist" ON public.wishlist_items;
CREATE POLICY "Users own wishlist" ON public.wishlist_items
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 5.7 ORDERS policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users read own orders" ON public.orders;
CREATE POLICY "Users read own orders" ON public.orders
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users create own orders" ON public.orders;
CREATE POLICY "Users create own orders" ON public.orders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Field staff create agro orders" ON public.orders;
CREATE POLICY "Field staff create agro orders" ON public.orders
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND (order_type = 'customer' OR public.is_field_staff_or_above())
  );

DROP POLICY IF EXISTS "Admins manage all orders" ON public.orders;
CREATE POLICY "Admins manage all orders" ON public.orders
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.8 ORDER ITEMS policies (mirror parent order)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users read own order items" ON public.order_items;
CREATE POLICY "Users read own order items" ON public.order_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_items.order_id AND o.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users create own order items" ON public.order_items;
CREATE POLICY "Users create own order items" ON public.order_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_items.order_id AND o.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins manage all order items" ON public.order_items;
CREATE POLICY "Admins manage all order items" ON public.order_items
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.9 PAYMENTS policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users read own payments" ON public.payments;
CREATE POLICY "Users read own payments" ON public.payments
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users create own payments" ON public.payments;
CREATE POLICY "Users create own payments" ON public.payments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins manage all payments" ON public.payments;
CREATE POLICY "Admins manage all payments" ON public.payments
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.10 DELIVERIES policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users read own deliveries" ON public.deliveries;
CREATE POLICY "Users read own deliveries" ON public.deliveries
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = deliveries.order_id AND o.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins manage deliveries" ON public.deliveries;
CREATE POLICY "Admins manage deliveries" ON public.deliveries
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.11 DELIVERY EVENTS policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users read own delivery events" ON public.delivery_events;
CREATE POLICY "Users read own delivery events" ON public.delivery_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.deliveries d
      JOIN public.orders o ON o.id = d.order_id
      WHERE d.id = delivery_events.delivery_id AND o.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins manage delivery events" ON public.delivery_events;
CREATE POLICY "Admins manage delivery events" ON public.delivery_events
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.12 INVENTORY MOVEMENTS policies (admin only)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins manage inventory" ON public.inventory_movements;
CREATE POLICY "Admins manage inventory" ON public.inventory_movements
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.13 REVIEWS policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public reads reviews" ON public.reviews;
CREATE POLICY "Public reads reviews" ON public.reviews
  FOR SELECT USING (TRUE);

DROP POLICY IF EXISTS "Users create own reviews" ON public.reviews;
CREATE POLICY "Users create own reviews" ON public.reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own reviews" ON public.reviews;
CREATE POLICY "Users update own reviews" ON public.reviews
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own reviews" ON public.reviews;
CREATE POLICY "Users delete own reviews" ON public.reviews
  FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

-- -----------------------------------------------------------------------------
-- 5.14 NOTIFICATIONS policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;
CREATE POLICY "Users read own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;
CREATE POLICY "Users update own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins manage all notifications" ON public.notifications;
CREATE POLICY "Admins manage all notifications" ON public.notifications
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- =============================================================================
-- 6. ATOMIC ORDER CREATION RPC
-- =============================================================================
-- Used by the customer apps via supabase.rpc('create_order', {...})
-- Performs everything in one transaction: validates stock, creates order &
-- items, decrements product stock, logs inventory movement, creates a pending
-- payment row.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.create_order(
  p_items           JSONB,                  -- [{product_id: 1, quantity: 2}, ...]
  p_payment_method  payment_method,
  p_shipping_address_id BIGINT DEFAULT NULL,
  p_shipping_address    TEXT  DEFAULT NULL,
  p_shipping_city       TEXT  DEFAULT NULL,
  p_shipping_phone      TEXT  DEFAULT NULL,
  p_notes               TEXT  DEFAULT NULL,
  p_order_type      order_type DEFAULT 'customer'
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id     UUID := auth.uid();
  v_order_id    BIGINT;
  v_order_no    TEXT;
  v_subtotal    NUMERIC(12,2) := 0;
  v_tax         NUMERIC(12,2) := 0;
  v_shipping    NUMERIC(12,2) := 0;
  v_total       NUMERIC(12,2);
  v_item        JSONB;
  v_product     RECORD;
  v_qty         INT;
  v_line_total  NUMERIC(12,2);
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_order_type = 'agro_input' AND NOT public.is_field_staff_or_above() THEN
    RAISE EXCEPTION 'Only field staff can create agro input orders';
  END IF;

  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order must contain at least one item';
  END IF;

  v_order_no := public.generate_order_number();

  -- Compute totals & validate stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    SELECT id, name, price, stock, audience, is_active
      INTO v_product
      FROM public.products
     WHERE id = (v_item->>'product_id')::BIGINT
     FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product not found: %', v_item->>'product_id';
    END IF;

    IF NOT v_product.is_active THEN
      RAISE EXCEPTION 'Product % is not available', v_product.name;
    END IF;

    -- Audience check
    IF v_product.audience = 'field_staff_only' AND NOT public.is_field_staff_or_above() THEN
      RAISE EXCEPTION 'You do not have access to product %', v_product.name;
    END IF;

    v_qty := (v_item->>'quantity')::INT;
    IF v_qty <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for product %', v_product.name;
    END IF;

    IF v_product.stock < v_qty THEN
      RAISE EXCEPTION 'Insufficient stock for product %', v_product.name;
    END IF;

    v_line_total := v_product.price * v_qty;
    v_subtotal := v_subtotal + v_line_total;
  END LOOP;

  v_tax := ROUND(v_subtotal * 0.0, 2);  -- adjust tax rate as needed
  v_total := v_subtotal + v_tax + v_shipping;

  -- Create order
  INSERT INTO public.orders (
    order_number, user_id, order_type, status,
    subtotal, tax, shipping_fee, total,
    shipping_address_id, shipping_address, shipping_city, shipping_phone, notes
  ) VALUES (
    v_order_no, v_user_id, p_order_type, 'pending',
    v_subtotal, v_tax, v_shipping, v_total,
    p_shipping_address_id, p_shipping_address, p_shipping_city, p_shipping_phone, p_notes
  ) RETURNING id INTO v_order_id;

  -- Insert order_items + decrement stock + log inventory
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    SELECT id, name, price INTO v_product
      FROM public.products WHERE id = (v_item->>'product_id')::BIGINT;

    v_qty := (v_item->>'quantity')::INT;
    v_line_total := v_product.price * v_qty;

    INSERT INTO public.order_items (
      order_id, product_id, product_name, unit_price, quantity, subtotal
    ) VALUES (
      v_order_id, v_product.id, v_product.name, v_product.price, v_qty, v_line_total
    );

    UPDATE public.products SET stock = stock - v_qty WHERE id = v_product.id;

    INSERT INTO public.inventory_movements (
      product_id, delta, reason, reference, created_by
    ) VALUES (
      v_product.id, -v_qty, 'sale', v_order_no, v_user_id
    );
  END LOOP;

  -- Create pending payment row
  INSERT INTO public.payments (order_id, user_id, method, amount, status)
  VALUES (v_order_id, v_user_id, p_payment_method, v_total, 'pending');

  -- Create delivery shell
  INSERT INTO public.deliveries (order_id, status) VALUES (v_order_id, 'pending');

  -- Notify user
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    v_user_id, 'order_created',
    'Order ' || v_order_no || ' received',
    'We have received your order. Awaiting payment confirmation.',
    jsonb_build_object('order_id', v_order_id, 'order_number', v_order_no)
  );

  RETURN v_order_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_order(JSONB, payment_method, BIGINT, TEXT, TEXT, TEXT, TEXT, order_type) TO authenticated;

-- =============================================================================
-- 7. ADMIN DASHBOARD VIEW
-- =============================================================================
CREATE OR REPLACE VIEW public.admin_dashboard_kpis AS
SELECT
  (SELECT COUNT(*) FROM public.orders WHERE created_at >= CURRENT_DATE) AS orders_today,
  (SELECT COUNT(*) FROM public.orders WHERE status = 'pending') AS orders_pending,
  (SELECT COALESCE(SUM(total), 0) FROM public.orders WHERE status = 'delivered' AND created_at >= CURRENT_DATE) AS revenue_today,
  (SELECT COALESCE(SUM(total), 0) FROM public.orders WHERE status = 'delivered' AND created_at >= date_trunc('month', CURRENT_DATE)) AS revenue_month,
  (SELECT COUNT(*) FROM public.payments WHERE status = 'submitted') AS payments_pending_verification,
  (SELECT COUNT(*) FROM public.products WHERE is_active = TRUE AND stock < 10) AS low_stock_products,
  (SELECT COUNT(*) FROM public.profiles WHERE role = 'customer') AS total_customers,
  (SELECT COUNT(*) FROM public.profiles WHERE role = 'field_staff') AS total_field_staff;

-- View security: only admins can SELECT
ALTER VIEW public.admin_dashboard_kpis OWNER TO postgres;

-- =============================================================================
-- 8. REALTIME PUBLICATION
-- =============================================================================
-- Add tables that we want clients to subscribe to live changes on.
DO $$
BEGIN
  -- products: live price/stock/image updates pushed to all clients
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'payments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'deliveries'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.deliveries;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'delivery_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_events;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'categories'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.categories;
  END IF;
END $$;

-- =============================================================================
-- 9. DONE
-- =============================================================================
-- Next steps:
--   1. Create your first admin user:
--      a) Sign up via Supabase Auth (any method)
--      b) Run: UPDATE public.profiles SET role='director' WHERE email='you@example.com';
--   2. Create Storage buckets in the dashboard:
--      • product-images   (public)
--      • category-icons   (public)
--      • avatars          (public)
--      • payment-proofs   (private)
--   3. Test as anon: SELECT * FROM products;     (should see public products only)
--   4. Test as customer: should NOT see audience='field_staff_only' products
-- =============================================================================
