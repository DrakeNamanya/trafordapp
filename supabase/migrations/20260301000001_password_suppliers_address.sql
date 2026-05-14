-- =========================================================================
-- Migration: phone+password auth, suppliers tab, street address
-- =========================================================================

-- 1. Add password_hash + street_address columns to users (idempotent)
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS street_address TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS village_id INTEGER REFERENCES villages(id);

-- 2. pgcrypto for bcrypt hashing on the server
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 3. RPC: set/update password (callable from the app with a known user_id)
--    Hashes server-side so plaintext never lives in the DB or in logs.
CREATE OR REPLACE FUNCTION public.set_user_password(
  p_user_id INTEGER,
  p_new_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_new_password IS NULL OR length(p_new_password) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters';
  END IF;
  UPDATE users
     SET password_hash = crypt(p_new_password, gen_salt('bf', 10))
   WHERE id = p_user_id;
  RETURN FOUND;
END;
$$;

-- 4. RPC: verify phone+password and return the user row on success
CREATE OR REPLACE FUNCTION public.verify_phone_password(
  p_phone TEXT,
  p_password TEXT
)
RETURNS TABLE (
  id INTEGER,
  name TEXT,
  phone TEXT,
  email TEXT,
  role TEXT,
  auth_id TEXT,
  address TEXT,
  city TEXT,
  country TEXT,
  street_address TEXT,
  village_id INTEGER,
  has_password BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.name, u.phone, u.email, u.role, u.auth_id,
         u.address, u.city, u.country, u.street_address, u.village_id,
         (u.password_hash IS NOT NULL) AS has_password
    FROM users u
   WHERE u.phone = p_phone
     AND u.password_hash IS NOT NULL
     AND u.password_hash = crypt(p_password, u.password_hash);
END;
$$;

-- 5. RPC: check if user has password set yet (used by phone-only fallback login)
CREATE OR REPLACE FUNCTION public.user_has_password(p_phone TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_has BOOLEAN;
BEGIN
  SELECT (password_hash IS NOT NULL) INTO v_has
    FROM users WHERE phone = p_phone LIMIT 1;
  RETURN COALESCE(v_has, FALSE);
END;
$$;

-- 6. Suppliers table
CREATE TABLE IF NOT EXISTS suppliers (
  id            SERIAL PRIMARY KEY,
  user_id       INTEGER REFERENCES users(id) ON DELETE SET NULL,
  full_name     TEXT NOT NULL,
  phone         TEXT NOT NULL,
  email         TEXT,
  product       TEXT NOT NULL,            -- what they want to supply
  quantity      TEXT,                     -- e.g. "200 kg", "5 crates"
  frequency     TEXT,                     -- daily / weekly / monthly / one-off
  notes         TEXT,
  district_id   INTEGER REFERENCES districts(id),
  subcounty_id  INTEGER REFERENCES subcounties(id),
  parish_id     INTEGER REFERENCES parishes(id),
  village_id    INTEGER REFERENCES villages(id),
  status        TEXT NOT NULL DEFAULT 'pending',  -- pending / contacted / approved / rejected
  admin_notes   TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_suppliers_user ON suppliers(user_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_status ON suppliers(status);
CREATE INDEX IF NOT EXISTS idx_suppliers_created ON suppliers(created_at DESC);

-- 7. RLS for suppliers
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS suppliers_insert_any ON suppliers;
CREATE POLICY suppliers_insert_any ON suppliers
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS suppliers_select_own_or_admin ON suppliers;
CREATE POLICY suppliers_select_own_or_admin ON suppliers
  FOR SELECT USING (true);  -- public select; admin portal will use service role

-- 8. Trigger to keep updated_at fresh
CREATE OR REPLACE FUNCTION touch_suppliers_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_suppliers_touch ON suppliers;
CREATE TRIGGER trg_suppliers_touch
  BEFORE UPDATE ON suppliers
  FOR EACH ROW EXECUTE FUNCTION touch_suppliers_updated_at();
