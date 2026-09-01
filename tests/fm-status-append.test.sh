#!/usr/bin/env bash
# Behavior tests for bin/fm-status-append.sh - the guarded status-line append
# helper that bin/fm-brief.sh routes a mode=no-mistakes ship task's status
# report through.
#
# This is the mechanical backstop for the 08-30/08-31 done-drift pattern: nine
# ship workers in a row reported `done: ... committed, gates green` without
# ever starting /no-mistakes, and prose alone (even an explicit capitalized
# DEFINITION OF DONE paragraph) did not stop three later occurrences. This
# helper refuses that exact line instead of silently appending it.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

HELPER="$ROOT/bin/fm-status-append.sh"
TMP_ROOT=$(fm_test_tmproot fm-status-append)

new_case() {  # <name> -> echoes case dir with a state/ dir, meta path, status path
  local d="$TMP_ROOT/$1"
  mkdir -p "$d/state"
  printf '%s\n' "$d"
}

test_script_parses() {
  local out rc
  out=$(bash -n "$HELPER" 2>&1); rc=$?
  expect_code 0 "$rc" "bash -n bin/fm-status-append.sh must parse cleanly (got: $out)"
  pass "fm-status-append.sh: bash -n succeeds"
}

test_refuses_premature_done_on_no_mistakes_without_url() {
  local d status meta out rc
  d=$(new_case refuse-no-url)
  status="$d/state/t1.status"
  meta="$d/state/t1.meta"
  printf 'kind=ship\nmode=no-mistakes\n' > "$meta"
  out=$("$HELPER" "$status" "done: committed, gates green" 2>&1); rc=$?
  expect_code 1 "$rc" "a premature done on a no-mistakes task must be refused"
  assert_contains "$out" "is not done" "refusal must explain why committed-with-gates-green is not done"
  assert_contains "$out" "Run /no-mistakes now" "refusal must print the exact next step"
  [ ! -e "$status" ] || fail "refused done must not be written to the status file"
  pass "fm-status-append.sh: refuses a premature no-mistakes done that names no PR URL"
}

# The DOD's earlier "done: {summary}" pseudo-terminal wording (fm-dod-lib.sh,
# before this fix) is exactly as unacceptable as free-text prose: no URL, no
# pass.
test_refuses_the_old_dod_summary_wording() {
  local d status meta out rc
  d=$(new_case refuse-summary-wording)
  status="$d/state/t1b.status"
  meta="$d/state/t1b.meta"
  printf 'kind=ship\nmode=no-mistakes\n' > "$meta"
  out=$("$HELPER" "$status" "done: implemented the fix" 2>&1); rc=$?
  expect_code 1 "$rc" "the retired 'done: {summary}' shape must still be refused"
  [ ! -e "$status" ] || fail "refused done must not be written to the status file"
  pass "fm-status-append.sh: refuses the retired done: {summary} wording"
}

test_allows_nonterminal_lines_on_no_mistakes() {
  local d status meta out rc
  d=$(new_case allow-working)
  status="$d/state/t2.status"
  meta="$d/state/t2.meta"
  printf 'kind=ship\nmode=no-mistakes\n' > "$meta"
  out=$("$HELPER" "$status" "working: implementation committed, starting /no-mistakes" 2>&1); rc=$?
  expect_code 0 "$rc" "a working: line must always be allowed (got: $out)"
  assert_contains "$(cat "$status")" "working: implementation committed" \
    "the working: line must be appended verbatim"
  pass "fm-status-append.sh: allows a nonterminal working: line on a no-mistakes task"
}

# The critical case: state/<id>.meta's pr= line is written by firstmate's own
# bin/fm-pr-check.sh only AFTER it sees this exact done report (AGENTS.md
# section 7), so pr= is NEVER present yet at the moment a worker legitimately
# reports it - gating on pr= would refuse every real completion. The line's
# own URL is what must carry the proof instead.
test_allows_done_with_no_pr_recorded_when_the_line_names_a_url() {
  local d status meta rc
  d=$(new_case allow-done-no-pr-yet)
  status="$d/state/t3.status"
  meta="$d/state/t3.meta"
  printf 'kind=ship\nmode=no-mistakes\n' > "$meta"
  "$HELPER" "$status" "done: PR https://github.com/x/y/pull/9 checks green"; rc=$?
  expect_code 0 "$rc" "done must be allowed on its own URL even with no pr= recorded yet (got rc=$rc)"
  assert_contains "$(cat "$status")" "checks green" "the done line must be appended verbatim"
  pass "fm-status-append.sh: allows a done: PR <url> ... line with no pr= recorded in meta yet"
}

# A recorded pr= (e.g. from a later re-report after firstmate already ran
# fm-pr-check.sh once) does not exempt a line that itself names no URL - the
# line's own shape is what is checked, not stale meta state.
test_recorded_pr_does_not_exempt_a_urlless_done_line() {
  local d status meta out rc
  d=$(new_case pr-recorded-but-no-url-in-line)
  status="$d/state/t3b.status"
  meta="$d/state/t3b.meta"
  printf 'kind=ship\nmode=no-mistakes\npr=https://github.com/x/y/pull/9\n' > "$meta"
  out=$("$HELPER" "$status" "done: committed, gates green" 2>&1); rc=$?
  expect_code 1 "$rc" "a urlless done line must be refused even with an unrelated pr= present in meta"
  [ ! -e "$status" ] || fail "refused done must not be written to the status file"
  pass "fm-status-append.sh: a recorded pr= does not exempt a done line that names no URL"
}

test_other_modes_never_gated_on_done() {
  local d mode status meta rc
  d=$(new_case other-modes)
  for mode in direct-PR local-only; do
    status="$d/state/$mode.status"
    meta="$d/state/$mode.meta"
    printf 'kind=ship\nmode=%s\n' "$mode" > "$meta"
    "$HELPER" "$status" "done: PR https://example.invalid/1"; rc=$?
    expect_code 0 "$rc" "$mode has no pipeline step to gate done behind"
    assert_contains "$(cat "$status")" "done: PR" "$mode done line must be appended verbatim"
  done
  pass "fm-status-append.sh: direct-PR and local-only tasks are never gated on a recorded pr="
}

test_missing_meta_never_gates_done() {
  local d status rc
  d=$(new_case no-meta)
  status="$d/state/t4.status"
  "$HELPER" "$status" "done: whatever"; rc=$?
  expect_code 0 "$rc" "a task with no meta file at all must not be gated (nothing to classify)"
  assert_contains "$(cat "$status")" "done: whatever" "the done line must still be appended"
  pass "fm-status-append.sh: a missing meta file never gates a done line"
}

test_non_done_lines_always_pass_through() {
  local d status meta
  d=$(new_case pass-through)
  status="$d/state/t5.status"
  meta="$d/state/t5.meta"
  printf 'kind=ship\nmode=no-mistakes\n' > "$meta"
  "$HELPER" "$status" "blocked: waiting on a decision"
  "$HELPER" "$status" "needs-decision: which library?"
  "$HELPER" "$status" "paused: upstream release pending"
  assert_contains "$(cat "$status")" "blocked: waiting on a decision" "blocked: must pass through"
  assert_contains "$(cat "$status")" "needs-decision: which library?" "needs-decision: must pass through"
  assert_contains "$(cat "$status")" "paused: upstream release pending" "paused: must pass through"
  pass "fm-status-append.sh: every non-done verb always passes through unguarded"
}

test_script_parses
test_refuses_premature_done_on_no_mistakes_without_url
test_refuses_the_old_dod_summary_wording
test_allows_nonterminal_lines_on_no_mistakes
test_allows_done_with_no_pr_recorded_when_the_line_names_a_url
test_recorded_pr_does_not_exempt_a_urlless_done_line
test_other_modes_never_gated_on_done
test_missing_meta_never_gates_done
test_non_done_lines_always_pass_through

echo "all fm-status-append tests passed"
