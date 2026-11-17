# TP-GEN Phase 3B.3: Post-HTTPS Live Integration Verification Report

**Project:** Qaza Namaz (`com.qaza_namaz.com`)  
**Phase:** 3B.3 — Post-HTTPS Live Integration Verification  
**Architecture:** Option A (PowerSync Unified SQLite + Drift ORM + Supabase PostgreSQL)  
**Host Target:** Oracle Cloud VM (`92.4.86.19`, Ubuntu 24.04 LTS)  
**Public Endpoints:**
- Supabase API / Auth Gateway: `https://qaza-api.duckdns.org`
- PowerSync Replication Service: `https://qaza-sync.duckdns.org`  
**Date:** November 10, 2026  
**Status:** **PASSED / FULLY VERIFIED (Zero Open Regressions)**

---

## 1. Executive Summary

Following the deployment of DuckDNS public DNS records and automated TLS certificate issuance in Phase 3B.2, this phase conducted a comprehensive end-to-end security, network, transport, reverse proxy, and database-level audit of the live infrastructure.

### Key Audit Findings & Verifications:
1. **Caddy Reverse Proxy Refined:** 
   - Eliminated the dangerous `{upstream_hostport}` rewrite override. Caddy now natively preserves the true external host headers (`qaza-api.duckdns.org` / `qaza-sync.duckdns.org`), guaranteeing that Supabase Auth redirect URLs, magic links, and OAuth callbacks operate without host spoofing or loopback mangling.
   - Removed redundant `X-Forwarded-*` directives and removed `admin off` to enable safe zero-downtime reloads via `systemctl reload caddy`.
   - Verified that PowerSync's persistent HTTP/WebSocket sync stream operates with `flush_interval -1` (unbuffered streaming).
2. **TLS Certificates Deep Inspection:**
   - Both `qaza-api.duckdns.org` and `qaza-sync.duckdns.org` are served via valid 90-day ZeroSSL ECC DV certificates (valid through February 8, 2027) with native TLS 1.3 (`TLS_AES_128_GCM_SHA256`).
   - Windows native Schannel and OpenSSL clients verify both certificate chains with zero trust warnings.
   - HTTP port 80 requests are automatically redirected to HTTPS via `308 Permanent Redirect`.
   - Removed the placeholder email (`abdul.kabeer@example.com`) to avoid ACME `invalidContact` errors.
3. **WAN Firewall Isolation & Persistence:**
   - Both host `INPUT` and Docker's `DOCKER-USER` iptables chains drop external incoming TCP traffic on ports `8000` (Supabase Kong/Envoy), `8080` (PowerSync), and `5432` (PostgreSQL) arriving on WAN interface `ens3`.
   - Rules are persisted via `/etc/iptables/rules.v4` and managed by `netfilter-persistent` across reboots.
   - Live external WAN TCP probes confirm: Ports 8000, 8080, and 5432 **FAILED** (dropped packets / connection timeout), while Port 443 **SUCCEEDED** (encrypted HTTPS).
4. **Supabase Auth & API Configuration:**
   - Updated `API_EXTERNAL_URL`, `SUPABASE_PUBLIC_URL`, and `SITE_URL` in `/opt/supabase/docker/.env` to `https://qaza-api.duckdns.org`.
   - GoTrue v2.197.0 auth health verified (`200 OK`).
   - PostgREST v14.18 authenticated querying verified. Anonymous access correctly enforces RLS (returns `[]` on `qaza_records`).
   - Invalid JWT tokens are rejected immediately with `401 Unauthorized` (`PGRST301: JWT cryptographic operation failed`).
5. **PowerSync Protocol & Health Probes:**
   - Health probes verified: `GET /probes/liveness` and `GET /probes/readiness` both return `HTTP 200 OK` (`{"ready":true,"started":true}`).
   - Sync stream endpoint verified: `POST /sync/stream` rejects unauthenticated requests with `401 Unauthorized` (`PSYNC_S2106`) and malformed JWTs with `401 Unauthorized` (`PSYNC_S2101`).
6. **Server-Authoritative Conflict Resolution & Resurrection Protection:**
   - Deployed `supabase/migrations/20261110000000_qaza_server_conflict_resolution.sql` to live PostgreSQL (`supabase-db`).
   - 12 conflict resolution triggers active across `qaza_records`, `account_profiles`, `qaza_additions`, `user_preferences`, `daily_salah_logs`, and `qaza_deletion_action_record_snapshots`.
   - Transaction-isolated verification confirmed: Stale version overwrites (`record_version < stored`) fail with `P0001`, equal-version tie-breaks auto-advance `record_version` monotonically, and higher versions are accepted.
7. **Flutter Mobile Client Health:**
   - `flutter analyze`: **0 issues found** (clean).
   - Full PowerSync automated test suite: **103/103 tests passed** (100% pass rate).
   - Cloud sync allowlist remains **empty** and `transportSecurityVerified = false` pending final authorization.

---

## 2. Caddy Reverse Proxy Audit & Deployment

### Caddyfile Review (`/etc/caddy/Caddyfile`)
The deployed configuration on VM `92.4.86.19` was audited and updated to remove anti-patterns and enable clean system administration:

```caddy
# =============================================================================
# Qaza Namaz Production Caddyfile
# Reverse Proxy with Automatic Let's Encrypt / ZeroSSL TLS (HTTPS / WSS)
# Active Domains: qaza-api.duckdns.org / qaza-sync.duckdns.org
# Public Host IP: 92.4.86.19
# =============================================================================

{
    log {
        output file /var/log/caddy/access.log {
            roll_size 10mb
            roll_keep 3
        }
    }
}

# -----------------------------------------------------------------------------
# 1. Supabase API Gateway (Auth, REST, Storage, Realtime)
# -----------------------------------------------------------------------------
qaza-api.duckdns.org {
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

    # Preserves external Host (qaza-api.duckdns.org) for Auth redirects & OAuth
    reverse_proxy 127.0.0.1:8000
}

# -----------------------------------------------------------------------------
# 2. PowerSync Sync Service (Streaming HTTP & WebSockets)
# -----------------------------------------------------------------------------
qaza-sync.duckdns.org {
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

    # Preserves external Host; unbuffered flush_interval -1 for persistent streaming
    reverse_proxy 127.0.0.1:8080 {
        flush_interval -1
    }
}
```

### Verification Highlights:
- **Host Header Forwarding:** In Caddy v2, `reverse_proxy <upstream>` automatically passes the incoming `Host` header to the backend (`qaza-api.duckdns.org`). Removing `{upstream_hostport}` prevents Kong and GoTrue from seeing `127.0.0.1:8000`, ensuring all generated OAuth callbacks and email confirmation links retain the public HTTPS scheme and domain.
- **WebSocket & Streaming:** Caddy automatically supports HTTP/1.1 WebSocket upgrades. The addition of `flush_interval -1` prevents buffering for NDJSON sync streams (`POST /sync/stream`), enabling instant client updates.
- **Admin Socket:** Removed `admin off` so Caddy binds to `127.0.0.1:2019`. This enables `systemctl reload caddy` to perform seamless, zero-downtime in-memory configuration reloads. Reload was tested and verified with `RELOAD_SUCCESS`.

---

## 3. TLS Certificate Deep Inspection

Certificates for both hostnames were examined using external OpenSSL probes:

| Property | `qaza-api.duckdns.org` | `qaza-sync.duckdns.org` |
| :--- | :--- | :--- |
| **Subject (CN)** | `CN = qaza-api.duckdns.org` | `CN = qaza-sync.duckdns.org` |
| **Issuer** | `ZeroSSL ECC DV SSL CA 2` (`ZeroSSL GmbH`, Austria) | `ZeroSSL ECC DV SSL CA 2` (`ZeroSSL GmbH`, Austria) |
| **Key Type** | ECDSA (ECC P-256) | ECDSA (ECC P-256) |
| **Validity Start** | Nov 10 00:00:00 2026 GMT | Nov 10 00:00:00 2026 GMT |
| **Validity Expiry** | Feb 8 23:59:59 2027 GMT (90 days) | Feb 8 23:59:59 2027 GMT (90 days) |
| **SANs** | `DNS:qaza-api.duckdns.org` | `DNS:qaza-sync.duckdns.org` |
| **TLS Protocol** | TLSv1.3 (Cipher: `TLS_AES_128_GCM_SHA256`) | TLSv1.3 (Cipher: `TLS_AES_128_GCM_SHA256`) |
| **Windows Trust** | Verified cleanly via Windows Schannel | Verified cleanly via Windows Schannel |
| **Port 80 Redirect**| `HTTP/1.1 308 Permanent Redirect` | `HTTP/1.1 308 Permanent Redirect` |
| **Auto-Renewal** | Caddy ACME automatic background renewal (30 days prior to expiry) | Caddy ACME automatic background renewal (30 days prior to expiry) |

---

## 4. Caddy Version & Maintenance Status

- **Installed Version:** `Caddy v2.6.2` (`2.6.2-6ubuntu0.24.04.3`)
- **Package Origin:** Ubuntu 24.04 LTS official repository (`noble-updates/universe`, `noble-security/universe`)
- **Upstream Version:** `v2.8.4`
- **Assessment & Recommendation:**
  - `v2.6.2` in Ubuntu 24.04 LTS is a hardened, LTS-maintained binary receiving backported security patches from the Canonical Security Team.
  - It natively supports all required features: automatic ACME (Let's Encrypt/ZeroSSL), HTTP/2, HTTP/3 (QUIC), WebSocket proxying, and streaming flush intervals.
  - **Decision:** Keep the official Ubuntu LTS package to guarantee stability, zero breaking configuration syntax changes, and seamless unattended security updates.

---

## 5. Firewall Persistence & WAN Port Scan Audit

To prevent cleartext leakage and protect unauthenticated services from WAN probing, host-level iptables and Docker firewalling were validated.

### 1. iptables Rules in Effect:
```text
Chain DOCKER-USER (1 references)
-A DOCKER-USER -i ens3 -p tcp -m multiport --dports 8000,8080,5432 -j DROP

Chain INPUT (policy ACCEPT)
-A INPUT -i ens3 -p tcp -m multiport --dports 8000,8080,5432 -j DROP
-A INPUT -p tcp -m multiport --dports 80,443,8000,5432 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
```

### 2. Rule Persistence:
- Verified `iptables-persistent` and `netfilter-persistent` (v1.0.20) are installed and active.
- `/etc/iptables/rules.v4` contains the DROP rules for ports 8000, 8080, and 5432 at the head of `DOCKER-USER` and `INPUT`.

### 3. Remote TCP Probing (from external network):

```powershell
# Probe 1: Port 8000 (Kong / Envoy API Gateway)
ComputerName: 92.4.86.19 | RemotePort: 8000 | TcpTestSucceeded: False (DROPPED)

# Probe 2: Port 8080 (PowerSync Sync Service)
ComputerName: 92.4.86.19 | RemotePort: 8080 | TcpTestSucceeded: False (DROPPED)

# Probe 3: Port 5432 (PostgreSQL)
ComputerName: 92.4.86.19 | RemotePort: 5432 | TcpTestSucceeded: False (DROPPED)

# Probe 4: Port 443 (HTTPS Caddy Reverse Proxy)
ComputerName: 92.4.86.19 | RemotePort: 443  | TcpTestSucceeded: True  (OPEN & ENCRYPTED)
```

---

## 6. Live Supabase API & Auth Verification

### 1. Environment Variable Alignment
Updated `/opt/supabase/docker/.env` and recreated the `supabase-auth` container:
- `API_EXTERNAL_URL=https://qaza-api.duckdns.org`
- `SUPABASE_PUBLIC_URL=https://qaza-api.duckdns.org`
- `SITE_URL=https://qaza-api.duckdns.org`

### 2. Live API Probes over HTTPS:

```bash
# 1. Health Probe
curl -H "apikey: <ANON_KEY>" https://qaza-api.duckdns.org/auth/v1/health
# Response (HTTP 200 OK):
{"version":"v2.197.0","name":"GoTrue","description":"GoTrue is a user registration and authentication API"}

# 2. Invalid JWT Token Rejection
curl -i -H "apikey: <ANON_KEY>" -H "Authorization: Bearer invalid.jwt.token" https://qaza-api.duckdns.org/rest/v1/qaza_records
# Response (HTTP 401 Unauthorized):
{"code":"PGRST301","details":null,"hint":null,"message":"JWT cryptographic operation failed"}

# 3. Row Level Security (RLS) Isolation
curl -i -H "apikey: <ANON_KEY>" -H "Authorization: Bearer <ANON_KEY>" https://qaza-api.duckdns.org/rest/v1/qaza_records
# Response (HTTP 200 OK):
[]  # Empty array returned because anonymous caller has no auth.uid() matching user_id
```

---

## 7. PowerSync Protocol & Liveness Probe Verification

Live testing of the PowerSync service over HTTPS (`https://qaza-sync.duckdns.org`):

### 1. Liveness & Readiness Probes
```bash
curl -i https://qaza-sync.duckdns.org/probes/liveness
# Response:
HTTP/1.1 200 OK
{"ready":true,"started":true,"touched_at":"2026-11-10T10:36:31.313Z"}

curl -i https://qaza-sync.duckdns.org/probes/readiness
# Response:
HTTP/1.1 200 OK
{"ready":true,"started":true,"touched_at":"2026-11-10T10:36:39.317Z"}
```

### 2. Stream Endpoint (`POST /sync/stream`) Protocol Security
```bash
# Unauthenticated request:
curl -i -X POST https://qaza-sync.duckdns.org/sync/stream
# Response (HTTP 401 Unauthorized):
{"error":{"code":"PSYNC_S2106","status":401,"description":"Authentication required","name":"AuthorizationError"}}

# Invalid Bearer Token:
curl -i -X POST -H "Authorization: Bearer invalid.token" https://qaza-sync.duckdns.org/sync/stream
# Response (HTTP 401 Unauthorized):
{"error":{"code":"PSYNC_S2101","status":401,"description":"Token is not a well-formed JWT. Check the token format.","name":"AuthorizationError"}}
```

---

## 8. Server-Authoritative Conflict Resolution & Resurrection Protection

Applied `supabase/migrations/20261110000000_qaza_server_conflict_resolution.sql` to `supabase-db`.

### 1. Active Conflict Resolution Triggers (12 Triggers):
- `trg_qaza_record_conflict_resolution` on `qaza_records` (INSERT, UPDATE)
- `trg_account_profile_conflict_resolution` on `account_profiles` (INSERT, UPDATE)
- `trg_qaza_additions_conflict_resolution` on `qaza_additions` (INSERT, UPDATE)
- `trg_user_preferences_conflict_resolution` on `user_preferences` (INSERT, UPDATE)
- `trg_daily_salah_logs_conflict_resolution` on `daily_salah_logs` (INSERT, UPDATE)
- `trg_prevent_delete_deletion_snapshots` on `qaza_deletion_action_record_snapshots` (UPDATE, DELETE)

### 2. Transaction-Isolated Functional Verification:
A PL/pgSQL verification block was executed in a rollback transaction on the live PostgreSQL instance:
1. **Stale Version Rejection:** Attempting to update a record with `record_version = 1` against stored `record_version = 2` was immediately caught and rejected with SQLSTATE `P0001` (`STALE_MUTATION_REJECTED`).
2. **Equal Version Tie-Breaking:** Updating a record with equal version (`2`) auto-advanced `record_version` to `3` and updated `updated_at` to server UTC time.
3. **Monotonic Higher Version:** Updating a record with higher version (`5`) was preserved and accepted without rejection.
4. **Audit Immutability:** Deletion action snapshots cannot be modified or deleted directly (`42501`).

---

## 9. Automated Test Suite & Code Quality Results

1. **Flutter Static Analysis:**
   ```bash
   flutter analyze
   # Analyzing Qaza App...
   # No issues found! (ran in 229.3s)
   ```
2. **PowerSync Integration Test Suite:**
   ```bash
   flutter test test/data/powersync/
   # 02:21 +103: All tests passed!
   ```
   - `powersync_phase1_integration_test.dart`: 12/12 passed
   - `powersync_phase2_dao_integration_test.dart`: 15/15 passed
   - `powersync_phase3a_runtime_cutover_test.dart`: 16/16 passed
   - `powersync_phase3a1_workspace_isolation_hardening_test.dart`: 11/11 passed
   - `powersync_phase3b_cloud_sync_integration_test.dart`: 23/23 passed
   - `powersync_phase3b2_transport_and_conflict_test.dart`: 18/18 passed
   - `powersync_signout_safety_test.dart`: 3/3 passed
   - `guest_data_adoption_service_test.dart`: 5/5 passed

---

## 10. Phase 3C Readiness & Controlled Gate Recommendations

| Criterion | Target | Audit Status | Note |
| :--- | :--- | :--- | :--- |
| Transport Security | Public HTTPS | **VERIFIED** | Valid ZeroSSL TLS 1.3 certificates active on both subdomains. |
| Cleartext Traffic | Disabled | **VERIFIED** | `android:usesCleartextTraffic="false"` in `AndroidManifest.xml`. |
| Port Lockdown | Direct WAN ports blocked | **VERIFIED** | Ports 8000, 8080, and 5432 confirmed blocked externally. |
| Auth Host Consistency| Public Domain in GoTrue | **VERIFIED** | `API_EXTERNAL_URL=https://qaza-api.duckdns.org` active. |
| Conflict Resolution | Server-Authoritative Triggers | **VERIFIED** | Version ordering, tie-breaking, and snapshot immutability active. |
| Cloud Sync Gate | Disabled / Safe Containment | **ENFORCED** | `PowerSyncConfig.transportSecurityVerified = false` and allowlist empty. |

### Recommendation for Phase 3C:
All technical, transport, protocol, database, and operational prerequisites for **Phase 3C — Controlled Multi-Device Cloud Synchronization** are complete. 

Before enabling cloud synchronization in code:
1. `PowerSyncConfig.transportSecurityVerified` will be toggled to `true`.
2. A single dedicated developer test account (e.g. `google_developer_test`) will be added to `_authorizedTestWorkspaces`.
3. Guest mode remains strictly air-gapped and local-only.
4. Two physical or emulated devices will sync synthetic test records over the live HTTPS infrastructure to verify convergence.
