-- =============================================================================
-- Migration: 20261030000000_qaza_supabase_core_schema.sql
-- Description: Core Schema & Row Level Security (RLS) for Qaza Namaz
-- Cloud Target: Supabase (PostgreSQL) + PowerSync Edition 3
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Helper function for auto-updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- 1. account_profiles: User's calculation profile (DOB, puberty, start date)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.account_profiles (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payload_json JSONB NOT NULL,
  entity_version INTEGER NOT NULL DEFAULT 1,
  writer_device_id TEXT NOT NULL,
  operation_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT uq_account_profiles_user UNIQUE (user_id)
);

CREATE TRIGGER update_account_profiles_updated_at
  BEFORE UPDATE ON public.account_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 2. account_plan_revisions: Historical revisions of the calculation plan
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.account_plan_revisions (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  revision_id TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT uq_account_plan_revisions_user_revision UNIQUE (user_id, revision_id)
);

-- -----------------------------------------------------------------------------
-- 3. qaza_additions: Batch addition groups of missed prayers
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.qaza_additions (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mode TEXT NOT NULL,
  input_snapshot JSONB NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TRIGGER update_qaza_additions_updated_at
  BEFORE UPDATE ON public.qaza_additions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 4. qaza_records: Individual Qaza prayer records
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.qaza_records (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  prayer_type TEXT NOT NULL CHECK (prayer_type IN ('fajr', 'zuhr', 'asr', 'maghrib', 'isha', 'witr')),
  original_date DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'completed')),
  completed_at TIMESTAMPTZ,
  completion_id TEXT,
  addition_id TEXT REFERENCES public.qaza_additions(id) ON DELETE SET NULL,
  record_version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT uq_qaza_records_user_prayer_date UNIQUE (user_id, prayer_type, original_date)
);

CREATE TRIGGER update_qaza_records_updated_at
  BEFORE UPDATE ON public.qaza_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 5. daily_salah_logs: Tracking of daily 5+1 prayers
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.daily_salah_logs (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  prayer_date DATE NOT NULL,
  prayer_type TEXT NOT NULL CHECK (prayer_type IN ('fajr', 'zuhr', 'asr', 'maghrib', 'isha', 'witr')),
  status TEXT NOT NULL CHECK (status IN ('prayed', 'missed', 'unrecorded')),
  tracker_created_qaza_id TEXT,
  linked_qaza_id TEXT,
  completion_sync_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT uq_daily_salah_logs_user_date_prayer UNIQUE (user_id, prayer_date, prayer_type)
);

CREATE TRIGGER update_daily_salah_logs_updated_at
  BEFORE UPDATE ON public.daily_salah_logs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- 6. qaza_deletion_actions: Undo/Delete actions
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.qaza_deletion_actions (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addition_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  resolved_at TIMESTAMPTZ,
  entity_version INTEGER NOT NULL DEFAULT 1
);

-- -----------------------------------------------------------------------------
-- 7. qaza_deletion_action_record_snapshots: Snapshots for Undo operations
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.qaza_deletion_action_record_snapshots (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  deletion_action_id TEXT NOT NULL REFERENCES public.qaza_deletion_actions(id) ON DELETE CASCADE,
  record_id TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  addition_id TEXT NOT NULL,
  prayer_type TEXT NOT NULL,
  original_date DATE NOT NULL,
  status TEXT NOT NULL,
  completed_at TIMESTAMPTZ,
  completion_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  record_version INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT uq_deletion_snapshots_action_record UNIQUE (deletion_action_id, record_id)
);

-- -----------------------------------------------------------------------------
-- 8. qaza_profile_plan_provenance: Linkage between generated records and plan
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.qaza_profile_plan_provenance (
  id TEXT PRIMARY KEY,
  record_id TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_revision_id TEXT NOT NULL,
  plan_fingerprint TEXT NOT NULL,
  CONSTRAINT uq_provenance_record UNIQUE (record_id)
);

-- -----------------------------------------------------------------------------
-- 9. user_preferences: Scoped preferences & settings
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_preferences (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_display_name TEXT,
  daily_salah_tracking_enabled BOOLEAN NOT NULL DEFAULT true,
  daily_salah_tracking_setup_dismissed BOOLEAN NOT NULL DEFAULT false,
  home_completion_mode TEXT DEFAULT 'autoSequence',
  home_auto_sequence_prayer TEXT DEFAULT 'fajr',
  home_selected_prayer TEXT DEFAULT 'fajr',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT uq_user_preferences_user UNIQUE (user_id)
);

CREATE TRIGGER update_user_preferences_updated_at
  BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- INDEXES FOR FAST QUERYING & SYNC PERFORMANCE
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_qaza_records_user_status ON public.qaza_records (user_id, status);
CREATE INDEX IF NOT EXISTS idx_qaza_records_user_prayer_status ON public.qaza_records (user_id, prayer_type, status);
CREATE INDEX IF NOT EXISTS idx_daily_salah_logs_user_date ON public.daily_salah_logs (user_id, prayer_date);
CREATE INDEX IF NOT EXISTS idx_qaza_additions_user_created ON public.qaza_additions (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_qaza_deletion_actions_user ON public.qaza_deletion_actions (user_id, created_at DESC);

-- =============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Strict Isolation: Users can ONLY access their own rows (auth.uid() = user_id)
-- =============================================================================

DO $$
DECLARE
  tbl text;
  tables text[] := ARRAY[
    'account_profiles',
    'account_plan_revisions',
    'qaza_additions',
    'qaza_records',
    'daily_salah_logs',
    'qaza_deletion_actions',
    'qaza_deletion_action_record_snapshots',
    'qaza_profile_plan_provenance',
    'user_preferences'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
    
    -- SELECT Policy
    EXECUTE format('
      DROP POLICY IF EXISTS %I ON public.%I;
      CREATE POLICY %I ON public.%I
      FOR SELECT TO authenticated
      USING (auth.uid() = user_id);
    ', tbl || '_select_own', tbl, tbl || '_select_own', tbl);

    -- INSERT Policy
    EXECUTE format('
      DROP POLICY IF EXISTS %I ON public.%I;
      CREATE POLICY %I ON public.%I
      FOR INSERT TO authenticated
      WITH CHECK (auth.uid() = user_id);
    ', tbl || '_insert_own', tbl, tbl || '_insert_own', tbl);

    -- UPDATE Policy
    EXECUTE format('
      DROP POLICY IF EXISTS %I ON public.%I;
      CREATE POLICY %I ON public.%I
      FOR UPDATE TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
    ', tbl || '_update_own', tbl, tbl || '_update_own', tbl);

    -- DELETE Policy
    EXECUTE format('
      DROP POLICY IF EXISTS %I ON public.%I;
      CREATE POLICY %I ON public.%I
      FOR DELETE TO authenticated
      USING (auth.uid() = user_id);
    ', tbl || '_delete_own', tbl, tbl || '_delete_own', tbl);
  END LOOP;
END $$;

-- =============================================================================
-- POWERSYNC PUBLICATION FOR LOGICAL REPLICATION
-- =============================================================================
DROP PUBLICATION IF EXISTS powersync;
CREATE PUBLICATION powersync FOR TABLE
  public.account_profiles,
  public.account_plan_revisions,
  public.qaza_additions,
  public.qaza_records,
  public.daily_salah_logs,
  public.qaza_deletion_actions,
  public.qaza_deletion_action_record_snapshots,
  public.qaza_profile_plan_provenance,
  public.user_preferences;
