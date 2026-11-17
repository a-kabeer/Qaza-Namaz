-- =============================================================================
-- Migration: 20261110000000_qaza_server_conflict_resolution.sql
-- Description: Server-Authoritative Conflict Resolution & Resurrection Protection
-- Cloud Target: Supabase (PostgreSQL) + PowerSync Edition 3
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. QAZA RECORDS CONFLICT RESOLUTION & RESURRECTION PROTECTION
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION enforce_qaza_record_conflict_resolution()
RETURNS TRIGGER AS $$
BEGIN
  -- Defense-in-depth ownership check
  IF auth.uid() IS NOT NULL AND NEW.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'UNAUTHORIZED_MUTATION: Record ownership % does not match authenticated user %',
      NEW.user_id, auth.uid()
      USING ERRCODE = '42501';
  END IF;

  -- Protection against stale resurrection of deleted records
  IF TG_OP = 'INSERT' THEN
    IF EXISTS (
      SELECT 1 FROM public.qaza_deletion_action_record_snapshots
      WHERE record_id = NEW.id AND user_id = NEW.user_id
    ) THEN
      RAISE EXCEPTION 'STALE_RESURRECTION_REJECTED: Record % was previously deleted under a deletion action snapshot',
        NEW.id
        USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
  END IF;

  -- Enforce version & timestamp ordering on UPDATE
  IF TG_OP = 'UPDATE' THEN
    -- Rule 1: Stale version rejection (NEW.record_version < OLD.record_version)
    IF NEW.record_version < OLD.record_version THEN
      RAISE EXCEPTION 'STALE_MUTATION_REJECTED: Incoming record_version (%) is older than stored version (%) for record %',
        NEW.record_version, OLD.record_version, OLD.id
        USING ERRCODE = 'P0001';
    END IF;

    -- Rule 2: Equal version tie-breaker via updated_at (NEW.record_version == OLD.record_version)
    IF NEW.record_version = OLD.record_version THEN
      IF NEW.updated_at IS NOT NULL AND OLD.updated_at IS NOT NULL AND NEW.updated_at < OLD.updated_at THEN
        RAISE EXCEPTION 'STALE_MUTATION_REJECTED: Incoming updated_at (%) is older than stored updated_at (%) for record %',
          NEW.updated_at, OLD.updated_at, OLD.id
          USING ERRCODE = 'P0001';
      END IF;
      -- Auto-advance version so future writes remain strictly monotonic
      NEW.record_version := OLD.record_version + 1;
    END IF;

    -- Update timestamp to authoritative server time
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_qaza_record_conflict_resolution ON public.qaza_records;
CREATE TRIGGER trg_qaza_record_conflict_resolution
  BEFORE INSERT OR UPDATE ON public.qaza_records
  FOR EACH ROW
  EXECUTE FUNCTION enforce_qaza_record_conflict_resolution();

-- -----------------------------------------------------------------------------
-- 2. ACCOUNT PROFILES CONFLICT RESOLUTION
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION enforce_account_profile_conflict_resolution()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'UNAUTHORIZED_MUTATION: Profile ownership % does not match authenticated user %',
      NEW.user_id, auth.uid()
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.entity_version < OLD.entity_version THEN
      RAISE EXCEPTION 'STALE_MUTATION_REJECTED: Incoming entity_version (%) is older than stored entity_version (%) for profile %',
        NEW.entity_version, OLD.entity_version, OLD.id
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.entity_version = OLD.entity_version THEN
      IF NEW.updated_at IS NOT NULL AND OLD.updated_at IS NOT NULL AND NEW.updated_at < OLD.updated_at THEN
        RAISE EXCEPTION 'STALE_MUTATION_REJECTED: Incoming updated_at (%) is older than stored updated_at (%) for profile %',
          NEW.updated_at, OLD.updated_at, OLD.id
          USING ERRCODE = 'P0001';
      END IF;
      NEW.entity_version := OLD.entity_version + 1;
    END IF;

    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_account_profile_conflict_resolution ON public.account_profiles;
CREATE TRIGGER trg_account_profile_conflict_resolution
  BEFORE INSERT OR UPDATE ON public.account_profiles
  FOR EACH ROW
  EXECUTE FUNCTION enforce_account_profile_conflict_resolution();

-- -----------------------------------------------------------------------------
-- 3. QAZA ADDITIONS CONFLICT RESOLUTION
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION enforce_qaza_additions_conflict_resolution()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'UNAUTHORIZED_MUTATION: Addition ownership % does not match authenticated user %',
      NEW.user_id, auth.uid()
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.revision < OLD.revision THEN
      RAISE EXCEPTION 'STALE_MUTATION_REJECTED: Incoming revision (%) is older than stored revision (%) for addition %',
        NEW.revision, OLD.revision, OLD.id
        USING ERRCODE = 'P0001';
    END IF;

    IF NEW.revision = OLD.revision THEN
      IF NEW.updated_at IS NOT NULL AND OLD.updated_at IS NOT NULL AND NEW.updated_at < OLD.updated_at THEN
        RAISE EXCEPTION 'STALE_MUTATION_REJECTED: Incoming updated_at (%) is older than stored updated_at (%) for addition %',
          NEW.updated_at, OLD.updated_at, OLD.id
          USING ERRCODE = 'P0001';
      END IF;
      NEW.revision := OLD.revision + 1;
    END IF;

    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_qaza_additions_conflict_resolution ON public.qaza_additions;
CREATE TRIGGER trg_qaza_additions_conflict_resolution
  BEFORE INSERT OR UPDATE ON public.qaza_additions
  FOR EACH ROW
  EXECUTE FUNCTION enforce_qaza_additions_conflict_resolution();

-- -----------------------------------------------------------------------------
-- 4. USER PREFERENCES & DAILY SALAH LOGS TIMESTAMP CONFLICT ENFORCEMENT
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION enforce_timestamp_conflict_resolution()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'UNAUTHORIZED_MUTATION: Ownership % does not match authenticated user %',
      NEW.user_id, auth.uid()
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.updated_at IS NOT NULL AND OLD.updated_at IS NOT NULL AND NEW.updated_at < OLD.updated_at THEN
      RAISE EXCEPTION 'STALE_MUTATION_REJECTED: Incoming updated_at (%) is older than stored updated_at (%)',
        NEW.updated_at, OLD.updated_at
        USING ERRCODE = 'P0001';
    END IF;

    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_preferences_conflict_resolution ON public.user_preferences;
CREATE TRIGGER trg_user_preferences_conflict_resolution
  BEFORE INSERT OR UPDATE ON public.user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION enforce_timestamp_conflict_resolution();

DROP TRIGGER IF EXISTS trg_daily_salah_logs_conflict_resolution ON public.daily_salah_logs;
CREATE TRIGGER trg_daily_salah_logs_conflict_resolution
  BEFORE INSERT OR UPDATE ON public.daily_salah_logs
  FOR EACH ROW
  EXECUTE FUNCTION enforce_timestamp_conflict_resolution();

-- -----------------------------------------------------------------------------
-- 5. IMMUTABLE AUDIT LOG PROTECTION FOR DELETION ACTIONS & SNAPSHOTS
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION prevent_deletion_snapshot_tampering()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'IMMUTABLE_AUDIT_LOG: Deletion action snapshots cannot be modified or deleted directly'
    USING ERRCODE = '42501';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_delete_deletion_snapshots ON public.qaza_deletion_action_record_snapshots;
CREATE TRIGGER trg_prevent_delete_deletion_snapshots
  BEFORE UPDATE OR DELETE ON public.qaza_deletion_action_record_snapshots
  FOR EACH ROW
  EXECUTE FUNCTION prevent_deletion_snapshot_tampering();
