#!/bin/bash
# Felles hjelpere for worktree-parallellitet. Denne fila SOURCES, den kjøres ikke:
#   . "$(dirname "$0")/wt-lib.sh"
#
# Må virke i bash 3.2 (macOS' /bin/bash): ingen assoc-arrays, ingen `{fd}>`.
# Låsene er mkdir-baserte fordi `flock` ikke finnes på macOS.

# ---------------------------------------------------------------- nøkkel ----
# Nøkkelen som skiller worktreene fra hverandre. Hovedtreet beholder produkt-
# navnet (så eksisterende byggmapper og DerivedData ikke invalideres); linked
# worktrees får <produkt>-<branch>.
#
# Produktdelen leses av --git-common-dir, som peker på HOVEDrepoets .git også
# fra en linked worktree. Uten det ville en worktree under
# .claude/worktrees/<navn> fått mappenavnet — altså branchnavnet alene — som
# nøkkel, og to produkter med samme branchnavn ville skrevet over hverandre.
wt_key() {
  local gcd gd prod br
  gcd="$(git rev-parse --git-common-dir 2>/dev/null)" || { basename "$PWD"; return; }
  gcd="$(cd "$gcd" && pwd)"
  gd="$(git rev-parse --absolute-git-dir 2>/dev/null || echo "$gcd")"
  prod="$(basename "$(dirname "$gcd")")"
  if [ "$gd" = "$gcd" ]; then
    printf '%s\n' "$prod"          # hovedtreet
    return
  fi
  br="$(git branch --show-current 2>/dev/null)"
  [ -n "$br" ] || br="detached-$(git rev-parse --short HEAD 2>/dev/null || echo ukjent)"
  printf '%s' "${prod}-${br}" | tr '/ ' '--' | tr -cd 'A-Za-z0-9._-'
  printf '\n'
}

# ------------------------------------------------------------------ låser ----
_WT_HELD=""

_wt_release() {
  local d
  for d in $_WT_HELD; do rm -rf "$d"; done
  _WT_HELD=""
}

# Prøv å ta én lås. Rydder opp etter en eier som ikke lever lenger (kill -9,
# strømbrudd) — ellers hadde en kræsj blokkert alle senere bygg.
_wt_take() {
  local eier
  if mkdir "$1" 2>/dev/null; then
    echo $$ >"$1/pid"
    _WT_HELD="$_WT_HELD $1"
    trap _wt_release EXIT INT TERM
    return 0
  fi
  eier="$(cat "$1/pid" 2>/dev/null || true)"
  if [ -n "$eier" ] && ! kill -0 "$eier" 2>/dev/null; then
    rm -rf "$1"
  fi
  return 1
}

# Eksklusiv lås:  wt_lock <navn> [maks-vent-sekunder]
wt_lock() {
  local dir="/tmp/devrig-lock-$1" maks="${2:-1800}" ventet=0
  while ! _wt_take "$dir"; do
    if [ "$ventet" -ge "$maks" ]; then
      echo "wt_lock: ga opp etter ${maks}s på $dir — er den foreldreløs? rm -rf $dir" >&2
      return 75
    fi
    [ "$ventet" -eq 0 ] && echo "== venter på lås «$1» ==" >&2
    sleep 3
    ventet=$((ventet + 3))
  done
}

# Semafor med N plasser:  wt_slot <navn> <antall> [maks-vent-sekunder]
# Setter WT_SLOT til plassnummeret. Poenget er RAM og CPU på byggeverten —
# hver bootet simulator koster ~1–2 GB, og Mac-mini-en har en grense.
wt_slot() {
  local navn="$1" n="${2:-2}" maks="${3:-1800}" ventet=0 i
  while :; do
    i=1
    while [ "$i" -le "$n" ]; do
      if _wt_take "/tmp/devrig-slot-$navn-$i"; then
        WT_SLOT="$i"
        return 0
      fi
      i=$((i + 1))
    done
    if [ "$ventet" -ge "$maks" ]; then
      echo "wt_slot: ga opp etter ${maks}s på «$navn» ($n plasser)" >&2
      return 75
    fi
    [ "$ventet" -eq 0 ] && echo "== venter på byggeplass ($n opptatt) ==" >&2
    sleep 3
    ventet=$((ventet + 3))
  done
}
