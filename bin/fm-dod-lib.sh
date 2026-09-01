#!/usr/bin/env bash
# Single owner of a ship task's mode-specific "Definition of done" block, and of
# the mode-specific status-report command that goes with it.
# Sourced by bin/fm-brief.sh, which renders both into a generated ship brief, and by
# bin/fm-promote.sh, which renders both into the ship instructions a promoted scout
# receives. Both paths must hand the worker the same contract: a promoted
# no-mistakes worker that never received the ask-user escalation rule, the
# `--yes` ban, or the guarded status-report command is the exact delivery hole
# this single owner exists to close.
# fm_dod_block <no-mistakes|direct-PR|local-only> <task-id> prints the block on
# stdout with no trailing blank line. The caller validates the mode; an unknown
# mode is refused rather than silently rendered as the pipeline contract.
# The block opens with the fixed machine-readable "Delivery contract: mode=<mode>"
# line that bin/fm-spawn.sh checks a ship brief against.
# fm_status_report_line <mode> <fm-root> <quoted-status-file> prints the exact
# status-report command a worker on that mode must run: the guarded
# bin/fm-status-append.sh helper for mode=no-mistakes (the only mode with a
# pipeline step to skip), otherwise the bare `echo ... >> status-file` every
# other mode keeps. fm_status_report_guard_note <mode> <quoted-status-file>
# prints the accompanying warning against bypassing the helper (empty for
# every mode but no-mistakes), formatted to append inline after a sentence
# (leading newline, no trailing one).
# Every heredoc here stays outside a command substitution: `VAR=$(cat <<EOF ...)`
# breaks parsing of the whole file on Bash 3.2 (tests/fm-brief.test.sh).

fm_dod_block() {  # <mode> <task-id>
  local mode=$1 id=$2
  case "$mode" in
    direct-PR)
      cat <<EOF
# Definition of done
Delivery contract: mode=direct-PR
This task ships **direct-PR**: you raise the PR yourself, without the no-mistakes pipeline.
The task is complete only when committed on your branch.
When it is implemented and committed, push your branch and open a PR with \`gh-axi\`, then append \`done: PR {url}\` to the status file and stop.
Do NOT run /no-mistakes. The configured merge authority decides whether to merge the PR; firstmate relays the outcome.
EOF
      ;;
    local-only)
      cat <<EOF
# Definition of done
Delivery contract: mode=local-only
This task ships **local-only**: no remote, no PR, no pipeline.
The task is complete only when committed on your branch \`fm/$id\`. Do NOT push, do NOT open a PR, do NOT merge.
Keep your branch a clean fast-forward onto the current default branch - if \`main\` has advanced, rebase onto it so the eventual merge stays a fast-forward.
When it is implemented and committed, append \`done: ready in branch fm/$id\` to the status file and stop.
The configured merge authority approves the ready branch, then firstmate merges it into local \`main\` through the guarded fast-forward path.
EOF
      ;;
    no-mistakes)
      cat <<EOF
# Definition of done
Delivery contract: mode=no-mistakes
"Committed, gates green" is NOT done. This mode still owns review, fixes, tests,
documentation, push, PR, and CI, and YOU drive that pipeline - firstmate does not
send you a follow-up instruction to start it. The one and only \`done:\` this task
ever reports is after CI is green with a PR; there is no earlier or intermediate
done state, so never append \`done:\` for the implementation/commit alone.

The moment your implementation is committed on your branch, in the SAME turn:
1. Append \`working: implementation committed, starting /no-mistakes\` to the status file (nonterminal - do not stop here).
2. Immediately invoke /no-mistakes yourself. Do not stop and wait for a firstmate instruction between the commit and this step.

You drive no-mistakes by responding to its gates, not by implementing fixes.
Follow the guidance no-mistakes itself provides for the mechanics: it loads when you invoke /no-mistakes, and \`no-mistakes axi run --help\` plus the \`help\` lines in each \`axi\` response are authoritative and version-matched to the installed binary.
When starting no-mistakes, make \`--intent\` preserve all relevant content from this brief's \`# Task\` section plus every later accepted Firstmate requirement, clarification, constraint, exclusion, and supersession, carrying only each requirement's current accepted form; retain direct requirements instead of substituting a diff summary, and exclude generic operational, status, delivery, and other scaffold boilerplate unless it is task-specific.
Do not hand-edit, commit, or fix findings yourself while a run is active - the pipeline applies every fix.

Two firstmate-specific rules layer on top of that guidance:
- ask-user findings are never yours to answer: escalate to firstmate (rule 6) and stop.
  Firstmate applies \`ask-user-authority\` and obtains any required captain decision.
  When the decision comes back, feed it to the gate with \`no-mistakes axi respond\` and let the pipeline apply it - do not route the question to "the user" or implement the fix yourself.
- NEVER pass \`--yes\` (or \`-y\`) to \`no-mistakes axi run\` or \`no-mistakes axi respond\`. It is banned fleet-wide.
  It auto-resolves every gate including ask-user findings with no escalation, and answering your own ask-user finding is a hard rule violation.

After /no-mistakes reports CI green (the CI-ready return point - do not wait for it to keep monitoring in the background until merge), append \`done: PR {url} checks green\` and stop. You are finished.
EOF
      ;;
    *)
      echo "error: fm_dod_block: unknown delivery mode '$mode'" >&2
      return 1 ;;
  esac
}

fm_status_report_line() {  # <mode> <fm-root> <quoted-status-file>
  local mode=$1 fm_root=$2 status_file_q=$3
  case "$mode" in
    no-mistakes)
      printf '%s %s "{state}: {one short line}"' "$(printf '%q' "$fm_root/bin/fm-status-append.sh")" "$status_file_q"
      ;;
    *)
      printf 'echo "{state}: {one short line}" >> %s' "$status_file_q"
      ;;
  esac
}

fm_status_report_guard_note() {  # <mode> <quoted-status-file>
  local mode=$1 status_file_q=$2
  [ "$mode" = no-mistakes ] || return 0
  cat <<EOF

   This mode=no-mistakes task's status file is guarded: appending \`done:\` this way is refused, with the exact next step printed instead, until \`no-mistakes\` has recorded a validated PR for this task. Never bypass the helper with a bare \`echo ... >> $status_file_q\`.
EOF
}
