# Traford Supabase Backend

This directory contains the database schema, RLS policies, helper functions,
triggers, and seed data for the **shared Supabase backend** used by:

- 📱 **Mobile app** — [`trafordapp`](https://github.com/DrakeNamanya/trafordapp)
- 🌐 **Customer website** — `trafordsite` *(coming soon)*
- 🛠️ **Admin portal** — [`trafordfresh`](https://github.com/DrakeNamanya/trafordfresh)

---

## 📂 Files

| File | Purpose |
|---|---|
| `migrations/20260101000000_traford_initial_schema.sql` | Complete schema, triggers, RLS, helpers, RPC, realtime publication |
| `seed.sql` | Optional development data — categories + sample products (incl. agro inputs hidden from customers) |

---

## 🚀 How to apply

### Option A — Supabase Dashboard (recommended for first run)

1. Open your project: <https://supabase.com/dashboard/project/ibigvmkybuejciykbqbg>
2. Go to **SQL Editor** → **New query**
3. Paste the entire contents of `migrations/20260101000000_traford_initial_schema.sql`
4. Click **Run**
5. (Optional) Repeat with `seed.sql` for sample data

### Option B — Supabase CLI

```bash
# from the trafordapp project root
supabase link --project-ref ibigvmkybuejciykbqbg
supabase db push
```

---

## ✅ Post-migration checklist

### 1. Promote yourself to admin/director
After signing up via any frontend (or directly in Auth dashboard):

```sql
UPDATE public.profiles
SET role = 'director'
WHERE email = 'you@trafordfarmfresh.com';
```

### 2. Create Storage buckets
In **Storage** dashboard, create the following buckets:

| Bucket | Public | Used for |
|---|---|---|
| `product-images` | ✅ | Product photos & galleries |
| `category-icons` | ✅ | Category icons |
| `avatars` | ✅ | User profile pictures |
| `payment-proofs` | 🔒 private | MoMo screenshots uploaded by customers |

### 3. Verify RLS
Open **Authentication → Policies** and confirm every table has at least one
policy listed. Tables without RLS will show a warning.

### 4. Smoke tests

```sql
-- As anon (no JWT): should only see public, active products
SET ROLE anon;
SELECT name, audience FROM public.products LIMIT 5;
RESET ROLE;

-- As authenticated customer: should NOT see field_staff_only products
-- (test via app/postman with a customer JWT)
```

### 5. Verify realtime
The migration auto-adds these tables to the `supabase_realtime` publication:
- `products`, `categories`
- `orders`, `payments`
- `deliveries`, `delivery_events`
- `notifications`

Subscribe from your app and watch live updates flow.

---

## 🧠 Key design decisions

### Audience-based product gating
Agro-input products use `audience = 'field_staff_only'`. RLS policies filter
them at the database level, so even if a customer reverse-engineers an API
call, they physically cannot see those rows.

### Atomic order creation via RPC
Apps don't insert directly into `orders` and `order_items`. They call
`create_order(...)` which:
- Validates stock and audience access in a single transaction
- Inserts the order, items, payment row, and delivery shell
- Logs an inventory movement
- Sends a notification

```dart
// Flutter example
final orderId = await supabase.rpc('create_order', params: {
  'p_items': [{'product_id': 1, 'quantity': 2}],
  'p_payment_method': 'mtn_momo',
  'p_shipping_address': 'Plot 12, Kampala Rd',
  'p_shipping_phone': '+256700123456',
});
```

### Role escalation guard
A trigger on `profiles` rejects `UPDATE` statements that change `role`
unless the caller is an admin/director — even if the row belongs to them.

### Delivery event log
Updating `deliveries.status` automatically inserts a row into
`delivery_events`, giving the customer an immutable timeline.

---

## 🔄 Rolling back / iterating

The migration is **idempotent** — you can re-run it after edits. Tables use
`CREATE TABLE IF NOT EXISTS`, policies use `DROP POLICY IF EXISTS` first.

For destructive changes (renamed columns, dropped tables), create a new
migration file with a higher timestamp prefix.

---

## 📚 Schema overview

```
profiles              ← extends auth.users, holds role
addresses             ← shipping addresses per user
categories            ← hierarchical (parent_id)
products              ← audience: 'public' | 'field_staff_only'
cart_items            ← per-user, unique on (user_id, product_id)
wishlist_items        ← per-user
orders                ← order_type: 'customer' | 'agro_input'
order_items           ← snapshot of product name & price at purchase time
payments              ← supports MoMo, Airtel, FlexiPay, cash, bank
deliveries            ← one per order
delivery_events       ← immutable status timeline
inventory_movements   ← stock audit log
reviews               ← 1-5 stars per (product, user)
notifications         ← in-app notifications
```

---

## 🔐 Security recap

| Layer | Protection |
|---|---|
| Anon key safety | RLS on every table — anon key cannot read private data |
| Service role key | NEVER ship in any client app — server-side only (Edge Functions / admin backend) |
| Role escalation | Trigger blocks `role` change unless caller is admin |
| Field-staff visibility | RLS + audience enum at DB level, not just app code |
| Order integrity | Single-transaction RPC validates stock + audience |
| 2FA recommendation | Enable Supabase MFA for all `admin` / `director` accounts |
