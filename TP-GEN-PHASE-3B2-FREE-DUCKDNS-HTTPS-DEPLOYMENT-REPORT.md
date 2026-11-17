# TP-GEN Phase 3B.2 — Complete DuckDNS + Free HTTPS Deployment Report

**Project**: Qaza Namaz (`com.qaza_namaz.com`)  
**Architecture**: Option A — PowerSync Unified SQLite + Drift ORM  
**Date**: 2026-11-10  
**Status**: DEPLOYED & VERIFIED (PRE-RELEASE / NOT PUBLISHED)  

---

## 1. Actual DuckDNS Subdomains Registered

Through collaboration with the user on the official DuckDNS dashboard, the two preferred subdomains were successfully registered and bound to the Oracle VM public IP:

- **API Subdomain**: `qaza-api.duckdns.org` $\rightarrow$ `92.4.86.19`
- **Sync Subdomain**: `qaza-sync.duckdns.org` $\rightarrow$ `92.4.86.19`

*Security Note: In accordance with zero-credential exposure policies, no DuckDNS account tokens were logged, printed, or stored in code or reports.*

---

## 2. DNS Resolution Evidence

Verified via authoritative public DNS resolver (`8.8.8.8`):

```powershell
Name                   Type  TTL  Section  IPAddress
----                   ----  ---  -------  ---------
qaza-api.duckdns.org   A     60   Answer   92.4.86.19
qaza-sync.duckdns.org  A     60   Answer   92.4.86.19
```

Both hostnames resolve directly and cleanly to the Oracle Cloud VM.

---

## 3. Free Automated TLS Certificate Issuance Results

Caddy v2.6.2 was installed on the Ubuntu 24.04 server. Upon configuration deployment, Caddy initiated automated ACME challenges via ZeroSSL / Let's Encrypt:

- **Challenge Type**: `http-01`
- **Port**: 80 (handled natively by Caddy HTTP challenge solver)
- **Validation**: All challenge requests from ACME validation servers passed.
- **Log Verification (`/var/log/caddy/access.log`)**:
  - `{"level":"info","logger":"tls.obtain","msg":"certificate obtained successfully","identifier":"qaza-api.duckdns.org"}`
  - `{"level":"info","logger":"tls.obtain","msg":"certificate obtained successfully","identifier":"qaza-sync.duckdns.org"}`
- **Protocols Supported**: TLS 1.2, TLS 1.3, HTTP/2, HTTP/3 (QUIC over UDP 443).
- **Certificate Renewal**: Completely automatic via Caddy systemd daemon; persistent storage in `/var/lib/caddy/.local/share/caddy`.

---

## 4. Caddy Reverse-Proxy Configuration

Production configuration deployed to `/etc/caddy/Caddyfile` and mirrored in repository at `powersync/Caddyfile`:

```caddy
{
    email abdul.kabeer@example.com
    admin off
    log {
        output file /var/log/caddy/access.log {
            roll_size 10mb
            roll_keep 3
        }
    }
}

# 1. Supabase API Gateway (Auth, REST, Storage, Realtime)
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

    reverse_proxy 127.0.0.1:8000 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto https
        header_up X-Forwarded-Host {host}
    }
}

# 2. PowerSync Sync Service (Streaming HTTP & WebSockets)
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

    reverse_proxy 127.0.0.1:8080 {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto https
        header_up X-Forwarded-Host {host}

        flush_interval -1
    }
}
```

---

## 5. Upstream Port Mappings & Infrastructure

Actual server layout inspected and configured:
- **Supabase Kong Gateway (`supabase-envoy`)**: Internal listener on `127.0.0.1:8000`.
- **PowerSync Service (`powersync`)**: Internal listener on `127.0.0.1:8080`.
- **Host Nginx**: Decommissioned, stopped, and disabled (`systemctl stop nginx && systemctl disable nginx`).
- **Caddy Web Server**: Bound to public `:80` (automated HTTPS redirect) and public `:443` (TLS termination).

---

## 6. Network Security & Firewall Lockdown

To prevent unencrypted cleartext access to the backend:
1. **Host Iptables Rules Applied**:
   - `sudo iptables -I DOCKER-USER -i ens3 -p tcp -m multiport --dports 8000,8080,5432 -j DROP`
   - `sudo iptables -I INPUT -i ens3 -p tcp -m multiport --dports 8000,8080,5432 -j DROP`
2. **External Verification**:
   - `92.4.86.19:8000` (Direct unencrypted Kong): **BLOCKED** (`TcpTestSucceeded: False`).
   - `92.4.86.19:8080` (Direct unencrypted PowerSync): **BLOCKED** (`TcpTestSucceeded: False`).
   - `92.4.86.19:22` (SSH administration): **PRESERVED & ACCESSIBLE**.
   - `92.4.86.19:80` (Caddy HTTP $\rightarrow$ HTTPS 308 redirect): **FUNCTIONAL**.
   - `92.4.86.19:443` (Caddy HTTPS): **SECURED WITH TLS**.

---

## 7. Flutter Endpoint & Transport Hardening

1. **Endpoint Defaults Updated**:
   In `lib/data/powersync/powersync_config.dart`:
   - `SUPABASE_URL`: `https://qaza-api.duckdns.org`
   - `POWERSYNC_ENDPOINT`: `https://qaza-sync.duckdns.org`
2. **Cleartext Traffic Rejection**:
   - `android/app/src/main/AndroidManifest.xml`: `android:usesCleartextTraffic="false"`
   - `PowerSyncConfig.validateTransportSecurity`: Rejects cleartext HTTP/WS in release builds with `StateError`.
3. **Controlled Containment Gate Maintained**:
   - `transportSecurityVerified = false` (default).
   - `_authorizedTestWorkspaces = <String>{}` (empty set by default).
   - Guest mode remains strictly air-gapped from cloud sync.

---

## 8. Server-Authoritative Conflict Resolution Review

The migration `supabase/migrations/20261110000000_qaza_server_conflict_resolution.sql` enforces:
1. **Monotonic Versioning**:
   - Rejects `NEW.record_version < OLD.record_version` with `STALE_MUTATION_REJECTED` (`P0001`).
2. **Equal-Version Tie Breaking**:
   - Resolves ties via `updated_at`; monotonically advances version.
3. **Resurrection Prevention**:
   - Checks `qaza_deletion_action_record_snapshots`; rejects stale inserts with `STALE_RESURRECTION_REJECTED` (`P0001`).
4. **Queue Reconciliation**:
   - `QazaSupabaseConnector.uploadData()` intercepts `P0001` conflict rejections, queries server canonical row, logs resolution, and acknowledges/completes the transaction, preventing infinite upload retry loops.

---

## 9. Comprehensive Test Suite & Verification Results

### External Live HTTPS Connectivity
- **Supabase Auth Health**:
  ```bash
  curl -s -H 'apikey: ...' https://qaza-api.duckdns.org/auth/v1/health
  # Response: {"version":"v2.197.0","name":"GoTrue","description":"GoTrue is a user registration and authentication API"}
  ```
- **PowerSync HTTPS Listener**:
  ```bash
  curl -Iv https://qaza-sync.duckdns.org/sync/stream
  # Response: HTTP/1.1 404 (valid TLS handshake, Strict-Transport-Security header present)
  ```
- **HTTP $\rightarrow$ HTTPS Redirection**:
  ```bash
  curl -I http://qaza-api.duckdns.org
  # Response: HTTP/1.1 308 Permanent Redirect -> Location: https://qaza-api.duckdns.org/
  ```

### Automated Flutter Test Suite
- `test/data/powersync/powersync_phase3b2_transport_and_conflict_test.dart`: **18/18 passed (100%)**
- `test/data/powersync/` (Full suite): **103/103 passed (100%)**
- `flutter analyze lib/data/powersync/ test/data/powersync/`: **0 issues found**

---

## 10. Remaining Blockers & Next Steps

All technical, infrastructure, and transport security blockers for Phase 3B.2 have been **100% resolved**.
Free HTTPS is active with automated certificate renewal.

Per project safety rules:
- Execution is **STOPPED**.
- The cloud-sync allowlist remains empty.
- We await explicit user authorization before re-enabling the developer test workspace for Phase 3C end-to-end cloud testing.

---

## 11. Git Status

- **Branch**: `main`
- **Commits / Push**: None (per instructions).
- **Working Tree**: Preserved with non-destructive changes:
  - `powersync/Caddyfile`
  - `supabase/migrations/20261110000000_qaza_server_conflict_resolution.sql`
  - `lib/data/powersync/powersync_config.dart`
  - `lib/data/powersync/supabase_connector.dart`
  - `android/app/src/main/AndroidManifest.xml`
  - `test/data/powersync/powersync_phase3b2_transport_and_conflict_test.dart`
  - Authoritative report artifacts.
