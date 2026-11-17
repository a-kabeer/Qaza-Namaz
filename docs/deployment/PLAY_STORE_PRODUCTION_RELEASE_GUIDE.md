# Qaza Namaz — Google Play Console Production Release Guide

> **Release Status:** PRE-RELEASE / VALIDATED RELEASE CANDIDATE (RC-1)  
> **Target Track:** Google Play Console — Internal Testing Track (Rollout Stage 1)  
> **Date:** November 17, 2026  
> **Git Base Commit:** `99efe3c` (`feat(sync): complete TP-GEN offline-first Supabase & PowerSync migration and Phase 3C.3 release candidate audit`)

---

## 1. Executive Summary & Build Specifications

Qaza Namaz has completed the complete engineering migration cycle from legacy Google Drive backup to modern **Offline-First Supabase Auth + PowerSync Replication** (Phases 1 through 3C.3).

All local databases remain hardware-accelerated, SQLCipher-encrypted (SQLite3 Multiple Ciphers), and work 100% offline. Remote synchronization activates seamlessly and securely over TLS 1.3 when connected.

### Build Specifications Table

| Attribute | Specification | Verification Status |
| :--- | :--- | :--- |
| **Application ID** | `com.qaza_namaz.com` | Verified in AndroidManifest.xml & build.gradle |
| **Version Code** | `2004` | Verified |
| **Version Name** | `0.2.0` | Verified |
| **Min SDK** | `26` (Android 8.0 Oreo) | Verified |
| **Target SDK** | `34` (Android 14) / `36` (Android 15+ compatible) | Verified |
| **Compile SDK** | `36` | Verified |
| **NDK Version** | `28.2.13676358` | Verified |
| **Cleartext Traffic** | `android:usesCleartextTraffic="false"` | Enforced (Zero unencrypted HTTP) |
| **Transport Security** | TLS 1.3 Only (`ECDHE-ECDSA-AES128-GCM-SHA256`) | Verified on Oracle Cloud Caddy |
| **Automated Test Suite** | 1,036 tests (907 unit/widget + 124 sync + 5 daily cap) | **100% PASS (0 failures)** |
| **Static Code Analysis** | `flutter analyze` | **0 issues** |

---

## 2. Release Artifacts & Cryptographic Signatures

### A. Google Play App Bundle (Production Artifact)

- **File Path:** `build/app/outputs/bundle/release/app-release.aab`
- **File Size:** `82,969,030 bytes` (~79.1 MB)
- **SHA-256 Checksum:**
  ```text
  E5AE49EC0518B4632BA7DE47389B9EC873C2DCB2C55D278C775601E5AA44656C
  ```
- **Estimated End-User Download Size:** `~22 MB – 28 MB` (Google Play dynamic feature & ABI split delivery).
- **Bundletool Validation:** **PASS** (`bundletool validate` returned 0 errors).

### B. Direct-Install Release APK (Physical Device Testing)

- **File Path:** `build/app/outputs/flutter-apk/app-release.apk`
- **File Size:** `85,967,453 bytes` (82.0 MB universal package)
- **SHA-256 Checksum:**
  ```text
  107472FE129D839E93B82B7BBF0A34B0A627B04EEE61B5222B203CA834B51109
  ```
- **Signing Scheme:** APK Signature Scheme v2 (Verified).

### C. Digital Certificate Fingerprints

- **Distinguished Name (DN):** `CN=Abdul Kabeer, OU=Development, O=Qaza Namaz, L=Karachi, ST=Sindh, C=PK`
- **Algorithm:** RSA 2048-bit (Validity: 28 years until 2054)
- **Certificate SHA-256 Digest:**
  ```text
  0FF7D6AB97CC5CF438AB52F64DBB0873A1C42707DB33BB8D037665CF18392018
  ```
- **Public Key SHA-256 Digest:**
  ```text
  1113F7F07E96D6728CF105222D6B387CC3BAF6EF6FE5FC1572B06ED8E26F53EE
  ```

---

## 3. Production Cloud Infrastructure Summary

The live backend is hosted on Oracle Cloud Infrastructure (OCI) Always-Free compute:

| Service | Public Endpoint | Port | Protocol | Security / Auth |
| :--- | :--- | :--- | :--- | :--- |
| **Supabase Gateway** | `https://qaza-api.duckdns.org` | 443 | TLS 1.3 | Supabase JWT / PostgREST RLS |
| **PowerSync Service** | `https://qaza-sync.duckdns.org` | 443 | TLS 1.3 | RS256 JWT Token Sync Validation |
| **Reverse Proxy** | Caddy v2 (Dockerized) | 443 / 80 | ACME Let's Encrypt | Strict SNI & TLS 1.3 Enforcement |
| **PostgreSQL Database** | Internal Docker Bridge | 5432 | TCP | Row Level Security (RLS) on all tables |

> [!IMPORTANT]
> The backend operates without commercial monthly licensing costs using DuckDNS + OCI Always Free + Let's Encrypt automated certificate renewals.

---

## 4. Google Play Console Pre-Launch Checklist

### Phase A: App Content & Policy Declarations

1. **Privacy Policy:**
   - Link: Host the privacy policy on GitHub Pages or custom domain explaining:
     - No personal data sold.
     - Prayers and dates are stored locally (encrypted) and synced to the user's private cloud account only when signed in.
     - Guest mode data never leaves the device.
2. **Data Safety Form:**
   - **Data Collected:**
     - Email address (Optional, only for account authentication & cloud sync).
     - App activity / Prayer records (Optional, stored in encrypted private database for sync).
   - **Data Shared:** None.
   - **Security Practices:**
     - Data encrypted in transit (TLS 1.3).
     - Data encrypted at rest on device (SQLite3 Multiple Ciphers / SQLCipher).
     - Users can request deletion of their account & data via in-app button or support email.
3. **Target Audience & Content:**
   - Target age: 13+ (All ages / Family friendly).
   - Does the app contain ads? **No**.
4. **App Permissions:**
   - Internet access (`android.permission.INTERNET`).
   - Network state access (`android.permission.ACCESS_NETWORK_STATE`).
   - Exact alarm / Notifications (for prayer reminders, if configured).

---

### Phase B: Store Listing Assets

1. **App Title:** `Qaza Namaz - قضا نماز` (max 30 characters)
2. **Short Description (English):**
   > Accurate offline-first Islamic prayer tracker for managing and completing missed (Qaza) prayers.
3. **Short Description (Urdu):**
   > چھوٹی ہوئی قضا نمازوں کا باقاعدہ اور محفوظ ریکارڈ رکھنے والی آف لائن ایپ۔
4. **Hi-res Icon:** `512 x 512 px` (PNG 32-bit with alpha).
5. **Feature Graphic:** `1024 x 500 px` (PNG or JPEG, 24-bit).
6. **Phone Screenshots:** Minimum 4 screenshots (Home dashboard, Add Qaza calendar/quick add, Review & Progress, and Account/Sync settings).

---

### Phase C: Internal Testing Track Deployment (Recommended Step 1)

1. Open **Google Play Console** > Select **Qaza Namaz**.
2. Go to **Testing** > **Internal testing**.
3. Click **Create new release**.
4. Upload `app-release.aab` from `build/app/outputs/bundle/release/app-release.aab`.
5. Enter **Release name:** `0.2.0 (2004) - Offline-First Supabase & PowerSync RC-1`.
6. Copy & paste the Release Notes below.
7. Click **Next** > Review warnings (if any) > **Save** and **Start rollout to Internal testing**.
8. Add your email address and tester emails under **Testers** tab to download and verify via the private Play Store link.

---

## 5. Official Release Notes (Ready to Copy)

### English (en-US)
```text
What's new in v0.2.0:
• Modern Offline-First Synchronization: Seamlessly record and complete your Qaza prayers anywhere without an internet connection.
• Secure Cloud Sync: Optional cloud backup with Supabase and real-time PowerSync technology.
• Strict Privacy & Guest Mode: Use the app completely offline without an account. Your data stays private on your phone.
• Enhanced Encryption: Military-grade on-device database encryption (SQLite3 Multiple Ciphers).
• Performance & Stability: Instant UI responsiveness and zero-latency prayer tracking.
```

### Roman Urdu (ur-Latn / Pakistan)
```text
Nayi Tabdeeliyan (v0.2.0):
• Behtareen Offline Sync: Internet ke baghair bhi apni Qaza namazain ba-asani darj aur mukammal karein.
• Mahfooz Cloud Sync: Supabase aur PowerSync ke zariye apna record online mahfooz banayein.
• Mukammal Privacy aur Guest Mode: Baghair account banaye mukammal tor par offline istemal karein. Aap ka data aap ke phone par hi rahega.
• Mazboot Encryption: Phone par aap ka tamam record SQLCipher se mehfooz hai.
• Tez aur Asaan: Naya design aur fori response ke sath behtar karkardagi.
```

### Urdu (ur-PK)
```text
نئی خصوصیات اور تبدیلیاں (ورژن 0.2.0):
• جدید آف لائن سنکرونائزیشن: انٹرنیٹ کے بغیر بھی اپنی قضا نمازوں کا ریکارڈ باآسانی درج اور مکمل کریں۔
• محفوظ کلاؤڈ بیک اپ: اپنے ریکارڈ کو آن لائن محفوظ بنانے کے لیے سپر بیس (Supabase) اور پاور سنک کی جدید سہولت۔
• مکمل پرائیویسی اور گیسٹ موڈ: بغیر اکاؤنٹ بنائے بھی تمام فیچرز مکمل آف لائن استعمال کریں۔ آپ کا ڈیٹا صرف آپ کے فون پر محفوظ رہے گا۔
• اعلیٰ ترین انکرپشن: آپ کا تمام ڈیٹا جدید ترین سیکیورٹی کے ساتھ انکرپٹڈ ہے۔
• تیز رفتار اور آسان انٹرفیس۔
```

---

## 6. How to Test on Real Android Phone via Direct APK

To test on your real phone (e.g. Realme Note 50) before uploading to Google Play Console:

1. Connect phone via USB or Wi-Fi ADB.
2. Run installation command:
   ```powershell
   adb install -r "D:\My Folder\My Work\Flutter\Flutter Project\Qaza App\build\app\outputs\flutter-apk\app-release.apk"
   ```
3. Or copy `app-release.apk` to your phone's internal storage and tap to install (enable "Install unknown apps" if prompted).
4. Verify:
   - Cold start without internet.
   - Add/Complete prayers offline.
   - Connect internet and connect email account to verify real-time sync.
