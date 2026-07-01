# Mobile APK QA with Firebase Test Lab

This folder documents the APK testing flow for MobileChat.

## Test types

- Firebase Robo: automatic crash crawl. It is useful, but it is not reliable for business flows in Flutter apps.
- Flutter integration test: deterministic five-person working-group flow used for login, group entry/creation, post creation, comments, votes, chat, invitations, role/membership checks, one-hour comment blocking, and owner tools.

The full QA scenario lives in `integration_test/app_flow_test.dart`.

## Full flow covered by integration_test

The Test Lab instrumentation run now acts as five QA users:

- starts the app;
- authenticates five test phones with code `111111`;
- logs the primary actor into the real UI;
- opens the groups screen;
- creates a group when the test account has admin permissions;
- otherwise opens or joins an available public group;
- creates a discussion publication;
- opens statistics, group access, admin management, invite, moderation, settings, and comment-mute tools;
- makes the second, third, fourth, and fifth actors join or accept an invite to the group;
- makes one invited actor decline an invitation first, then accept a fresh invite;
- creates discussion, vote-only, and read-only publications;
- creates additional publications as the fourth and fifth actors;
- uploads a tiny PNG through the public-request upload API;
- creates a media publication and verifies the media block/photo section in the real details UI;
- votes support and oppose as different actors;
- opens the publication details;
- writes UI and API comments as different actors;
- sends and reads group chat messages from all five actors through the backend API;
- issues a WebSocket token for realtime coverage;
- registers and deletes a push token;
- generates or reads the group invite code;
- makes one actor leave and rejoin the group through invite code;
- checks invalid invite code rejection;
- checks invalid auth code rejection without creating a session;
- promotes and demotes a member by phone;
- promotes and demotes another member as an admin check;
- mutes a member for one hour by phone;
- verifies the muted member cannot comment while blocked;
- unmutes the member and verifies commenting works again;
- creates and deletes a temporary comment;
- verifies request status, vote counters, comment counters, and comment contents through the backend API;
- verifies group statistics through the backend API.

If strict group creation is required, run the test with a `platform_admin` or `super_admin` test phone. A normal user can create a post/comment only inside an existing or joinable public group.

The APK now has a role preflight. `TEST_EXPECTED_USER_ROLE` defaults to `user`.
For a super-admin run, pass a phone that the backend returns as `super_admin`
and set `TEST_EXPECTED_USER_ROLE=super_admin`; otherwise the test fails before
UI actions with a clear setup error.

It also checks group membership through `TEST_EXPECTED_GROUP_ROLE`. The current
working production demo phone `+996555555555` is a global `user`, but it is an
`owner` in existing public groups, so it covers the group-admin/owner screens.

## Required GitHub secrets

Set these in GitHub repository settings before running the workflow:

```text
GCP_SA_KEY
FIREBASE_RESULTS_BUCKET        optional
TEST_AUTH_PHONE                optional, defaults to +996555555555
TEST_ACTOR2_PHONE              optional, defaults to +996700000001
TEST_ACTOR3_PHONE              optional, defaults to +996700000002
TEST_ACTOR4_PHONE              optional, defaults to +996700000003
TEST_ACTOR5_PHONE              optional, defaults to +996700000004
TEST_AUTH_CODE                 optional, defaults to 111111
TEST_AUTH_DISPLAY_NAME         optional, defaults to Koom QA Owner
TEST_ACTOR2_DISPLAY_NAME       optional, defaults to Koom QA Supporter
TEST_ACTOR3_DISPLAY_NAME       optional, defaults to Koom QA Opponent
TEST_ACTOR4_DISPLAY_NAME       optional, defaults to Koom QA Observer
TEST_ACTOR5_DISPLAY_NAME       optional, defaults to Koom QA Reviewer
TEST_EXPECTED_USER_ROLE        optional, defaults to user
TEST_EXPECTED_GROUP_ROLE       optional, defaults to owner
```

`GCP_SA_KEY` must be a Google Cloud service account JSON with permission to run Firebase Test Lab in project `koom-9f163`.

The backend used by `api_base_url` must allow all five test phones in test auth
configuration. For the Go backend, `TEST_AUTH_PHONE` can be comma-separated,
or the public demo phone allowlist must include all five numbers. A quick
preflight signal is that `/api/auth/request-code` returns `test_code_ready` for
each QA phone; if it returns `code_sent`, Test Lab will fail at `verify-code`
with `invalid credentials`.

## Manual GitHub Actions run

Open GitHub Actions, choose **Mobile Firebase Test Lab QA**, and run it with:

```text
api_base_url = https://koom.servemp3.com
run_robo = true
run_integration = true
```

## Local Windows run

Before the first run, sign in to Google Cloud:

```powershell
gcloud auth login
gcloud config set project koom-9f163
```

The default Test Lab device is `model=Pixel2.arm,version=30,locale=ru,orientation=portrait`.
Use the `.arm` model id; `Pixel2` is not a valid Firebase Test Lab model for this project.

Run the full deterministic Flutter flow in Firebase Test Lab:

```powershell
.\scripts\run_firebase_integration_testlab.ps1 -Build
```

Run the role matrix:

```powershell
.\scripts\run_firebase_role_matrix.ps1
```

Run a strict super-admin build after the backend has a test super-admin phone:

```powershell
.\scripts\run_firebase_integration_testlab.ps1 `
  -Build `
  -TestAuthPhone "+996000000000" `
  -TestActor2Phone "+996700000001" `
  -TestActor3Phone "+996700000002" `
  -TestActor4Phone "+996700000003" `
  -TestActor5Phone "+996700000004" `
  -TestExpectedUserRole "super_admin"
```

Run only the Robo crash crawl:

```powershell
.\scripts\run_firebase_robo.ps1 -Build
```

If APKs are already built, run the integration test without rebuilding:

```powershell
.\scripts\run_firebase_integration_testlab.ps1 `
  -AppApk "build/app/outputs/apk/debug/app-debug.apk" `
  -TestApk "build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
```

## Local bash run

```bash
flutter pub get
flutter build apk --debug -t lib/main.dart \
  --dart-define=API_BASE_URL=https://koom.servemp3.com \
  --dart-define=TEST_AUTH_PHONE=+996555555555 \
  --dart-define=TEST_ACTOR2_PHONE=+996700000001 \
  --dart-define=TEST_ACTOR3_PHONE=+996700000002 \
  --dart-define=TEST_ACTOR4_PHONE=+996700000003 \
  --dart-define=TEST_ACTOR5_PHONE=+996700000004

cd android
./gradlew app:assembleAndroidTest -Ptarget=integration_test/app_flow_test.dart
./gradlew app:assembleDebug \
  -Ptarget=integration_test/app_flow_test.dart \
  -Pdart-defines="$(printf '%s\n' \
    API_BASE_URL=https://koom.servemp3.com \
    TEST_AUTH_PHONE=+996555555555 \
    TEST_ACTOR2_PHONE=+996700000001 \
    TEST_ACTOR3_PHONE=+996700000002 \
    TEST_ACTOR4_PHONE=+996700000003 \
    TEST_ACTOR5_PHONE=+996700000004 \
    TEST_AUTH_CODE=111111 | while IFS= read -r value; do printf '%s' "$value" | base64 -w0; printf ','; done | sed 's/,$//')"
cd ..

bash scripts/run_firebase_integration_testlab.sh
```

## What counts as passed

A run is acceptable only when:

- `flutter analyze --no-fatal-infos` passes;
- `flutter test` passes;
- debug APK builds successfully;
- Android instrumentation test APK builds successfully;
- Firebase instrumentation test completes without Flutter test failure;
- Test Lab artifacts contain screenshots, video, and logs for review.

## Firebase quota failures

`TEST_QUOTA_EXCEEDED` means Firebase stopped the run during validation before
starting the device. In that case there is no new app logcat, XML, screenshot,
or video to inspect. Increase Test Lab quota, wait for the quota reset, or run
the same APKs against a billing-enabled Firebase/GCP project.
