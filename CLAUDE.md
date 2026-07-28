# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run all checks (specs + rubocop)
bundle exec rake

# Run specs only
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/galaxy_store_upload_apk_spec.rb

# Run rubocop linter
bundle exec rubocop

# Auto-fix rubocop offenses
bundle exec rubocop -a
```

## Architecture

This is a [fastlane](https://github.com/fastlane/fastlane) plugin for managing Android app releases on the Samsung Galaxy Store via the [Galaxy Store Developer API](https://developer.samsung.com/galaxy-store/galaxy-store-developer-api.html).

### Key layers

**Actions** (`lib/fastlane/plugin/galaxystore/actions/`) — Each file is a standalone fastlane action following the `Fastlane::Actions::SomeNameAction` convention. All actions that call the Galaxy Store API instantiate `Helper::GalaxyStoreClient` with `service_account_id` and `access_token`. Parameters are declared via `available_options` using `FastlaneCore::ConfigItem`, and each sensitive param has a corresponding `env_name` (e.g. `GALAXY_STORE_ACCESS_TOKEN`).

**GalaxyStoreClient** (`helper/galaxy_store_client.rb`) — Thin HTTP wrapper around `https://devapi.samsungapps.com`. All requests set `Authorization: Bearer <token>` and `service-account-id` headers. File uploads go to a separate host (`seller.samsungapps.com`) using a multipart body built manually. `handle_response` raises `UI.user_error!` for non-200/204 responses.

**LanguageMapper** (`helper/language_mapper.rb`) — Converts BCP-47 locale codes (used by fastlane Supply / Google Play) to Samsung's three-letter Galaxy Store language codes (e.g. `en` → `ENG`, `es` → `SPA`). Chinese requires special-casing (Simplified vs Traditional by region). `resolve_languages` handles many-to-one collisions using a built-in priority list and optional developer overrides.

### Local metadata structure

Galaxy Store metadata lives under `fastlane/metadata/galaxystore/`:
```
fastlane/metadata/galaxystore/
  icon.png                     # single icon, shared across languages
  ENG/
    title.txt
    short_description.txt
    long_description.txt
    screenshots/
      1.png, 2.png, ...
  FRA/
    ...
```

The `galaxy_store_import_from_supply` action populates this directory from `fastlane/metadata/android/` (Supply format). The `galaxy_store_upload_metadata` action reads this directory and pushes it to the API.

### APK upload flow

`galaxy_store_upload_apk` executes these Galaxy Store API calls in sequence:
1. `POST /seller/contentUpdate` — opens an update draft
2. `POST /seller/createUploadSessionId` — gets a session ID
3. `POST seller.samsungapps.com/galaxyapi/fileUpload` — uploads the binary (multipart)
4. `POST /seller/v2/content/binary` — registers the file key against the content ID


## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
