# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-06

### Added

- `galaxy_store_upload_apk` — uploads an APK or AAB binary and registers it against the app's content ID. Auto-detects the binary path from gradle lane context (`GRADLE_AAB_OUTPUT_PATH`, `GRADLE_APK_OUTPUT_PATH`, and the `_ALL_` variants) when `apk_path` is not provided. Requires a `gms` (`Y`/`N`) parameter indicating whether the build includes Google Mobile Services. Returns the new binary's `binarySeq` and writes it to `SharedValues::GALAXY_STORE_BINARY_SEQ` for downstream chaining.
- `galaxy_store_upload_metadata` — uploads localized title, short description, long description, release notes (`newFeature`), icon, screenshots, and app-level YouTube URL / hero image from `fastlane/metadata/galaxystore/` to the Galaxy Store. Hero image upload is gated behind `upload_hero_image: true` since the API only accepts it for Game-category apps. Includes pre-flight validation of short description byte length and a per-language diagnostic breakdown when the API returns a 400.
- `galaxy_store_app_info` — fetches the current app listing from the Galaxy Store and writes it to `fastlane/metadata/galaxystore/<language_code>/`, prefering any in-progress listing (any `contentStatus` other than `FOR_SALE`, including `REGISTERING`, `UPDATING`, `READY_FOR_REVIEW`, `UNDER_DEVICE_TEST`, `READY_FOR_CHANGE`, and any intermediate review states Samsung adds in the future) over the live `FOR_SALE` listing. Writes per-language release notes (`new_feature.txt`) and app-level `youtube_url.txt` when present. Downloads icon, hero image, and screenshots in parallel.
- `galaxy_store_app_list` — retrieves the full list of apps registered to the seller account, with an optional `output_path` to write the result as JSON.
- `galaxy_store_import_from_supply` — imports metadata from a Fastlane Supply (Google Play) directory into the Galaxy Store format, mapping BCP-47 language codes to Galaxy Store three-letter codes. Bridges per-language title / short / long descriptions; release notes (`changelogs/<version_code>.txt` with `default.txt` fallback, matching Supply semantics); phone screenshots; the default language's icon and YouTube URL; and (with `import_hero_image: true`) the default language's feature graphic as hero image. Supports `language_priority` overrides for resolving regional-variant conflicts (e.g. `es-ES` vs `es-419`).
- `galaxy_store_set_publication_type` — configures whether an update publishes automatically, on a scheduled date, or manually after review.
- `galaxy_store_submit_app` — submits a pending update for Galaxy Store review.
- `galaxy_store_publish_app` — sets the app status to `FOR_SALE` (for use with the manual publication type after review passes).
- `galaxy_store_staged_rollout` — checks which binaries have staged rollout enabled for a given app and returns the current rollout rate.
- `galaxy_store_set_staged_rollout` — enables or disables staged rollout. Supports a global rollout rate, per-country rates declared inline, or per-country rates loaded from a JSON file.
- `galaxy_store_update_staged_rollout_binary` — adds or removes a binary from the staged rollout group by `binarySeq`. The `binary_seq` parameter is optional; when omitted it falls back to `SharedValues::GALAXY_STORE_BINARY_SEQ` set by `galaxy_store_upload_apk`.
- Async response handling — the API client transparently polls `303 See Other` responses to completion, surfacing only the final result to callers.
- Structured error reporting — when the Galaxy Store API returns a non-success response, the client parses `errorCode` and `errorMsg` from the response body and surfaces them in the raised error rather than dumping the raw JSON.
- `galaxy_store_app_info` also writes the raw API response to `fastlane/metadata/galaxystore/app_info.json` for inspection and scripting.
- Download hardening in `galaxy_store_app_info` — redirects must use HTTPS and must not resolve to loopback, private, or link-local addresses; only files with an allowlisted image extension (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`) are downloaded.
- Every API request carries an `X-Client-Source` header identifying the plugin, plus verbose request/response logging when fastlane runs with `--verbose`.
- Authentication via the `GALAXY_STORE_ACCESS_TOKEN` and `GALAXY_STORE_SERVICE_ACCOUNT_ID` environment variables; per-action overrides supported.
