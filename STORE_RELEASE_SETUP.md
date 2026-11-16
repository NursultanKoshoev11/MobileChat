# Store releases from `main`

The Android and iOS workflows build and submit releases when a commit reaches `main`.
`workflow_dispatch` remains build-only, so a manual run will not publish to either store.

## Google Play

Add the repository Actions secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. Its value is the full
service-account JSON key. The service account must have access to the existing Play Console
app `com.nursultankoshoev.mobilechat` and permission to manage production releases. The
workflow signs the AAB with the existing Android upload-key secrets, then submits it to the
production track. A successful upload means Google Play accepted the submission; Google may
still review it before users receive it.

The workflow uses `run_number * 100 + run_attempt` as `versionCode`, so rerunning a release
gets a new code. The displayed version is `1.0.<run_number>`.

## App Store

Add these repository Actions secrets:

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_EXPORT_OPTIONS_PLIST_BASE64`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8_BASE64`

For each file secret, create a single-line Base64 value on Windows PowerShell with:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\to\file'))
```

Use the `.p12` certificate, `.mobileprovision` profile, export-options `.plist`, and
App Store Connect `.p8` key for the corresponding secrets above. Keep the original files
and passwords private; add the encoded value directly in the GitHub secret form.

The export-options plist must describe this exact bundle ID, team, and provisioning
profile. Its key values are configuration, not credentials from the App Store. For
example, use this structure and replace the team ID and profile UUID with the values in
your Apple Developer account:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>YOUR_TEAM_ID</string>
  <key>provisioningProfiles</key><dict>
    <key>com.nursultankoshoev.mobilechat</key><string>YOUR_PROFILE_UUID</string>
  </dict>
</dict></plist>
```

The workflow checks that the team ID and profile UUID/name match the downloaded profile,
then configures the generated Xcode project for manual App Store signing.

`IOS_KEYCHAIN_PASSWORD` is optional. The certificate, provisioning profile, and export
options must be for the App Store distribution of `com.nursultankoshoev.mobilechat`. The
App Store Connect API key needs permission to upload builds and submit the app for review.
The app record must already exist in App Store Connect.

On `main`, the workflow signs the IPA, uploads it, and submits the existing app listing for
review without replacing its metadata or screenshots. It requests automatic release after
Apple approves the build; Apple review is still required. The marketing version is
`1.0.<run_number>` and the build number is `<run_id>.<run_attempt>`.

## What blocks a release

The workflows fail before store submission if their required credentials are missing. Store
accounts also need an existing app record, valid signing assets, and completed store-side
requirements (such as agreements, privacy answers, review details, and listing metadata).
For Google Play, the app/package must already be created in Play Console. For Apple, the
existing App Store Connect listing must be ready to receive a new build and review submission.
