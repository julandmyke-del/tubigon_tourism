-- ═══════════════════════════════════════════════════════════════════════════════
-- TUBIGON SMART TOURISM — Security & Row Level Security (RLS) Hardening
-- Safe, non-destructive migration script to enforce strict RBAC & RLS policies.
-- Run this in the Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── 1. SECURITY HELPER FUNCTIONS ─────────────────────────────────────────────

-- Function to check if the authenticated user is an Admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.profiles p
    JOIN public.roles r ON p.role_id = r.id
    WHERE p.id = auth.uid() 
      AND r.name = 'admin'
      AND p.deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Function to check if the authenticated user is a Tourism Partner
CREATE OR REPLACE FUNCTION public.is_partner()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.profiles p
    JOIN public.roles r ON p.role_id = r.id
    WHERE p.id = auth.uid() 
      AND r.name = 'tourism_partner'
      AND p.deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Function to check if the authenticated user is LGU Staff
CREATE OR REPLACE FUNCTION public.is_lgu()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.profiles p
    JOIN public.roles r ON p.role_id = r.id
    WHERE p.id = auth.uid() 
      AND r.name = 'lgu_staff'
      AND p.deleted_at IS NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ─── 2. ENABLE RLS ON ALL CORE TABLES ──────────────────────────────────────────

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tourism_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_notifications ENABLE ROW LEVEL SECURITY;

-- ─── 3. PROFILES POLICIES ──────────────────────────────────────────────────────

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id OR public.is_admin());

-- ─── 4. RESERVATION POLICIES ───────────────────────────────────────────────────

DROP POLICY IF EXISTS "reservations_tourist_select" ON public.reservations;
CREATE POLICY "reservations_tourist_select" ON public.reservations
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = partner_id OR public.is_admin());

DROP POLICY IF EXISTS "reservations_tourist_insert" ON public.reservations;
CREATE POLICY "reservations_tourist_insert" ON public.reservations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "reservations_tourist_update" ON public.reservations;
CREATE POLICY "reservations_tourist_update" ON public.reservations
  FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = partner_id OR public.is_admin());

-- ─── 5. TOURISM LISTINGS POLICIES ──────────────────────────────────────────────

DROP POLICY IF EXISTS "tourism_listings_public_select" ON public.tourism_listings;
CREATE POLICY "tourism_listings_public_select" ON public.tourism_listings
  FOR SELECT USING (deleted_at IS NULL AND is_active = true OR auth.uid() = owner_id OR public.is_admin());

DROP POLICY IF EXISTS "tourism_listings_partner_manage" ON public.tourism_listings;
CREATE POLICY "tourism_listings_partner_manage" ON public.tourism_listings
  FOR ALL USING (auth.uid() = owner_id OR public.is_admin());

-- ─── 6. PARTNER NOTIFICATIONS POLICIES ────────────────────────────────────────

DROP POLICY IF EXISTS "partner_notifications_owner" ON public.partner_notifications;
CREATE POLICY "partner_notifications_owner" ON public.partner_notifications
  FOR ALL USING (auth.uid() = user_id OR public.is_admin());

-- ═══════════════════════════════════════════════════════════════════════════════
-- RLS HARDENING COMPLETE
-- ═══════════════════════════════════════════════════════════════════════════════
