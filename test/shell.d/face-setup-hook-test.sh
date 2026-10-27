#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

hook="$ROOT/install/user/first-run/setup-face.hook"
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
log="$test_tmp/calls.log"
copy="$test_tmp/setup-face.hook"
mkdir -p "$stub_bin"

sed -e "s|/etc/omarchy/face.conf|$test_tmp/face.conf|" "$hook" >"$copy"

cat >"$stub_bin/omarchy-hw-dell-xps-ir-camera" <<'SH'
#!/bin/bash
[[ $# == 0 && $TEST_HW == 1 ]]
SH
cat >"$stub_bin/omarchy-done" <<'SH'
#!/bin/bash
[[ $* == "ensure face-setup-invitation" ]]
SH
cat >"$stub_bin/omarchy-notification-send" <<'SH'
#!/bin/bash
printf 'notify %s\n' "$*" >>"$TEST_LOG"
SH
chmod +x "$stub_bin"/*

# invoke <camera fitted: 1 or 0>
invoke() {
  : >"$log"
  TEST_LOG="$log" TEST_HW="$1" PATH="$stub_bin:/usr/bin:/bin" bash "$copy" || fail "the hook never fails the first run"
}

invoke 1
grep -q 'notify .*omarchy-setup-security-face' "$log" || fail "a fitted camera without a setup gets the invitation, driver or not" "$(cat "$log")"
invoke 0
[[ ! -s $log ]] || fail "a machine without the camera gets no invitation" "$(cat "$log")"
: >"$test_tmp/face.conf"
invoke 1
[[ ! -s $log ]] || fail "a finished setup gets no invitation" "$(cat "$log")"
pass "the hook invites to the setup only while a fitted camera is not set up"
