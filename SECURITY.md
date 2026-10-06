# Security Policy

## Supported Versions

Only the latest released version of this plugin receives security fixes. Keep
`fastlane-plugin-galaxystore` up to date in your `Gemfile` / `Pluginfile`.

## Reporting a Vulnerability

Please do **not** report security vulnerabilities through public GitHub issues.

Instead, use GitHub's private vulnerability reporting: open the **Security** tab of this
repository and choose **Report a vulnerability**. You will receive a response as soon as
possible, normally within a few business days.

Please include:

- A description of the issue and its impact
- Steps to reproduce (a minimal Fastfile lane if applicable)
- Any suggested remediation

## Scope notes

- The plugin sends your Galaxy Store access token and service account ID only to
  `devapi.samsungapps.com` and `seller.samsungapps.com`, always over HTTPS. Image
  downloads performed by `galaxy_store_app_info` carry no credentials and only follow
  HTTPS redirects to public addresses.
- `access_token` and `service_account_id` are marked sensitive, so fastlane redacts them
  in its parameter summary. Supply them via the `GALAXY_STORE_ACCESS_TOKEN` and
  `GALAXY_STORE_SERVICE_ACCOUNT_ID` environment variables from your CI secret store;
  never commit them to a Fastfile.
- Releases on rubygems.org are published by MFA-protected accounts only.
