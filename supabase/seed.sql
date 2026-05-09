-- =============================================================================
-- TRAFORD FARM FRESH — Development Seed Data
-- =============================================================================
-- Optional: run AFTER the initial schema migration to populate dev data.
-- DO NOT run this in production.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Categories (parent → children)
-- -----------------------------------------------------------------------------
INSERT INTO public.categories (name, slug, description, parent_id, display_order, is_active) VALUES
  ('Fresh Produce',     'fresh-produce',    'Farm-fresh vegetables and fruits', NULL, 1, TRUE),
  ('Meat and Poultry',  'meat-poultry',     'Quality meat products',            NULL, 2, TRUE),
  ('Dry Items',         'dry-items',        'Pantry essentials',                NULL, 3, TRUE),
  ('Honey',             'honey',            'Pure natural honey',               NULL, 4, TRUE),
  ('Legumes & Nuts',    'legumes-nuts',     'Beans, peas and nuts',             NULL, 5, TRUE),
  ('Agro Inputs',       'agro-inputs',      'Seeds, fertilizers, tools',        NULL, 99, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- Children of "Fresh Produce" and "Meat and Poultry"
INSERT INTO public.categories (name, slug, description, parent_id, display_order, is_active)
SELECT 'Vegetables', 'vegetables', 'Leafy greens & vegetables',
       (SELECT id FROM public.categories WHERE slug = 'fresh-produce'), 1, TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE slug = 'vegetables');

INSERT INTO public.categories (name, slug, description, parent_id, display_order, is_active)
SELECT 'Fruits', 'fruits', 'Seasonal fruits',
       (SELECT id FROM public.categories WHERE slug = 'fresh-produce'), 2, TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE slug = 'fruits');

INSERT INTO public.categories (name, slug, description, parent_id, display_order, is_active)
SELECT 'Beef', 'beef', 'Local beef cuts',
       (SELECT id FROM public.categories WHERE slug = 'meat-poultry'), 1, TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE slug = 'beef');

INSERT INTO public.categories (name, slug, description, parent_id, display_order, is_active)
SELECT 'Chicken', 'chicken', 'Free-range chicken',
       (SELECT id FROM public.categories WHERE slug = 'meat-poultry'), 2, TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE slug = 'chicken');

INSERT INTO public.categories (name, slug, description, parent_id, display_order, is_active)
SELECT 'Goat', 'goat', 'Goat meat',
       (SELECT id FROM public.categories WHERE slug = 'meat-poultry'), 3, TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE slug = 'goat');

-- -----------------------------------------------------------------------------
-- Public products (visible to everyone)
-- -----------------------------------------------------------------------------
INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_featured, is_active, audience)
SELECT 'Tomatoes', 'tomatoes', 'Fresh red tomatoes',
       (SELECT id FROM public.categories WHERE slug='vegetables'),
       4000, 'kg', 100,
       'https://images.unsplash.com/photo-1561136594-7f68413baa99?auto=format&fit=crop&w=600&q=80',
       TRUE, TRUE, 'public'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='tomatoes');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_featured, is_active, audience)
SELECT 'Bananas', 'bananas', 'Sweet ripe bananas',
       (SELECT id FROM public.categories WHERE slug='fruits'),
       2500, 'bunch', 50,
       'https://images.unsplash.com/photo-1574226516831-e1dff420e12b?auto=format&fit=crop&w=600&q=80',
       TRUE, TRUE, 'public'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='bananas');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_featured, is_active, audience)
SELECT 'Avocado', 'avocado', 'Creamy ripe avocados',
       (SELECT id FROM public.categories WHERE slug='fruits'),
       1000, 'piece', 200,
       'https://images.unsplash.com/photo-1589927986089-35812388d1f4?auto=format&fit=crop&w=600&q=80',
       TRUE, TRUE, 'public'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='avocado');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_featured, is_active, audience)
SELECT 'Carrots', 'carrots', 'Fresh orange carrots',
       (SELECT id FROM public.categories WHERE slug='vegetables'),
       3000, 'kg', 80,
       'https://images.unsplash.com/photo-1447175008436-054170c2e979?auto=format&fit=crop&w=600&q=80',
       FALSE, TRUE, 'public'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='carrots');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_featured, is_active, audience)
SELECT 'Spinach', 'spinach', 'Fresh leafy spinach',
       (SELECT id FROM public.categories WHERE slug='vegetables'),
       2000, 'bundle', 60,
       'https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=600&q=80',
       TRUE, TRUE, 'public'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='spinach');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_featured, is_active, audience)
SELECT 'Local Beef', 'local-beef', 'Fresh local beef cuts',
       (SELECT id FROM public.categories WHERE slug='beef'),
       18000, 'kg', 30,
       'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=600&q=80',
       FALSE, TRUE, 'public'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='local-beef');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_featured, is_active, audience)
SELECT 'Free Range Chicken', 'free-range-chicken', 'Whole free-range chicken',
       (SELECT id FROM public.categories WHERE slug='chicken'),
       25000, 'piece', 40,
       'https://images.unsplash.com/photo-1587593810167-a84920ea0781?auto=format&fit=crop&w=600&q=80',
       TRUE, TRUE, 'public'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='free-range-chicken');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_featured, is_active, audience)
SELECT 'Pure Honey', 'pure-honey', '500ml jar of natural raw honey',
       (SELECT id FROM public.categories WHERE slug='honey'),
       15000, 'jar', 70,
       'https://images.unsplash.com/photo-1587049352846-4a222e784d38?auto=format&fit=crop&w=600&q=80',
       TRUE, TRUE, 'public'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='pure-honey');

-- -----------------------------------------------------------------------------
-- Field-staff-only products (HIDDEN from regular customers)
-- -----------------------------------------------------------------------------
INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_active, audience)
SELECT 'Maize Seeds (Hybrid)', 'maize-seeds-hybrid', 'High-yield hybrid maize seeds, 2kg bag',
       (SELECT id FROM public.categories WHERE slug='agro-inputs'),
       45000, 'bag', 200,
       'https://images.unsplash.com/photo-1551754655-cd27e38d2076?auto=format&fit=crop&w=600&q=80',
       TRUE, 'field_staff_only'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='maize-seeds-hybrid');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_active, audience)
SELECT 'NPK Fertilizer 50kg', 'npk-fertilizer-50kg', 'NPK 17-17-17 balanced fertilizer',
       (SELECT id FROM public.categories WHERE slug='agro-inputs'),
       180000, 'bag', 80,
       'https://images.unsplash.com/photo-1592982537447-7440770cbfc9?auto=format&fit=crop&w=600&q=80',
       TRUE, 'field_staff_only'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='npk-fertilizer-50kg');

INSERT INTO public.products (name, slug, description, category_id, price, unit, stock, image_url, is_active, audience)
SELECT 'Pesticide Sprayer 16L', 'pesticide-sprayer-16l', 'Manual knapsack sprayer',
       (SELECT id FROM public.categories WHERE slug='agro-inputs'),
       95000, 'piece', 25,
       'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?auto=format&fit=crop&w=600&q=80',
       TRUE, 'field_staff_only'
WHERE NOT EXISTS (SELECT 1 FROM public.products WHERE slug='pesticide-sprayer-16l');
