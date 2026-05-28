# fastlane-plugin-upload_galaxystore

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-upload_galaxystore)

A [fastlane](https://github.com/fastlane/fastlane) plugin for managing Android app releases on the Samsung Galaxy Store using the [Galaxy Store Developer API](https://developer.samsung.com/galaxy-store/galaxy-store-developer-api.html).

## Contents

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Authentication](#authentication)
- [Actions](#actions)
- [App status lifecycle](#app-status-lifecycle)
- [Example Workflows](#example-workflows)
- [Issues and Feedback](#issues-and-feedback)
- [Troubleshooting](#troubleshooting)
- [About fastlane](#about-fastlane)

## Getting Started

### Prerequisites

Before using this plugin you will need:

1. A Samsung Galaxy Store seller account at [seller.samsungapps.com](https://seller.samsungapps.com)
2. A service account and access token, created via **Assistance → API Service** in the seller portal
3. The 12-digit **content ID** for your app (visible in the Galaxy Store seller portal)

### Installation

Add the plugin to your project:

```bash
fastlane add_plugin upload_galaxystore
```

Or add it manually to your `fastlane/Pluginfile`:

```ruby
gem 'fastlane-plugin-upload_galaxystore'
```

Then run `bundle install`.

### Authentication

The plugin requires two credentials for all API calls. Set them as environment variables and the plugin will read them automatically — you don't need to pass `access_token` or `service_account_id` to individual actions:

```bash
export GALAXY_STORE_ACCESS_TOKEN="your-access-token"
export GALAXY_STORE_SERVICE_ACCOUNT_ID="your-service-account-id"
```

The examples below assume these environment variables are set. If you need to pass credentials explicitly (e.g. from a CI secret store), every action accepts `access_token:` and `service_account_id:` params that override the environment.

---

## Actions

### `galaxy_store_import_from_supply`

Imports app metadata from a [Supply](https://docs.fastlane.tools/actions/supply/) (Google Play) metadata directory into the Galaxy Store format. Use this action to populate `fastlane/metadata/galaxystore/` from an existing `fastlane/metadata/android/` directory, so you can reuse Play Store content for your Galaxy Store listing.

The action:
- Maps BCP-47 language codes (used by Supply) to Galaxy Store language codes
- Copies `title.txt`, `short_description.txt`, and `full_description.txt` → `long_description.txt` for each language
- Copies phone screenshots from each language's `phoneScreenshots/` directory
- Copies a `changelogs/` file as `<galaxy_code>/new_feature.txt` per language. When `version_code` is set, looks for `changelogs/<version_code>.txt` and falls back to `changelogs/default.txt`. When `version_code` is omitted, uses `default.txt` only
- Copies `icon.png` from the default language's directory to the top-level `galaxystore/` folder
- Copies the default language's `video.txt` to top-level `youtube_url.txt`
- Optionally copies the default language's `featureGraphic` to top-level `hero_image.png` (Game-category apps only — see `import_hero_image` below)
- When multiple regional variants of a language exist (e.g. `es`, `es-ES`, `es-419`), selects the best one automatically with a warning

```ruby
galaxy_store_import_from_supply(
  default_language_code: "ENG"
)
```

**Resolving language variant conflicts with `language_priority`:**

If your Supply metadata contains multiple variants for the same language (e.g. both `es-ES` and `es-419`), the action picks one automatically. Use `language_priority` to control which variant is used for a specific Galaxy Store language code:

```ruby
galaxy_store_import_from_supply(
  language_priority: {
    "SPA" => "es-419",
    "POR" => "pt-BR"
  }
)
```

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `metadata_path` | Path to the metadata folder containing the `android` Supply directory | No | `fastlane/metadata` |
| `default_language_code` | Galaxy Store language code for the default listing. Determines which language's icon, YouTube URL, and hero image are used | No | `ENG` |
| `language_priority` | Hash overriding which BCP-47 variant to use per Galaxy Store language code | No | |
| `import_hero_image` | Copy the default language's `featureGraphic` to `galaxystore/hero_image.png`. Only enable for Game-category apps — uploads to non-Game apps will fail at the Galaxy Store API | No | `false` |
| `version_code` | APK version code matching the release being uploaded. When set, picks `changelogs/<version_code>.txt` per language and falls back to `default.txt`. When omitted, only `default.txt` is used | No | |

**Returns:** A hash mapping Galaxy Store language codes to the BCP-47 directories they were imported from.

> **Note:** Galaxy Store only supports one app icon, one YouTube URL, and one hero image. They are taken from the `default_language_code` language's Supply directory. If that language is not present in the Supply metadata, those app-level files will not be copied.

---

### `galaxy_store_app_info`

Retrieves detailed information for a specific app and writes the metadata to local files in `fastlane/metadata/galaxystore/`. Prefers any in-progress listing (any `contentStatus` other than `FOR_SALE`) if one exists, otherwise falls back to the `FOR_SALE` listing. See [App status lifecycle](#app-status-lifecycle) for the statuses you'll typically see.

> **Warning:** Running this action can overwrite the metadata that's stored your local metadata directory if you have made local edits or have imported Play Store metadata from Supply.  

The following files are written for each supported language:

```
fastlane/metadata/galaxystore/
  icon.png
  hero_image.png       # only when the listing has one (Game-category apps)
  youtube_url.txt      # only when the listing has a YouTube URL set
  ENG/
    title.txt
    short_description.txt
    long_description.txt
    new_feature.txt    # release notes; only when the listing has them
    screenshots/
      1.png
      2.png
      ...
  FRA/
    title.txt
    ...
```

```ruby
galaxy_store_app_info(
  content_id: "000007654321"
)
```

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `access_token` | Galaxy Store API access token | Yes | |
| `service_account_id` | Galaxy Store service account ID | Yes | |
| `content_id` | 12-digit app content ID | Yes | |
| `metadata_path` | Path to write metadata files | No | `fastlane/metadata` |

**Returns:** A hash containing the full app info API response.

---

### `galaxy_store_upload_metadata`

Reads app metadata from the local `fastlane/metadata/galaxystore/` directory, uploads any image assets (icon and screenshots), and submits everything to the Galaxy Store via the content update API.

```ruby
galaxy_store_upload_metadata(
  content_id: "000007654321"
)
```

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `access_token` | Galaxy Store API access token | Yes | |
| `service_account_id` | Galaxy Store service account ID | Yes | |
| `content_id` | 12-digit app content ID | Yes | |
| `default_language_code` | Language code for the default listing | No | `ENG` |
| `metadata_path` | Path to the metadata folder | No | `fastlane/metadata` |
| `upload_hero_image` | Upload `hero_image.<ext>` if present in the metadata directory. Only enable for Game-category apps — the Galaxy Store API rejects hero images for non-Game apps | No | `false` |

The action scans the `galaxystore/` directory for:
- `icon.png` (or other image extension) at the top level
- `hero_image.png` at the top level (uploaded only when `upload_hero_image: true`)
- `youtube_url.txt` at the top level
- `title.txt`, `short_description.txt`, `long_description.txt`, `new_feature.txt` in each language directory
- Images in each language's `screenshots/` subdirectory

Only languages and fields that exist on disk are included in the update payload.

> **Note:** The Galaxy Store API exposes additional listing fields (support email, privacy policy URL, copyright holder, age limits, categories, etc.) that this action does not touch — manage them through the [Galaxy Store seller portal](https://seller.samsungapps.com). The local directory format is additive-only: new top-level files or per-language files for these fields can be added in future releases without breaking existing setups.

**Returns:** A hash containing the content update API response.

---

### `galaxy_store_app_list`

Retrieves the full list of apps registered to your Galaxy Store seller account.

```ruby
app_list = galaxy_store_app_list

# Optionally write the result to a JSON file
galaxy_store_app_list(
  output_path: "app_list.json"
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |
| `output_path` | Path to write the app list as a JSON file. When omitted the result is only returned | No |

**Returns:** An array of hashes, each containing app information for a registered app.

---

### `galaxy_store_upload_apk`

Uploads an APK or AAB file to the Galaxy Store. This action handles the full upload flow automatically:

1. Opens an update draft for the app (`contentUpdate`)
2. Creates an upload session ID
3. Uploads the binary file
4. Registers the binary against the content ID (`add binary`)

```ruby
galaxy_store_upload_apk(
  content_id: "000007654321",
  apk_path: "app/build/outputs/apk/release/app-release.apk",
  gms: "N"
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |
| `content_id` | 12-digit app content ID | Yes |
| `apk_path` | Path to the `.apk` or `.aab` file to upload. If not provided will check the existing lane for Grade Output Paths  | No |
| `gms` | `Y` if your build includes the Google Play Services SDK, `N` otherwise. Rarely changes between releases for a given app — hardcode it in your Fastfile | Yes |

**Returns:** The `binarySeq` (string) of the newly added binary, or `nil` if the API did not include one.

**Lane context:** Sets `SharedValues::GALAXY_STORE_BINARY_SEQ` to the same value, so `galaxy_store_update_staged_rollout_binary` can pick it up automatically when chained.

---

### `galaxy_store_set_publication_type`

Configures how and when an app update goes live after passing review. Must be called before `galaxy_store_submit_app`. Defaults to automatic publication (`'01'`) if `publication_type` is not specified.

| Value | Behaviour |
|-------|-----------|
| `'01'` | Publish automatically once the Pre-Review phase completes |
| `'02'` | Publish on a specific date (requires `start_publication_date`) |
| `'03'` | Publish manually — the seller must trigger publication via `galaxy_store_publish_app` after all review phases complete |

```ruby
# Automatic (default)
galaxy_store_set_publication_type(
  content_id: "000007654321",
  publication_type: "01"
)

# Scheduled date
galaxy_store_set_publication_type(
  content_id: "000007654321",
  publication_type: "02",
  start_publication_date: "2026-06-01 09:00:00"
)

# Manual — publisher controls when the update goes live
galaxy_store_set_publication_type(
  content_id: "000007654321",
  publication_type: "03"
)
```

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `access_token` | Galaxy Store API access token | Yes | |
| `service_account_id` | Galaxy Store service account ID | Yes | |
| `content_id` | 12-digit app content ID | Yes | |
| `publication_type` | Publication mode: `'01'` automatic, `'02'` scheduled, `'03'` manual | No | `'01'` |
| `start_publication_date` | Publication date in `yyyy-MM-dd HH:mm:ss` format. Required when `publication_type` is `'02'` | No* | |

*Required when `publication_type` is `'02'`.

**Returns:** A hash containing the content update API response.

---

### `galaxy_store_submit_app`

Submits a pending app update for review. Can be used standalone after making changes in the seller portal, or chained after `galaxy_store_upload_apk` or `galaxy_store_upload_metadata`.

```ruby
galaxy_store_submit_app(
  content_id: "000007654321"
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |
| `content_id` | 12-digit app content ID | Yes |

**Returns:** A hash containing the submission API response.

---

### `galaxy_store_publish_app`

Sets the app status to `FOR_SALE`, making it live on the Galaxy Store. Intended for use after `galaxy_store_submit_app` when the app was submitted with the Manual Publication option (`'03'`), allowing the publisher to control exactly when the update goes live.

```ruby
galaxy_store_publish_app(
  content_id: "000007654321"
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |
| `content_id` | 12-digit app content ID | Yes |

**Returns:** A hash containing the content status update API response.

---

### `galaxy_store_update_staged_rollout_binary`

Adds or removes a binary from the staged rollout group for a given app. Use `galaxy_store_staged_rollout` first to view available binaries and their `binarySeq` values, or chain directly after `galaxy_store_upload_apk` and the seq will be picked up from lane context automatically.

```ruby
# Chain directly after upload — binary_seq picked up from lane context
galaxy_store_upload_apk(
  content_id: "000007654321",
  apk_path: options[:apk_path],
  gms: "N"
)
galaxy_store_update_staged_rollout_binary(
  content_id: "000007654321",
  function: "ADD"
)

# Or specify binary_seq explicitly
galaxy_store_update_staged_rollout_binary(
  content_id: "000007654321",
  function: "REMOVE",
  binary_seq: "15"
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |
| `content_id` | 12-digit app content ID | Yes |
| `function` | `ADD` or `REMOVE` the binary from the staged rollout group | Yes |
| `binary_seq` | The sequence number of the binary. Falls back to `SharedValues::GALAXY_STORE_BINARY_SEQ` (set by `galaxy_store_upload_apk`) when omitted. Use `galaxy_store_staged_rollout` to look up an existing binary's seq | No |

**Returns:** A hash containing the staged rollout binary API response.

---

### `galaxy_store_set_staged_rollout`

Enables or disables the staged rollout rate for a given app. Supports a global rollout rate, per-country rates hardcoded in the Fastfile, or a JSON file for complex per-country configurations.

**Enable with a global rate:**
```ruby
galaxy_store_set_staged_rollout(
  content_id: "000007654321",
  action: "ENABLE",
  app_status: "REGISTRATION",
  rollout_rate: 25
)
```

**Enable with per-country rates hardcoded in the Fastfile:**
```ruby
galaxy_store_set_staged_rollout(
  content_id: "000007654321",
  action: "ENABLE",
  app_status: "REGISTRATION",
  rollout_rate: 25,
  countries: [
    { countryCode: "USA", rolloutRate: 40 },
    { countryCode: "KOR", rolloutRate: 45 }
  ]
)
```

**Enable with per-country rates from a JSON file:**
```ruby
galaxy_store_set_staged_rollout(
  content_id: "000007654321",
  action: "ENABLE",
  app_status: "REGISTRATION",
  rollout_rate: 25,
  countries_json_path: "fastlane/rollout_countries.json"
)
```

Where `rollout_countries.json` contains:
```json
[
  { "countryCode": "USA", "rolloutRate": 40 },
  { "countryCode": "KOR", "rolloutRate": 45 }
]
```

**Disable staged rollout:**
```ruby
galaxy_store_set_staged_rollout(
  content_id: "000007654321",
  action: "DISABLE",
  app_status: "REGISTRATION"
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |
| `content_id` | 12-digit app content ID | Yes |
| `action` | `ENABLE` or `DISABLE` the staged rollout | Yes |
| `app_status` | `SALE` (live binaries) or `REGISTRATION` (pending binaries) | Yes |
| `rollout_rate` | Global rollout percentage (1-100). Required when action is `ENABLE` | No* |
| `countries` | Array of per-country rollout rates for hardcoding in a Fastfile | No |
| `countries_json_path` | Path to a JSON file containing per-country rollout rates. Takes precedence over `countries` | No |

*Required when `action` is `ENABLE`.

**Returns:** A hash containing the staged rollout rate API response.

---

### `galaxy_store_staged_rollout`

Checks which binaries have staged rollout enabled for a given app, and if any are found, also retrieves the current rollout rate.

```ruby
galaxy_store_staged_rollout(
  content_id: "000007654321",
  app_status: "SALE" # or "REGISTRATION"
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |
| `content_id` | 12-digit app content ID | Yes |
| `app_status` | `SALE` (live binaries) or `REGISTRATION` (pending binaries) | Yes |

**Returns:** A hash with `binaries` (array of binary info) and `rollout_rate` (rate data, or `nil` if rollout is not enabled).

---

## App status lifecycle

Each listing returned by `galaxy_store_app_info` has a `contentStatus` field that reflects where it sits in the Galaxy Store publication flow. Common values:

| Status | Meaning |
|--------|---------|
| `REGISTERING` | A first-time submission that has not yet been submitted for review |
| `UPDATING` | An update to a previously published app that has not yet been submitted for review |
| `READY_FOR_REVIEW` | Submitted, queued for Samsung's review pipeline |
| `UNDER_DEVICE_TEST` | In the device-testing phase of review |
| `READY_FOR_CHANGE` | Passed review and awaiting manual publication. Only appears when `galaxy_store_set_publication_type` was set to `'03'` (manual) |
| `FOR_SALE` | The listing is live on the Galaxy Store |

Samsung's review pipeline includes additional intermediate states we may not have documented yet. The `galaxy_store_app_info` action handles this by treating any `contentStatus` other than `FOR_SALE` as in-progress, so new statuses are picked up automatically. A rejected submission returns to `REGISTERING` or `UPDATING` rather than producing a distinct rejected status — check the seller portal for review feedback.

After `galaxy_store_submit_app` with manual publication (`'03'`), poll `galaxy_store_app_info` and call `galaxy_store_publish_app` once the in-progress listing reaches `READY_FOR_CHANGE`:

```ruby
lane :publish_when_ready do
  info = galaxy_store_app_info(content_id: "000007654321")
  ready = info.any? { |entry| entry['contentStatus'] == 'READY_FOR_CHANGE' }
  if ready
    galaxy_store_publish_app(content_id: "000007654321")
  else
    UI.message("Not yet approved — try again later")
  end
end
```

---

## Example Workflows

### Full release workflow

Upload a new binary and submit it for review in a single lane:

```ruby
lane :release do |options|
  galaxy_store_upload_apk(
    content_id: "000007654321",
    apk_path: options[:apk_path],
    gms: "N"
  )
  galaxy_store_submit_app(
    content_id: "000007654321"
  )
end
```

### Manual publication workflow

Upload and submit with manual publication mode, then publish separately once the review has completed:

```ruby
lane :release_manual do |options|
  galaxy_store_upload_apk(
    content_id: "000007654321",
    apk_path: options[:apk_path],
    gms: "N"
  )
  galaxy_store_set_publication_type(
    content_id: "000007654321",
    publication_type: "03"
  )
  galaxy_store_submit_app(
    content_id: "000007654321"
  )
end

# Run this lane separately once the review has passed
lane :publish do
  galaxy_store_publish_app(
    content_id: "000007654321"
  )
end
```

### Import metadata from Google Play (Supply)

If you already manage your Play Store listing with Supply, import that content into the Galaxy Store format and push it up:

```ruby
lane :import_and_upload_metadata do
  galaxy_store_import_from_supply(
    default_language_code: "ENG"
  )
  galaxy_store_upload_metadata(
    content_id: "000007654321"
  )
end
```

---

### Sync and update store listing metadata

Pull current metadata from the Galaxy Store, edit the local files, then push your changes:

```ruby
# Pull metadata from Galaxy Store to local files
lane :fetch_metadata do
  galaxy_store_app_info(
    content_id: "000007654321"
  )
end

# Push local metadata changes back to Galaxy Store
lane :upload_metadata do
  galaxy_store_upload_metadata(
    content_id: "000007654321"
  )
end
```

---

## Issues and Feedback

For any issues or feedback, please submit them to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## About fastlane

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
