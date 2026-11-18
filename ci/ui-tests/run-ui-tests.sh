#!/usr/bin/env bash
# Runs inside reactivecircus/android-emulator-runner once the emulator is up.
#   1. installs the debug APK,
#   2. runs the Maestro user journey,
#   3. runs N Monkey rounds, each after a fresh Maestro sign-in.
# Every stage runs even if an earlier one failed; results go to $OUT and the
# script exits non-zero at the end if anything failed.
set -uo pipefail

APK="${APK:?APK is required}"
OUT="${OUT:-ui-test-results}"
PKG="${PKG:-com.nursultankoshoev.mobilechat.debug}"
MONKEY_ROUNDS="${MONKEY_ROUNDS:-4}"
MONKEY_EVENTS="${MONKEY_EVENTS:-1500}"
MONKEY_SEED_BASE="${MONKEY_SEED_BASE:-4242}"
# One APP_REVIEW test account per Monkey round (the backend allows only a few
# code requests per number per 10 minutes).
MONKEY_PHONES=(${MONKEY_PHONES:-700000102 700000103 700000104 700000105})

mkdir -p "$OUT/maestro" "$OUT/monkey" "$OUT/logcat"
SUMMARY="$OUT/summary.md"
: > "$SUMMARY"
failures=0

note() { echo "$*" | tee -a "$SUMMARY"; }

# Flutter/Android failure patterns in `adb logcat -v threadtime` output.
LOGCAT_FAIL_RE='FATAL EXCEPTION|ANR in '"$PKG"'| E flutter |EXCEPTION CAUGHT BY|Unhandled Exception|Another exception was thrown'

check_logcat() { # file label
  local file="$1" label="$2" hits
  hits="$(grep -E "$LOGCAT_FAIL_RE" "$file" | grep -v 'Firebase unavailable' || true)"
  if [ -n "$hits" ]; then
    note "- FAIL $label: crash/Flutter error in logcat ($(echo "$hits" | wc -l) lines), see $(basename "$file")"
    echo "$hits" | head -20 | sed 's/^/    /' | tee -a "$SUMMARY"
    return 1
  fi
  note "- ok $label: logcat clean"
}

capture_logcat() { # file
  adb logcat -d -v threadtime > "$1" 2>&1 || true
}

maestro_run() { # label flow [env...]
  local label="$1" flow="$2"; shift 2
  local args=()
  local kv
  for kv in "$@"; do args+=(-e "$kv"); done
  maestro test "${args[@]}" \
    --format junit --output "$OUT/maestro/$label.xml" \
    --test-output-dir "$OUT/maestro/$label" \
    "$flow"
}

adb wait-for-device
adb logcat -G 16M || true
# A freshly booted CI emulator often shows "Pixel Launcher isn't responding";
# that system dialog covers the app under test. Hide system crash/ANR dialogs
# (app crashes/ANRs are still caught from Monkey output and logcat) and let
# the launcher settle before starting.
adb shell settings put global hide_error_dialogs 1 || true
until [ "$(adb shell getprop sys.boot_completed | tr -d '')" = 1 ]; do sleep 2; done
sleep 20
adb shell input keyevent KEYCODE_HOME || true
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true

echo "Installing $APK"
adb install -r -g "$APK"

# ---- Maestro user journey -------------------------------------------------
adb logcat -c || true
if maestro_run journey .maestro/journey.yaml; then
  note "- ok Maestro journey"
else
  note "- FAIL Maestro journey (see maestro/journey)"
  failures=$((failures + 1))
fi
capture_logcat "$OUT/logcat/journey.txt"
check_logcat "$OUT/logcat/journey.txt" "Maestro journey" || failures=$((failures + 1))

# ---- Monkey rounds ----------------------------------------------------------
for round in $(seq 1 "$MONKEY_ROUNDS"); do
  seed=$((MONKEY_SEED_BASE + round))
  phone="${MONKEY_PHONES[$((round - 1))]:-${MONKEY_PHONES[0]}}"
  label="monkey-round$round"
  adb logcat -c || true

  if ! maestro_run "$label-login" .maestro/monkey_login.yaml \
      "PHONE_LOCAL=$phone" "DISPLAY_NAME=Monkey $round"; then
    note "- FAIL $label: sign-in before Monkey failed; Monkey still runs on whatever screen is shown"
    failures=$((failures + 1))
  fi

  echo "Monkey round $round: seed=$seed events=$MONKEY_EVENTS"
  adb shell monkey -p "$PKG" --throttle 100 --pct-syskeys 0 -s "$seed" -v "$MONKEY_EVENTS" \
    > "$OUT/monkey/$label.txt" 2>&1
  rc=$?
  capture_logcat "$OUT/logcat/$label.txt"

  round_failed=0
  if grep -qE '// CRASH|// NOT RESPONDING|ANR in|Monkey aborted' "$OUT/monkey/$label.txt"; then
    note "- FAIL $label (seed $seed): Monkey reported a crash/ANR"
    grep -E -A12 '// CRASH|// NOT RESPONDING|ANR in' "$OUT/monkey/$label.txt" | head -40 | sed 's/^/    /' | tee -a "$SUMMARY"
    round_failed=1
  elif [ "$rc" -ne 0 ] || ! grep -q 'Monkey finished' "$OUT/monkey/$label.txt"; then
    note "- FAIL $label (seed $seed): Monkey exited with $rc without finishing"
    tail -20 "$OUT/monkey/$label.txt" | sed 's/^/    /' | tee -a "$SUMMARY"
    round_failed=1
  else
    note "- ok $label (seed $seed): $(grep -m1 'Events injected' "$OUT/monkey/$label.txt" || echo 'finished')"
  fi
  check_logcat "$OUT/logcat/$label.txt" "$label logcat" || round_failed=1
  failures=$((failures + round_failed))

  # Recover the app for the next round if Monkey left it dead.
  adb shell am force-stop "$PKG" || true
done

note ""
note "UI test failures: $failures"
[ "$failures" -eq 0 ]
