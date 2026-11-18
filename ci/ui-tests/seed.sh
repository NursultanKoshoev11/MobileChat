#!/usr/bin/env bash
# Seeds the throwaway UI-test backend through its public API:
#   * each test user signs in once (fixed APP_REVIEW code, no SMS),
#   * submits a group-creation request,
#   * the seed-only platform admin approves it, so the user owns a group,
#   * a few posts are added so the feed has content to explore.
# Refuses to run against anything but a local backend.
set -euo pipefail

API="${API:-http://127.0.0.1:8080}"
case "$API" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) echo "seed.sh only talks to a local test backend, got API=$API" >&2; exit 1 ;;
esac

ADMIN_PHONE="${UI_TEST_ADMIN_PHONE:-+996700000900}"
ADMIN_CODE="${UI_TEST_ADMIN_CODE:-900900}"
USER_CODE="${UI_TEST_CODE:-111111}"

post() { # path token json
  local path="$1" token="$2" body="$3" out status
  out="$(mktemp)"
  if [ -n "$token" ]; then
    status="$(curl -sS -o "$out" -w '%{http_code}' -X POST "$API$path" \
      -H 'Content-Type: application/json' -H "Authorization: Bearer $token" --data "$body")"
  else
    status="$(curl -sS -o "$out" -w '%{http_code}' -X POST "$API$path" \
      -H 'Content-Type: application/json' --data "$body")"
  fi
  if [ "${status:0:1}" != "2" ]; then
    echo "POST $path -> HTTP $status: $(cat "$out")" >&2
    rm -f "$out"
    return 1
  fi
  cat "$out"
  rm -f "$out"
}

login() { # phone code display_name -> access token
  local phone="$1" code="$2" name="$3"
  post /api/auth/request-code "" "$(jq -nc --arg m "$phone" '{mobile:$m}')" >/dev/null
  post /api/auth/verify-code "" \
    "$(jq -nc --arg m "$phone" --arg c "$code" --arg n "$name" '{mobile:$m,code:$c,display_name:$n}')" \
    | jq -er .access_token
}

admin_token="$(login "$ADMIN_PHONE" "$ADMIN_CODE" "CI Platform Admin")"
echo "admin signed in"

seed_user() { # phone display_name group_title -> prints group id
  local phone="$1" name="$2" title="$3" token request_id group_id
  token="$(login "$phone" "$USER_CODE" "$name")"
  request_id="$(post /api/group-creation-requests "$token" "$(jq -nc --arg n "$name" --arg t "$title" '{
      applicant_name:$n, position:"Coordinator", organization_name:"Koom QA",
      organization_type:"community", region:"Bishkek", official_phone:"+996700000000",
      official_email:"qa@example.invalid", website:"", group_title:$t,
      group_description:"Seeded group for automated UI tests",
      reason:"Automated UI testing", documents:""}')" | jq -er .id)"
  group_id="$(post "/api/admin/group-creation-requests/$request_id/approve" "$admin_token" \
      '{"admin_comment":"ci seed"}' | jq -er .created_group_id)"
  local mode
  for mode in discussion vote_only read_only; do
    post "/api/groups/$group_id/requests" "$token" "$(jq -nc --arg m "$mode" '{
        request_type:"suggestion", interaction_mode:$m,
        title:("Seeded " + $m + " post"), body:"Seeded content for UI tests"}')" >/dev/null
  done
  echo "seeded $phone -> group $group_id ($title)" >&2
  echo "$group_id"
}

seed_user "${UI_TEST_JOURNEY_PHONE:-+996700000101}" "Maestro Journey" "Maestro QA Group" >/dev/null
# One account per Monkey round (see run-ui-tests.sh).
n=0
for phone in ${UI_TEST_MONKEY_PHONES:-+996700000102 +996700000103 +996700000104 +996700000105}; do
  n=$((n + 1))
  seed_user "$phone" "Monkey $n" "Monkey QA Group $n" >/dev/null
done
echo "seed complete"
