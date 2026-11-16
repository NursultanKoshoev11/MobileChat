# Koom iOS TestFlight setup

The App Store Connect record for Koom already exists:

- App ID: `6835412657`
- Bundle ID: `com.nursultankoshoev.mobilechat`
- Launcher icon source: `assets/images/koom_app_icon.png`

The iOS workflow generates launcher icons from the project source and can build either unsigned artifacts or a signed build for TestFlight. The TestFlight path is a manual GitHub Actions workflow dispatch. It uploads a build to App Store Connect only; it does not submit the app for App Review, release it publicly, or invite testers.

## Required GitHub Actions secrets

Add these under **Settings → Secrets and variables → Actions** in `NursultanKoshoev11/MobileChat`:

| Secret | Value |
| --- | --- |
| `IOS_CERTIFICATE_P12_BASE64` | Base64-encoded Apple Distribution certificate in PKCS#12 format |
| `IOS_CERTIFICATE_PASSWORD` | Password used to export the PKCS#12 certificate |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store provisioning profile for the Koom bundle ID |
| `IOS_EXPORT_OPTIONS_PLIST_BASE64` | Base64-encoded Xcode export options property list |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | Base64-encoded private `.p8` key for the API key above |

Use a Developer-role API key restricted to Koom if the account supports app-specific user keys. Keep all signing and API key material in GitHub Actions secrets; do not commit it or put it in workflow inputs. The workflow checks that the certificate, profile, export settings, bundle ID, and team ID agree before building.

The export options plist must use the App Store Connect distribution method, include the matching Apple team ID, and map `com.nursultankoshoev.mobilechat` to the App Store provisioning profile name or UUID.

## Upload a test build

In GitHub, open **Actions → iOS Build → Run workflow**, choose `testflight` as the destination, and keep the Koom bundle ID and production API URL unless a different HTTPS test endpoint is intended. After Apple processes the build, add it to an internal TestFlight group and invite the intended testers in App Store Connect.

The default `artifact` destination builds downloadable simulator and unsigned iPhone artifacts. Pushes to `main` keep their existing build-only behavior and do not upload to TestFlight.
