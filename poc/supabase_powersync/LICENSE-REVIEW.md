# Dependency and Service License Review — POC-0

**Status: preliminary source inventory; not deployment/legal approval.** This document is checked against the exact pins in `pubspec.yaml`. CI will inventory license files for the complete resolved transitive dependency graph. Any missing or unclassified package license must be manually investigated before Run A is treated as complete.

## Direct Dart/Flutter package pins

| Package and exact pin | License reported by package/official source | Evidence |
|---|---|---|
| PowerSync Flutter client SDK `powersync 2.5.0` | Apache-2.0 for the client SDK | [PowerSync license/terms overview](https://powersync.com/legal/licensing-terms); [pub.dev versions](https://pub.dev/packages/powersync/versions) |
| `sqlite_async 0.14.5` | MIT | [pub.dev package versions/license metadata](https://pub.dev/packages/sqlite_async/versions) |
| `drift_sqlite_async 0.3.1` | MIT | [pub.dev package versions/license metadata](https://pub.dev/packages/drift_sqlite_async/versions) |
| `drift 2.35.0` | MIT | [pub.dev package license](https://pub.dev/packages/drift/license) |
| `sqlite3 3.5.2` | MIT | [pub.dev package versions/license metadata](https://pub.dev/packages/sqlite3/versions) |
| `supabase_flutter 2.18.3` | MIT | [pub.dev package versions/license metadata](https://pub.dev/packages/supabase_flutter/versions) |
| `flutter_lints 6.0.0` | BSD-3-Clause | [pub.dev package versions](https://pub.dev/packages/flutter_lints/versions) |

These are the declared direct-package license snapshots. The CI inventory is still required to identify exact resolved transitive packages and local license files; this table alone is not a full bill of materials.

## PowerSync service is a separate licensing decision

The client SDK license does not determine the service license:

- PowerSync **Open Edition (self-hosted service)** is provided under the **Functional Source License (FSL)**, a source-available license. This must be reviewed for the intended use and deployment model before production commitment.
- PowerSync Cloud and Enterprise self-hosted service editions are subject to their own commercial licensing/service terms.
- The Supabase Docker stack contains multiple components; do not infer that all self-hosted services share one license.
- The public [PowerSync self-host demo](https://github.com/powersync-ja/self-host-demo) is a configuration reference, not an automatic license grant for each included service/container image.

Official references:
- [PowerSync licensing and terms by edition](https://powersync.com/legal/licensing-terms)
- [PowerSync source availability](https://powersync.com/open-source)
- [Supabase self-hosting](https://supabase.com/docs/guides/self-hosting)
- [Supabase Docker self-hosting instructions](https://supabase.com/docs/guides/self-hosting/docker)
- [PowerSync Supabase local development](https://docs.powersync.com/integrations/supabase/local-development)

## Automated CI inventory

The workflow reads each resolved Dart package directory's `LICENSE`, `LICENCE`, `COPYING`, `NOTICE`, or related top-level files. It records package name, locked version, license-file paths, and a conservative textual license marker. Files that cannot be classified are marked **MANUAL REVIEW REQUIRED**, not guessed. The report and the exact generated `pubspec.lock` are uploaded as artifacts.

A human must review every unknown/missing item and the applicable service/container terms. This is not legal advice and is not production approval.
