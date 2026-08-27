-- ─── EXTENSIONS ──────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── TABLES ──────────────────────────────────────────────────────────────────

-- 1. Roles Table
CREATE TABLE public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 2. Profiles Table (Linked to auth.users)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role_id UUID REFERENCES public.roles(id) ON DELETE RESTRICT NOT NULL,
    avatar_url TEXT,
    phone TEXT,
    bio TEXT,
    language TEXT DEFAULT 'en' NOT NULL,
    is_verified BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ,
    CONSTRAINT fk_profiles_auth FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- 3. Spot Categories Table
CREATE TABLE public.spot_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integer_id SERIAL UNIQUE NOT NULL, -- Bridging key for Flutter integer IDs
    name TEXT UNIQUE NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 4. Tourist Spots Table
CREATE TABLE public.tourist_spots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integer_id SERIAL UNIQUE NOT NULL, -- Bridging key for Flutter integer IDs
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT,
    category_id UUID REFERENCES public.spot_categories(id) ON DELETE SET NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    entrance_fee NUMERIC DEFAULT 0 NOT NULL,
    opening_hours TEXT,
    eco_tips TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
    images TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
    average_rating NUMERIC DEFAULT 0 NOT NULL,
    review_count INT DEFAULT 0 NOT NULL,
    is_featured BOOLEAN DEFAULT false NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 5. Establishments Table
CREATE TABLE public.establishments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integer_id SERIAL UNIQUE NOT NULL, -- Bridging key for Flutter integer IDs
    name TEXT NOT NULL,
    category TEXT,
    description TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    phone TEXT,
    email TEXT,
    website TEXT,
    business_hours TEXT,
    images TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
    average_rating NUMERIC DEFAULT 0 NOT NULL,
    review_count INT DEFAULT 0 NOT NULL,
    is_verified BOOLEAN DEFAULT false NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 6. MSMEs Table
CREATE TABLE public.msmes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integer_id SERIAL UNIQUE NOT NULL, -- Bridging key for Flutter integer IDs
    profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    tagline TEXT,
    description TEXT,
    phone TEXT,
    address TEXT,
    business_hours TEXT,
    rating NUMERIC DEFAULT 0 NOT NULL,
    review_count INT DEFAULT 0 NOT NULL,
    color TEXT,
    icon TEXT,
    is_verified BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 7. Reservation Status Table
CREATE TABLE public.reservation_status (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 8. Reservations Table
CREATE TABLE public.reservations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reservable_type TEXT NOT NULL, -- 'spot', 'msme', 'establishment'
    reservable_id UUID NOT NULL,
    reservation_date TIMESTAMPTZ NOT NULL,
    start_time TEXT,
    end_time TEXT,
    guests INT DEFAULT 1 NOT NULL,
    status_id UUID REFERENCES public.reservation_status(id) ON DELETE RESTRICT NOT NULL,
    notes TEXT,
    total_amount NUMERIC DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 9. Favorites Table
CREATE TABLE public.favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    favoritable_type TEXT NOT NULL, -- 'spot', 'msme', 'establishment'
    favoritable_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ,
    UNIQUE(user_id, favoritable_type, favoritable_id)
);

-- 10. Reviews Table
CREATE TABLE public.reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    reviewable_type TEXT NOT NULL, -- 'spot', 'msme', 'establishment'
    reviewable_id UUID NOT NULL,
    rating INT NOT NULL,
    content TEXT,
    images TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 11. Ratings Table
CREATE TABLE public.ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    rateable_type TEXT NOT NULL, -- 'spot', 'msme', 'establishment'
    rateable_id UUID NOT NULL,
    value INT NOT NULL CHECK (value BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ,
    UNIQUE(user_id, rateable_type, rateable_id)
);

-- 12. Waste Reports Table
CREATE TABLE public.waste_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    location_description TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    images TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
    status TEXT DEFAULT 'pending' NOT NULL, -- 'pending', 'under_review', 'resolved'
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 13. Eco Tips Table
CREATE TABLE public.eco_tips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integer_id SERIAL UNIQUE NOT NULL, -- Bridging key for Flutter integer IDs
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT,
    spot_id UUID REFERENCES public.tourist_spots(id) ON DELETE SET NULL,
    language TEXT DEFAULT 'en' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 14. Announcements Table
CREATE TABLE public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    category TEXT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 15. Notifications Table
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    data JSONB DEFAULT '{}'::JSONB NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 16. Emergency Contacts Table
CREATE TABLE public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integer_id SERIAL UNIQUE NOT NULL, -- Bridging key for Flutter integer IDs
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    phone TEXT NOT NULL,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 17. Ferry Schedules Table
CREATE TABLE public.ferry_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integer_id SERIAL UNIQUE NOT NULL, -- Bridging key for Flutter integer IDs
    operator TEXT NOT NULL,
    route TEXT NOT NULL,
    departure_time TEXT NOT NULL,
    arrival_time TEXT,
    fare NUMERIC,
    status TEXT DEFAULT 'on_time' NOT NULL,
    days_of_week TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 18. Images Table
CREATE TABLE public.images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    url TEXT NOT NULL,
    bucket TEXT NOT NULL,
    owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 19. Activity Logs Table
CREATE TABLE public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- 20. Settings Table
CREATE TABLE public.settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    notifications_enabled BOOLEAN DEFAULT true NOT NULL,
    location_enabled BOOLEAN DEFAULT true NOT NULL,
    offline_mode BOOLEAN DEFAULT false NOT NULL,
    language TEXT DEFAULT 'en' NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ,
    UNIQUE(user_id)
);

-- ─── DATABASE INDEXES ────────────────────────────────────────────────────────
CREATE INDEX idx_spots_slug ON public.tourist_spots(slug);
CREATE INDEX idx_spots_featured ON public.tourist_spots(is_featured) WHERE is_active = true;
CREATE INDEX idx_reservations_user ON public.reservations(user_id);
CREATE INDEX idx_favorites_user ON public.favorites(user_id);
CREATE INDEX idx_reviews_type_id ON public.reviews(reviewable_type, reviewable_id);

-- ─── AUTH TRIGGERS & FUNCTIONS ───────────────────────────────────────────────

-- Insert roles defaults
INSERT INTO public.roles (name) VALUES ('tourist'), ('msme_owner'), ('lgu_staff'), ('admin')
ON CONFLICT (name) DO NOTHING;

-- Insert default reservation status types
INSERT INTO public.reservation_status (name) VALUES ('pending'), ('confirmed'), ('completed'), ('cancelled')
ON CONFLICT (name) DO NOTHING;

-- Trigger Function: Auto-populate user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    default_role_id UUID;
BEGIN
    SELECT id INTO default_role_id FROM public.roles WHERE name = 'tourist';
    
    INSERT INTO public.profiles (id, name, email, role_id, is_verified, created_at, updated_at)
    VALUES (
        new.id,
        coalesce(new.raw_user_meta_data->>'name', 'Explorer'),
        new.email,
        default_role_id,
        false,
        now(),
        now()
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind Trigger to auth.users
CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── ROW LEVEL SECURITY (RLS) POLICIES ───────────────────────────────────────

-- Enable RLS on all tables
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spot_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tourist_spots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.establishments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.msmes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservation_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waste_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eco_tips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ferry_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- 1. Helper function to check if active user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT r.name INTO user_role 
    FROM public.profiles p 
    JOIN public.roles r ON p.role_id = r.id 
    WHERE p.id = auth.uid();
    RETURN (user_role = 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Helper function to check if active user is LGU Staff
CREATE OR REPLACE FUNCTION public.is_lgu()
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT r.name INTO user_role 
    FROM public.profiles p 
    JOIN public.roles r ON p.role_id = r.id 
    WHERE p.id = auth.uid();
    RETURN (user_role = 'lgu_staff' OR user_role = 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- General policy layouts:
-- PUBLIC TABLES (Read: Anyone, Write: LGU/Admin)
CREATE POLICY "Allow public read access" ON public.spot_categories FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Allow public read access" ON public.tourist_spots FOR SELECT USING (deleted_at IS NULL AND is_active = true);
CREATE POLICY "Allow public read access" ON public.establishments FOR SELECT USING (deleted_at IS NULL AND is_active = true);
CREATE POLICY "Allow public read access" ON public.msmes FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Allow public read access" ON public.eco_tips FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Allow public read access" ON public.emergency_contacts FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Allow public read access" ON public.ferry_schedules FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Allow public read access" ON public.announcements FOR SELECT USING (deleted_at IS NULL AND is_active = true);

-- Write policies for LGU/Admin on public content tables
CREATE POLICY "Allow write for LGU and Admin" ON public.tourist_spots FOR ALL USING (public.is_lgu());
CREATE POLICY "Allow write for LGU and Admin" ON public.establishments FOR ALL USING (public.is_lgu());
CREATE POLICY "Allow write for LGU and Admin" ON public.ferry_schedules FOR ALL USING (public.is_lgu());
CREATE POLICY "Allow write for LGU and Admin" ON public.announcements FOR ALL USING (public.is_lgu());

-- PROFILES
CREATE POLICY "Profiles read to authenticated" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Profiles update by owner" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- SETTINGS
CREATE POLICY "Settings manage by owner" ON public.settings FOR ALL USING (auth.uid() = user_id);

-- RESERVATIONS (Read/Write by user owner, MSME owners, or LGU/Admin)
CREATE POLICY "Reservations owner read write" ON public.reservations FOR ALL USING (auth.uid() = user_id);

-- FAVORITES
CREATE POLICY "Favorites owner read write" ON public.favorites FOR ALL USING (auth.uid() = user_id);

-- REVIEWS & RATINGS
CREATE POLICY "Reviews anyone read" ON public.reviews FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Reviews owner write" ON public.reviews FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Ratings owner write" ON public.ratings FOR ALL USING (auth.uid() = user_id);

-- WASTE REPORTS
CREATE POLICY "Waste reports read to owner and LGU" ON public.waste_reports FOR SELECT USING (auth.uid() = user_id OR public.is_lgu());
CREATE POLICY "Waste reports write to owner" ON public.waste_reports FOR ALL USING (auth.uid() = user_id);

-- NOTIFICATIONS
CREATE POLICY "Notifications manage by owner" ON public.notifications FOR ALL USING (auth.uid() = user_id);

-- ─── SEED DEFAULT ADMIN USER ──────────────────────────────────────────────────
-- Enable pgcrypto if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$ 
DECLARE 
    v_user_id UUID := 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
    v_email TEXT := 'admin@gmail.com';
    v_password TEXT := 'admin123';
    v_admin_role_id UUID;
BEGIN
    -- 1. Insert user into auth.users if they don't exist
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = v_email) THEN
        INSERT INTO auth.users (
            id, instance_id, aud, role, email, 
            encrypted_password, email_confirmed_at, 
            raw_app_meta_data, raw_user_meta_data, 
            created_at, updated_at
        ) VALUES (
            v_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 
            'authenticated', v_email, 
            extensions.crypt(v_password, extensions.gen_salt('bf')), 
            NOW(), '{"provider":"email","providers":["email"]}', '{"name": "System Admin"}', 
            NOW(), NOW()
        );

        -- 2. Insert user into auth.identities
        INSERT INTO auth.identities (
            id, user_id, identity_data, provider, 
            provider_id, last_sign_in_at, created_at, updated_at
        ) VALUES (
            v_user_id, v_user_id, 
            format('{"sub": "%s", "email": "%s"}', v_user_id::text, v_email)::jsonb, 
            'email', v_user_id::text, NOW(), NOW(), NOW()
        );
    END IF;

    -- 3. Get the admin role ID
    SELECT id INTO v_admin_role_id FROM public.roles WHERE name = 'admin';

    -- 4. Set the profile's role to Admin (trigger automatically inserted it as tourist)
    UPDATE public.profiles
    SET role_id = v_admin_role_id, is_verified = true
    WHERE id = v_user_id;
END $$;

-- ─── SYSTEM SETTINGS & ADMIN NOTIFICATIONS ────────────────────────────────────

-- 1. System Settings Table
CREATE TABLE public.system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    app_name TEXT DEFAULT 'Tubigon Smart Tourism' NOT NULL,
    contact_email TEXT DEFAULT 'support@tubigontourism.gov.ph' NOT NULL,
    contact_phone TEXT DEFAULT '+63 38 508 8000' NOT NULL,
    privacy_policy TEXT,
    terms_of_service TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 2. Admin Notifications Table
CREATE TABLE public.admin_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL, -- e.g., 'new_reservation', 'msme_application', 'waste_report'
    data JSONB DEFAULT '{}'::JSONB NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;

-- Policies for System Settings
CREATE POLICY "Allow public read access" ON public.system_settings FOR SELECT USING (true);
CREATE POLICY "Allow write for Admin" ON public.system_settings FOR ALL USING (public.is_admin());

-- Policies for Admin Notifications
CREATE POLICY "Allow manage for Admin" ON public.admin_notifications FOR ALL USING (public.is_admin());

-- Seed default system settings
INSERT INTO public.system_settings (app_name, contact_email, contact_phone, privacy_policy, terms_of_service)
VALUES ('Tubigon Smart Tourism', 'support@tubigontourism.gov.ph', '+63 38 508 8000', 'Privacy Policy Content', 'Terms of Service Content')
ON CONFLICT DO NOTHING;


