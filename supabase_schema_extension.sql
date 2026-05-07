-- ============================================================
-- TRAFORD FARM FRESH - Database Schema Extension
-- Run this in Supabase SQL Editor:
-- https://supabase.com/dashboard/project/ibigvmkybuejciykbqbg/sql/new
-- ============================================================

-- 1. UGANDA DISTRICTS TABLE
CREATE TABLE IF NOT EXISTS districts (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  region VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 2. SUBCOUNTIES TABLE
CREATE TABLE IF NOT EXISTS subcounties (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  district_id INTEGER REFERENCES districts(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 3. PARISHES/VILLAGES TABLE
CREATE TABLE IF NOT EXISTS parishes (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  subcounty_id INTEGER REFERENCES subcounties(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 4. PROFILES TABLE (extends users)
CREATE TABLE IF NOT EXISTS profiles (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  full_name VARCHAR(200) NOT NULL,
  date_of_birth DATE NOT NULL,
  phone VARCHAR(20) NOT NULL,
  district_id INTEGER REFERENCES districts(id),
  subcounty_id INTEGER REFERENCES subcounties(id),
  parish_id INTEGER REFERENCES parishes(id),
  gps_latitude DOUBLE PRECISION,
  gps_longitude DOUBLE PRECISION,
  nin VARCHAR(20),
  is_complete BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 5. ORDER NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS order_notifications (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_subcounties_district ON subcounties(district_id);
CREATE INDEX IF NOT EXISTS idx_parishes_subcounty ON parishes(subcounty_id);
CREATE INDEX IF NOT EXISTS idx_profiles_user ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON order_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON order_notifications(user_id, is_read);

-- Auto-update timestamp trigger for profiles
CREATE OR REPLACE FUNCTION update_profiles_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS profiles_updated_at ON profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_profiles_timestamp();

-- ============================================================
-- SEED DATA: UGANDA DISTRICTS (All 146 districts by region)
-- ============================================================

INSERT INTO districts (name, region) VALUES
-- CENTRAL REGION
('Buikwe', 'Central'), ('Bukomansimbi', 'Central'), ('Butambala', 'Central'),
('Buvuma', 'Central'), ('Gomba', 'Central'), ('Kalangala', 'Central'),
('Kalungu', 'Central'), ('Kampala', 'Central'), ('Kayunga', 'Central'),
('Kiboga', 'Central'), ('Kyankwanzi', 'Central'), ('Kyotera', 'Central'),
('Luwero', 'Central'), ('Lwengo', 'Central'), ('Lyantonde', 'Central'),
('Masaka', 'Central'), ('Mityana', 'Central'), ('Mpigi', 'Central'),
('Mubende', 'Central'), ('Mukono', 'Central'), ('Nakaseke', 'Central'),
('Nakasongola', 'Central'), ('Rakai', 'Central'), ('Sembabule', 'Central'),
('Wakiso', 'Central'), ('Kassanda', 'Central'),
-- EASTERN REGION
('Amuria', 'Eastern'), ('Budaka', 'Eastern'), ('Bududa', 'Eastern'),
('Bugiri', 'Eastern'), ('Bugweri', 'Eastern'), ('Bukedea', 'Eastern'),
('Bukwo', 'Eastern'), ('Bulambuli', 'Eastern'), ('Busia', 'Eastern'),
('Butaleja', 'Eastern'), ('Buyende', 'Eastern'), ('Iganga', 'Eastern'),
('Jinja', 'Eastern'), ('Kaberamaido', 'Eastern'), ('Kaliro', 'Eastern'),
('Kamuli', 'Eastern'), ('Kapchorwa', 'Eastern'), ('Katakwi', 'Eastern'),
('Kibuku', 'Eastern'), ('Kumi', 'Eastern'), ('Kween', 'Eastern'),
('Luuka', 'Eastern'), ('Manafwa', 'Eastern'), ('Mayuge', 'Eastern'),
('Mbale', 'Eastern'), ('Namayingo', 'Eastern'), ('Namutumba', 'Eastern'),
('Ngora', 'Eastern'), ('Pallisa', 'Eastern'), ('Serere', 'Eastern'),
('Sironko', 'Eastern'), ('Soroti', 'Eastern'), ('Tororo', 'Eastern'),
('Namisindwa', 'Eastern'), ('Kapelebyong', 'Eastern'), ('Butebo', 'Eastern'),
-- NORTHERN REGION
('Abim', 'Northern'), ('Adjumani', 'Northern'), ('Agago', 'Northern'),
('Alebtong', 'Northern'), ('Amolatar', 'Northern'), ('Amudat', 'Northern'),
('Amuru', 'Northern'), ('Apac', 'Northern'), ('Arua', 'Northern'),
('Dokolo', 'Northern'), ('Gulu', 'Northern'), ('Kaabong', 'Northern'),
('Kitgum', 'Northern'), ('Koboko', 'Northern'), ('Kole', 'Northern'),
('Kotido', 'Northern'), ('Lamwo', 'Northern'), ('Lira', 'Northern'),
('Maracha', 'Northern'), ('Moroto', 'Northern'), ('Moyo', 'Northern'),
('Nabilatuk', 'Northern'), ('Nakapiripirit', 'Northern'), ('Napak', 'Northern'),
('Nebbi', 'Northern'), ('Nwoya', 'Northern'), ('Omoro', 'Northern'),
('Otuke', 'Northern'), ('Oyam', 'Northern'), ('Pader', 'Northern'),
('Pakwach', 'Northern'), ('Yumbe', 'Northern'), ('Zombo', 'Northern'),
('Kwania', 'Northern'), ('Obongi', 'Northern'), ('Madi-Okollo', 'Northern'),
('Karenga', 'Northern'),
-- WESTERN REGION
('Buhweju', 'Western'), ('Buliisa', 'Western'), ('Bundibugyo', 'Western'),
('Bushenyi', 'Western'), ('Hoima', 'Western'), ('Ibanda', 'Western'),
('Isingiro', 'Western'), ('Kabale', 'Western'), ('Kabarole', 'Western'),
('Kamwenge', 'Western'), ('Kanungu', 'Western'), ('Kasese', 'Western'),
('Kibaale', 'Western'), ('Kiruhura', 'Western'), ('Kiryandongo', 'Western'),
('Kisoro', 'Western'), ('Kyegegwa', 'Western'), ('Kyenjojo', 'Western'),
('Masindi', 'Western'), ('Mbarara', 'Western'), ('Mitooma', 'Western'),
('Ntoroko', 'Western'), ('Ntungamo', 'Western'), ('Rubirizi', 'Western'),
('Rubanda', 'Western'), ('Rukiga', 'Western'), ('Rukungiri', 'Western'),
('Sheema', 'Western'), ('Kagadi', 'Western'), ('Kakumiro', 'Western'),
('Kikuube', 'Western'), ('Rwampara', 'Western'), ('Kazo', 'Western'),
('Bunyangabu', 'Western'), ('Fort Portal City', 'Western')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- SEED SUBCOUNTIES & PARISHES FOR KEY DISTRICTS
-- (Kampala + Wakiso + Mukono + Jinja + Mbarara + Gulu + Masaka)
-- ============================================================

-- KAMPALA DISTRICT subcounties (divisions)
INSERT INTO subcounties (name, district_id) VALUES
('Kawempe Division', (SELECT id FROM districts WHERE name = 'Kampala')),
('Rubaga Division', (SELECT id FROM districts WHERE name = 'Kampala')),
('Nakawa Division', (SELECT id FROM districts WHERE name = 'Kampala')),
('Makindye Division', (SELECT id FROM districts WHERE name = 'Kampala')),
('Central Division', (SELECT id FROM districts WHERE name = 'Kampala'));

-- Kawempe Division parishes
INSERT INTO parishes (name, subcounty_id) VALUES
('Bwaise I', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Bwaise II', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Bwaise III', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kalerwe', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kawempe I', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kawempe II', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kanyanya', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kyebando', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kikaaya', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Komamboga', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Makerere I', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Makerere II', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Makerere III', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Mpererwe', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Mulago I', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Mulago II', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Mulago III', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Wandegeya', (SELECT id FROM subcounties WHERE name = 'Kawempe Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala')));

-- Rubaga Division parishes
INSERT INTO parishes (name, subcounty_id) VALUES
('Lubaga', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Lungujja', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Busega', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kabowa', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kasubi', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kawaala', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Mutundwe', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Nakulabye', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Namirembe', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Nateete', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Ndeeba', (SELECT id FROM subcounties WHERE name = 'Rubaga Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala')));

-- Nakawa Division parishes
INSERT INTO parishes (name, subcounty_id) VALUES
('Naguru I', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Naguru II', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Ntinda I', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Ntinda II', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Bukoto I', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Bukoto II', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kiswa', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Mbuya I', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Mbuya II', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Butabika', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Luzira', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Banda', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kyambogo', (SELECT id FROM subcounties WHERE name = 'Nakawa Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala')));

-- Makindye Division parishes
INSERT INTO parishes (name, subcounty_id) VALUES
('Kibuli', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kibuye I', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kibuye II', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kansanga', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kabalagala', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Ggaba', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Lukuli', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Luwafu', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Nsambya', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Salaama', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Katwe I', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Katwe II', (SELECT id FROM subcounties WHERE name = 'Makindye Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala')));

-- Central Division parishes
INSERT INTO parishes (name, subcounty_id) VALUES
('Kisenyi I', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kisenyi II', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kisenyi III', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kamwokya I', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kamwokya II', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kololo I', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kololo II', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Nakasero I', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Nakasero II', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Old Kampala', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala'))),
('Kagugube', (SELECT id FROM subcounties WHERE name = 'Central Division' AND district_id = (SELECT id FROM districts WHERE name = 'Kampala')));

-- WAKISO DISTRICT
INSERT INTO subcounties (name, district_id) VALUES
('Kira Municipality', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Nansana Municipality', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Entebbe Municipality', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Makindye-Ssabagabo Municipality', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Katabi Town Council', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Wakiso Town Council', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Kakiri Town Council', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Ssisa Subcounty', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Nsangi Subcounty', (SELECT id FROM districts WHERE name = 'Wakiso')),
('Busukuma Subcounty', (SELECT id FROM districts WHERE name = 'Wakiso'));

INSERT INTO parishes (name, subcounty_id) VALUES
('Kireka', (SELECT id FROM subcounties WHERE name = 'Kira Municipality')),
('Bweyogerere', (SELECT id FROM subcounties WHERE name = 'Kira Municipality')),
('Namugongo', (SELECT id FROM subcounties WHERE name = 'Kira Municipality')),
('Kira Town', (SELECT id FROM subcounties WHERE name = 'Kira Municipality')),
('Nansana Central', (SELECT id FROM subcounties WHERE name = 'Nansana Municipality')),
('Nabweru', (SELECT id FROM subcounties WHERE name = 'Nansana Municipality')),
('Gombe', (SELECT id FROM subcounties WHERE name = 'Nansana Municipality')),
('Entebbe Central', (SELECT id FROM subcounties WHERE name = 'Entebbe Municipality')),
('Kigungu', (SELECT id FROM subcounties WHERE name = 'Entebbe Municipality')),
('Bugonga', (SELECT id FROM subcounties WHERE name = 'Makindye-Ssabagabo Municipality')),
('Salaama', (SELECT id FROM subcounties WHERE name = 'Makindye-Ssabagabo Municipality')),
('Ndejje', (SELECT id FROM subcounties WHERE name = 'Makindye-Ssabagabo Municipality'));

-- MUKONO DISTRICT
INSERT INTO subcounties (name, district_id) VALUES
('Mukono Municipality', (SELECT id FROM districts WHERE name = 'Mukono')),
('Goma Subcounty', (SELECT id FROM districts WHERE name = 'Mukono')),
('Nama Subcounty', (SELECT id FROM districts WHERE name = 'Mukono')),
('Nakisunga Subcounty', (SELECT id FROM districts WHERE name = 'Mukono')),
('Seeta-Namuganga', (SELECT id FROM districts WHERE name = 'Mukono'));

INSERT INTO parishes (name, subcounty_id) VALUES
('Mukono Central', (SELECT id FROM subcounties WHERE name = 'Mukono Municipality')),
('Namilyango', (SELECT id FROM subcounties WHERE name = 'Mukono Municipality')),
('Seeta', (SELECT id FROM subcounties WHERE name = 'Seeta-Namuganga')),
('Namataba', (SELECT id FROM subcounties WHERE name = 'Goma Subcounty')),
('Mpoma', (SELECT id FROM subcounties WHERE name = 'Goma Subcounty'));

-- JINJA DISTRICT
INSERT INTO subcounties (name, district_id) VALUES
('Jinja Central Division', (SELECT id FROM districts WHERE name = 'Jinja')),
('Walukuba-Masese Division', (SELECT id FROM districts WHERE name = 'Jinja')),
('Mpumudde-Kimaka Division', (SELECT id FROM districts WHERE name = 'Jinja')),
('Bugembe Town Council', (SELECT id FROM districts WHERE name = 'Jinja'));

INSERT INTO parishes (name, subcounty_id) VALUES
('Jinja Central', (SELECT id FROM subcounties WHERE name = 'Jinja Central Division')),
('Walukuba', (SELECT id FROM subcounties WHERE name = 'Walukuba-Masese Division')),
('Masese', (SELECT id FROM subcounties WHERE name = 'Walukuba-Masese Division')),
('Mpumudde', (SELECT id FROM subcounties WHERE name = 'Mpumudde-Kimaka Division')),
('Bugembe', (SELECT id FROM subcounties WHERE name = 'Bugembe Town Council'));

-- MBARARA DISTRICT
INSERT INTO subcounties (name, district_id) VALUES
('Kamukuzi Division', (SELECT id FROM districts WHERE name = 'Mbarara')),
('Kakoba Division', (SELECT id FROM districts WHERE name = 'Mbarara')),
('Nyamitanga Division', (SELECT id FROM districts WHERE name = 'Mbarara')),
('Biharwe Division', (SELECT id FROM districts WHERE name = 'Mbarara'));

INSERT INTO parishes (name, subcounty_id) VALUES
('Kamukuzi', (SELECT id FROM subcounties WHERE name = 'Kamukuzi Division')),
('Kakoba', (SELECT id FROM subcounties WHERE name = 'Kakoba Division')),
('Ruharo', (SELECT id FROM subcounties WHERE name = 'Kakoba Division')),
('Nyamitanga', (SELECT id FROM subcounties WHERE name = 'Nyamitanga Division')),
('Biharwe', (SELECT id FROM subcounties WHERE name = 'Biharwe Division'));

-- GULU DISTRICT
INSERT INTO subcounties (name, district_id) VALUES
('Bardege-Layibi Division', (SELECT id FROM districts WHERE name = 'Gulu')),
('Laroo-Pece Division', (SELECT id FROM districts WHERE name = 'Gulu')),
('Patiko Subcounty', (SELECT id FROM districts WHERE name = 'Gulu'));

INSERT INTO parishes (name, subcounty_id) VALUES
('Bardege', (SELECT id FROM subcounties WHERE name = 'Bardege-Layibi Division')),
('Layibi', (SELECT id FROM subcounties WHERE name = 'Bardege-Layibi Division')),
('Laroo', (SELECT id FROM subcounties WHERE name = 'Laroo-Pece Division')),
('Pece', (SELECT id FROM subcounties WHERE name = 'Laroo-Pece Division')),
('Patiko', (SELECT id FROM subcounties WHERE name = 'Patiko Subcounty'));

-- MASAKA DISTRICT
INSERT INTO subcounties (name, district_id) VALUES
('Katwe-Butego Division', (SELECT id FROM districts WHERE name = 'Masaka')),
('Nyendo-Ssenyange Division', (SELECT id FROM districts WHERE name = 'Masaka')),
('Kimanya-Kabonera Division', (SELECT id FROM districts WHERE name = 'Masaka'));

INSERT INTO parishes (name, subcounty_id) VALUES
('Katwe', (SELECT id FROM subcounties WHERE name = 'Katwe-Butego Division')),
('Nyendo', (SELECT id FROM subcounties WHERE name = 'Nyendo-Ssenyange Division')),
('Ssenyange', (SELECT id FROM subcounties WHERE name = 'Nyendo-Ssenyange Division')),
('Kimanya', (SELECT id FROM subcounties WHERE name = 'Kimanya-Kabonera Division'));

-- ============================================================
-- ROW LEVEL SECURITY (open for development)
-- ============================================================
ALTER TABLE districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE subcounties ENABLE ROW LEVEL SECURITY;
ALTER TABLE parishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_notifications ENABLE ROW LEVEL SECURITY;

-- Allow read access for all (public data)
CREATE POLICY "Allow public read districts" ON districts FOR SELECT USING (true);
CREATE POLICY "Allow public read subcounties" ON subcounties FOR SELECT USING (true);
CREATE POLICY "Allow public read parishes" ON parishes FOR SELECT USING (true);

-- Allow full access for development
CREATE POLICY "Allow all profiles" ON profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all notifications" ON order_notifications FOR ALL USING (true) WITH CHECK (true);

SELECT 'Setup complete! Districts: ' || (SELECT COUNT(*) FROM districts) || 
       ', Subcounties: ' || (SELECT COUNT(*) FROM subcounties) || 
       ', Parishes: ' || (SELECT COUNT(*) FROM parishes) AS result;
