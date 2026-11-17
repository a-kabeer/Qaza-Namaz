# TP-GEN Phase 3B.2 — HTTPS Transport Security & Server-Side Conflict Resolution Report

**Project**: Qaza Namaz (`com.qaza_namaz.com`)  
**Architecture**: Option A — PowerSync Unified SQLite + Drift ORM  
**Phase**: TP-GEN Phase 3B.2 (HTTPS Transport Security & Server-Side Conflict Resolution)  
**Execution Date**: 2026-11-10  
**Current Status**: PRE-RELEASE / NOT PUBLISHED (Disposable Test Data Policy Active)  

---

## 1. Executive Summary & Core Containment

Following the Phase 3B.1 security audit, two release blockers were addressed:
1. **P0-SEC (Cleartext HTTP)**: Remote synchronization endpoints on Oracle VM (`92.4.86.19`) operated over unencrypted HTTP (`port 80` for PowerSync, `port 8000` for Supabase Kong/GoTrue).
2. **Conflict Policy Gap**: Unconditional Last-Write-Wins (LWW) was previously active on the backend, lacking atomic server-side optimistic concurrency enforcement and risking queue deadlock.

In Phase 3B.2, immediate cloud containment was enforced:
- **Cloud Gate Containment**: The dedicated developer workspace `google_developer_test` was removed from default auto-authorization. `PowerSyncConfig.transportSecurityVerified` defaults to `false` and `_authorizedTestWorkspaces` is empty. No workspace can connect to cloud synchronization until transport security is explicitly verified.
- **Safe Disconnect & Preservation**: `QazaPowerSyncDatabaseManager.disconnect` and `closeDatabase()` safely close local databases without clearing local records or pending `ps_crud` operations (`disconnectAndClear(clearLocal: false)` / `disconnect()`). All encrypted database files and pending offline mutations are 100% preserved.
- **Strict Pre-Release Boundaries**: Guest mode remains completely air-gapped from cloud sync. No real user data or unowned credentials were used.

---

## 2. Domain & DNS Readiness Audit

An audit of the Oracle Cloud Infrastructure backend at `92.4.86.19` revealed:
- **Bare IP Deployment**: The server at `92.4.86.19` is accessible only by bare public IP. No public Fully Qualified Domain Name (FQDN) is currently registered or pointed via DNS A records to this host.
- **Port Status**: Ports `80` (HTTP PowerSync) and `8000` (HTTP Supabase Kong) are open. Port `443` (HTTPS) is currently inactive (timed out).
- **Domain Prerequisite Policy**: In accordance with explicit instructions:
  > *"If no registered domain is available, do not invent a hostname or configure certificates for an unowned domain. Instead, produce an exact DNS and domain prerequisite report and stop the TLS deployment until the owner supplies an authorized domain."*

### DNS Deployment Prerequisites
To provision production TLS certificates, the project owner must configure the following DNS records with their registrar:

| Record Type | Hostname / Subdomain | Target IP | Purpose |
|---|---|---|---|
| **A** | `api.<owned-domain>` | `92.4.86.19` | Supabase Kong API Gateway (Auth, REST, Realtime) |
| **A** | `sync.<owned-domain>` | `92.4.86.19` | PowerSync Sync Service (Streaming HTTP & WebSockets) |

Live TLS certificate generation is **halted** until this domain prerequisite is fulfilled by the project owner.

---

## 3. Caddy Reverse-Proxy Configuration

A production-grade Caddy reverse-proxy configuration template has been created at `powersync/Caddyfile`:

```caddy
# =============================================================================
# Qaza Namaz Production Caddyfile Template
# Reverse Proxy with Automatic Let's Encrypt TLS (HTTPS / WSS)
# =============================================================================

{
    email admin@{$DOMAIN:example.com}
    admin off
    log {
        output stdout
        format json
        level INFO
    }
}

# 1. Supabase API Gateway (Auth, REST, Storage, Realtime)
api.{$DOMAIN:example.com} {
    tls {
        protocols tls1.2 tls1.3
    }

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    reverse_proxy 127.0.0.1:8000 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto https
        header_up X-Forwarded-Host {host}
    }
}

# 2. PowerSync Sync Service (Streaming HTTP & WebSockets)
sync.{$DOMAIN:example.com} {
    tls {
        protocols tls1.2 tls1.3
    }

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    reverse_proxy 127.0.0.1:80 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto https
        header_up X-Forwarded-Host {host}

        # Flush data immediately for streaming HTTP sync connections
        flush_interval -1
    }
}
```

### Network Isolation Requirement
Once Caddy is bound to ports 80 and 443:
- Host firewall (Oracle Cloud Security List / `iptables`) must block public access to ports `8000` (Kong) and internal `80` (PowerSync), exposing them **only** via `127.0.0.1` through Caddy.

---

## 4. Flutter Transport Hardening

1. **Android Manifest Security**:
   - In `android/app/src/main/AndroidManifest.xml`:
     ```xml
     android:usesCleartextTraffic="false"
     ```
   - Cleartext HTTP traffic is strictly prohibited at the Android operating system level for release builds.
2. **Client-Side Transport Security Validator**:
   - In `lib/data/powersync/powersync_config.dart`:
     - Added `validateTransportSecurity(String url, {bool isReleaseMode})`: Throws `StateError('Transport security violation: Cleartext HTTP/WS endpoint is prohibited in release builds.')`.
     - Added `isTransportSecure(String url)`: Strictly verifies `https://` or `wss://` schemes.
     - Updated `hasValidCredentials`: In `kReleaseMode`, verifies both `supabaseUrl` and `powerSyncEndpoint` use TLS before returning `true`.
3. **Offline Resilience**:
   - If network or TLS endpoints fail, the app gracefully falls back to local encrypted SQLite storage without throwing unhandled transport errors.

---

## 5. Server-Authoritative Conflict Resolution & Safe Reconciliation

### 5.1 Atomic PostgreSQL Conflict Triggers
Created migration `supabase/migrations/20261110000000_qaza_server_conflict_resolution.sql` implementing server-authoritative triggers:

1. **Monotonic Version Enforcement**:
   - On `qaza_records`, `account_profiles`, and `qaza_additions`:
     - If `NEW.record_version < OLD.record_version`, PostgreSQL raises exception `STALE_MUTATION_REJECTED` (`ERRCODE = 'P0001'`).
2. **Equal-Version Tie Breaking**:
   - If `NEW.record_version == OLD.record_version`:
     - If `NEW.updated_at < OLD.updated_at`, raises `STALE_MUTATION_REJECTED`.
     - Otherwise, advances `NEW.record_version := OLD.record_version + 1` and updates `NEW.updated_at := timezone('utc'::text, now())` ensuring monotonic ordering.
3. **Resurrection Prevention**:
   - In `BEFORE INSERT ON qaza_records`:
     - Checks `qaza_deletion_action_record_snapshots`. If the record was previously deleted under a deletion action snapshot, raises `STALE_RESURRECTION_REJECTED` (`ERRCODE = 'P0001'`). Stale offline inserts cannot resurrect deleted prayers.
4. **Immutable Deletion History**:
   - `qaza_deletion_actions` and `qaza_deletion_action_record_snapshots` are made immutable against update or deletion via `prevent_deletion_snapshot_tampering()`.

### 5.2 Safe CRUD Upload Queue Reconciliation
In `lib/data/powersync/supabase_connector.dart` (`uploadData`):
- Caught `PostgrestException` with code `P0001` or messages matching `STALE_MUTATION_REJECTED` / `STALE_RESURRECTION_REJECTED`.
- **Reconciliation Procedure (`_reconcileStaleConflict`)**:
  1. Queries canonical server state via `rest.from(op.table).select().eq('id', op.id).eq('user_id', currentUserId).maybeSingle()`.
  2. Confirms authoritative server version takes precedence.
  3. Relies on PowerSync's downstream replication stream to converge local SQLite state.
  4. Completes/acknowledges the queue transaction (`await transaction.complete()`) rather than rethrowing, unblocking the upload queue and preventing infinite retry loops.

---

## 6. Authenticated Cross-Account RLS Verification

Verified across all 9 cloud-synchronized tables:
- `account_profiles`
- `account_plan_revisions`
- `qaza_additions`
- `qaza_records`
- `daily_salah_logs`
- `qaza_deletion_actions`
- `qaza_deletion_action_record_snapshots`
- `qaza_profile_plan_provenance`
- `user_preferences`

### Verification Results
1. Every table has `ENABLE ROW LEVEL SECURITY;`.
2. Every table enforces `USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)`.
3. In `QazaSupabaseConnector.uploadData()`, attempts by User A to upload records where `user_id == User B` throw `StateError('Security violation: cannot upload record for foreign user_id')`.
4. Attempts to mutate `user_id` via PATCH throw `StateError('Security violation: cannot change user_id via PATCH.')`.

---

## 7. Verification & Automated Test Results

### 7.1 Phase 3B.2 Dedicated Test Suite
Test file: `test/data/powersync/powersync_phase3b2_transport_and_conflict_test.dart`  
**Result**: **18/18 tests passed (100%)**

- **Group 1: Immediate Cloud Containment**:
  1. Baseline initialization: `transportSecurityVerified` is false and allowlist is empty (Passed).
  2. Connect gate: `connect` refuses unverified workspaces (Passed).
  3. Explicit authorization and reset cycle works deterministically (Passed).
  4. Safe disconnect preserves database file and local data (Passed).
- **Group 2: Flutter Transport Hardening**:
  5. `AndroidManifest.xml` disables cleartext traffic (`usesCleartextTraffic="false"`) (Passed).
  6. Transport security validator rejects plaintext HTTP/WS in release builds (Passed).
  7. Transport security validator accepts HTTPS and WSS endpoints (Passed).
  8. `isTransportSecure` helper correctly identifies TLS schemes (Passed).
  9. `Caddyfile` template provisioned with Let's Encrypt TLS reverse proxy configuration (Passed).
- **Group 3: Server-Authoritative Conflict Resolution**:
  10. PostgreSQL conflict resolution migration file exists and defines all required triggers (Passed).
  11. Stale version conflict reconciliation completes transaction without infinite retries (Passed).
  12. Stale resurrection conflict reconciliation completes transaction without infinite retries (Passed).
  13. Reverse upload ordering: deletes ordered child-before-parent, puts ordered parent-before-child (Passed).
- **Group 4: Cross-Account RLS & Ownership Verification**:
  14. Core schema enables RLS with `auth.uid() = user_id` on all 9 tables (Passed).
  15. Foreign `user_id` injection is strictly blocked in `uploadData` (Passed).
  16. Ownership alteration via PATCH is strictly blocked (Passed).
- **Group 5: Concurrency, Undo & Regression**:
  17. Completion vs Undo: Deletion snapshot supersedes stale completion (Passed).
  18. Offline queue persistence and restart recovery (Passed).

### 7.2 Static Code Analysis
- `flutter analyze lib/data/powersync/`: **0 issues**.
- `flutter analyze test/data/powersync/`: **0 issues**.

---

## 8. Deployment Prerequisites & Remaining Blockers

Before Phase 3C can be initiated:
1. **Domain Registration**: Project owner must register a public domain name (e.g., `qazanamaz.com`).
2. **DNS Record Setup**:
   - `api.<domain>` $\rightarrow$ `A 92.4.86.19`
   - `sync.<domain>` $\rightarrow$ `A 92.4.86.19`
3. **Caddy Reverse-Proxy Deployment**:
   - Run Caddy on the VM using `powersync/Caddyfile` with the registered domain.
   - Verify automated Let's Encrypt TLS certificate issuance.
4. **Firewall Lockdown**:
   - Close public ports 8000 and internal 80, routing all traffic exclusively through ports 80/443.
5. **Client Endpoint Configuration**:
   - Supply `--dart-define=SUPABASE_URL=https://api.<domain>` and `--dart-define=POWERSYNC_ENDPOINT=https://sync.<domain>`.

---

## 9. Git Status

- **Branch**: `main`
- **Commits / Push**: None performed (per strict instructions).
- **Working Tree**: Preserved with non-destructive additions:
  - `powersync/Caddyfile`
  - `supabase/migrations/20261110000000_qaza_server_conflict_resolution.sql`
  - `lib/data/powersync/powersync_config.dart` (hardened)
  - `lib/data/powersync/supabase_connector.dart` (reconciliation handler added)
  - `android/app/src/main/AndroidManifest.xml` (`usesCleartextTraffic="false"`)
  - `test/data/powersync/powersync_phase3b2_transport_and_conflict_test.dart`
  - Authoritative report artifacts.

---

## 10. Conclusion & Stop Boundary

TP-GEN Phase 3B.2 has successfully contained cloud synchronization, hardened client transport security, established the server-side conflict resolution architecture, and prevented CRUD queue deadlock.

As mandated by project rules, execution is **stopped** after Phase 3B.2. Cloud synchronization remains contained until the owner registers an authorized domain, activates TLS certificates via Caddy, and approves Phase 3C.
