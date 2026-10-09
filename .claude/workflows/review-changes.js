export const meta = {
  name: 'review-changes',
  description: 'Review uncommittede/branch-endringer langs fire akser, adversarially verifisert',
  whenToUse: 'Før merge eller når Erik ber om review av endringene',
  phases: [
    { title: 'Review', detail: 'fire akser i parallell på diffen' },
    { title: 'Verify', detail: 'hvert funn angripes av en skeptiker' },
  ],
}

// args (valgfri): { base: "main" } — diff-grunnlag; default HEAD (uncommittet arbeid)
const base = (args && args.base) ? args.base : 'HEAD'

// Modell per fase. Uten eksplisitt model arver agent() hovedøkta — i v10b ga det
// 21 % av forbruket på opus til generiske agenter (Scripts/model-usage.sh).
// Review er kandidatleting (bredt, billig); verify er dommen som avgjør merge.
const TIER = {
  review: { model: 'sonnet', effort: 'high' },
  verify: { model: 'opus', effort: 'high' },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'line', 'summary', 'failureScenario', 'severity'],
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          summary: { type: 'string' },
          failureScenario: { type: 'string', description: 'Konkret input/tilstand → galt utfall' },
          severity: { type: 'string', enum: ['critical', 'major', 'minor'] },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['isReal', 'reasoning'],
  properties: {
    isReal: { type: 'boolean' },
    reasoning: { type: 'string' },
  },
}

const AXES = [
  { key: 'korrekthet', prompt: 'kantverdier, feilhåndtering, samtidighet, brutte antakelser' },
  { key: 'sikkerhet', prompt: 'injeksjon, secrets i kode/logg, tillitsgrenser (server er eksponert)' },
  { key: 'tester', prompt: 'mangler det tester som ville fanget regresjonen? TDD-postur: tester i samme commit' },
  { key: 'enkelhet', prompt: 'unødvendig abstraksjon, duplisering mot packages/shared, død kode' },
  {
    key: 'hig',
    prompt:
      'KUN hvis diffen rører SwiftUI/UI-kode i apple/ (ellers: tomt funn-array). ' +
      'Les .claude/skills/hig-design/SKILL.md og vurder mot sjekklisten der: web-mønstre i SwiftUI-drakt, ' +
      'hardkodede størrelser/farger (Dynamic Type/mørk modus), egne komponenter der standard finnes, ' +
      'manglende accessibility-identifier/-label, navigasjon utenfor HIG-mønstre',
  },
]

phase('Review')
const results = await pipeline(
  AXES,
  axe =>
    agent(
      `Kjør \`git diff ${base}\` (og \`git status --porcelain\` for utrackede filer) i dette repoet og review endringene UTELUKKENDE langs aksen «${axe.key}»: ${axe.prompt}. ` +
        `Les omkringliggende kode ved behov. Rapporter kun reelle funn med konkret feilscenario — ingen stilsynsing, ingen hypotetiske «kunne kanskje». Tomt funn-array er et gyldig og godt svar.`,
      { label: `review:${axe.key}`, phase: 'Review', schema: FINDINGS_SCHEMA, ...TIER.review },
    ),
  (review, axe) =>
    parallel(
      (review ? review.findings : []).slice(0, 6).map(f => () =>
        agent(
          `Vær skeptikeren: prøv å AVKREFTE dette review-funnet i repoet. Funn (akse ${axe.key}): ${f.file}:${f.line} — ${f.summary}. Påstått feilscenario: ${f.failureScenario}. ` +
            `Les koden selv. Er scenarioet faktisk mulig? Ved tvil: isReal=false.`,
          { label: `verify:${f.file}:${f.line}`, phase: 'Verify', schema: VERDICT_SCHEMA, ...TIER.verify },
        ).then(v => ({ ...f, axis: axe.key, verdict: v })),
      ),
    ),
)

const confirmed = results
  .flat()
  .filter(Boolean)
  .filter(f => f.verdict && f.verdict.isReal)

log(`${confirmed.length} bekreftede funn etter adversarial verifisering`)
return {
  confirmed,
  conclusion: confirmed.some(f => f.severity !== 'minor') ? 'ENDRINGER KREVES' : 'GODKJENT',
}
