# Store releases from `main`

The Android workflow submits releases when a commit reaches `main`. The iOS workflow uploads
signed builds to TestFlight on `main`; App Store review and public release remain manual.
`workflow_dispatch` runs unsigned iOS builds only.

## Google Play

The repository Actions secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` is configured. The service
account has access to the existing Play Console app `com.nursultankoshoev.mobilechat` and
permission to publish releases.
The workflow signs the AAB with the existing Android upload-key secrets, then submits it to
the `alpha` closed-testing track. Koom must first complete Google Play's closed-testing
eligibility requirement and receive production access before the workflow is changed to submit
production releases. A successful upload means Google Play accepted the submission; Google
may still review it before testers or users receive it.

The workflow uses `run_number * 100 + run_attempt` as `versionCode`, so rerunning a release
gets a new code. The displayed version is `1.0.<run_number>`.

## App Store

The GitHub Actions environment `ios-production` exists and is restricted to the `main` branch.
It contains these signing and App Store Connect secrets:

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_EXPORT_OPTIONS_PLIST_BASE64`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8_BASE64`

The signing secrets are configured for the Koom App Store distribution certificate and
profile. Do not commit their source files, passwords, or encoded values to the repository.
The profile is named `Koom App Store Distribution 2026`, uses team `7RHTX4XXX2`, and
expires on 2027-11-16. Rotate the certificate, profile, and matching secrets before expiry.

The export-options plist must describe this exact bundle ID, team, and provisioning
profile. Its key values are configuration, not credentials from the App Store. The
configured export-options plist uses this structure and current profile UUID:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>7RHTX4XXX2</string>
  <key>provisioningProfiles</key><dict>
    <key>com.nursultankoshoev.mobilechat</key><string>5ce51063-7768-433d-b3a3-74fa069062c0</string>
  </dict>
</dict></plist>
```

The workflow checks that the team ID and profile UUID/name match the downloaded profile,
then configures the generated Xcode project for manual App Store signing. The signed IPA job
uses the `macos-26` runner so it builds with the iOS 26 SDK required by App Store Connect.

`IOS_KEYCHAIN_PASSWORD` is optional. The certificate, provisioning profile, and export
options must be for the App Store distribution of `com.nursultankoshoev.mobilechat`. The
App Store Connect API key needs permission to upload builds. A Team API key applies to
all apps in the Apple account, even with the Developer role; the workflow uses it only to
upload Koom builds to TestFlight.
The app record must already exist in App Store Connect.

These workflow changes are in PR #48 (`codex/store-auto-release` → `main`). Until that PR is
merged, the new store-release jobs are not active on `main`.

On `main`, the workflow signs the IPA and uploads it to TestFlight. It does not add testers,
submit the app for App Review, or release it publicly. The marketing version is
`1.0.<run_number>` and the build number is `<run_id>.<run_attempt>`.

## What blocks a release

The workflows fail before store submission if their required credentials are missing. Store
accounts also need an existing app record and valid signing assets. App Store public release
also requires completed store-side requirements (such as agreements, privacy answers, review
details, and listing metadata).
For Google Play, the app/package must already be created in Play Console. New personal
developer accounts may also need to complete the required closed test before production access
is granted. For Apple, the existing App Store Connect listing must be ready before a public
App Review submission.

## Before store submission

The app code now covers the client side of these review requirements: report/block for
user-generated content (App Store guideline 1.2, Google Play UGC policy), required acceptance
of the Terms of Use and Privacy Policy at sign-in, Terms/Privacy links in the profile, no
crash when Firebase is not configured, FCM token deletion on logout/account deletion,
private lock-screen notifications on Android, and `ITSAppUsesNonExemptEncryption=false`.
The items below still have to be done by the owner.

### Backend and content

- [ ] Deploy the report/block API the app calls: `POST /api/reports`,
      `POST`/`DELETE /api/users/{id}/block`, `GET /api/me/blocks`,
      `GET /api/groups/{id}/reports`, `POST /api/reports/{id}/resolve`. Until then the app
      shows "not available yet" for these actions (it handles HTTP 404/405).
- [ ] Publish `https://koom.com.kg/privacy` and `https://koom.com.kg/terms`. The Terms must
      state that objectionable content and abusive users are not tolerated, and describe how
      reports are handled (Apple expects action on reports within 24 hours).
- [ ] Make sure the server sets Android notification visibility to private (or omits content)
      for FCM notification messages, because system-displayed notifications bypass the app's
      local-notification settings.
- [ ] If invite codes become 12 characters long, the server must accept codes with dashes in
      groups of three (`ABC-DEF-234-567`), as the app sends them formatted.

### iOS

- [ ] Add `ios/Runner/GoogleService-Info.plist` (for example with `flutterfire configure`).
      Without it the app runs, but push notifications are disabled on iOS.
- [ ] Commit a real iOS Xcode project (`ios/Runner.xcodeproj`, `Runner.xcworkspace`,
      `Podfile`, entitlements) instead of regenerating it in CI with `flutter create`; signing,
      capabilities and privacy files cannot be maintained reliably in a regenerated project.
- [ ] Create an APNs authentication key in the Apple Developer account and upload it to
      Firebase (Project settings → Cloud Messaging → Apple app configuration).
- [ ] Enable the Push Notifications capability and add the `aps-environment` entitlement
      (`production` for App Store builds); keep Background Modes → Remote notifications.
- [ ] Add `ios/Runner/PrivacyInfo.xcprivacy` declaring collected data types and required-reason
      APIs (for example UserDefaults / file timestamp APIs used by plugins), and check the
      privacy manifests of third-party SDKs (Firebase, image/file pickers, video player).
- [ ] Permission strings in `Info.plist` are Russian only (there is no `InfoPlist.strings`
      localization yet). Add Kyrgyz `InfoPlist.strings` once the Xcode project is committed.
- [ ] Fill in the App Store privacy "nutrition labels" in App Store Connect (phone number,
      name, photos/videos, user content, device push token, crash/diagnostics if any).
- [ ] Provide a demo account for App Review (test phone number + fixed verification code, or
      a review-only login path) in App Review Information, with a group that has content.
- [ ] Mention the report/block features and the moderation process in the review notes.

### Android / Google Play

- [ ] Complete the Play Console **Data safety** form (phone number, name, photos/videos,
      messages/user content, device IDs/push token; data encrypted in transit; account
      deletion available in the app).
- [ ] Declare user-generated content and the moderation features in the Play Console app
      content section.
- [ ] Provide reviewer access (demo account) in Play Console → App access.

### Firebase

- [ ] Restrict the Firebase/Google API key from `google-services.json` in Google Cloud
      Console: Android apps restricted to package `com.nursultankoshoev.mobilechat` + the
      upload and Play app-signing SHA-1 fingerprints; iOS key restricted to the bundle ID;
      limit the APIs the key can call.
- [ ] Enable Firebase App Check (Play Integrity on Android, App Attest/DeviceCheck on iOS)
      and enforce it for the Firebase services in use.
