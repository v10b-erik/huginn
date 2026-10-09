#!/bin/bash
# Modellbruk per rolle — leser Claude Code-transkriptene direkte (ingen hook,
# ingen egen logg som kan drive fra sannheten).
#
#   Scripts/model-usage.sh                 # dette repoet (+ worktrees), siste 7 dager
#   Scripts/model-usage.sh --dager 30
#   Scripts/model-usage.sh --alle          # alle prosjekter på verten
#
# Rolle = hovedøkt | agenttypen fra <agent>.meta.json | workflow.
# Kost = Anthropic-listepris (1P). Vertex-fakturaen kan avvike — bruk tallene
# relativt (hvilken rolle spiser budsjettet), og fasit fra GCP-billing.
# Linjer merket ⚠ er arv: generiske agenter (general-purpose/workflow) på
# opus/fable — som regel et agent()/Agent-kall uten eksplisitt model.
set -euo pipefail

dager=7
alle=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dager) dager="$2"; shift 2 ;;
    --alle) alle=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "ukjent argument: $1" >&2; exit 2 ;;
  esac
done

rot=""
if [ "$alle" = 0 ]; then
  # Hovedtreet, også når skriptet kjøres fra en worktree.
  felles=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
    echo "ikke i et git-repo — bruk --alle" >&2; exit 2; }
  rot=$(dirname "$felles")
  # Økter startes like gjerne fra produktets JD-mappe i ~/basic (via .ygg-jd).
  jd=$(tr -d '[:space:]' < "$rot/.ygg-jd" 2>/dev/null || true)
  if [[ "$jd" =~ ^[0-9]{2}\.[0-9]{2}$ ]]; then
    for d in "$HOME"/basic/*/*/"${jd}"_*; do [ -d "$d" ] && rot="$rot:$d"; done
  fi
fi

python3 - "$dager" "$rot" <<'PY'
import json, sys, time, glob, os
from collections import defaultdict

dager = int(sys.argv[1])
røtter = tuple(r for r in sys.argv[2].split(':') if r)
grense = time.time() - dager * 86400

# $/MTok: input, output, cache-les. Cache-skriv = 1,25× (5m) / 2× (1t) input.
PRIS = {
    'claude-fable-5-1':  (10.0, 50.0, 0.25),
    'claude-fable-5':    (10.0, 50.0, 1.00),
    'claude-opus-5-5':   (4.0,  20.0, 0.20),
    'claude-opus-5':     (5.0,  25.0, 0.50),
    'claude-sonnet-5-5': (2.0,  10.0, 0.20),
    'claude-sonnet-5':   (2.0,  10.0, 0.20),
    'claude-haiku-5-5':  (0.10, 0.50, 0.01),
    'claude-haiku-4-5':  (1.0,  5.0,  0.10),
}

def pris(modell):
    m = modell.split('@')[0]
    return PRIS.get(m)

def rolle(sti):
    if '/subagents/' not in sti:
        return 'hovedøkt'
    meta = sti[:-len('.jsonl')] + '.meta.json'
    try:
        t = json.load(open(meta)).get('agentType', '?')
    except Exception:
        t = '?'
    return 'workflow' if t == 'workflow-subagent' else t

sum_ = defaultdict(lambda: [0, 0, 0, 0, 0, 0, 0.0])  # kall in skriv5 skriv1t les out $
ukjent = set()
sett = set()
filer = glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl')) + \
        glob.glob(os.path.expanduser('~/.claude/projects/*/*/subagents/**/*.jsonl'), recursive=True)
for sti in filer:
    if os.path.getmtime(sti) < grense:
        continue
    r = rolle(sti)
    with open(sti, errors='replace') as f:
        for linje in f:
            if '"assistant"' not in linje:
                continue
            try:
                d = json.loads(linje)
            except ValueError:
                continue
            if d.get('type') != 'assistant':
                continue
            if røtter and not (d.get('cwd') or '').startswith(røtter):
                continue
            m = d.get('message') or {}
            mid, modell, u = m.get('id'), m.get('model'), m.get('usage')
            if not (mid and modell and u) or modell == '<synthetic>':
                continue
            # Én API-respons skrives som flere linjer (én per innholdsblokk) med samme usage.
            if mid in sett:
                continue
            sett.add(mid)
            ts = d.get('timestamp', '')
            try:
                if time.mktime(time.strptime(ts[:19], '%Y-%m-%dT%H:%M:%S')) < grense:
                    continue
            except ValueError:
                pass
            cc = u.get('cache_creation') or {}
            s1t = cc.get('ephemeral_1h_input_tokens', 0) or 0
            s5 = (u.get('cache_creation_input_tokens', 0) or 0) - s1t
            inn, les, ut = u.get('input_tokens', 0) or 0, u.get('cache_read_input_tokens', 0) or 0, u.get('output_tokens', 0) or 0
            nøkkel = (r, modell.split('@')[0], d.get('effort') or '-')
            a = sum_[nøkkel]
            a[0] += 1; a[1] += inn; a[2] += s5; a[3] += s1t; a[4] += les; a[5] += ut
            p = pris(modell)
            if p:
                pi, po, pl = p
                a[6] += (inn * pi + s5 * pi * 1.25 + s1t * pi * 2 + les * pl + ut * po) / 1e6
            else:
                ukjent.add(modell)

if not sum_:
    print(f'Ingen modellkall siste {dager} dager' + (f' under {", ".join(røtter)}' if røtter else '') + '.')
    sys.exit(0)

tot = sum(a[6] for a in sum_.values()) or 1
mt = lambda n: f'{n/1e6:7.2f}'
print(f'Modellbruk siste {dager} dager' + (f' — {", ".join(røtter)}' if røtter else ' — alle prosjekter'))
print(f'{"rolle":<22}{"modell":<19}{"effort":<8}{"kall":>6}{"inn M":>8}{"skriv M":>8}{"les M":>8}{"ut M":>8}{"$":>9}{"andel":>7}')
for (r, modell, eff), a in sorted(sum_.items(), key=lambda kv: -kv[1][6]):
    arv = '⚠' if r in ('general-purpose', 'workflow') and ('opus' in modell or 'fable' in modell) else ' '
    print(f'{r[:21]:<22}{modell[:18]:<19}{eff:<8}{a[0]:>6}{mt(a[1])}{mt(a[2]+a[3]):>8}{mt(a[4]):>8}{mt(a[5]):>8}{a[6]:>9.2f}{100*a[6]/tot:>6.0f}%{arv}')
print(f'{"sum":<55}{"":>32}{tot:>9.2f}')
if ukjent:
    print('Uten pris (ikke regnet med):', ', '.join(sorted(ukjent)))
if any(r in ('general-purpose', 'workflow') and ('opus' in m or 'fable' in m) for (r, m, _) in sum_):
    print('⚠ = generisk agent på topptier: sett model/effort eksplisitt i agent()/Agent-kallet.')
PY
