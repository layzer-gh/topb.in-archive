#!/usr/bin/env bash
# Starts topb.in's gameweek tick at the two moments that can't wait for
# GitHub's scheduler, which delivers only a fraction of scheduled runs:
#
#  1. A played gameweek is signed off by FPL (data_checked) but not yet scored
#     here: start the tick so the receipt lands within minutes.
#  2. The next deadline is 2.5-6 hours away and no read inside 6 hours has been
#     frozen: start the tick so the final read exists.
#
# The tick itself decides what to do; this only makes sure it runs. It stays
# up while either moment is pending, then hands over to a fresh run before
# GitHub's 6-hour job limit. When nothing is pending it exits at once, without
# calling FPL.
set -uo pipefail

UA="Mozilla/5.0 (compatible; topb.in-watch)"
POLL=300                       # seconds between checks
LIFETIME=$((5 * 3600 + 1800))  # hand over to a fresh run after 5.5h
GAP=1800                       # never start the tick twice within 30 min
last_dispatch=0

now() { date -u +%s; }
log() { echo "$(date -u +%H:%MZ) $*"; }
epoch() { date -u -d "$1" +%s; }

dispatch() {
  if (( $(now) - last_dispatch < GAP )); then log "tick started recently; waiting"; return; fi
  # The REST call needs only the token's Actions permission (gh workflow run
  # also looks up the default branch, which this token can't read).
  if gh api -X POST repos/layzer-gh/topb.in/actions/workflows/tick.yml/dispatches -f ref=main --silent; then
    last_dispatch=$(now); log "started the tick: $1"
  else
    log "could not start the tick (token?)"
  fi
}

fpl() { curl -sf --retry 3 --retry-delay 20 -H "User-Agent: $UA" "https://fantasy.premierleague.com/api/$1"; }

# One pass: sets STATE to "active" while something is pending, else "idle".
# Runs in this shell (not a pipe) so the last-dispatch time carries over.
check() {
  # The tick writes here when it freezes or scores; read its latest state, or
  # this would keep starting ticks that have already done their job.
  if ! { git fetch -q --depth 1 origin main && git reset -q --hard origin/main; }; then
    log "could not read the archive; not starting anything this pass"; STATE=active; return
  fi
  local dir; dir=$(ls -d archive/*/ | sort | tail -1)
  local active=idle t; t=$(now)

  # 1. The oldest played, unscored gameweek.
  local pending=""
  for f in $(ls "$dir"gw*.json | sort -V); do
    if [ "$(jq -r '.actuals == null' "$f")" = true ] && (( $(epoch "$(jq -r .deadline "$f")") < t )); then
      pending=$(jq -r .gw "$f"); break
    fi
  done
  if [ -n "$pending" ]; then
    local boot checked lastko
    if boot=$(fpl bootstrap-static/ | jq -c "[.events[] | select(.id == $pending)][0] | {data_checked}"); then
      checked=$(echo "$boot" | jq -r .data_checked)
      if [ "$checked" = true ]; then
        dispatch "gameweek $pending signed off by FPL"; active=active
      else
        lastko=$(fpl "fixtures/?event=$pending" | jq -r '[.[].kickoff_time | select(. != null)] | max // empty')
        if [ -n "$lastko" ] && (( $(epoch "$lastko") + 7200 < t )); then
          log "gameweek $pending: last match over, waiting for FPL to sign it off"; active=active
        else
          log "gameweek $pending: matches still to finish"
        fi
      fi
    else
      log "FPL did not answer; will try again"; active=active
    fi
  fi

  # 2. The final read before the next deadline.
  local next; next=$(ls "$dir"gw*.json | sort -V | tail -1)
  local d hb; d=$(epoch "$(jq -r .deadline "$next")"); hb=$(jq -r .hoursBefore "$next")
  local left=$(( d - t ))
  if (( left > 9000 && left <= 21600 )); then
    if awk "BEGIN{exit !($hb > 6)}"; then
      dispatch "final read for gameweek $(jq -r .gw "$next") (latest frozen ${hb}h out)"; active=active
    else
      log "gameweek $(jq -r .gw "$next"): final read frozen ${hb}h out"
    fi
  elif (( left > 21600 && left <= 25200 )); then
    active=active  # stay up into the final-read window
  fi

  STATE=$active
}

start=$(now)
while :; do
  check
  [ "$STATE" = active ] || { log "nothing pending"; exit 0; }
  if (( $(now) - start > LIFETIME )); then
    gh api -X POST repos/layzer-gh/topb.in-archive/actions/workflows/watch.yml/dispatches -f ref=main --silent && log "handed over to a fresh run"
    exit 0
  fi
  sleep $POLL
done
