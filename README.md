# fastlane-plugin-upload_galaxystore

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-upload_galaxystore)

A [fastlane](https://github.com/fastlane/fastlane) plugin for managing Android app releases on the Samsung Galaxy Store using the [Galaxy Store Developer API](https://developer.samsung.com/galaxy-store/galaxy-store-developer-api.html).

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

The plugin requires two credentials for all API calls. Set these as environment variables to avoid hardcoding secrets in your Fastfile:

```bash
export GALAXY_STORE_ACCESS_TOKEN="your-access-token"
export GALAXY_STORE_SERVICE_ACCOUNT_ID="your-service-account-id"
```

---

## Actions

### `galaxy_store_app_list`

Retrieves the full list of apps registered to your Galaxy Store seller account.

```ruby
app_list = galaxy_store_app_list(
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"]
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |

**Returns:** An array of hashes, each containing app information for a registered app.

---

### `galaxy_store_app_info`

Retrieves detailed information for a specific app and writes the metadata to local files in `fastlane/metadata/galaxystore/`. Prefers an `UPDATING` listing if one exists, otherwise falls back to the `FOR_SALE` listing.

The following files are written for each supported language:

```
fastlane/metadata/galaxystore/
  icon.png
  ENG/
    title.txt
    short_description.txt
    long_description.txt
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
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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

The action scans the `galaxystore/` directory for:
- `icon.png` (or other image extension) at the top level
- `title.txt`, `short_description.txt`, `long_description.txt` in each language directory
- Images in each language's `screenshots/` subdirectory

Only languages and fields that exist on disk are included in the update payload.

**Returns:** A hash containing the content update API response.

---

### `galaxy_store_upload_apk`

Uploads an APK or AAB file to the Galaxy Store. This action handles the full upload flow automatically:

1. Opens an update draft for the app (`contentUpdate`)
2. Creates an upload session ID
3. Uploads the binary file
4. Registers the binary against the content ID (`add binary`)

```ruby
galaxy_store_upload_apk(
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
  content_id: "000007654321",
  apk_path: "app/build/outputs/apk/release/app-release.apk"
)
```

| Parameter | Description | Required |
|-----------|-------------|----------|
| `access_token` | Galaxy Store API access token | Yes |
| `service_account_id` | Galaxy Store service account ID | Yes |
| `content_id` | 12-digit app content ID | Yes |
| `apk_path` | Path to the `.apk` or `.aab` file to upload | Yes |

**Returns:** A hash containing the add binary API response.

---

### `galaxy_store_submit_app`

Submits a pending app update for review. Can be used standalone after making changes in the seller portal, or chained after `galaxy_store_upload_apk` or `galaxy_store_upload_metadata`.

```ruby
galaxy_store_submit_app(
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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

### `galaxy_store_update_staged_rollout_binary`

Adds or removes a binary from the staged rollout group for a given app. Use `galaxy_store_staged_rollout` first to view available binaries and their `binarySeq` values.

```ruby
# Add a binary to staged rollout
galaxy_store_update_staged_rollout_binary(
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
  content_id: "000007654321",
  function: "ADD",
  binary_seq: "15"
)

# Remove a binary from staged rollout
galaxy_store_update_staged_rollout_binary(
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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
| `binary_seq` | The sequence number of the binary. Use `galaxy_store_staged_rollout` to find this value | Yes |

**Returns:** A hash containing the staged rollout binary API response.

---

### `galaxy_store_set_staged_rollout`

Enables or disables the staged rollout rate for a given app. Supports a global rollout rate, per-country rates hardcoded in the Fastfile, or a JSON file for complex per-country configurations.

**Enable with a global rate:**
```ruby
galaxy_store_set_staged_rollout(
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
  content_id: "000007654321",
  action: "ENABLE",
  app_status: "REGISTRATION",
  rollout_rate: 25
)
```

**Enable with per-country rates hardcoded in the Fastfile:**
```ruby
galaxy_store_set_staged_rollout(
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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
  access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
  service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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

## Example Workflows

### Full release workflow

Upload a new binary and submit it for review in a single lane:

```ruby
lane :release do |options|
  galaxy_store_upload_apk(
    access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
    service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
    content_id: "000007654321",
    apk_path: options[:apk_path]
  )
  galaxy_store_submit_app(
    access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
    service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
    content_id: "000007654321"
  )
end
```

### Sync and update store listing metadata

Pull current metadata from the Galaxy Store, edit the local files, then push your changes:

```ruby
# Pull metadata from Galaxy Store to local files
lane :fetch_metadata do
  galaxy_store_app_info(
    access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
    service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
    content_id: "000007654321"
  )
end

# Push local metadata changes back to Galaxy Store
lane :upload_metadata do
  galaxy_store_upload_metadata(
    access_token: ENV["GALAXY_STORE_ACCESS_TOKEN"],
    service_account_id: ENV["GALAXY_STORE_SERVICE_ACCOUNT_ID"],
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
