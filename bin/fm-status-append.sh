#!/usr/bin/env bash
# fm-status-append.sh - guarded status-line append for a crew's status file.
#
# A crewmate reports its own state by appending one line to state/<id>.status
# (AGENTS.md section 3's status protocol). For a mode=no-mistakes ship task,
# done only means the pipeline reported CI green with a recorded PR
# (bin/fm-pr-check.sh's pr= line in the sibling state/<id>.meta) -
# no-mistakes still owns review, fixes, tests, documentation, push, PR, and
# CI, so a worker that stops at "committed, gates green" without ever
# starting it is not done. Brief wording alone has repeatedly failed to stop
# that early stop (see git history for this file's introducing PR), so this
# is the mechanical backstop: bin/fm-brief.sh's generated no-mistakes ship
# brief routes its status-report command through this helper instead of a
# bare `echo ... >> status-file`. Other delivery modes and kinds keep the
# bare echo, since they have no pipeline step to skip.
#
# Usage: fm-status-append.sh <status-file> <status-line>
#   <status-file>  the crew's state/<id>.status path; its sibling
#                  state/<id>.meta (same basename, .meta instead of .status)
#                  is read for kind=, mode=, and pr=.
#   <status-line>  the exact line to append, e.g. "done: implemented".
#
# Refuses (exit 1, printing the required next step to stderr instead of
# appending) only a `done:` line on a mode=no-mistakes ship task whose meta
# has no pr= line yet. Every other line, mode, and kind appends exactly as a
# bare echo would - this is a drop-in replacement, not a new contract.
set -eu

[ $# -eq 2 ] || { echo "usage: fm-status-append.sh <status-file> <status-line>" >&2; exit 2; }
STATUS_FILE=$1
LINE=$2
META="${STATUS_FILE%.status}.meta"

meta_value() {  # <key>
  [ -f "$META" ] || return 0
  grep "^$1=" "$META" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

case "$LINE" in
  done:*)
    KIND=$(meta_value kind)
    [ -n "$KIND" ] || KIND=ship
    MODE=$(meta_value mode)
    if [ "$KIND" = ship ] && [ "$MODE" = no-mistakes ] && ! grep -q '^pr=' "$META" 2>/dev/null; then
      cat >&2 <<'EOF'
refused: this is a mode=no-mistakes task, so "committed, gates green" is not done.
Run /no-mistakes now and respond to its gates until it reports CI green, then
report done as: done: PR {url} checks green
EOF
      exit 1
    fi
    ;;
esac

mkdir -p "$(dirname "$STATUS_FILE")" 2>/dev/null || true
printf '%s\n' "$LINE" >> "$STATUS_FILE"
