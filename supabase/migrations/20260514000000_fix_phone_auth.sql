-- ============================================================================
-- Fix phone-first login so the website + mobile app actually establish a
-- Supabase Auth session when the user enters their phone+password.
--
-- Background — what was broken:
--   * The old `verify_phone_password` / `set_user_password` RPCs called
--     `crypt()` / `gen_salt('bf')` which live in the `pgcrypto` extension.
--   * `pgcrypto` was never enabled on this project (the extension only ships
--     with the migration file, it doesn't auto-install on `supabase db push`
--     unless you also enable it).
--   * Result: every call to those RPCs returned
--       `function crypt(text, text) does not exist`
--     so the LoginForm hit "Welcome back" then died silently when it tried
--     to verify the password.
--   * RLS on `profiles` also hides rows from `anon`, so the LoginForm
--     couldn't even read the email it needed for `signInWithPassword`.
--
-- This migration fixes all three problems atomically:
--   1. Enable pgcrypto so crypt()/gen_salt() resolve.
--   2. Add SECURITY DEFINER helper `profile_email_by_phone(p_phone)` so
--      the login form can map phone → email without exposing the whole
--      profiles row to anon (we only return the email column).
--   3. Make sure the existing RPCs key off `profiles` (UUID), not the
--      legacy int-keyed `users` table — replace them in-place.
-- ============================================================================

-- 1. pgcrypto -----------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. profiles.password_hash column (idempotent — may already exist) -----------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- 3. RPC: set_user_password(uuid, text) -> bool
--    Replaces the legacy int-keyed version. Hashes server-side.
DROP FUNCTION IF EXISTS public.set_user_password(INTEGER, TEXT);
DROP FUNCTION IF EXISTS public.set_user_password(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.set_user_password(
  p_user_id UUID,
  p_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_password IS NULL OR length(p_password) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters';
  END IF;
  UPDATE public.profiles
     SET password_hash = crypt(p_password, gen_salt('bf', 10))
   WHERE id = p_user_id;
  RETURN FOUND;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_user_password(UUID, TEXT)
  TO anon, authenticated;

-- 4. RPC: user_has_password(p_phone) -> text
--    Returns one of: 'has_password' | 'no_password' | 'not_found'.
--    SECURITY DEFINER so it can see profiles rows that RLS hides from anon.
DROP FUNCTION IF EXISTS public.user_has_password(TEXT);
CREATE OR REPLACE FUNCTION public.user_has_password(p_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_has BOOLEAN;
BEGIN
  SELECT id, (password_hash IS NOT NULL)
    INTO v_id, v_has
    FROM public.profiles
   WHERE phone = p_phone
   LIMIT 1;

  IF v_id IS NULL THEN
    RETURN 'not_found';
  ELSIF v_has THEN
    RETURN 'has_password';
  ELSE
    RETURN 'no_password';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.user_has_password(TEXT)
  TO anon, authenticated;

-- 5. RPC: profile_id_by_phone(p_phone) -> uuid
DROP FUNCTION IF EXISTS public.profile_id_by_phone(TEXT);
CREATE OR REPLACE FUNCTION public.profile_id_by_phone(p_phone TEXT)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id
    FROM public.profiles
   WHERE phone = p_phone
   LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.profile_id_by_phone(TEXT)
  TO anon, authenticated;

-- 6. RPC: profile_email_by_phone(p_phone) -> text
--    NEW — needed so the LoginForm can map phone → email and call
--    supabase.auth.signInWithPassword({ email, password }). The website's
--    Supabase project has the phone provider disabled, so the *only* way to
--    establish a session for a phone-first user is via their email.
--    SECURITY DEFINER bypasses RLS but we only ever return the email column.
DROP FUNCTION IF EXISTS public.profile_email_by_phone(TEXT);
CREATE OR REPLACE FUNCTION public.profile_email_by_phone(p_phone TEXT)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT email
    FROM public.profiles
   WHERE phone = p_phone
   LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.profile_email_by_phone(TEXT)
  TO anon, authenticated;

-- 7. RPC: verify_phone_password(p_phone, p_password)
--    Returns a 1-row set with the profile id + email when the password
--    matches, otherwise an empty set. The LoginForm uses the presence of a
--    row as the green-light to call signInWithPassword.
DROP FUNCTION IF EXISTS public.verify_phone_password(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.verify_phone_password(
  p_phone TEXT,
  p_password TEXT
)
RETURNS TABLE (
  id    UUID,
  email TEXT,
  phone TEXT,
  full_name TEXT,
  role TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.email, p.phone, p.full_name, p.role
    FROM public.profiles p
   WHERE p.phone = p_phone
     AND p.password_hash IS NOT NULL
     AND p.password_hash = crypt(p_password, p.password_hash);
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_phone_password(TEXT, TEXT)
  TO anon, authenticated;

-- 8. Sanity check ------------------------------------------------------------
-- After running this migration the following should succeed:
--   SELECT public.user_has_password('256701634653');     -- 'has_password' | 'no_password'
--   SELECT public.profile_email_by_phone('256701634653');-- the email used for signInWithPassword
--   SELECT * FROM public.verify_phone_password('256701634653', '<their password>');
