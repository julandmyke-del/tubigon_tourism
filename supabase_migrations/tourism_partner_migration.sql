-- ═══════════════════════════════════════════════════════════════════════════════
-- TUBIGON SMART TOURISM — Tourism Partner Module Migration
-- Safe, additive-only migration. NO DROP statements. NO data deletion.
-- Run this in the Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── 1. ADD TOURISM PARTNER ROLE ─────────────────────────────────────────────
INSERT INTO public.roles (name)
VALUES ('tourism_partner')
ON CONFLICT (name) DO NOTHING;

-- ─── 2. ADD NEW RESERVATION STATUSES ─────────────────────────────────────────
INSERT INTO public.reservation_status (name)
VALUES ('approved'), ('rejected')
ON CONFLICT (name) DO NOTHING;

-- ─── 3. CREATE TOURISM LISTINGS TABLE ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tourism_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    listing_name TEXT NOT NULL,
    listing_type TEXT NOT NULL DEFAULT 'attraction',
    description TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    contact_number TEXT,
    email TEXT,
    operating_hours TEXT,
    images TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
    status TEXT DEFAULT 'active' NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    average_rating NUMERIC DEFAULT 0 NOT NULL,
    review_count INT DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- ─── 4. ADD partner_id TO RESERVATIONS ───────────────────────────────────────
-- Safe ALTER — existing rows get NULL which is fine (they have no partner)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'reservations'
          AND column_name = 'partner_id'
    ) THEN
        ALTER TABLE public.reservations
        ADD COLUMN partner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ─── 5. CREATE PARTNER NOTIFICATIONS TABLE ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.partner_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    data JSONB DEFAULT '{}'::JSONB NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    deleted_at TIMESTAMPTZ
);

-- ─── 6. INDEXES ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tourism_listings_owner ON public.tourism_listings(owner_id);
CREATE INDEX IF NOT EXISTS idx_tourism_listings_type ON public.tourism_listings(listing_type);
CREATE INDEX IF NOT EXISTS idx_tourism_listings_active ON public.tourism_listings(is_active) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reservations_partner ON public.reservations(partner_id);
CREATE INDEX IF NOT EXISTS idx_partner_notifications_user ON public.partner_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_partner_notifications_read ON public.partner_notifications(user_id, is_read);

-- ─── 7. HELPER FUNCTION: IS TOURISM PARTNER ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_tourism_partner()
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT r.name INTO user_role
    FROM public.profiles p
    JOIN public.roles r ON p.role_id = r.id
    WHERE p.id = auth.uid();
    RETURN (user_role = 'tourism_partner');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── 8. ENABLE RLS ON NEW TABLES ────────────────────────────────────────────
ALTER TABLE public.tourism_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_notifications ENABLE ROW LEVEL SECURITY;

-- ─── 9. RLS POLICIES — TOURISM LISTINGS ─────────────────────────────────────

-- Anyone authenticated can read active listings
CREATE POLICY "tourism_listings_public_read"
ON public.tourism_listings FOR SELECT
USING (deleted_at IS NULL AND is_active = true);

-- Partner can manage (SELECT/INSERT/UPDATE/DELETE) only their own listings
CREATE POLICY "tourism_listings_partner_manage"
ON public.tourism_listings FOR ALL
USING (auth.uid() = owner_id);

-- Admin has full access
CREATE POLICY "tourism_listings_admin_all"
ON public.tourism_listings FOR ALL
USING (public.is_admin());

-- ─── 10. RLS POLICIES — RESERVATIONS (PARTNER ACCESS) ───────────────────────

-- Partner can read reservations assigned to them
CREATE POLICY "reservations_partner_read"
ON public.reservations FOR SELECT
USING (auth.uid() = partner_id);

-- Partner can update reservations assigned to them (approve/reject/complete)
CREATE POLICY "reservations_partner_update"
ON public.reservations FOR UPDATE
USING (auth.uid() = partner_id);

-- ─── 11. RLS POLICIES — PARTNER NOTIFICATIONS ──────────────────────────────

-- Partner manages own notifications
CREATE POLICY "partner_notifications_owner_manage"
ON public.partner_notifications FOR ALL
USING (auth.uid() = user_id);

-- Admin can read all partner notifications
CREATE POLICY "partner_notifications_admin_read"
ON public.partner_notifications FOR SELECT
USING (public.is_admin());

-- ─── 12. RLS POLICIES — REVIEWS (PARTNER READ FOR OWN LISTINGS) ─────────────
-- Reviews already have a public read policy ("Reviews anyone read").
-- Partners can already read reviews via that existing policy.
-- No additional policy needed — they filter by listing ID in application code.

-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRATION COMPLETE
-- Verify by running: SELECT * FROM public.roles;
-- You should see: tourist, msme_owner, lgu_staff, admin, tourism_partner
-- ═══════════════════════════════════════════════════════════════════════════════
