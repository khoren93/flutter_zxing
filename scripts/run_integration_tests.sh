#!/usr/bin/env bash

# Runs the example app's integration tests on one device, one file per run.
#
# Usage: scripts/run_integration_tests.sh [device]
#   device: passed to `flutter test -d`; omit it to use the only device attached.
#           `linux` runs the tests under a virtual X server.
#
# Why one file per run: a desktop app cannot be started a second time within
# one `flutter test` ("Unable to start the app on the device").
#
# Why the time limit: on CI runners the app sometimes never connects to
# `flutter test` after it has been launched, mostly on the iOS simulator, and
# the run then waits until the whole job times out. A run that takes longer than
# RUN_TIMEOUT seconds is stopped and retried once. A test that fails is not
# retried.

set -uo pipefail

DEVICE="${1:-}"
RUN_TIMEOUT="${RUN_TIMEOUT:-720}"

cd "$(git rev-parse --show-toplevel)/example"

run() {
  local cmd=(flutter test "$1")
  if [ -n "$DEVICE" ]; then
    cmd+=(-d "$DEVICE")
  fi
  if [ "$DEVICE" == "linux" ]; then
    # `-a` picks a free display: the Xvfb of the previous run may still hold :99.
    cmd=(xvfb-run -a "${cmd[@]}")
  fi
  if [ "${RUNNER_OS:-}" == "Windows" ]; then
    "${cmd[@]}"
  else
    # `alarm` survives `exec`, so the run is killed with SIGALRM (status 142).
    perl -e 'alarm shift; exec @ARGV' "$RUN_TIMEOUT" "${cmd[@]}"
  fi
}

for test in integration_test/*_test.dart; do
  for attempt in 1 2; do
    run "$test"
    status=$?
    if [ "$status" -eq 0 ]; then
      break
    fi
    if [ "$status" -ne 142 ] || [ "$attempt" -eq 2 ]; then
      echo "$test failed (exit status $status)" >&2
      exit "$status"
    fi
    echo "::warning::$test hung and was stopped after ${RUN_TIMEOUT}s, retrying"
  done
done
