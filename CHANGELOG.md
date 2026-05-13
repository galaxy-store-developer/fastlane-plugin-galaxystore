# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `galaxy_store_upload_apk` — uploads an APK or AAB binary and registers it against the app's content ID. Auto-detects the binary path from gradle lane context (`GRADLE_AAB_OUTPUT_PATH`, `GRADLE_APK_OUTPUT_PATH`, and the `_ALL_` variants) when `apk_path` is not provided.
- `galaxy_store_upload_metadata` — uploads localized title, short description, long description, icon, and screenshots from `fastlane/metadata/galaxystore/` to the Galaxy Store. Includes pre-flight validation of short description byte length and a per-language diagnostic breakdown when the API returns a 400.
- `galaxy_store_app_info` — fetches the current app listing from the Galaxy Store and writes it to `fastlane/metadata/galaxystore/<language_code>/`, prefering an in-progress (`REGISTERING` or `UPDATING`) listing over the live `FOR_SALE` one. Downloads icon and screenshots in parallel.
- `galaxy_store_app_list` — retrieves the full list of apps registered to the seller account, with an optional `output_path` to write the result as JSON.
- `galaxy_store_import_from_supply` — imports metadata from a Fastlane Supply (Google Play) directory into the Galaxy Store format, mapping BCP-47 language codes to Galaxy Store three-letter codes. Supports `language_priority` overrides for resolving regional-variant conflicts (e.g. `es-ES` vs `es-419`).
- `galaxy_store_set_publication_type` — configures whether an update publishes automatically, on a scheduled date, or manually after review.
- `galaxy_store_submit_app` — submits a pending update for Galaxy Store review.
- `galaxy_store_publish_app` — sets the app status to `FOR_SALE` (for use with the manual publication type after review passes).
- `galaxy_store_staged_rollout` — checks which binaries have staged rollout enabled for a given app and returns the current rollout rate.
- `galaxy_store_set_staged_rollout` — enables or disables staged rollout. Supports a global rollout rate, per-country rates declared inline, or per-country rates loaded from a JSON file.
- `galaxy_store_update_staged_rollout_binary` — adds or removes a binary from the staged rollout group by `binarySeq`.
- Async response handling — the API client transparently polls `303 See Other` responses to completion, surfacing only the final result to callers.
- Authentication via the `GALAXY_STORE_ACCESS_TOKEN` and `GALAXY_STORE_SERVICE_ACCOUNT_ID` environment variables; per-action overrides supported.
